import _bootstrap
import copy
import json
from contextlib import closing
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

import bluebooks_local as local


class LocalTests(unittest.TestCase):
    def setUp(self):
        self.con = sqlite3.connect(":memory:")
        local.migrate_sqlite(self.con)
        self.con.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Test','local:test')")
        self.con.execute("INSERT INTO pages(page_id,book_id,site_page_id,url,title) VALUES(1,1,1,'local:page','Test')")
        self.con.executemany(
            "INSERT INTO sections(page_id,heading,body_text,ord) VALUES(1,?,?,?)",
            [("Definition", "carcinoma alpha", 1), ("Features", "beta carcinoma", 2)],
        )
        self.con.commit()

    def tearDown(self):
        self.con.close()

    def test_migration_idempotent_and_activity_excluded(self):
        local.migrate_sqlite(self.con)
        self.assertEqual(self.con.execute("PRAGMA user_version").fetchone()[0], local.VERSION)
        self.assertFalse(self.con.execute("SELECT 1 FROM sqlite_master WHERE name='agent_jobs'").fetchone())
        self.assertNotIn("crawl_queue", local.TABLES)
        self.assertNotIn("agent_jobs", local.TABLES)
        unique_keys = {
            tuple(row[2] for row in self.con.execute(f'PRAGMA index_info("{index[1]}")'))
            for index in self.con.execute('PRAGMA index_list("entity_identifiers")')
            if index[2]
        }
        self.assertIn(
            ("page_id", "system", "identifier", "source_heading", "term"),
            unique_keys,
        )

    def test_legacy_identifier_table_migrates_to_provenance_key(self):
        self.con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        self.con.execute("DROP TABLE entity_identifiers")
        self.con.execute(
            "CREATE TABLE entity_identifiers ("
            "identifier_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),"
            "system TEXT NOT NULL CHECK(system IN ('OMIM')), identifier TEXT NOT NULL,"
            "term TEXT NOT NULL, source_heading TEXT NOT NULL, raw_text TEXT NOT NULL,"
            "UNIQUE(page_id,system,identifier,term))"
        )
        self.con.execute(
            "INSERT INTO entity_identifiers VALUES"
            "(1,1,'OMIM','145001','','Pathogenesis','MIM 145001')"
        )
        self.con.commit()

        local.migrate_sqlite(self.con)

        self.assertEqual(
            self.con.execute(
                "SELECT source_kind FROM entity_identifiers WHERE identifier='145001'"
            ).fetchone()[0],
            "section_text",
        )
        self.assertIn(
            "ix_entity_identifiers_lookup",
            {row[1] for row in self.con.execute('PRAGMA index_list("entity_identifiers")')},
        )
        self.con.execute(
            "INSERT INTO entity_identifiers "
            "(page_id,system,identifier,term,source_kind,source_heading,raw_text) "
            "VALUES(1,'OMIM','145001','','section_text','Genetic factors','MIM 145001')"
        )
        self.assertEqual(
            self.con.execute(
                "SELECT COUNT(*) FROM entity_identifiers WHERE identifier='145001'"
            ).fetchone()[0],
            2,
        )

    def test_page_and_navigation_indexes(self):
        expected = {"page_term_mentions": "page_id", "page_icdo_codes": "page_id",
                    "authors": "page_id", "chapters": "book_id",
                    "images": "section_id", "references": "section_id"}
        for table, col in expected.items():
            indexes = [list(self.con.execute(f'PRAGMA index_info("{i[1]}")'))
                       for i in self.con.execute(f'PRAGMA index_list("{table}")')]
            self.assertTrue(any(rows and rows[0][2] == col for rows in indexes))
            plan = self.con.execute(
                f'EXPLAIN QUERY PLAN SELECT * FROM "{table}" WHERE "{col}"=?', (1,)
            ).fetchone()[3]
            self.assertIn("SEARCH", plan)
        for col in ("chapter_id", "parent_group"):
            plan = self.con.execute(
                f'EXPLAIN QUERY PLAN SELECT * FROM page_groups WHERE "{col}"=?', (1,)
            ).fetchone()[3]
            self.assertIn("SEARCH", plan)

    def test_server_index_definition_matching(self):
        self.assertEqual(local.server_default("datetime('now')"), " DEFAULT SYSUTCDATETIME()")
        self.assertEqual(local.server_default("(datetime('now'))"), " DEFAULT SYSUTCDATETIME()")
        self.assertEqual(local.server_default(None), "")
        self.assertEqual(
            local._server_type("source_heading", "TEXT", "entity_identifiers"),
            "NVARCHAR(100)",
        )
        self.assertEqual(local._server_type("icdo4_code", "TEXT", "cpc_curation"),
                         "NVARCHAR(40)")
        self.assertEqual(local._server_type("icdo32_code", "TEXT", "cpc_curation"),
                         "NVARCHAR(40)")
        self.assertEqual(
            local._foreign_key_name("cpc_curation", "book_id", "books"),
            "fk_local_cpc_curation_book_id_books",
        )
        index = {"type": 1, "disabled": False, "filter": None, "unique": False,
                 "keys": (("icdo_code", False), ("page_id", False))}
        self.assertTrue(local.index_covers(index, ["icdo_code", "page_id"], False))
        self.assertFalse(local.index_covers(index, ["page_id", "icdo_code"], False))
        self.assertFalse(local.index_covers(index, ["icdo_code", "page_id"], True))
        self.assertFalse(local.index_covers(dict(index, disabled=True), ["icdo_code", "page_id"], False))
        self.assertFalse(local.index_covers(dict(index, filter="page_id > 0"),
                                           ["icdo_code", "page_id"], False))

    def test_duplicate_cleanup_protects_dependencies(self):
        from unittest.mock import Mock
        victim = {"name": "ux_local_pages_url", "id": 3, "type": 2,
                  "protected": False, "disabled": False, "unique": True,
                  "filter": None, "keys": (("url", False),), "include": (),
                  "options": (0, False), "compression": (0,)}
        keeper = dict(victim, name="existing_url_constraint", id=2, protected=True)
        cur = Mock()
        cur.execute.return_value.fetchone.return_value = (1,)
        with patch.object(local, "server_indexes", return_value=[victim, keeper]):
            with self.assertRaisesRegex(ValueError, "dependency"):
                local.consolidate_server_indexes(cur)
        self.assertFalse(any("DROP INDEX" in str(c) for c in cur.execute.call_args_list))
        cur.reset_mock()
        cur.execute.return_value.fetchone.return_value = None
        with patch.object(local, "server_indexes",
                          side_effect=lambda cursor, table: [victim, keeper] if table == "pages" else []):
            local.consolidate_server_indexes(cur)
        self.assertTrue(any("DROP INDEX [ux_local_pages_url]" in str(c)
                            for c in cur.execute.call_args_list))
        cur.reset_mock()
        with patch.object(local, "server_indexes",
                          side_effect=lambda cursor, table: [victim] if table == "pages" else []):
            local.consolidate_server_indexes(cur)
        cur.execute.assert_not_called()

    def test_search_cross_sections_update_delete(self):
        local.build_documents(self.con)
        local.rebuild_sqlite_search(self.con)
        self.assertEqual(len(local.search(self.con, "alpha AND beta")), 1)
        self.assertEqual(len(local.search(self.con, '"carcinoma alpha"')), 1)
        self.assertEqual(len(local.search(self.con, "carc*")), 1)
        self.assertEqual(len(local.search(self.con, "carcinoma OR missing", book_id=1)), 1)
        self.assertEqual(len(local.search(self.con, "carcinoma", book_id=2)), 0)
        self.con.execute("UPDATE sections SET body_text='gamma' WHERE ord=1")
        local.build_documents(self.con)
        local.rebuild_sqlite_search(self.con)
        self.assertEqual(len(local.search(self.con, "alpha")), 0)
        self.con.execute("DELETE FROM sections")
        local.build_documents(self.con)
        local.rebuild_sqlite_search(self.con)
        self.assertEqual(len(local.search(self.con, "carcinoma")), 0)

    def test_deterministic_documents(self):
        self.con.execute(
            "INSERT INTO sections(page_id,heading,body_text,ord) VALUES(1,'Send us Feedback','',3)"
        )
        local.build_documents(self.con)
        before = list(self.con.execute("SELECT * FROM page_search_documents"))
        self.assertNotIn("Send us Feedback", before[0][3])
        local.build_documents(self.con)
        self.assertEqual(before, list(self.con.execute("SELECT * FROM page_search_documents")))

    def test_body_recovery_preserves_ids_links_and_is_idempotent(self):
        self.con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        self.con.execute("UPDATE sections SET body_text='' WHERE heading='Definition'")
        section_id = self.con.execute(
            "SELECT section_id FROM sections WHERE heading='Definition'"
        ).fetchone()[0]
        self.con.execute(
            "INSERT INTO images(page_id,section_id,caption) VALUES(1,?,'retained')", (section_id,)
        )
        self.con.execute(
            'INSERT INTO "references"(page_id,section_id,token) VALUES(1,?,\'12345\')', (section_id,)
        )
        self.con.execute("UPDATE pages SET raw_html=? WHERE page_id=1", (
            '<app-chaptercontent><div class="description" id="d">'
            '<p>Definition</p><p>Recovered definition.</p></div>'
            '<div class="description" id="h"><p>Histopathology</p>'
            '<p>A teratoma of the lung is a test phrase.</p></div>'
            '<div class="description"><p>Prognosis</p></div></app-chaptercontent>',
        ))
        first = local.backfill_sections(self.con)
        self.assertEqual(first["sections_filled"], 1)
        self.assertEqual(first["sections_added"], 1)
        before = list(self.con.execute("SELECT * FROM sections ORDER BY section_id"))
        second = local.backfill_sections(self.con)
        self.assertEqual(second["sections_added"], 0)
        self.assertEqual(second["sections_filled"], 0)
        self.assertEqual(before, list(self.con.execute("SELECT * FROM sections ORDER BY section_id")))
        self.assertEqual(self.con.execute(
            "SELECT body_text FROM sections WHERE section_id=?", (section_id,)
        ).fetchone()[0], "Recovered definition.")
        for table in ('images', '"references"'):
            self.assertEqual(self.con.execute(
                f"SELECT section_id FROM {table}"
            ).fetchone()[0], section_id)
        local.build_documents(self.con)
        local.rebuild_sqlite_search(self.con)
        self.assertEqual(len(local.search(self.con, '"teratoma of the lung"')), 1)

    def test_body_recovery_reports_nonempty_conflict(self):
        self.con.execute("UPDATE pages SET raw_html=? WHERE page_id=1", (
            '<app-chaptercontent><div class="description"><p>Definition</p>'
            '<p>Different saved definition.</p></div></app-chaptercontent>',
        ))
        report = local.backfill_sections(self.con)
        self.assertEqual(len(report["conflicts"]), 1)
        self.assertEqual(self.con.execute(
            "SELECT body_text FROM sections WHERE section_id=1"
        ).fetchone()[0], "carcinoma alpha")
        self.assertEqual(local.backfill_sections(self.con)["sections_added"], 0)

    def test_empty_entity_sections_are_pruned_only_when_unlinked(self):
        self.con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        self.con.executemany(
            "INSERT INTO sections(page_id,heading,body_text,ord) VALUES(1,?,?,?)",
            [("Attachment", "", 3), ("Authors", "  ", 4), ("Feedback", None, 5)],
        )
        ids = dict(self.con.execute(
            "SELECT heading,section_id FROM sections WHERE ord>=3"
        ))
        self.con.execute(
            "INSERT INTO images(page_id,section_id,caption) VALUES(1,?,'linked image')",
            (ids["Authors"],),
        )
        self.con.execute(
            'INSERT INTO "references"(page_id,section_id,token) VALUES(1,?,\'12345\')',
            (ids["Feedback"],),
        )

        removed = local.prune_empty_entity_sections(self.con)

        self.assertEqual(removed, 1)
        remaining = {r[0] for r in self.con.execute(
            "SELECT section_id FROM sections WHERE ord>=3"
        )}
        self.assertEqual(remaining, {ids["Authors"], ids["Feedback"]})

    def test_identifier_schema_and_search_do_not_create_morphology(self):
        self.con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        self.con.execute(
            "INSERT INTO entity_identifiers(page_id,system,identifier,term,source_heading,raw_text) "
            "VALUES(1,'OMIM','609310','Hereditary syndrome','ICD-O coding','609310 Hereditary syndrome')"
        )
        with self.assertRaises(sqlite3.IntegrityError):
            self.con.execute(
                "INSERT INTO entity_identifiers(page_id,system,identifier,term,source_heading,raw_text) "
                "VALUES(1,'ICDO','609310','Wrong','ICD-O coding','Wrong')"
            )
        local._codes(self.con)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM page_icdo_codes").fetchone()[0], 0)
        local.build_documents(self.con)
        local.rebuild_sqlite_search(self.con)
        self.assertEqual(len(local.search(self.con, "609310")), 1)

    def test_raw_codes_and_structured_supplement(self):
        self.con.execute("INSERT INTO entity_pages(page_id,book_id) VALUES(1,1)")
        self.con.execute(
            "INSERT INTO entity_codes(entity_code_id,page_id,ordinal,term,code,is_subtype) "
            "VALUES(1,1,0,'Sample subtype','81403/3',1)"
        )
        local._codes(self.con)
        row = self.con.execute("SELECT icdo_code,icdo_code_raw,section_heading FROM page_icdo_codes").fetchone()
        self.assertEqual(row, ("8140/3", "81403/3", "Subtype(s)"))

    def test_entities_both_editions_saved_html(self):
        self.con.execute("DELETE FROM sections")
        self.con.execute("UPDATE books SET edition='5th' WHERE book_id=1")
        self.con.execute("INSERT INTO books(book_id,title,edition,url) VALUES(2,'Sixth','6th','local:sixth')")
        for bid in (1, 2):
            self.con.execute("INSERT INTO chapters(chapter_id,book_id,title) VALUES(?,?,?)",
                             (bid, bid, "Chapter"))
            self.con.execute("INSERT INTO page_groups(group_id,chapter_id,label,level) VALUES(?,?,?,1)",
                             (bid, bid, "Category"))
        html = lambda code: (
            '<div class="description"><p>Definition</p><p>Test definition.</p></div>'
            f'<div class="description"><p>ICD-O coding</p><p>{code} Test entity</p></div>'
            '</app-chaptercontent>'
        )
        self.con.execute("UPDATE pages SET chapter_id=1,group_id=1,raw_html=? WHERE page_id=1",
                         (html("8140/3"),))
        self.con.execute(
            "INSERT INTO pages(page_id,book_id,chapter_id,group_id,site_page_id,url,title,raw_html) "
            "VALUES(2,2,2,2,2,'local:sixthpage','Test entity',?)", (html("81403/3"),))
        self.con.execute(
            "INSERT INTO pages(page_id,book_id,chapter_id,group_id,site_page_id,url,title,raw_html,page_type) "
            "VALUES(3,1,1,1,3,'local:frontmatter','Foreword',?,'foreword')", (html("8140/3"),))
        local._entities(self.con, "2026-10-06T00:00:00+00:00")
        self.assertEqual(list(self.con.execute("SELECT page_id,book_id FROM entity_pages ORDER BY page_id")),
                         [(1, 1), (2, 2)])
        self.assertEqual(list(self.con.execute("SELECT page_id,code FROM entity_codes ORDER BY page_id")),
                         [(1, "8140/3"), (2, "81403/3")])
        local._codes(self.con)
        self.assertEqual(self.con.execute("SELECT COUNT(*) FROM page_icdo_codes").fetchone()[0], 2)

    def test_policy_and_curation_preservation(self):
        rules = local.companion("build_agent_tables")
        self.assertEqual(rules._heading_policy("Acceptable terminology")[:2], ("excluded", False))
        self.assertEqual(rules._heading_policy("Not recommended terminology")[:2], ("excluded", False))
        self.assertNotIn("cpc_curation", local.DERIVED)
        self.assertEqual(local._row_bytes([1, 0.9]), local._row_bytes([True, local.Decimal("0.90")]))

    def test_freshness_rejects_changed_corpus(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.db"
            Path(str(path) + ".local-build.json").write_text(json.dumps({
                "version": local.VERSION, "corpus_hashes": local.corpus_hashes(self.con),
                "reference_hashes": {},
            }), encoding="utf-8")
            local.check_freshness(path, self.con)
            self.con.execute("UPDATE sections SET body_text='changed'")
            with self.assertRaisesRegex(ValueError, "Corpus changed"):
                local.check_freshness(path, self.con)

    def test_normalization_boundaries(self):
        clean = local.companion("clean_term").clean
        self.assertEqual(clean("(specify example)"), "")
        self.assertEqual(clean("Grade II"), "Grade II")
        self.assertEqual(clean("Tumour type III"), "Tumor 3")
        self.assertEqual(clean("Tumour TYPE III"), "Tumor TYPE 3")
        self.assertEqual(clean("A nos"), "A nos")

    def test_query_adapter_subset(self):
        adapter = local.companion("local_queries")
        self.assertEqual(adapter.read_frame(
            "SELECT TOP 1 LEFT(body_text,5) AS preview FROM dbo.sections ORDER BY ord",
            self.con).iloc[0]["preview"], "carci")
        with self.assertRaisesRegex(ValueError, "read-only"):
            adapter.read_frame("DELETE FROM dbo.sections", self.con)

    def test_missing_input_does_not_modify_database(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.db"
            path.write_bytes(b"unchanged")
            with patch.object(local, "reference_rows", side_effect=FileNotFoundError("required input")):
                with self.assertRaises(FileNotFoundError):
                    local.refresh_local(path)
            self.assertEqual(path.read_bytes(), b"unchanged")

    def test_refresh_failure_rolls_back_existing_data(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.db"
            dst = sqlite3.connect(path)
            self.con.backup(dst)
            dst.close()
            with patch.object(local, "reference_rows", return_value=({}, {})), \
                 patch.object(local, "_entities", side_effect=RuntimeError("parse failed")):
                with self.assertRaises(RuntimeError):
                    local.refresh_local(path)
            with closing(sqlite3.connect(path)) as con:
                self.assertEqual(con.execute("SELECT COUNT(*) FROM sections").fetchone()[0], 2)
                self.assertIsNone(con.execute("SELECT title_norm FROM pages").fetchone()[0])

    def test_refresh_preserves_manual_curation_rows(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.db"
            self.con.execute(
                "INSERT INTO cpc_curation(curation_id,book_id,icdo4_code,naaccr_note) "
                "VALUES(1,1,'81403/3','manual decision')"
            )
            self.con.commit()
            with closing(sqlite3.connect(path)) as dst:
                self.con.backup(dst)
            with patch.object(local, "reference_rows", return_value=({}, {})), \
                 patch.object(local, "_entities"), patch.object(local, "_evidence"), \
                 patch.object(local.term_recovery, "load_manifest", return_value={
                     "terms": [], "reference_files": [], "source_kind": "AI_recovered_prose",
                     "batch": "test",
                 }):
                local.refresh_local(path)
            with closing(sqlite3.connect(path)) as con:
                self.assertEqual(con.execute(
                    "SELECT curation_id,icdo4_code,naaccr_note FROM cpc_curation"
                ).fetchone(), (1, "81403/3", "manual decision"))

    def test_notebook_upgrades_idempotent(self):
        import nbformat
        from notebook_local import upgrade_runner, upgrade_explorer, upgrade_sites
        root = Path(local.ROOT)
        for path, fn in (
            (root / "Crawler_Runner.ipynb", upgrade_runner),
            (local.COMPANION / "BlueBooks_Explorer_3.ipynb", upgrade_explorer),
            (local.COMPANION / "Querying_Site_Specific_Terms.ipynb", upgrade_sites),
        ):
            nb = nbformat.read(path, 4)
            once = fn(copy.deepcopy(nb))
            twice = fn(copy.deepcopy(once))
            self.assertEqual([c.source for c in once.cells], [c.source for c in twice.cells])
            for cell in once.cells:
                if cell.cell_type == "code" and not any(l.lstrip().startswith(("%", "!")) for l in cell.source.splitlines()):
                    compile(cell.source, str(path), "exec")

    def test_step7_generator_preserves_cells_on_repeat(self):
        import nbformat
        generator = local.companion("build_notebook_step7")
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "Explorer.ipynb"
            nb = nbformat.read(local.COMPANION / "BlueBooks_Explorer_3.ipynb", 4)
            nb.cells.append(nbformat.v4.new_code_cell("# user-owned scratch cell\nx = 123"))
            nbformat.write(nb, path)
            with patch.object(generator, "NB", path):
                generator.main()
                once = nbformat.read(path, 4)
                generator.main()
                twice = nbformat.read(path, 4)
            self.assertEqual([c.source for c in once.cells], [c.source for c in twice.cells])
            self.assertEqual(twice.cells[-1].source, "# user-owned scratch cell\nx = 123")


if __name__ == "__main__":
    unittest.main()
