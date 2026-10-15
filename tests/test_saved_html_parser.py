import unittest
import sqlite3
from pathlib import Path
import sys
from unittest.mock import patch
from contextlib import closing

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "BBNotebook"))
from bb_entity_extract import (
    audit_saved_body_coverage,
    build_spreadsheet_rows,
    extract_saved_sections,
    parse_entity_page,
)


def _section(heading, body, anchor=""):
    section_id = f' id="{anchor}"' if anchor else ""
    heading_id = f' id="#{anchor}"' if anchor else ""
    return (
        f'<div class="description"{section_id}>'
        f"<p{heading_id}><span>{heading}</span></p>"
        f'<span class="description">{body}</span></div>'
    )


def _page(*sections):
    return "<app-chaptercontent>" + "".join(sections) + "</app-chaptercontent>"


class SavedHTMLParserTests(unittest.TestCase):
    def test_spreadsheet_retains_uncoded_title_and_shared_edition_outcomes(self):
        entity = parse_entity_page(_page(
            _section("Definition", "A mixed tumor."),
            _section("ICD-O coding", "Not applicable")), "Gynandroblastoma")
        record = {"entity": entity, "page_id": 4941, "chapter": "Chapter",
                  "category": "", "subcategory": "", "url": ""}
        with closing(sqlite3.connect(":memory:")) as con:
            con.execute(
                "CREATE TABLE v_page_code_terms(book_id,page_id,TermUS,code_edition,"
                "morphology_code,candidateTermUS,is_proposed_code,is_proposed_term,"
                "lookup_outcome,review_status)")
            con.executemany("INSERT INTO v_page_code_terms VALUES(?,?,?,?,?,?,?,?,?,?)", [
                (7, 4941, "Gynandroblastoma", "ICD-O-3.2", "8632/1",
                 "Gynandroblastoma", 1, 0, "matched", "proposed"),
                (7, 4941, "Gynandroblastoma", "ICD-O-4", "86320/1",
                 "Gynandroblastoma", 1, 0, "matched", "proposed"),
            ])
            outcomes = []
            with patch("bb_entity_extract.extract_book_entities", return_value=[record]):
                rows = build_spreadsheet_rows(con, 7, lookup_status_out=outcomes)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["ICD-O-4 Term"], "Gynandroblastoma")
            self.assertEqual(rows[0]["ICD-O-4"], "")
            self.assertEqual(rows[0]["Lookup_ICDO32+"], "8632/1")
            self.assertEqual(rows[0]["Lookup_ICDO4.0"], "86320/1")
            self.assertEqual(rows[0]["IsProposedCode"], 1)
            self.assertEqual(outcomes, [("Gynandroblastoma", "matched", "matched")])
            con.execute("INSERT INTO v_page_code_terms VALUES(?,?,?,?,?,?,?,?,?,?)",
                        (7, 4941, "Gynandroblastoma", "ICD-O-4", "99999/1",
                         "Alternate official label", 1, 1, "matched", "needs_review"))
            with patch("bb_entity_extract.extract_book_entities", return_value=[record]):
                ambiguous = build_spreadsheet_rows(con, 7, lookup_status_out=outcomes)
            self.assertEqual(ambiguous[0]["Lookup_ICDO4.0"], "")
            self.assertTrue(outcomes[-1][2].startswith("ambiguous:"))
            self.assertIn("needs_review", ambiguous[0]["MappingReviewStatus"])

    def test_title_eligible_despite_beta_or_empty_coding(self):
        for coding in ("Awaiting ICD-O", "Not applicable", ""):
            entity = parse_entity_page(_page(
                _section("Definition", "A mixed sex cord stromal tumor."),
                _section("ICD-O coding", coding)), "Gynandroblastoma")
            self.assertTrue(entity.has_entity_content)
            self.assertEqual(entity.title, "Gynandroblastoma")
            self.assertFalse(entity.coded_terms)

    def test_nested_definition_and_related_only_content_are_eligible(self):
        entity = parse_entity_page(_page(
            _section("Definition", ""),
            _section("Additional entity definition", "Metastatic tumors are secondary lesions.")),
            "Metastases to the peritoneum")
        self.assertTrue(entity.has_entity_content)
        self.assertIn("secondary lesions", entity.definition)
        related = parse_entity_page(_page(
            _section("Related terminology", "Acceptable: Tumor alternate name")),
            "Related-only entity")
        self.assertTrue(related.has_entity_content)
        blank = parse_entity_page(_page(_section("Definition", "")), "Blank")
        self.assertFalse(blank.has_entity_content)

    def test_standalone_placeholder_not_parenthetical_qualifier(self):
        entity = parse_entity_page(_page(_section(
            "Related terminology",
            "Acceptable: Not Applicable.; Not applicable (N/A); "
            "Tumor (classification not applicable)")))
        self.assertEqual(entity.acceptable, ["Tumor (classification not applicable)"])

    def test_extracts_ordered_anchored_sections_without_navigation_chrome(self):
        raw_html = _page(
            '<div class="navbar"><div class="description" id="nav">'
            "<p>Definition</p><span>navigation text</span></div></div>",
            _section("Definition", "Main definition.", "definition-anchor"),
            _section("Clinical features", "All body text is retained.", "features"),
            _section("Epidemiology", "A final section.", "epidemiology"),
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            [section.heading for section in sections],
            ["Definition", "Clinical features", "Epidemiology"],
        )
        self.assertEqual(sections[0].body_text, "Main definition.")
        self.assertEqual(sections[0].anchor, "definition-anchor")
        self.assertEqual(sections[-1].body_text, "A final section.")

    def test_extracts_unknown_bold_and_heading_tag_sections(self):
        raw_html = (
            "<app-chaptercontent>"
            '<div class="description" id="root">'
            '<p id="#overview"><span>Overview</span></p>'
            '<span class="description">Overview text.'
            '<p style="font-weight: bold"><strong>Additional findings</strong></p>'
            "<p>Additional body text.</p>"
            "<h3>Supplementary notes</h3>"
            "<p>Supplementary body text.</p>"
            "</span></div></app-chaptercontent>"
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            [(section.heading, section.body_text, section.anchor) for section in sections],
            [
                ("Overview", "Overview text.", "overview"),
                ("Additional findings", "Additional body text.", ""),
                ("Supplementary notes", "Supplementary body text.", ""),
            ],
        )

    def test_inline_bold_labels_become_headings_without_losing_their_prose(self):
        raw_html = _page(
            _section(
                "Definition",
                "Opening text."
                "<p><strong>Hormone receptors:</strong> Nuclear ER expression "
                "should be evaluated in IBC.</p>"
                "<p><strong>Intermediate (locally aggressive): </strong>"
                "Bone tumours in this category often recur locally.</p>",
            )
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            [(section.heading, section.body_text) for section in sections],
            [
                ("Definition", "Opening text."),
                (
                    "Hormone receptors",
                    "Nuclear ER expression should be evaluated in IBC.",
                ),
                (
                    "Intermediate (locally aggressive)",
                    "Bone tumours in this category often recur locally.",
                ),
            ],
        )

    def test_inline_bold_heading_preserves_less_than_and_greater_than_text(self):
        body = (
            "Ki-67 labelling hotspots, often with an index of &lt; 20% "
            "(but index values &gt; 20% do not exclude the "
            "diagnosis), and p16 positivity is retained."
        )
        raw_html = _page(
            _section(
                "Histopathology",
                f"<p><strong>Cellular schwannoma:</strong> {body}</p>",
            )
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            [section.heading for section in sections],
            ["Histopathology", "Cellular schwannoma"],
        )
        self.assertEqual(
            sections[1].body_text,
            body.replace("&lt;", "<").replace("&gt;", ">"),
        )
        self.assertIn("index values > 20% do not exclude the diagnosis", sections[1].body_text)

    def test_long_bold_paragraph_stays_in_body_and_is_not_truncated(self):
        long_paragraph = (
            "Bone tumours in this category often recur locally and may be "
            "associated with an infiltrative and locally destructive growth "
            "pattern. They do not appear to have the potential to metastasize."
        )
        styled_paragraph = (
            "This entire paragraph is styled bold but remains explanatory "
            "prose rather than a section heading."
        )
        raw_html = _page(
            _section(
                "Definition",
                f"<p><strong>{long_paragraph}</strong></p>"
                f'<p style="font-weight: 700">{styled_paragraph}</p>'
                "<p>Additional body text.</p>",
            )
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual([section.heading for section in sections], ["Definition"])
        self.assertEqual(
            sections[0].body_text,
            f"{long_paragraph}\n{styled_paragraph}\nAdditional body text.",
        )

    def test_extracts_simple_unwrapped_description_fragment(self):
        sections = extract_saved_sections(
            '<div class="description" id="fragment">'
            "<p>Supplementary notes</p>"
            "<p>Saved body text.</p>"
            "</div>"
        )

        self.assertEqual(
            [(section.heading, section.body_text, section.anchor) for section in sections],
            [("Supplementary notes", "Saved body text.", "fragment")],
        )

    def test_nested_description_markup_does_not_truncate_outer_body(self):
        raw_html = _page(
            _section(
                "Histopathology",
                "Text before nested markup. "
                '<div class="description">Nested text with <em>detail</em>.</div> '
                "Text after nested markup.",
            )
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            sections[0].body_text,
            "Text before nested markup. Nested text with detail. Text after nested markup.",
        )

    def test_recovers_embedded_plain_heading_and_prefers_real_duplicate(self):
        raw_html = _page(
            _section("Definition", "Papillary DCIS is a lesion.", "1014"),
            _section(
                "ICD-O coding",
                '<font color="red">Classification in progress, '
                "Data not available in this Beta</font>",
                "1015",
            ),
            _section(
                "Prognosis and prediction",
                "Papillary DCIS is associated with other patterns."
                "<p>ICD-O coding</p>"
                "<p>8503/2 Ductal carcinoma in situ, papillary</p>",
                "1028",
            ),
        )

        sections = extract_saved_sections(raw_html)
        section_by_heading = {section.heading: section for section in sections}
        entity = parse_entity_page(raw_html, "Papillary ductal carcinoma in situ")

        self.assertEqual(
            section_by_heading["ICD-O coding"].body_text,
            "8503/2 Ductal carcinoma in situ, papillary",
        )
        self.assertEqual(section_by_heading["ICD-O coding"].anchor, "1015")
        self.assertIn("Papillary DCIS is associated", entity.sections["Prognosis and prediction"])
        self.assertEqual(
            [(term.code, term.term) for term in entity.coded_terms],
            [("8503/2", "Ductal carcinoma in situ, papillary")],
        )

    def test_distinct_repeated_heading_bodies_are_merged_in_document_order(self):
        raw_html = _page(
            _section("Stage", "Earlier staging criteria."),
            _section("Stage", "Later staging criteria."),
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(len(sections), 1)
        self.assertEqual(
            sections[0].body_text,
            "Earlier staging criteria.\nLater staging criteria.",
        )

    def test_repeated_heading_prefers_complete_body_over_its_subset(self):
        raw_html = _page(
            _section("Definition", "Shared sentence."),
            _section("Definition", "Shared sentence. Additional details."),
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            sections[0].body_text,
            "Shared sentence. Additional details.",
        )

    def test_repeated_heading_keeps_prose_ending_in_to_be_determined(self):
        molecular_paragraph = (
            "Despite a strong syndromic association, few defining genetic "
            "events have emerged. Monosomy 22 is frequently observed. The "
            "relationship to the reported fusion remains to be determined."
        )
        raw_html = _page(
            _section("Schwannoma-neurofibroma", "Clinical presentation."),
            _section("Schwannoma-neurofibroma", molecular_paragraph),
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(len(sections), 1)
        self.assertIn("Monosomy 22 is frequently observed.", sections[0].body_text)
        self.assertIn(
            "The relationship to the reported fusion remains to be determined.",
            sections[0].body_text,
        )

    def test_breast_tnm_child_sections_retain_classification_body(self):
        raw_html = _page(
            _section("TNM Clinical Classification", ""),
            _section(
                "T – Primary Tumour",
                "Tis Carcinoma in situ\nT4d Inflammatory carcinoma.",
            ),
            _section(
                "N – Regional Lymph Nodes",
                "N1 Metastasis in movable ipsilateral axillary nodes.",
            ),
            _section("pTNM Pathological Classification", ""),
            _section(
                "pN – Regional Lymph Nodes",
                "pN3c Metastasis in ipsilateral supraclavicular lymph nodes.",
            ),
        )

        sections = extract_saved_sections(raw_html)
        by_heading = {section.heading: section.body_text for section in sections}

        self.assertEqual(by_heading["TNM Clinical Classification"], "")
        self.assertIn("Tis Carcinoma in situ", by_heading["T – Primary Tumour"])
        self.assertIn("N1 Metastasis", by_heading["N – Regional Lymph Nodes"])
        self.assertEqual(by_heading["pTNM Pathological Classification"], "")
        self.assertIn("pN3c Metastasis", by_heading["pN – Regional Lymph Nodes"])

    def test_code_only_rows_use_entity_title_as_term(self):
        cases = (
            ("8890/3", "Leiomyosarcoma"),
            ("9570/0", "Solitary circumscribed neuroma"),
            ("9132/0", "Intramuscular vascular anomalies"),
            ("9120/0", "Spindle cell haemangioma"),
            ("8823/1", "Desmoplastic fibroma of bone"),
        )
        for code, title in cases:
            with self.subTest(code=code):
                entity = parse_entity_page(
                    _page(
                        _section("Definition", "Entity definition."),
                        _section("ICD-O coding", f"<p>{code}</p>"),
                    ),
                    title,
                )
                self.assertEqual(
                    [(term.code, term.term) for term in entity.coded_terms],
                    [(code, title)],
                )

    def test_nested_code_section_headings_do_not_hide_structured_rows(self):
        raw_html = _page(
            _section(
                "ICD-O coding",
                "<h5>Composite phaeochromocytoma</h5>"
                "<p>8700/3 Composite phaeochromocytoma-ganglioneuroma</p>"
                "<h5>Composite paraganglioma</h5>"
                "<p>8693/3 Composite paraganglioma-ganglioneuroma</p>",
            ),
            _section(
                "Subtype(s)",
                "<h6>Mucosal</h6>"
                "<p>Adenocarcinoma, HPV-independent (84840/3); "
                "adenocarcinoma, HPV-associated (84830/3)</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Composite tumour")

        self.assertEqual(
            [(term.code, term.term) for term in entity.coded_terms],
            [
                ("8700/3", "Composite phaeochromocytoma-ganglioneuroma"),
                ("8693/3", "Composite paraganglioma-ganglioneuroma"),
            ],
        )
        self.assertEqual(
            [(term.code, term.term) for term in entity.subtypes],
            [
                ("84840/3", "Adenocarcinoma, HPV-independent"),
                ("84830/3", "Adenocarcinoma, HPV-associated"),
            ],
        )

    def test_five_8500_2_rows_are_all_retained(self):
        terms = (
            "Intraductal carcinoma",
            "Intercalated duct intraductal carcinoma",
            "Apocrine intraductal carcinoma",
            "Oncocytic intraductal carcinoma",
            "Mixed intraductal carcinoma",
        )
        entity = parse_entity_page(
            _page(
                _section(
                    "ICD-O coding",
                    "".join(f"<p>8500/2 {term}</p>" for term in terms),
                )
            ),
            "Intraductal carcinoma",
        )

        self.assertEqual(
            [(term.code, term.term) for term in entity.coded_terms],
            [("8500/2", term) for term in terms],
        )

    def test_empty_or_none_icdo_block_does_not_create_a_code(self):
        for no_code in ("None", "\u2014"):
            with self.subTest(no_code=no_code):
                entity = parse_entity_page(
                    _page(
                        _section("Definition", "Entity definition."),
                        _section("ICD-O coding", no_code),
                    ),
                    "Uncoded entity",
                )
                self.assertEqual(entity.coded_terms, [])

    def test_mim_numbering_rows_are_omim_identifiers_not_coded_terms(self):
        raw_html = _page(
            _section("Definition", "A hereditary predisposition syndrome."),
            _section(
                "ICD-O coding",
                "<p>MIM numbering:</p>"
                "<p>609310 Colorectal cancer, hereditary nonpolyposis, type 2</p>"
                "<p>120435 Lynch syndrome I (colorectal cancer, hereditary "
                "nonpolyposis, type 1)</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Lynch syndrome")

        self.assertEqual(entity.coded_terms, [])
        self.assertEqual(
            [
                (
                    item.system,
                    item.identifier,
                    item.term,
                    item.source_heading,
                )
                for item in entity.identifiers
            ],
            [
                (
                    "OMIM",
                    "609310",
                    "Colorectal cancer, hereditary nonpolyposis, type 2",
                    "ICD-O coding",
                ),
                (
                    "OMIM",
                    "120435",
                    "Lynch syndrome I (colorectal cancer, hereditary "
                    "nonpolyposis, type 1)",
                    "ICD-O coding",
                ),
            ],
        )
        self.assertTrue(all(item.raw_text for item in entity.identifiers))

    def test_polyposis_mim_number_rows_move_out_of_code_terms(self):
        raw_html = _page(
            _section(
                "Definition",
                "Familial adenomatous polyposis is an inherited condition.",
            ),
            _section(
                "ICD-O coding",
                "<p>MIM number</p>"
                "<p>175100 Familial adenomatous polyposis</p>"
                "<p>MIM numbering: none</p>"
                "<p>Other MIM related to particular genes</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Familial adenomatous polyposis 1")

        self.assertEqual(entity.coded_terms, [])
        self.assertEqual(
            [(item.identifier, item.term) for item in entity.identifiers],
            [("175100", "Familial adenomatous polyposis")],
        )

    def test_hash_prefixed_mim_numbering_and_multiple_inline_ids(self):
        raw_html = _page(
            _section(
                "Definition",
                "An inherited syndrome associated with tumour predisposition.",
            ),
            _section(
                "ICD-O coding",
                "<p>MIM numbering</p>"
                "<p># 615134 Melanoma susceptibility type 9</p>"
                "<p># 615848 Melanoma susceptibility type 10</p>",
            ),
            _section(
                "Subtype(s)",
                "<p>Muir-Torre syndrome (MIM number: 158320)</p>"
                "<p>Chromosome 11p13 deletion containing WT1 (MIM 607102), "
                "PAX6 (MIM 607108) and BDNF (MIM 113505)</p>"
                "<p>Myxoid inflammatory myofibroblastic sarcoma (MIMS)</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Inherited tumour predisposition syndrome")

        self.assertEqual(entity.coded_terms, [])
        self.assertEqual(
            {item.identifier for item in entity.identifiers},
            {"615134", "615848", "158320", "607102", "607108", "113505"},
        )
        self.assertNotIn(
            "Muir-Torre syndrome (MIM number: 158320)",
            [item.term for item in entity.subtypes],
        )
        self.assertIn("Muir-Torre syndrome", [item.term for item in entity.subtypes])
        self.assertIn(
            "Myxoid inflammatory myofibroblastic sarcoma (MIMS)",
            [item.term for item in entity.subtypes],
        )

    def test_unprefixed_mim_rows_in_genetic_syndrome_icdo_block_are_identifiers(self):
        raw_html = _page(
            _section(
                "Definition",
                "Lynch syndrome is an autosomal dominant disorder caused by "
                "pathogenic mutations in DNA mismatch repair genes.",
            ),
            _section(
                "ICD-O coding",
                "<p>609310 Colorectal cancer, hereditary nonpolyposis, type 2</p>"
                "<p>120435 Lynch syndrome I (colorectal cancer, hereditary "
                "nonpolyposis, type 1)</p>"
                "<p>614350 Colorectal cancer, hereditary nonpolyposis, type 5</p>"
                "<p>614337 Colorectal cancer, hereditary nonpolyposis, type 4</p>"
                "<p>613244 Colorectal cancer, hereditary nonpolyposis, type 8</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Lynch syndrome")

        self.assertEqual(entity.coded_terms, [])
        self.assertEqual(
            [
                (
                    item.system,
                    item.identifier,
                    item.term,
                    item.source_heading,
                    item.raw_text,
                )
                for item in entity.identifiers
            ],
            [
                (
                    "OMIM",
                    "609310",
                    "Colorectal cancer, hereditary nonpolyposis, type 2",
                    "ICD-O coding",
                    "609310 Colorectal cancer, hereditary nonpolyposis, type 2",
                ),
                (
                    "OMIM",
                    "120435",
                    "Lynch syndrome I (colorectal cancer, hereditary "
                    "nonpolyposis, type 1)",
                    "ICD-O coding",
                    "120435 Lynch syndrome I (colorectal cancer, hereditary "
                    "nonpolyposis, type 1)",
                ),
                (
                    "OMIM",
                    "614350",
                    "Colorectal cancer, hereditary nonpolyposis, type 5",
                    "ICD-O coding",
                    "614350 Colorectal cancer, hereditary nonpolyposis, type 5",
                ),
                (
                    "OMIM",
                    "614337",
                    "Colorectal cancer, hereditary nonpolyposis, type 4",
                    "ICD-O coding",
                    "614337 Colorectal cancer, hereditary nonpolyposis, type 4",
                ),
                (
                    "OMIM",
                    "613244",
                    "Colorectal cancer, hereditary nonpolyposis, type 8",
                    "ICD-O coding",
                    "613244 Colorectal cancer, hereditary nonpolyposis, type 8",
                ),
            ],
        )

    def test_explicit_omim_rows_are_not_morphology_terms(self):
        entity = parse_entity_page(
            _page(
                _section(
                    "ICD-O coding",
                    "<p>OMIM 609310 Lynch syndrome</p>"
                    "<p>MIM 120435 Lynch syndrome I</p>",
                )
            ),
            "Lynch syndrome",
        )

        self.assertEqual(entity.coded_terms, [])
        self.assertEqual(
            [(item.system, item.identifier) for item in entity.identifiers],
            [("OMIM", "609310"), ("OMIM", "120435")],
        )

    def test_inline_omim_citation_does_not_use_body_as_display_term(self):
        entity = parse_entity_page(
            _page(
                _section(
                    "Etiology",
                    "Gene rearrangements are a hallmark of BL; OMIM 308240.",
                )
            ),
            "Burkitt lymphoma",
        )

        self.assertEqual(
            [(item.identifier, item.term) for item in entity.identifiers],
            [("308240", "")],
        )
        self.assertEqual(
            entity.identifiers[0].raw_text,
            "Gene rearrangements are a hallmark of BL; OMIM 308240.",
        )

    def test_identifier_terms_are_clean_and_source_kind_is_explicit(self):
        entity = parse_entity_page(
            _page(
                _section(
                    "ICD-O coding",
                    "<p>MIM numbering:</p>"
                    "<p>175100 Familial adenomatous polyposis</p>",
                ),
                _section(
                    "Clinical features",
                    "FAP is associated with OMIM 175100.",
                ),
                _section(
                    "Subtype(s)",
                    "Molecular subtypes include:\n"
                    "PAX6 (MIM 607108) and BDNF (MIM 113505).",
                ),
                _section(
                    "Pathogenesis",
                    "Inactivating mutations are the underlying cause of "
                    "hyperparathyroidism-jaw tumour syndrome (MIM 145001).",
                ),
                _section(
                    "Genetic factors",
                    "Mutations in CDC73 cause hyperparathyroidism-jaw tumour "
                    "syndrome (MIM 145001).",
                ),
            ),
            "Familial adenomatous polyposis",
        )

        identifiers = {
            (item.identifier, item.term, item.source_kind, item.source_heading)
            for item in entity.identifiers
        }
        self.assertIn(
            ("175100", "Familial adenomatous polyposis", "coding_section", "ICD-O coding"),
            identifiers,
        )
        self.assertIn(
            ("175100", "", "section_text", "Clinical features"),
            identifiers,
        )
        self.assertIn(
            ("113505", "BDNF", "section_text", "Subtype(s)"),
            identifiers,
        )
        self.assertIn(
            ("145001", "", "section_text", "Pathogenesis"),
            identifiers,
        )
        self.assertIn(
            ("145001", "", "section_text", "Genetic factors"),
            identifiers,
        )
        self.assertNotIn(
            "Molecular subtypes include",
            [item.term for item in entity.coded_terms + entity.subtypes],
        )

    def test_unlabelled_six_digit_code_is_not_assumed_to_be_omim(self):
        entity = parse_entity_page(
            _page(_section("ICD-O coding", "<p>123456 Unclassified entry</p>")),
            "Entity",
        )

        self.assertEqual(entity.identifiers, [])
        self.assertEqual(
            [(term.code, term.term) for term in entity.coded_terms],
            [("", "123456 Unclassified entry")],
        )

    def test_related_terms_and_subtypes_keep_the_existing_fields(self):
        raw_html = _page(
            _section(
                "Related terminology",
                "<h5>Spindle cell squamous cell carcinoma</h5>"
                "<p><strong>Acceptable:</strong> term one; term two</p>"
                "<p><strong>Not recommended:</strong> obsolete term</p>",
            ),
            _section(
                "Subtype(s)",
                "<p>Subtype A (80510/3); Subtype B (80741/3)</p>",
            ),
        )

        entity = parse_entity_page(raw_html, "Main entity")

        self.assertEqual(entity.acceptable, ["Term one", "Term two"])
        self.assertEqual(entity.not_recommended, ["Obsolete term"])
        self.assertEqual(
            entity.related_other,
            ["Spindle cell squamous cell carcinoma"],
        )
        self.assertEqual(
            [(term.code, term.term, term.is_subtype) for term in entity.subtypes],
            [
                ("80510/3", "Subtype A", True),
                ("80741/3", "Subtype B", True),
            ],
        )

    def test_salivary_not_recommended_terms_are_preserved(self):
        cases = (
            (
                "Salivary gland myoepithelioma",
                "myoepithelial cell tumour; myoepithelial adenoma",
                ["Myoepithelial cell tumour", "Myoepithelial adenoma"],
            ),
            (
                "Salivary gland carcinoma NOS",
                "unclassified adenocarcinoma; ductal adenocarcinoma; "
                "(papillary) cystadenocarcinoma",
                [
                    "Unclassified adenocarcinoma",
                    "Ductal adenocarcinoma",
                    "(papillary) cystadenocarcinoma",
                ],
            ),
        )
        for title, terms, expected in cases:
            with self.subTest(title=title):
                entity = parse_entity_page(
                    _page(
                        _section(
                            "Related terminology",
                            f"<p><em>Not recommended:</em> {terms}</p>",
                        )
                    ),
                    title,
                )
                self.assertEqual(entity.not_recommended, expected)

    def test_meaningful_link_text_is_kept_but_citation_links_are_dropped(self):
        raw_html = _page(
            _section(
                "Clinical features",
                'Includes <a href="/terms/linked-term">linked terminology</a>. '
                '{<a href="https://pubmed.ncbi.nlm.nih.gov/12345678/">'
                "12345678</a>; }",
            )
        )

        section = extract_saved_sections(raw_html)[0]

        self.assertEqual(
            section.body_text,
            "Includes linked terminology.",
        )
        self.assertNotIn("12345678", section.body_text        )

    def test_independent_body_audit_matches_saved_paragraphs_and_excludes_chrome(self):
        raw_html = _page(
            '<div class="sidebar"><div class="description">'
            "<p>Navigation heading</p><p>Chrome-only phrase.</p>"
            "</div></div>",
            _section(
                "Definition",
                "<p>Independent source paragraph keeps "
                '<a href="/terms/meaningful">linked wording</a>.</p>'
                "<p>Second paragraph has {<a "
                'href="https://pubmed.ncbi.nlm.nih.gov/12345678/">citation</a>; } '
                "but retains its body.</p>",
            ),
        )
        bodies = [section.body_text for section in extract_saved_sections(raw_html)]

        checked_count, unmatched = audit_saved_body_coverage(raw_html, bodies)

        self.assertEqual(checked_count, 2)
        self.assertEqual(unmatched, [])

    def test_independent_body_audit_reports_intentionally_omitted_prose(self):
        omitted = (
            "Distinctive untreated prose establishes the independently "
            "auditable source paragraph."
        )
        raw_html = _page(
            _section(
                "Definition",
                "<p>Present paragraph remains in the stored body.</p>"
                f"<p><strong>{omitted}</strong></p>",
            )
        )

        checked_count, unmatched = audit_saved_body_coverage(
            raw_html,
            ["Present paragraph remains in the stored body."],
        )

        self.assertEqual(checked_count, 2)
        self.assertEqual(unmatched, [omitted])

    def test_independent_body_audit_normalizes_inline_and_footnote_boundaries(self):
        raw_html = _page(
            _section(
                "Definition",
                "<p>Notes<br><sup>a</sup> First complete "
                "<span>source</span> sentence.<br>"
                "<sup>b</sup> A second sentence with and"
                "<span>multiple</span> adjacent words.</p>",
            )
        )
        persisted_document = (
            "Definition Notes a First complete source sentence. "
            "b A second sentence with andmultiple adjacent words."
        )

        checked_count, unmatched = audit_saved_body_coverage(
            raw_html, persisted_document
        )

        self.assertEqual(checked_count, 3)
        self.assertEqual(unmatched, [])

    def test_all_body_sections_are_kept_not_only_entity_fields(self):
        raw_html = _page(
            _section("Definition", "Definition text."),
            _section("Epidemiology", "First paragraph.<p>Second paragraph.</p>"),
            _section("Prognosis and prediction", "Prognosis text."),
        )

        sections = extract_saved_sections(raw_html)

        self.assertEqual(
            [section.heading for section in sections],
            ["Definition", "Epidemiology", "Prognosis and prediction"],
        )
        self.assertEqual(
            sections[1].body_text,
            "First paragraph.\nSecond paragraph.",
        )


if __name__ == "__main__":
    unittest.main()
