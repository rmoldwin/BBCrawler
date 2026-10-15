import _bootstrap
import copy
import json
from pathlib import Path
import sqlite3
import unittest
from unittest.mock import patch

import bluebooks_local as local
import term_recovery as recovery


class TermRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.con = sqlite3.connect(":memory:")
        self.addCleanup(self.con.close)
        local.migrate_sqlite(self.con)
        self.con.execute("INSERT INTO books(book_id,title,alias,url) "
                         "VALUES(1,'Test','Test','local:book')")
        self.con.execute("INSERT INTO pages(page_id,book_id,site_page_id,url,title) VALUES(1,1,1,'local:page','Parent')")
        self.con.execute("INSERT INTO entity_pages(page_id,book_id,title) VALUES(1,1,'Parent')")
        self.manifest = {
            "source_kind": "AI_recovered_prose", "batch": "test",
            "terms": [{
                "term": "Recovered tumour", "suggested_qualifier": "subtype",
                "terminology_status": "unspecified", "note": "Not a source code",
                "sources": [
                    {"table": "entity_codes", "row_id": 51, "page_id": 1,
                     "page_title": "Parent", "original_text": "Prose mentions recovered tumour"},
                    {"table": "entity_related_terms", "row_id": 52, "page_id": 1,
                     "page_title": "Parent", "original_text": "Differential includes recovered tumour"},
                ],
                "matches": [{
                    "edition": "ICD-O-4", "code": "80000/3",
                    "official_term": "Neoplasm, malignant", "match_type": "broader",
                    "candidate_order": 1, "conditions": "Only if classification confirmed",
                    "reference_file": "reference.xlsx", "reference_sheet": "Morphology",
                    "reference_row": 12, "reference_sha256": "a" * 64,
                    "code_term_evidence": [{"term": "Neoplasm, malignant", "row": 12}],
                }],
            }],
        }

    def test_populate_and_idempotence(self):
        result = recovery.populate(self.con, self.manifest)
        self.assertEqual(result, {"new_related_terms": 1, "new_provenance_links": 2,
                                  "new_code_matches": 1, "page_terms": 1})
        self.assertEqual(self.con.execute("SELECT kind,TermUS,TermNormUS FROM entity_related_terms").fetchone(),
                         ("other", "Recovered tumor", "Recovered tumor"))
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM entity_codes").fetchone()[0], 0)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM page_icdo_codes").fetchone()[0], 0)
        again = recovery.populate(self.con, self.manifest)
        self.assertEqual(again["new_related_terms"], 0)
        self.assertEqual(again["new_provenance_links"], 0)
        self.assertEqual(again["new_code_matches"], 0)
        self.assertTrue(recovery.populate_check(self.con, self.manifest))
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_entity_terms").fetchone()[0], 1)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_entity_term_provenance").fetchone()[0], 2)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_entity_term_code_matches").fetchone()[0], 1)

    def test_reuses_existing_terms_not_lossy_norm(self):
        self.con.execute("INSERT INTO entity_codes(page_id,ordinal,term,code) VALUES(1,0,'Recovered tumour','8000/3')")
        result = recovery.populate(self.con, self.manifest)
        self.assertEqual(result["new_related_terms"], 0)
        self.assertIsNotNone(self.con.execute("SELECT entity_code_id FROM entity_term_provenance").fetchone()[0])
        self.manifest["terms"][0]["term"] = "Recovered tumour NOS"
        self.assertEqual(recovery.populate(self.con, self.manifest)["new_related_terms"], 1)
        self.assertEqual(self.con.execute("SELECT code FROM entity_codes").fetchone()[0], "8000/3")

    def test_refresh_relinks_ids_and_preserves_reviews(self):
        recovery.populate(self.con, self.manifest)
        self.con.execute("UPDATE entity_term_provenance SET review_status='approved',note='Reviewed',suggested_qualifier='related'")
        self.con.execute("UPDATE entity_term_code_matches SET review_status='rejected'")
        reviews = recovery.snapshot_reviews(self.con)
        for table in ("entity_term_code_matches", "entity_term_provenance", "entity_related_terms"):
            self.con.execute(f"DELETE FROM {table}")
        self.con.execute("INSERT INTO entity_related_terms(related_term_id,page_id,kind,term) VALUES(99,1,'other','Existing')")
        recovery.populate(self.con, self.manifest, reviews)
        self.assertEqual(self.con.execute("SELECT related_term_id,review_status,note,suggested_qualifier FROM entity_term_provenance").fetchone(),
                         (100, "approved", "Reviewed", "related"))
        self.assertEqual(self.con.execute("SELECT review_status FROM entity_term_code_matches").fetchone()[0], "rejected")

    def test_constraints_and_parent_checks(self):
        recovery.populate(self.con, self.manifest)
        with self.assertRaises(sqlite3.IntegrityError):
            self.con.execute("UPDATE entity_term_provenance SET review_status='unknown'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.con.execute("UPDATE entity_term_provenance SET related_term_id=NULL")
        other = copy.deepcopy(self.manifest)
        other["terms"][0]["sources"][0]["page_title"] = "Changed"
        with self.assertRaisesRegex(ValueError, "title changed"):
            recovery.plan(self.con, other)
        other = copy.deepcopy(self.manifest)
        other["terms"][0]["matches"][0]["code"] = "80001/3"
        other["terms"].append(copy.deepcopy(self.manifest["terms"][0]))
        with self.assertRaisesRegex(ValueError, "Conflicting"):
            recovery.plan(self.con, other)

    def test_uncoded_terms_not_lost_in_left_join(self):
        self.manifest["terms"][0]["matches"] = []
        recovery.populate(self.con, self.manifest)
        self.assertEqual(self.con.execute("SELECT term,suggested_code FROM v_entity_term_code_matches").fetchone(),
                         ("Recovered tumour", None))
        self.assertEqual(self.con.execute(
            "SELECT TermUS,morphology_code FROM v_page_code_terms"
        ).fetchone(), ("Recovered tumor", None))

    def test_book_alias_legacy_mapping_and_user_override(self):
        self.con.execute(
            "INSERT INTO books(book_id,title,edition,url) "
            "VALUES(2,'Digestive System Tumours (6th ed.)','6th','local:book2')"
        )
        self.con.commit()
        local.migrate_sqlite(self.con)
        self.assertEqual(
            self.con.execute("SELECT alias FROM books WHERE book_id=2").fetchone()[0],
            "GI, v6",
        )
        self.con.execute("UPDATE books SET alias='My preferred label' WHERE book_id=2")
        self.con.commit()
        local.migrate_sqlite(self.con)
        self.assertEqual(
            self.con.execute("SELECT alias FROM books WHERE book_id=2").fetchone()[0],
            "My preferred label",
        )
        self.assertEqual(recovery.book_version_alias(
            "WHO Reporting System for Lymph Node, Spleen, and Thymus Cytopathology",
            "cytopathology",
        ), "LN/spleen/thymus, cyto")

    def test_page_view_unique_pairs_sections_candidates_and_sites(self):
        self.con.execute(
            "UPDATE books SET title='Digestive System Tumours',alias='GI, v6',edition='6th'"
        )
        self.manifest["terms"][0]["matches"][0]["official_term"] = "Malignant tumour"
        recovery.populate(self.con, self.manifest)
        for heading in ("Coding", "Subtype(s)", "Coding"):
            self.con.execute(
                "INSERT INTO page_icdo_codes(page_id,icdo_code,icdo_code_raw,"
                "term_in_coding_section,section_heading) VALUES(1,'8000/3','8000D/3','Recovered tumor',?)",
                (heading,),
            )
        self.con.execute("INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype) "
                         "VALUES(1,0,'Recovered tumour','8000D/3',1)")
        self.con.execute("INSERT INTO entity_codes(page_id,ordinal,term,code) "
                         "VALUES(1,1,'Distinct diagnosis','8000D/3')")
        for code, confidence in (("C000", .9), ("C000", .99), ("C001", .89), ("C002", .95)):
            self.con.execute("INSERT INTO page_site_hints(page_id,c_code,provenance,confidence_score)"
                             " VALUES(1,?,'test',?)", (code, confidence))
        rows = self.con.execute(
            "SELECT alias,TermUS,candidateTermUS,ICDO32,ICDO4,page_sections,is_subtype,"
            "code_kind,source_kind,suggested_qualifier,match_type,conditions,"
            "candidate_topography_codes,site_confidence_min FROM v_page_code_terms "
            "ORDER BY TermUS,ICDO4"
        ).fetchall()
        self.assertEqual(len(rows), 3)
        candidate = next(r for r in rows if r[4] == "80000/3")
        self.assertEqual(candidate[:5], ("GI, v6", "Recovered tumor", "Malignant tumor", None, "80000/3"))
        self.assertEqual(candidate[7:11], ("candidate", "AI_recovered_prose", "subtype", "broader"))
        self.assertEqual(candidate[11], "Only if classification confirmed")
        source = next(r for r in rows if r[1] == "Recovered tumor" and r[4] == "8000D/3")
        self.assertEqual(source[5], "Coding; Subtype(s)")
        self.assertEqual(source[6], 1)
        self.assertEqual(source[7], "contextual_code; source_assignment")
        for row in rows:
            self.assertEqual(row[12:], ("C000; C002", .95))
        self.assertEqual(self.con.execute("SELECT official_term,official_term_source,candidateTermUS "
                                         "FROM v_entity_term_code_matches WHERE match_id IS NOT NULL").fetchone(),
                         ("Malignant tumor", "Malignant tumour", "Malignant tumor"))
        self.assertEqual(self.con.execute("SELECT official_term FROM entity_term_code_matches").fetchone()[0],
                         "Malignant tumour")
        self.con.execute("UPDATE entity_term_code_matches SET official_term='Benign tumour'")
        self.assertEqual(self.con.execute("SELECT candidateTermUS FROM v_entity_term_code_matches "
                                         "WHERE match_id IS NOT NULL").fetchone()[0], "Benign tumor")
        recovery.ensure_sqlite_views(self.con)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_page_code_terms").fetchone()[0], 3)
        view_columns = [row[1] for row in self.con.execute("PRAGMA table_info(v_page_code_terms)")]
        self.assertIn("book_name", view_columns)
        self.assertIn("alias", view_columns)
        self.assertIn("edition", view_columns)
        self.assertIn("ch_order", view_columns)
        self.assertEqual(
            self.con.execute("SELECT DISTINCT alias FROM v_page_code_terms").fetchall(),
            [("GI, v6",)],
        )
        self.con.execute("UPDATE books SET alias='Custom GI label' WHERE book_id=1")
        recovery.ensure_sqlite_views(self.con)
        self.assertEqual(
            self.con.execute("SELECT DISTINCT alias FROM v_page_code_terms").fetchall(),
            [("Custom GI label",)],
        )
        from term_hygiene import term_keys
        for term_us, term_norm_us in self.con.execute(
                "SELECT TermUS,TermNormUS FROM v_page_code_terms").fetchall():
            self.assertEqual(term_norm_us, term_keys(term_us)[1])
        self.assertNotIn("CleanBritishSpelling2", self.con.execute(
            "SELECT sql FROM sqlite_master WHERE name='v_entity_term_code_matches'"
        ).fetchone()[0])

    def test_candidate_and_source_same_pair_keep_metadata_without_duplicate(self):
        self.manifest["terms"][0]["matches"][0]["code"] = "8000D/3"
        self.con.execute("INSERT INTO entity_codes(page_id,ordinal,term,code) "
                         "VALUES(1,0,'Recovered tumour','8000D/3')")
        recovery.populate(self.con, self.manifest)
        row = self.con.execute("SELECT morphology_code,TermUS,candidateTermUS,code_kind,"
                               "source_kind,suggested_qualifier,match_type FROM v_page_code_terms").fetchall()
        self.assertEqual(row, [("8000D/3", "Recovered tumor", "Neoplasm, malignant",
                               "candidate; source_assignment", "AI_recovered_prose; parsed_entity",
                               "subtype", "broader")])

    def test_shipped_manifest_and_counts(self):
        manifest = recovery.load_manifest()
        self.assertEqual(len(manifest["terms"]), 144)
        self.assertTrue(any(not t["matches"] for t in manifest["terms"]))
        for term in manifest["terms"]:
            for match in term["matches"]:
                self.assertNotIn(match["code"], ("9367/3", "9368/3"))
                self.assertIn(match["match_type"], ("exact", "synonym", "broader", "conditional"))
                self.assertTrue(match["conditions"])

    def test_refresh_preflights_official_sources_without_manifest_replay(self):
        source = Path(local.__file__).read_text(encoding="utf-8")
        self.assertLess(source.index("official_refs, official_hashes = term_pipeline.read_references()"),
                        source.index("for table in reversed(DERIVED)"))
        self.assertIn("p.is_added_term=1", source)
        self.assertNotIn("recovery_result = term_recovery.populate", source)
        self.assertIn("recovery_result = term_pipeline.run", source)


if __name__ == "__main__":
    unittest.main()
