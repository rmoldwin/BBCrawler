import json
import sqlite3
import unittest

import bluebooks_local as local
import term_pipeline as pipeline
from term_hygiene import is_standalone_placeholder, term_keys


def reference(edition, code, term, row=3, revision="a"*64, level="Preferred", conditions=None):
    us, norm = term_keys(term)
    return (pipeline.key(edition, revision, row), edition, "local.xlsx", revision,
            "Morphology", row, code, term, us, norm, level, conditions)


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.con = sqlite3.connect(":memory:")
        local.migrate_sqlite(self.con)
        self.con.execute("INSERT INTO books(book_id,title,url,edition,alias) VALUES(1,'Test','local:test','6th','Edited alias')")
        for page in (1, 2):
            self.con.execute("INSERT INTO pages(page_id,book_id,site_page_id,url,title) VALUES(?,1,?,'local:'||?, 'Gynandroblastoma')", (page, page, page))
            self.con.execute("INSERT INTO entity_pages(page_id,book_id,title) VALUES(?,1,'Gynandroblastoma')", (page,))
        self.refs = [reference("ICD-O-3.2", "8632/1", "Gynandroblastoma"),
                     reference("ICD-O-4", "86320/1", "Gynandroblastoma")]

    def tearDown(self):
        self.con.close()

    def run_pipeline(self):
        pipeline.run(self.con, self.refs)
        self.con.commit()
        pipeline.ensure_views(self.con)

    def test_title_discovery_and_independent_edition_evaluations(self):
        self.run_pipeline()
        row = self.con.execute("SELECT TermUS,ICDO4,is_proposed_code,is_proposed_term,lookup_outcome FROM v_page_code_terms WHERE page_id=1 AND code_edition='ICD-O-4'").fetchone()
        self.assertEqual(row, ("Gynandroblastoma", "86320/1", 1, 0, "matched"))
        self.assertEqual(self.con.execute("SELECT DISTINCT source_kind FROM entity_term_provenance").fetchall(), [])
        self.refs = [self.refs[0], reference("ICD-O-4", "80000/3", "Neoplasm", revision="b"*64)]
        self.run_pipeline()
        self.assertEqual(self.con.execute("SELECT lookup_outcome FROM v_page_code_terms WHERE page_id=1 AND code_edition='ICD-O-4'").fetchone()[0], "no_match")

    def test_page_4941_gynandroblastoma_is_proposed_from_title(self):
        self.con.execute(
            "INSERT INTO pages(page_id,book_id,site_page_id,url,title) "
            "VALUES(4941,1,4941,'local:4941','Gynandroblastoma')"
        )
        self.con.execute(
            "INSERT INTO entity_pages(page_id,book_id,title) "
            "VALUES(4941,1,'Gynandroblastoma')"
        )
        self.run_pipeline()
        row = self.con.execute(
            "SELECT ICDO4,is_proposed_code,is_proposed_term,lookup_outcome,code_kind "
            "FROM v_page_code_terms WHERE page_id=4941 AND TermUS='Gynandroblastoma' "
            "AND code_edition='ICD-O-4'"
        ).fetchone()
        self.assertEqual(row, ("86320/1", 1, 0, "matched", "candidate"))
        self.assertEqual(
            self.con.execute(
                "SELECT COUNT(*) FROM page_term_mentions WHERE page_id=4941 "
                "AND term_source='page_title' AND term_origin='source' AND is_current=1"
            ).fetchone()[0],
            1,
        )

    def test_placeholder_is_standalone_only(self):
        for term in ("Not applicable", "Not Applicable.", "not-applicable!", "Not applicable (N/A)"):
            with self.subTest(term=term):
                self.assertTrue(is_standalone_placeholder(term))
        self.assertFalse(is_standalone_placeholder("Tumor (classification not applicable)"))

    def test_longest_embedded_phrase_and_context(self):
        refs = [reference("ICD-O-4", "80000/3", "Carcinoma"),
                reference("ICD-O-4", "80700/3", "Squamous cell carcinoma", row=4)]
        spans = list(pipeline.PhraseIndex(refs).spans("No squamous cell carcinoma. Differential: carcinoma."))
        self.assertEqual([s[2].lower() for s in spans], ["squamous cell carcinoma", "carcinoma"])
        self.assertEqual(pipeline.context("No squamous cell carcinoma.", 3, 26)[0], "negated")
        self.assertEqual(pipeline.context("Differential: carcinoma.", 14, 23)[0], "differential")
        self.assertEqual(pipeline.context("Formerly carcinoma.", 9, 18)[0], "historical")
        self.assertEqual(pipeline.context("Incidental carcinoma.", 11, 20)[0], "incidental")

    def test_scoped_rejection_history_and_unchanged_refresh(self):
        self.run_pipeline()
        ck, evidence = self.con.execute(
            "SELECT c.candidate_key,e.evidence_hash FROM term_code_candidates c "
            "JOIN term_lookup_evaluations e ON e.evaluation_id=c.evaluation_id "
            "JOIN page_term_mentions m ON m.mention_id=e.mention_id WHERE m.page_id=1 AND e.edition='ICD-O-4'").fetchone()
        pipeline.decide(self.con, ck, "candidate", "rejected", "Local page mismatch", evidence)
        self.run_pipeline()
        self.assertEqual(self.con.execute("SELECT review_status FROM term_code_candidates WHERE candidate_key=?", (ck,)).fetchone()[0], "rejected")
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_page_code_terms WHERE page_id=2 AND ICDO4='86320/1'").fetchone()[0], 1)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM term_review_decisions").fetchone()[0], 1)
        with self.assertRaises(sqlite3.IntegrityError):
            self.con.execute("DELETE FROM term_review_decisions")
        self.refs[1] = reference("ICD-O-4", "86320/1", "Gynandroblastoma", revision="b"*64)
        self.run_pipeline()
        self.assertEqual(self.con.execute("SELECT c.review_status FROM term_code_candidates c JOIN term_lookup_evaluations e ON e.evaluation_id=c.evaluation_id JOIN page_term_mentions m ON m.mention_id=e.mention_id WHERE m.page_id=1 AND e.edition='ICD-O-4' AND e.is_current=1").fetchone()[0], "needs_review")

    def test_stable_keys_and_history(self):
        self.run_pipeline()
        before = self.con.execute("SELECT mention_id,observation_key FROM page_term_mentions ORDER BY mention_id").fetchall()
        counts = [self.con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in pipeline.TABLES]
        self.run_pipeline()
        self.assertEqual(before, self.con.execute("SELECT mention_id,observation_key FROM page_term_mentions ORDER BY mention_id").fetchall())
        self.assertEqual(counts, [self.con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0] for t in pipeline.TABLES])
        plan = self.con.execute("EXPLAIN QUERY PLAN SELECT * FROM term_lookup_evaluations WHERE mention_id=1 AND edition='ICD-O-4' AND is_current=1").fetchone()[3]
        self.assertIn("ix_term_evaluation_observation", plan)

    def test_multiple_evidence_consolidated_without_overwriting_source(self):
        self.con.execute("INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype,term_role,TermUS,TermNormUS) VALUES(1,0,'Gynandroblastoma','86320/1',0,'preferred','Gynandroblastoma','Gynandroblastoma')")
        self.run_pipeline()
        rows = self.con.execute("SELECT code_kind,is_proposed_code FROM v_page_code_terms WHERE page_id=1 AND ICDO4='86320/1'").fetchall()
        self.assertEqual(rows, [("source_assignment; candidate", 0)])
        self.assertEqual(self.con.execute("SELECT code FROM entity_codes").fetchone()[0], "86320/1")

    def test_ambiguity_and_evidence_rows(self):
        self.refs.append(reference("ICD-O-4", "86321/1", "Gynandroblastoma", row=4))
        self.run_pipeline()
        outcomes = self.con.execute("SELECT DISTINCT lookup_outcome FROM v_page_code_terms WHERE page_id=1 AND code_edition='ICD-O-4'").fetchall()
        self.assertEqual(outcomes, [("ambiguous",)])
        evidence = json.loads(self.con.execute("SELECT reference_evidence FROM term_code_candidates LIMIT 1").fetchone()[0])
        self.assertEqual(evidence[0]["row"], 3)
        provenance = self.con.execute(
            "SELECT reference_file,reference_sheet,reference_row,reference_sha256 "
            "FROM v_entity_term_code_matches WHERE page_id=1 "
            "AND edition='ICD-O-4' ORDER BY candidate_order LIMIT 1"
        ).fetchone()
        self.assertEqual(provenance, ("local.xlsx", "Morphology", 3, "a"*64))
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM page_site_hints").fetchone()[0], 0)

    def test_lossy_mapping_and_broader_labels_are_review_only(self):
        self.con.execute("UPDATE entity_pages SET title='Gynandroblastoma, NOS' WHERE page_id=1")
        self.run_pipeline()
        row = self.con.execute("SELECT match_type,review_status,is_proposed_code,is_proposed_term FROM v_page_code_terms WHERE page_id=1 AND ICDO4='86320/1'").fetchone()
        self.assertEqual(row, ("normalized", "needs_review", 1, 1))
        self.con.execute("UPDATE entity_pages SET title='Unclassified squamous cell carcinoma variant' WHERE page_id=1")
        self.refs.append(reference("ICD-O-4", "80700/3", "Squamous cell carcinoma", row=4))
        self.run_pipeline()
        row = self.con.execute("SELECT match_type,conditions,lookup_outcome FROM v_page_code_terms WHERE page_id=1 AND ICDO4='80700/3'").fetchone()
        self.assertEqual(row[0], "broader")
        self.assertIn("qualifiers", row[1])
        self.assertEqual(row[2], "needs_review")

    def test_mapping_rejection_is_edition_scoped(self):
        self.run_pipeline()
        pipeline.decide(self.con, pipeline.mapping_target("Gynandroblastoma", "ICD-O-4", "86320/1"),
                        "term_edition_code", "rejected", "Reference relationship disputed", "a"*64)
        self.run_pipeline()
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_page_code_terms WHERE ICDO4='86320/1'").fetchone()[0], 0)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM v_page_code_terms WHERE ICDO32='8632/1'").fetchone()[0], 2)

    def test_legacy_review_and_missing_current_html_survive_without_replay(self):
        import term_recovery
        manifest = {"source_kind": "AI_recovered_prose", "batch": "test", "terms": [{
            "term": "Historical recovered tumor", "suggested_qualifier": "subtype",
            "terminology_status": "historical", "note": "Preserve curated evidence",
            "sources": [{"table": "entity_codes", "row_id": 99, "page_id": 1,
                         "page_title": "Gynandroblastoma",
                         "original_text": "Earlier source revision contained the name"}],
            "matches": [{"edition": "ICD-O-4", "code": "80000/3",
                         "official_term": "Neoplasm, malignant", "match_type": "broader",
                         "candidate_order": 1, "conditions": "Review classification",
                         "reference_file": "reference.xlsx", "reference_sheet": "Morphology",
                         "reference_row": 12, "reference_sha256": "a"*64,
                         "code_term_evidence": [{"term": "Neoplasm, malignant", "row": 12}]}]}]}
        term_recovery.populate(self.con, manifest)
        self.con.execute("UPDATE entity_term_provenance SET review_status='approved'")
        self.con.execute("UPDATE entity_term_code_matches SET review_status='rejected'")
        self.run_pipeline()
        self.run_pipeline()
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM term_review_decisions").fetchone()[0], 2)
        self.assertEqual(
            self.con.execute(
                "SELECT imported_rows FROM term_pipeline_migrations WHERE migration_key=?",
                (pipeline.LEGACY_MIGRATION,),
            ).fetchone()[0],
            1,
        )
        self.assertEqual(self.con.execute("SELECT term_origin,context_class,review_status FROM page_term_mentions WHERE term_origin='legacy_import'").fetchone(), ("legacy_import", "historical", "approved"))
        self.assertEqual(self.con.execute("SELECT review_status FROM term_code_candidates WHERE legacy_match_key IS NOT NULL").fetchone()[0], "rejected")
        self.assertEqual(self.con.execute("SELECT is_current FROM term_lookup_evaluations WHERE matcher_version='legacy-import'").fetchone()[0], 0)

    def test_pipeline_tables_reject_invalid_enums(self):
        self.run_pipeline()
        with self.assertRaises(sqlite3.IntegrityError):
            self.con.execute(
                "INSERT INTO term_review_decisions(decision_key,target_key,scope,outcome,reason,"
                "evidence_hash,decided_at) VALUES('bad','bad','unsupported','approved','x',?, 'now')",
                ("a" * 64,),
            )

    def test_refresh_cleanup_removes_standalone_placeholder_rows(self):
        self.con.execute(
            "INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype,TermUS,TermNormUS) "
            "VALUES(1,0,'Not applicable.','',0,'Not applicable.','Not applicable')"
        )
        self.con.execute(
            "INSERT INTO entity_related_terms(page_id,kind,term,TermUS,TermNormUS) "
            "VALUES(1,'other','Not-Applicable','Not-Applicable','Not applicable')"
        )
        self.con.execute(
            "INSERT INTO entity_related_terms(page_id,kind,term,TermUS,TermNormUS) "
            "VALUES(1,'acceptable','N/A','N/A','N A')"
        )
        self.con.execute(
            "INSERT INTO page_icdo_codes(page_id,term_in_coding_section,TermUS,TermNormUS) "
            "VALUES(1,'Not applicable.','Not applicable.','Not applicable')"
        )
        self.con.execute(
            "INSERT INTO entity_related_terms(page_id,kind,term,TermUS,TermNormUS) "
            "VALUES(1,'other','Tumor (classification not applicable)',"
            "'Tumor (classification not applicable)','Tumor')"
        )
        removed = pipeline.cleanup(self.con)
        self.assertEqual(removed, {
            "entity_codes": 1,
            "entity_related_terms": 2,
            "page_icdo_codes": 1,
            "entity_term_provenance": 0,
            "entity_term_code_matches": 0,
            "term_reference_rows": 0,
            "term_code_candidates": 0,
            "page_term_mentions": 0,
            "page_entity_evidence": 0,
        })
        self.assertEqual(self.con.execute("SELECT term FROM entity_related_terms").fetchone()[0],
                         "Tumor (classification not applicable)")
        for table, column in (("entity_codes", "term"), ("entity_related_terms", "term"),
                              ("page_icdo_codes", "term_in_coding_section")):
            self.assertFalse(any(is_standalone_placeholder(row[0])
                                for row in self.con.execute(f"SELECT {column} FROM {table}")))


if __name__ == "__main__":
    unittest.main()
