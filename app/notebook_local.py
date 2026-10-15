"""Preserve reader cells while updating shared notebook instructions."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import shutil
import nbformat
from project_paths import ROOT, COMPANION

MARKER = "## Local data parity (no online access)"
TERM_MARKER = "## Term hygiene and indexed US/comparison values"
RECOVERY_MARKER = "## Recovered alternate terms and suggested ICD-O matches"
SUMMARY = """## Local data parity (no online access)

This workflow updates saved data without logging in or visiting the website.
It reads the saved pages and local reference files, builds searchable text,
and keeps source assignments separate from suggested codes. SQL Server copying
is optional and checks that the copied values match SQLite.

Use the local refresh section only when you intend to change saved data.
It makes safety copies first. Missing inputs or conflicting review decisions
stop the update rather than silently discard information.
See the [data guide](../BBCrawler%20Notebook/docs/technical/data-guide.md).
"""
TERM_SUMMARY = """## Term hygiene and indexed US/comparison values

Term lists are cleaned of footnotes and list punctuation without changing
meaningful scientific signs. `TermUS` is the US-spelling display value;
`TermNormUS` is a simplified value for matching text, not a unique identifier.
Both are indexed in SQLite and SQL Server.

For writing, use the shared connection helper so automatic text maintenance
is available. Ordinary read-only database connections can read stored values.
See [text matching](../BBCrawler%20Notebook/docs/technical/reference-matching.md).
"""
RECOVERY_SUMMARY = """## Recovered alternate terms and suggested ICD-O matches

Saved page titles are kept even when no code is printed. Suggested matches
come from edition-specific reference files and retain their supporting rows.
A suggested code and a suggested official term are flagged independently;
neither silently replaces the wording or code on the page.

`v_page_code_terms` includes uncoded terms as well as source and suggested
codes. `v_term_candidate_evidence` shows why a match was offered.
Review decisions retain their history and their page or candidate scope.
Legacy `is_subtype` is kept only for compatibility; use explicit source and
relationship fields rather than treating it as a biological classification.
"""
TERM_CHECK = """# Read-only checks: use the existing local database, no crawl or login.
from contextlib import closing
import local_pipeline as local
with closing(local.connect_sqlite(local.CRAWLER / "bluebooks.db", readonly=True)) as term_db:
    print("Text matching problems:", local.validate_terms(term_db))
"""
RECOVERY_CHECK = """# Comprehensive read-only output: retain uncoded terms and proposed alternatives.
from contextlib import closing
import local_pipeline as local
with closing(local.connect_sqlite(local.CRAWLER / "bluebooks.db", readonly=True)) as recovery_db:
    rows = recovery_db.execute(
        "SELECT alias,book_name,edition,page_title,TermUS,candidateTermUS,"
        "ICDO32,ICDO4,is_proposed_code,is_proposed_term,lookup_outcome,review_status "
        "FROM v_page_code_terms ORDER BY page_id,TermUS LIMIT 30").fetchall()
    print("Terms, source codes and suggestions:", rows)
"""


def upgrade_terms(nb, *, crawler=False):
    if crawler:
        return upgrade_runner(nb)
    sections = ((TERM_MARKER, TERM_SUMMARY, TERM_CHECK, "# Read-only checks:"),
                (RECOVERY_MARKER, RECOVERY_SUMMARY, RECOVERY_CHECK,
                 "# Comprehensive read-only output:"))
    for marker, summary, check, prefix in sections:
        found = False
        for entry in nb.cells:
            if entry.cell_type == "markdown" and entry.source.startswith(marker):
                entry.source = summary
                found = True
            if entry.cell_type == "code" and entry.source.startswith(prefix):
                entry.source = check
                entry.outputs = []
                entry.execution_count = None
        if not found:
            nb.cells.extend([nbformat.v4.new_markdown_cell(summary),
                             nbformat.v4.new_code_cell(check)])
    return nb


def upgrade_recovery(nb, *, crawler=False):
    return upgrade_terms(nb, crawler=crawler)


def upgrade_runner(nb):
    from build_runner import build
    return build(nb)


def upgrade_explorer(nb):
    setup = """# Shared local pipeline setup; never contacts Blue Books online.
from pathlib import Path
import local_pipeline as local
LOCAL_SQLITE = Path(SQLITE_PATH) if "SQLITE_PATH" in globals() else local.CRAWLER / "bluebooks.db"
if "MIRROR_SQLSERVER" not in globals():
    MIRROR_SQLSERVER = False
"""
    build = """# Back up and refresh all local derived data; optional complete mirror.
print(local.backup_databases(LOCAL_SQLITE, local.CRAWLER / "local_backups",
                            "localhost" if MIRROR_SQLSERVER else None))
local_result = local.refresh_local(LOCAL_SQLITE)
print(local_result["counts"])
if MIRROR_SQLSERVER:
    print(local.mirror(LOCAL_SQLITE))
    with local.connect_server() as cn:
        print(local.server_search(cn))
"""
    for entry in nb.cells:
        src = entry.source
        if entry.cell_type != "code":
            continue
        if src.startswith("# Shared local pipeline setup;"):
            start = src.index("# Back up and refresh")
            entry.source = setup + src[start:]
        if "S.sync_book_corpus" in src and "ALL_BOOKS =" not in src:
            entry.source = setup + build
        if "S.sync_book_corpus" in src and "ALL_BOOKS =" in src:
            lines = [line for line in src.splitlines() if not any(
                text in line for text in ("S.store_book(", "S.sync_book_corpus(", "S.push_to_sqlserver("))]
            entry.source = setup + build + "\n" + "\n".join(lines)
        if "CL.import_sqlite(" in src:
            start = src.index("import bb_icdo_lookup")
            entry.source = setup + build + "\n" + src[start:].split("_counts =")[0] + """
