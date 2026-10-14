import sqlite3
import unittest
import hashlib
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

import bluebooks_local as local
import term_hygiene as hygiene


class TermHygieneTests(unittest.TestCase):
    def test_decorations_and_scientific_notation(self):
        for raw, expected in (
            (" Tumour\u2020 ", "Tumour"),
            ("Tumour\u2021*;.", "Tumour"),
            ("* Tumour*", "Tumour"),
            ("*\t Tumour \u2020", "Tumour"),
            ("Tumour [[Author. Book; citation]]", "Tumour"),
            ("Tumour << see section 1.9 >>", "Tumour"),
            ("Tumour ( \tSee: section 1)", "Tumour"),
            ("Tumour <<\tsee section >>\t", "Tumour"),
            ("Tumour << see section >>\u2020", "Tumour"),
            ("Tumour (seed variant)", "Tumour (seed variant)"),
            ("\u2022 Tumour:", "Tumour"),
            ("Ph+", "Ph+"), ("HER2\u207a", "HER2\u207a"),
            ("CD4\u207a/CD8\u207b", "CD4\u207a/CD8\u207b"),
            ("H\u2082O", "H\u2082O"), ("del(5q)", "del(5q)"),
            ("Tumour (grade II)", "Tumour (grade II)"),
            ("Rearrangement (-)", "Rearrangement (-)"),
        ):
            with self.subTest(raw=raw):
                self.assertEqual(hygiene.clean_term_ending(raw), expected)
        self.assertIsNone(hygiene.clean_term_ending(None))

    def test_composition_not_legacy_clean(self):
        self.assertEqual(hygiene.term_keys("Tumour, NOS\u2020"),
                         ("Tumor, NOS", "Tumor"))
        self.assertEqual(hygiene.term_keys("oesophageal tumour type II"),
                         ("Esophageal tumor type II", "Esophageal tumor 2"))
        self.assertEqual(hygiene.term_keys(None), (None, None))
        with self.assertRaisesRegex(ValueError, "600"):
            hygiene.term_keys("x" * 601)
        with self.assertRaisesRegex(ValueError, "4000"):
            hygiene.term_keys("x" * 4001)

    def test_insert_update_and_indexed_keys(self):
        con = sqlite3.connect(":memory:")
        self.addCleanup(con.close)
        local.migrate_sqlite(con)
        con.execute("PRAGMA recursive_triggers=ON")
        con.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Test','local:book')")
        con.execute(
            "INSERT INTO pages(page_id,book_id,site_page_id,url) VALUES(1,1,1,'local:page')"
        )
        con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        con.execute(
            "INSERT INTO entity_codes(page_id,ordinal,term,code) "
            "VALUES(1,0,'Tumour, NOS\u2020','8140/3')"
        )
        self.assertEqual(
            con.execute("SELECT term,TermUS,TermNormUS FROM entity_codes").fetchone(),
            ("Tumour, NOS", "Tumor, NOS", "Tumor"),
        )
        con.execute("UPDATE entity_codes SET term='Oesophageal tumour type II*'")
        self.assertEqual(
            con.execute("SELECT TermUS,TermNormUS FROM entity_codes").fetchone(),
            ("Esophageal tumor type II", "Esophageal tumor 2"),
        )
        con.execute("UPDATE entity_codes SET TermUS='wrong',TermNormUS='wrong'")
        self.assertEqual(hygiene.validate_terms(con)["entity_codes"], 0)
        for table in hygiene.TERM_SOURCES:
            for col in hygiene.TERM_COLUMNS:
                plan = con.execute(
                    f"EXPLAIN QUERY PLAN SELECT * FROM [{table}] WHERE [{col}]=?", ("Tumor",)
                ).fetchone()[3]
                self.assertIn("SEARCH", plan)
        con.commit()
        local.migrate_sqlite(con)
        self.assertTrue(all(count == 0 for count in hygiene.refresh_terms(con).values()))

    def test_parser_preserves_source_but_cleans_term(self):
        parser = local.companion("bb_entity_extract")
        html = (
            '<div class="description"><p>ICD-O coding</p>'
            '<p>8140/3 Tumour<sup>\u2020</sup></p></div>'
            '<div class="description"><p>Related terminology</p>'
            '<p>Acceptable: Neoplasm*; HER2\u207a</p></div>'
            '</app-chaptercontent>'
        )
        parsed = parser.parse_entity_page(html)
        self.assertEqual(parsed.coded_terms[0].term, "Tumour")
        self.assertEqual(parsed.acceptable, ["Neoplasm", "HER2\u207a"])
        self.assertIn("\u2020", parsed.sections["ICD-O coding"])

    def test_related_section_boundary_and_subtype_prose(self):
        parser = local.companion("bb_entity_extract")
        html = (
            '<div class="description"><p>Related terminology</p>'
            '<p><b>Acceptable:</b> Breast tumour.</p>'
            '<p><b>Histopathology</b></p>'
            '<p>Histological text is a description, not a term.</p>'
            '<p><b>Subtype(s)</b></p>'
            '<p>Various morphological subtypes may be identified in this tumour.</p>'
            '</div></app-chaptercontent>'
        )
        parsed = parser.parse_entity_page(html)
        self.assertEqual(parsed.acceptable, ["Breast tumour"])
        self.assertEqual(parsed.related_other, [])
        self.assertEqual(parsed.subtypes, [])
        self.assertIn("Histological text", parsed.sections["Histopathology"])

    def test_citation_does_not_delete_genuine_term(self):
        parser = local.companion("bb_entity_extract")
        html = (
            '<div class="description"><p>Subtype(s)</p>'
            '<p>atypical pseudoangiomatous stromal hyperplasia '
            '[[Author. Book. Publisher; 2026.]]</p>'
            '<p>Malignant granular cell tumour (see another volume '
            '[[WHO. Book; 2026.]])</p></div>'
            '<div class="description"><p>Related terminology</p>'
            '<p>Acceptable:</p></div></app-chaptercontent>'
        )
        parsed = parser.parse_entity_page(html)
        self.assertEqual([item.term for item in parsed.subtypes], [
            "Atypical pseudoangiomatous stromal hyperplasia", "Malignant granular cell tumour"
        ])
        self.assertEqual(parsed.related_other, [])
        self.assertFalse(parser.is_term_prose(
            "Carney triad (restricted to disease where no germline variant has been identified)"
        ))

    def test_code_after_parenthesized_name_is_not_a_term(self):
        con = sqlite3.connect(":memory:")
        self.addCleanup(con.close)
        local.migrate_sqlite(con)
        con.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Test','local:book')")
        con.execute(
            "INSERT INTO pages(page_id,book_id,site_page_id,url) VALUES(1,1,1,'local:page')"
        )
        con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        con.execute(
            "INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype) "
            "VALUES(1,0,'Breast tumour','8140/3',1)"
        )
        self.assertEqual(
            local.code_display_term(con, 1, "8140/3", "Subtype(s)", ")"), "Breast tumour"
        )
        self.assertIsNone(
            local.code_display_term(con, 1, "8140/3", "Clinical features", ").")
        )

    def test_ascii_initial_only_and_reference_triggers(self):
        for raw, expected in (
            ("tumour NOS", "Tumour NOS"), ("p53-mutant tumour", "P53-mutant tumour"),
            ("t(11;22) tumour", "T(11;22) tumour"), ("2-cell tumour", "2-cell tumour"),
            ("\u03b2-catenin tumour", "\u03b2-catenin tumour"),
            ("(lowercase) tumour", "(lowercase) tumour"), ("", ""), (None, None),
        ):
            self.assertEqual(hygiene.upper_initial(raw), expected)
        con = sqlite3.connect(":memory:")
        self.addCleanup(con.close)
        local.migrate_sqlite(con)
        con.execute("PRAGMA recursive_triggers=ON")
        con.execute("INSERT INTO icdo4_morphology(row_id,term,term_clean) VALUES(1,'c-ALL','c ALL')")
        self.assertEqual(con.execute("SELECT term,term_clean FROM icdo4_morphology").fetchone(),
                         ("C-ALL", "C ALL"))
        con.execute("UPDATE icdo4_morphology SET term='\u03b2-cell'")
        self.assertEqual(con.execute("SELECT term FROM icdo4_morphology").fetchone()[0], "\u03b2-cell")
        self.assertEqual(hygiene.upper_initial("a" + "b" * 3999), "A" + "b" * 3999)

    def test_explicit_context_recovers_all_shared_code_names(self):
        self.assertEqual(local.explicit_code_terms(
            "Neuroendocrine tumour, grade 2 (8249/3); neuroendocrine tumour, grade 3 (8249/3)",
            "8249/3"), ["Neuroendocrine tumour, grade 2", "Neuroendocrine tumour, grade 3"])
        self.assertEqual(local.explicit_code_terms(
            "Anal gland (anal duct) adenocarcinoma (82150/3)", "82150/3"),
            ["Anal gland (anal duct) adenocarcinoma"])
        self.assertEqual(local.explicit_code_terms(
            "Acceptable: Burkitt cell leukaemia (9826/3).", "9826/3"), ["Burkitt cell leukaemia"])
        self.assertEqual(local.explicit_code_terms(
            "For example, 8500/3 (Carcinoma of no special type) or 8520/3 (Invasive lobular carcinoma).",
            "8500/3"), ["Carcinoma of no special type"])
        self.assertEqual(local.explicit_code_terms(
            "Leiomyosarcoma\u00a0\u00a0 8890/3\nAdenosarcoma 8933/3", "8890/3"),
            ["Leiomyosarcoma"])
        self.assertEqual(local.explicit_code_terms(
            "The classification applies to choriocarcinoma (9100/3), invasive hydatidiform mole (9100/1), "
            "and placental site trophoblastic tumour (9104/1).", "9100/3"), ["Choriocarcinoma"])
        self.assertEqual(local.explicit_code_terms("The tumour can be coded 8140/3 in some cases.", "8140/3"), [])

    def test_code_rebuild_preserves_shared_names_and_evidence_matching(self):
        con = sqlite3.connect(":memory:")
        self.addCleanup(con.close)
        local.migrate_sqlite(con)
        con.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Test','local:book')")
        con.execute(
            "INSERT INTO pages(page_id,book_id,site_page_id,url,title) "
            "VALUES(1,1,1,'local:page','neuroendocrine tumour, grade 2')"
        )
        con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        for ordinal, name in enumerate(("neuroendocrine tumour, grade 2", "neuroendocrine tumour, grade 3")):
            con.execute(
                "INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype) VALUES(1,?,?, '8249/3',1)",
                (ordinal, name),
            )
        con.execute(
            "INSERT INTO sections(page_id,heading,body_text,ord) VALUES(1,'Subtype(s)',?,1)",
            ("neuroendocrine tumour, grade 2 (8249/3); neuroendocrine tumour, grade 3 (8249/3)",),
        )
        local._codes(con)
        self.assertEqual(con.execute(
            "SELECT term_in_coding_section FROM page_icdo_codes ORDER BY code_id"
        ).fetchall(), [("Neuroendocrine tumour, grade 2",), ("Neuroendocrine tumour, grade 3",)])
        con.execute(
            "INSERT INTO icdo_site_specific_terms(term_id,source_sheet,icdo_code,icdo_code_raw,"
            "icdo_term,term_clean,site_specific_flag) VALUES(1,'test','8249/3','8249/3',"
            "'neuroendocrine tumour, grade 2','neuroendocrine tumor grade 2','Yes')"
        )
        local._evidence(con)
        self.assertGreater(con.execute(
            "SELECT COUNT(*) FROM page_term_mentions WHERE source_kind='page_title' "
            "AND term_original='Neuroendocrine tumour, grade 2'"
        ).fetchone()[0], 0)
        self.assertTrue(all(v == 0 for v in hygiene.validate_terms(con).values()))

    def test_confirmed_nonterm_section_leakage(self):
        con = sqlite3.connect(":memory:")
        self.addCleanup(con.close)
        local.migrate_sqlite(con)
        con.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Test','local:book')")
        html = (
            '<div class="description"><p>Related terminology</p>'
            '<p>Acceptable: Breast tumour.</p>'
            '<p><b>Etiology</b></p><p>Unknown</p></div></app-chaptercontent>'
        )
        con.execute(
            "INSERT INTO pages(page_id,book_id,site_page_id,url,raw_html) "
            "VALUES(1,1,1,'local:page',?)", (html,)
        )
        con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        con.execute(
            "INSERT INTO entity_related_terms(related_term_id,page_id,kind,term) "
            "VALUES(1,1,'other','Unknown')"
        )
        con.execute(
            "INSERT INTO entity_related_terms(related_term_id,page_id,kind,term) "
            "VALUES(2,1,'acceptable','Breast tumour')"
        )
        self.assertEqual(local.plan_nonterm_removal(con)["entity_related_terms"], [1])

    def test_related_term_parser_preserves_semicolons_inside_cytogenetic_terms(self):
        extractor = local.companion("bb_entity_extract")
        self.assertEqual(
            extractor._split_top_level("first (qualifier; detail); second"),
            ["first (qualifier; detail)", " second"],
        )
        self.assertEqual(
            extractor._split_top_level("broken (first; second"),
            ["broken (first", " second"],
        )
        parsed = extractor.parse_entity_page(
            '<div class="description"><p>Related terminology</p>'
            '<p>Not recommended: NUT-rearranged carcinoma; '
            't(15;19) carcinoma; carcinoma with t(15;19) translocation; '
            'aggressive t(15;19)-positive carcinoma.</p></div>',
            "NUT carcinoma",
        )
        self.assertEqual(
            parsed.not_recommended,
            [
                "NUT-rearranged carcinoma",
                "T(15;19) carcinoma",
                "Carcinoma with t(15;19) translocation",
                "Aggressive t(15;19)-positive carcinoma",
            ],
        )

    def test_related_term_parser_handles_qualified_labels_and_omits_editorial_text(self):
        extractor = local.companion("bb_entity_extract")
        parsed = extractor.parse_entity_page(
            '<div class="description"><p>Related terminology</p>'
            '<p>Acceptable (in familial cases): hereditary leiomyomatosis '
            'and renal cell carcinoma (HLRCC) syndrome-associated renal cell carcinoma.</p>'
            '<p>See section Lynch syndrome.</p>'
            '<p>Related terminology is similar to that for invasive carcinoma '
            'of the female breast.</p></div>',
            "Fumarate hydratase-deficient renal cell carcinoma",
        )
        self.assertEqual(
            parsed.acceptable,
            [
                "Hereditary leiomyomatosis and renal cell carcinoma "
                "(HLRCC) syndrome-associated renal cell carcinoma"
            ],
        )
        self.assertEqual(parsed.not_recommended, [])
        self.assertEqual(parsed.related_other, [])

    def test_reference_relocation_requires_identical_bytes(self):
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            relocated = root / "Library" / "references" / "input.csv"
            relocated.parent.mkdir(parents=True)
            relocated.write_bytes(b"same")
            original = root / "references" / "input.csv"
            with patch.object(local, "COMPANION", root):
                expected = hashlib.sha256(b"same").hexdigest()
                self.assertEqual(local.validate_reference_hashes({str(original): expected}),
                                 {str(relocated): expected})
                with self.assertRaisesRegex(ValueError, "Reference changed"):
                    local.validate_reference_hashes({str(original): "different"})


if __name__ == "__main__":
    unittest.main()
