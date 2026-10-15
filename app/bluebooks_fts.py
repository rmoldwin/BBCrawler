"""
Step 3 — (Re)build the FTS5 keyword index from the sections table.

Usage:
    python bluebooks_fts.py --config config.json

The FTS5 virtual table `sections_fts` is contentless, so we rebuild it
explicitly from `sections`. Safe to run repeatedly (it clears first).
"""
import argparse
import json
import sqlite3
import sys
from pathlib import Path
from contextlib import closing
from project_paths import DEFAULT_CONFIG, load_config


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the SQLite FTS5 index.")
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    args = ap.parse_args()
    cfg = load_config(args.config)

    from bluebooks_local import (connect_sqlite, migrate_sqlite, backfill_sections,
                                build_documents, rebuild_sqlite_search)
    with closing(connect_sqlite(Path(cfg["db_path"]))) as con:
        migrate_sqlite(con)
        with con:
            recovery = backfill_sections(con)
            build_documents(con)
            rebuild_sqlite_search(con)
        n = con.execute("SELECT COUNT(*) FROM sections_fts").fetchone()[0]
        pn = con.execute("SELECT COUNT(*) FROM pages_fts").fetchone()[0]
    print(f"[fts] indexed {n} sections and {pn} whole-page documents.")
    print(f"[fts] saved-HTML recovery: {recovery['sections_filled']} filled, "
          f"{recovery['sections_added']} added, {len(recovery['unparsed_pages'])} unparsed pages.")
    if recovery["sections_filled"] or recovery["sections_added"]:
        print("[fts] Sections changed; run the complete local refresh before SQL Server mirroring.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