_con = local.connect_sqlite(LOCAL_SQLITE)
LOOKUP = CL.CodeLookup(_con)
print("Lookup ready from shared local reference tables.")
"""
        if "SQLITE_PATH =" in src:
            import re
            entry.source = re.sub(
                r'^SQLITE_PATH\s*=\s*["\']bluebooks_demo\.db["\'].*$',
                'SQLITE_PATH = str(__import__("pathlib").Path.cwd().parent / "BBCrawler Notebook" / "bluebooks.db")',
                entry.source, flags=re.M)
        if "_srv = S.connect_sqlserver().cursor()" in entry.source:
            start = entry.source.index("_srv = S.connect_sqlserver().cursor()")
            end = entry.source.index("\nshow(pd.DataFrame", start)
            entry.source = entry.source[:start] + """from contextlib import closing
_rows = []
for _bid in ALL_BOOKS:
    _title = _con.execute("SELECT title FROM books WHERE book_id=?", (_bid,)).fetchone()[0]
    _rows.append((_bid, _title, "sqlite", *_con.execute(_audit, (_bid,) * 4).fetchone()))
if MIRROR_SQLSERVER:
    with closing(local.connect_server()) as _server:
        for _bid in ALL_BOOKS:
            _title = _con.execute("SELECT title FROM books WHERE book_id=?", (_bid,)).fetchone()[0]
            _rows.append((_bid, _title, "sqlserver", *_server.cursor().execute(_audit, *([_bid] * 4)).fetchone()))
""" + entry.source[end:]
        if "WHERE t.name = 'pages'" in entry.source and "sys.fulltext_indexes" in entry.source:
            entry.source = entry.source.replace("WHERE t.name = 'pages'",
                "WHERE t.name IN ('pages','sections','page_search_documents')")
        if "QUERY =" in src and "pages_fts" in src:
            entry.source = """# Search the same saved text on either database.
import local_pipeline as local
from pathlib import Path
QUERY = "neuroendocrine"
if _engine == "sqlite":
    with local.connect_sqlite(Path(SQLITE_PATH), readonly=True) as _search:
        show(pd.DataFrame(local.search(_search, QUERY), columns=["page_id","title","url","full_text"]))
else:
    with local.connect_server(SERVER, DATABASE) as _search:
        show(pd.DataFrame.from_records([tuple(r) for r in local.search(_search, QUERY, backend="sqlserver")],
                                      columns=["page_id","title","url","full_text"]))
"""
        if entry.source != src:
            entry.outputs = []
            entry.execution_count = None
    return _summaries(nb)


def _summaries(nb):
    found = False
    for entry in nb.cells:
        if entry.cell_type == "markdown" and entry.source.startswith(MARKER):
            entry.source = SUMMARY
            found = True
    if not found:
        nb.cells.insert(1, nbformat.v4.new_markdown_cell(SUMMARY))
    return upgrade_terms(nb)


def upgrade_sites(nb):
    for entry in nb.cells:
        src = entry.source
        if entry.cell_type != "code":
            continue
        if src.startswith("# Cell 1.0"):
            entry.source = "# Use the installed local environment; no downloads.\nimport pandas, sqlalchemy, matplotlib\n"
        if src.startswith("# Cell 1.1") and "# Connection details" in src:
            start = src.index("# Connection details")
            end = src.index("\n\ndef show_df", start)
            entry.source = src[:start] + """# Choose the database to inspect.
from pathlib import Path
from local_queries import read_frame
import local_pipeline as local
DB_KIND = "sqlite"
SQLITE_PATH = local.CRAWLER / "bluebooks.db"
if DB_KIND == "sqlite":
    con = local.connect_sqlite(SQLITE_PATH, readonly=True)
elif DB_KIND == "sqlserver":
    con = local.connect_server()
else:
    raise ValueError("DB_KIND must be sqlite or sqlserver")
""" + src[end:]
        if entry.source != src:
            entry.outputs = []
            entry.execution_count = None
    return _summaries(nb)


def backup_notebook(path):
    path = Path(path)
    if path.exists():
        backup = ROOT / "local_backups" / (
            path.stem + "-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + ".ipynb")
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup)
        return backup
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--companions", action="store_true",
                        help="Also update managed cells in neighboring exploration notebooks")
    args = parser.parse_args()
    targets = [(ROOT / "Crawler_Runner.ipynb", upgrade_runner)]
    if args.companions:
        targets.extend([
            (COMPANION / "BlueBooks_Explorer_3.ipynb", upgrade_explorer),
            (COMPANION / "BlueBooks_Explorer_2.ipynb", upgrade_explorer),
            (COMPANION / "Querying_Site_Specific_Terms.ipynb", upgrade_sites),
        ])
    for path, fn in targets:
        nb = nbformat.read(path, 4)
        result = fn(nb)
        nbformat.validate(result)
        backup_notebook(path)
        nbformat.write(result, path)
        print(f"Updated {path.name}; no cells executed.")


if __name__ == "__main__":
    main()
