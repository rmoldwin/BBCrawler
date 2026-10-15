import _bootstrap
import copy
from contextlib import chdir
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import unquote

import nbformat
import build_runner
import build_local_docs
import bluebooks_local as local
from project_paths import APP, ROOT, SQL, DEFAULT_CONFIG, load_config


class RepositoryLayoutTests(unittest.TestCase):
    def test_file_locations_do_not_depend_on_working_directory(self):
        with tempfile.TemporaryDirectory() as folder, chdir(folder):
            self.assertEqual(local.ROOT, ROOT)
            self.assertEqual(DEFAULT_CONFIG, ROOT / "config.json")
            self.assertTrue((SQL / "schema.sql").is_file())
            self.assertTrue((SQL / "00_dbo_Clean2.sql").is_file())
            self.assertTrue((local.COMPANION / "bb_entity_extract.py").is_file())

    def test_settings_paths_are_relative_to_settings_file(self):
        with tempfile.TemporaryDirectory() as folder, tempfile.TemporaryDirectory() as elsewhere:
            path = Path(folder) / "settings.json"
            absolute = str(Path(folder) / "private-session.json")
            path.write_text(json.dumps({"db_path": "saved.db", "auth_state_path": absolute}))
            with chdir(elsewhere):
                config = load_config(path)
            self.assertEqual(Path(config["db_path"]), Path(folder) / "saved.db")
            self.assertEqual(config["auth_state_path"], absolute)

    def test_schema_and_normalization_load_from_another_directory(self):
        from contextlib import closing
        import sqlite3
        from clean_term2 import clean2
        with tempfile.TemporaryDirectory() as folder, chdir(folder):
            with closing(sqlite3.connect(":memory:")) as connection:
                local.migrate_sqlite(connection)
                self.assertGreater(len(local.columns(connection, "page_term_mentions")), 5)
            self.assertEqual(clean2("Adenocarcinoma, NOS"), "Adenocarcinoma")

    def test_command_help_from_another_directory(self):
        with tempfile.TemporaryDirectory() as folder:
            for script in ("bluebooks_books.py", "bluebooks_crawl.py", "bluebooks_fts.py",
                           "search.py", "bluebooks_local.py", "validate_term_pipeline.py"):
                with self.subTest(script=script):
                    result = subprocess.run(
                        [sys.executable, str(APP / script), "--help"], cwd=folder,
                        capture_output=True, text=True, encoding="utf-8")
                    self.assertEqual(result.returncode, 0, result.stderr)

    def test_runner_regeneration_preserves_reader_cells_and_settings(self):
        first = build_runner.build()
        custom = nbformat.v4.new_code_cell("# My own analysis\nanswer = 42")
        first.cells.append(custom)
        collection = next(c for c in first.cells if c.id == "runner-collect")
        collection.source = collection.source.replace("BOOKS = []", "BOOKS = [48, 51]")
        search = next(c for c in first.cells if c.id == "runner-search")
        search.source = search.source.replace("'neuroendocrine'", "'gynandroblastoma'")
        workspace = next(c for c in first.cells if c.id == "runner-workspace")
        workspace.source = workspace.source.replace("PROJECT_FOLDER = None", "PROJECT_FOLDER = 'chosen-folder'")
        second = build_runner.build(copy.deepcopy(first))
        third = build_runner.build(copy.deepcopy(second))
        self.assertEqual([c.source for c in second.cells], [c.source for c in third.cells])
        self.assertEqual(second.cells[-1].source, custom.source)
        self.assertIn("BOOKS = [48, 51]", next(c.source for c in second.cells if c.id == "runner-collect"))
        self.assertIn("'gynandroblastoma'", next(c.source for c in second.cells if c.id == "runner-search"))
        self.assertIn("PROJECT_FOLDER = 'chosen-folder'", next(c.source for c in second.cells if c.id == "runner-workspace"))
        for entry in second.cells:
            if entry.cell_type == "code":
                compile(entry.source, entry.id, "exec")
                self.assertEqual(entry.outputs, [])
                self.assertIsNone(entry.execution_count)
        for name in ("login", "discover", "collect", "refresh", "mirror"):
            source = next(c.source for c in second.cells if c.id == f"runner-{name}")
            self.assertIn("= False", source)
            self.assertIn("raise RuntimeError", source)

    def test_active_markdown_links_resolve(self):
        documents = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md")),
                     *sorted((ROOT / "issues").rglob("*.md"))]
        for path in documents:
            text = path.read_text(encoding="utf-8")
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                target = unquote(target.strip("<>").split("#", 1)[0])
                if not target or "://" in target or target.startswith("mailto:"):
                    continue
                with self.subTest(file=path.name, target=target):
                    resolved = (path.parent / target).resolve()
                    self.assertTrue(resolved.exists(), f"{path}: {target}")
                    self.assertNotIn("Archive", resolved.relative_to(ROOT).parts)

    def test_table_reference_has_every_managed_table(self):
        from contextlib import closing
        import sqlite3
        with closing(sqlite3.connect(":memory:")) as connection:
            local.migrate_sqlite(connection)
            text = build_local_docs.table_reference(connection)
        for table in local.TABLES:
            self.assertIn(f"## `{table}`", text)
        self.assertNotIn("Completed term migration", text)
        self.assertIn("candidateTermUS32", text)
        self.assertIn("candidateTermUS4", text)
        self.assertIn("not a code crosswalk", text)

    def test_runner_read_only_cells_and_confirmation_guards(self):
        from contextlib import closing
        import sqlite3
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as folder:
            database = Path(folder) / "saved.db"
            config_path = Path(folder) / "config.json"
            config_path.write_text(json.dumps({
                "db_path": "saved.db", "auth_state_path": "auth.json"}))
            with closing(local.connect_sqlite(database)) as connection:
                local.migrate_sqlite(connection)
                connection.execute("INSERT INTO books(book_id,title,url) VALUES(1,'Fixture','local:test')")
                connection.commit()
                local.term_pipeline.ensure_views(connection)
                local.rebuild_sqlite_search(connection)
            nb = build_runner.build()
            cells = {entry.id: entry.source for entry in nb.cells if entry.cell_type == "code"}
            workspace = cells["runner-workspace"].replace(
                "PROJECT_FOLDER = None", f"PROJECT_FOLDER = {str(ROOT)!r}")
            workspace = workspace.replace("CONFIG_PATH = DEFAULT_CONFIG",
                                          f"CONFIG_PATH = Path({str(config_path)!r})")
            displayed = []
            namespace = {"display": displayed.append}
            with tempfile.TemporaryDirectory() as elsewhere, chdir(elsewhere):
                exec(workspace, namespace)
                for name in ("inventory", "search", "terms"):
                    exec(cells[f"runner-{name}"], namespace)
            self.assertEqual(len(displayed), 3)
            self.assertEqual(len(displayed[0]), 1)
            with patch.object(local, "backup_databases") as backup, \
                 patch.object(subprocess, "Popen") as process:
                for name in ("refresh", "login", "discover", "collect", "mirror"):
                    with self.subTest(name=name), self.assertRaises(RuntimeError):
                        exec(cells[f"runner-{name}"], namespace)
                backup.assert_not_called()
                process.assert_not_called()


if __name__ == "__main__":
    unittest.main()
