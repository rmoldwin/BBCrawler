"""Idempotent local-workflow notebook upgrades; preserve unrelated/user cells."""
from pathlib import Path
from datetime import datetime, timezone
import shutil
import nbformat

MARKER = "## Local data parity (no online access)"
TERM_MARKER = "## Term hygiene and indexed US/comparison values"
TERM_SUMMARY = """## Term hygiene and indexed US/comparison values

Schema version 10 cleans term-list footnotes (dagger, double dagger, asterisk,
section/paragraph marks), leading bullets, trailing whitespace and list punctuation.
Scientific signs, numeric superscripts/subscripts, codes, raw HTML, section prose
and snippets remain intact. The saved-page parser and database INSERT/UPDATE
triggers prevent these artifacts from returning.

| Table | Source for TermUS and TermNormUS |
|---|---|
| entity_codes | term |
| entity_related_terms | term |
| page_icdo_codes | term_in_coding_section |
| page_term_mentions | term_original |
| page_entity_evidence | term_clean (existing evidence grouping key) |

`TermUS = UpperInitial(CleanBritishSpelling2(CleanDisplayTerm(source)))` and
`TermNormUS = UpperInitial(Clean2(TermUS))`. Both are stored Unicode values with separate
nonunique lookup indexes in **both databases**. Stored values plus automatic
maintenance are used rather than computed columns, so ordinary SQLite connections
can read them without evaluating a Python UDF. Writes to these tables must use
`local.connect_sqlite`, which registers the deterministic functions.

Clean2 uses the existing deployed SQL Server v3 definition, explicitly selected
by the maintainer on 2026-10-10, not the earlier repository version. Its exact
SQL replacement program also drives Python, preventing rule drift. Case is
preserved inside Clean2; display handling uppercases only an initial ASCII a-z.
Digits, Greek symbols, punctuation-led values and the remaining characters stay
unchanged. No synonym equivalence or code crosswalk is inferred.
TermNormUS is separate from legacy term_clean/term_original_norm/matched_term_norm;
those keys keep the legacy Clean rules but no longer retain footnote decoration.

For an existing snapshot, `local.repair_term_tables(SQLITE_PATH)` makes fresh
SQLite and SQL Server COPY_ONLY backups, repairs the five tables in place,
preserves genuine IDs/codes/provenance, removes only saved-HTML-confirmed
misplaced prose approved by the maintainer, and verifies all 23 managed row hashes.
Full Runner/Explorer refreshes and mirrors also maintain the new columns.
Notebook regeneration backs up every notebook before writing it.

Initial suffix audit (per database): 674 page_icdo_codes rows, 673
page_term_mentions rows and 558 page_entity_evidence rows. The named entity
tables had no dagger/asterisk suffixes, but do contain trailing punctuation.
Confirmed misplaced explanatory prose is removed from uncoded entity/related
term rows. Scientific parenthetical qualifiers remain. Contextual code terms
containing punctuation/prose are recovered from an unambiguous structured
assignment in coding/subtype sections, otherwise set to NULL; their code evidence
is preserved. This was the initial version-7 repair; version 9 recovers explicit
name/code pairs from the same saved section, including shared-code alternatives
and nested headings, without assigning the parent diagnosis to a contextual code.

Completed in both databases on 2026-10-11: 44 misplaced uncoded entity rows
and 41 related-term prose/heading rows removed; 465 contextual code terms
repaired (407 recovered names, 58 NULL rather than invented names).
All code assignments, raw saved evidence and genuine scientific qualifiers
were retained. Source values changed in 32 entity-code, 14 retained related-term,
1,279 contextual-code, 814 mention and 672 evidence rows.
All five tables have separate TermUS/TermNormUS indexes and automatic maintenance.
Validation found no empty derived keys or rule mismatches; 23-table row-value
parity passed. Initial notebook and database backups are in local_backups;
SQL Server COPY_ONLY backups are in the instance's default Backup directory.

Version-9 follow-up: all 58 NULL coding names were recoverable from explicit
saved-source pairs. Code IDs and assignments are retained; any absent shared-code
alternatives are added, not discarded. Display capitalization also covers
identifier terms, reference terms/keys, recovered names and proposed official names.
Original prose and workbook code-term evidence JSON remain verbatim.
Absent optional workbook preferred terms remain NULL; none are invented.
Use `local.repair_term_display(SQLITE_PATH)` for the backed-up display repair;
Clean2 itself is unchanged. Both engines and all 25 managed tables are verified.
"""
TERM_CHECK = """# Read-only checks: use the existing local database, no crawl or login.
from contextlib import closing
import local_pipeline as local
with closing(local.connect_sqlite(local.CRAWLER / "bluebooks.db", readonly=True)) as term_db:
    print("Term hygiene/key mismatches:", local.validate_terms(term_db))
    print("Sample TermUS / TermNormUS:", term_db.execute(
        "SELECT term, TermUS, TermNormUS FROM entity_codes "
        "WHERE term LIKE '%tumour%' LIMIT 5"
    ).fetchall())
"""
RECOVERY_MARKER = "## Recovered alternate terms and suggested ICD-O matches"
RECOVERY_SUMMARY = """## Recovered alternate terms and suggested ICD-O matches

Schema version 8 preserves valid names embedded in the removed prose.
New names are in `entity_related_terms` with `kind='other'`; provenance is
explicitly `AI_recovered_prose` in `entity_term_provenance`. The suggested
qualifier is synonym, related, subtype, grouper or other, separate from
terminology acceptability. Historical names and uncoded diagnoses remain searchable.

`entity_term_code_matches` holds edition-specific exact/synonym/broader/conditional
**proposed** matches, official reference terms, workbook row/hash evidence and
conditions. These never overwrite source codes or count as positive source-code
evidence. Review status defaults to proposed. Code availability does not prove a
patient diagnosis or registry reportability.

Use `v_entity_terms` for every term once, `v_entity_term_provenance` for every
source link, and `v_entity_term_code_matches` for comprehensive terms plus candidate
codes, including unmapped terms. `source_code` and `suggested_code` are separate.
Multiple candidate rows are intentional. Avoid an edition WHERE filter that
accidentally removes NULL/unmapped rows.

Related-terminology extraction splits semicolons only outside balanced
parentheses, preserving terms such as `t(15;19) carcinoma`. Qualified
Acceptable/Not recommended labels are separated from their term lists, while
cross-references and explanatory prose are not stored as terms. Full refresh
re-extracts these rows from saved page HTML.

Schema version 10 adds `v_page_code_terms`: short book/version, chapter, page
title/URL, relevant sections, scalar TermUS/TermNormUS/candidateTermUS and ICDO32/ICDO4,
source/candidate kinds, subtype/qualifier/match/review metadata and conditions.
Each page/edition/code/TermUS pair occurs once; different terms sharing a code
remain separate. Only sections/metadata and page-level candidate topography
codes are concatenated. Site hints require confidence_score >= 0.9 and are
not verified term-specific or patient sites. Unmapped terms keep NULL codes.
`v_entity_term_code_matches.official_term` and `candidateTermUS` now display US
spelling; `official_term_source` preserves original reference wording.

### Deprecated legacy field: `is_subtype`

**Deprecated:** do not use `is_subtype` in new queries or extraction logic.
It remains exposed for compatibility only; prefer `term_role` and explicit
source provenance/relationship metadata. This section describes historical
behavior. It was a source-section flag, not an inferred biological
classification. In `entity_codes`, `1` meant the term came from a Blue Books
**Subtype(s)** section, including nested subtype sections; `0` meant it came
from the ordinary **ICD-O coding** section. `_parse_subtype_block` in the
companion `bb_entity_extract.py` set the legacy flag; `bluebooks_local.py`
stored it as 0/1.

For backward compatibility, `v_page_code_terms` still exposes this deprecated
field. Entity rows carry the stored flag; contextual `page_icdo_codes` rows
inherit it from a matching **page + raw code + TermUS** in `entity_codes`,
otherwise `0`. Historically, repeated occurrences used **`MAX(is_subtype)`**.
New consumers should use `term_role` and explicit provenance instead.

Recovered alternate terms in `entity_related_terms` appear with deprecated
`is_subtype=0`, even when their recovery metadata has `suggested_qualifier='subtype'`.
These deliberately express different things:

| Field | Meaning |
|---|---|
| Deprecated `is_subtype=1` | Legacy flag for extraction from a source subtype section |
| `suggested_qualifier='subtype'` | Proposed relationship for a recovered term |

**Deprecated `is_subtype=0` does not mean a diagnosis is not biologically a subtype.**
It means the legacy source-subtype flag was not established by this extraction pathway.

### `v_page_code_terms.terminology_kind` values

`terminology_kind` records where in the source page a term came from (provenance
only; not code validity, preferred-term, synonym or registry status):

| Value | Definition | Origin |
|---|---|---|
| `coding` | Term from the ICD-O coding or Subtype(s) section | `entity_codes` |
| `contextual` | Term-code pair found in section text | `page_icdo_codes` |
| `acceptable` | Related terminology labeled "Acceptable" | `entity_related_terms.kind='acceptable'` |
| `not_recommended` | Related terminology labeled "Not recommended" | `entity_related_terms.kind='not_recommended'` |
| `other` | Unlabeled related terminology, including recovered alternate terms | `entity_related_terms.kind='other'` |

A row with more than one origin combines distinct values alphabetically with
`; ` (for example `coding; contextual`). Filter with `LIKE` or split on `; `.

The frozen recovery manifest is `Library/recovered_terms.json` in the crawler
project. Full refresh re-applies it and preserves review status, qualifiers and
notes; mirroring includes both new tables. Initial recovery: 171 new term rows,
17 existing page-linked targets reused, 215 provenance links and 398 code matches
per database; 16 of 188 targets have no proposed match. Backups precede migration.
"""
RECOVERY_CHECK = """# Comprehensive read-only output: retain uncoded terms and proposed alternatives.
from contextlib import closing
import local_pipeline as local
with closing(local.connect_sqlite(local.CRAWLER / "bluebooks.db", readonly=True)) as recovery_db:
    print("Recovery tables:", {table: recovery_db.execute(
        f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        for table in ("entity_term_provenance", "entity_term_code_matches")})
    recovery_rows = recovery_db.execute(
        "SELECT page_id,term,source_code,suggested_code,edition,official_term,"
        "match_type,suggested_qualifier,review_status "
        "FROM v_entity_term_code_matches WHERE source_kind='AI_recovered_prose' "
        "ORDER BY page_id,term,edition,candidate_order"
    ).fetchall()
    print("Recovered terms and all candidate matches:", recovery_rows[:30])
    page_code_terms = recovery_db.execute(
        "SELECT book_version,chapter,page_title,page_url,page_sections,TermUS,"
                "TermNormUS,candidateTermUS,ICDO32,ICDO4,is_subtype AS deprecated_is_subtype,code_kind,source_kind,"
        "suggested_qualifier,match_type,candidate_topography_codes "
        "FROM v_page_code_terms ORDER BY page_id,TermUS,code_edition,morphology_code LIMIT 30"
    ).fetchall()
    print("Distinct page code-term pairs:", page_code_terms)
"""


def upgrade_recovery(nb, *, crawler=False):
    check = RECOVERY_CHECK
    if crawler:
        check = check.replace("import local_pipeline as local", "import bluebooks_local as local")
        check = check.replace("local.CRAWLER", "local.ROOT")
    for cell in nb.cells:
        if cell.cell_type == "code" and cell.source.startswith("# Comprehensive read-only output:"):
            cell.source = check
    for cell in nb.cells:
        if cell.cell_type == "markdown" and cell.source.startswith(RECOVERY_MARKER):
            cell.source = RECOVERY_SUMMARY
            return nb
    nb.cells.insert(4, nbformat.v4.new_markdown_cell(RECOVERY_SUMMARY))
    nb.cells.insert(5, nbformat.v4.new_code_cell(check))
    return nb


def upgrade_terms(nb, *, crawler=False):
    check = TERM_CHECK
    if crawler:
        check = check.replace("import local_pipeline as local", "import bluebooks_local as local")
        check = check.replace("local.CRAWLER", "local.ROOT")
        check = check.replace("local.validate_terms(term_db)", "local.term_hygiene.validate_terms(term_db)")
    for cell in nb.cells:
        if cell.cell_type == "code" and cell.source.startswith("# Read-only checks: use the existing local database"):
            cell.source = check
    for cell in nb.cells:
        if cell.cell_type == "markdown" and cell.source.startswith(TERM_MARKER):
            cell.source = TERM_SUMMARY
            return upgrade_recovery(nb, crawler=crawler)
    nb.cells.insert(2, nbformat.v4.new_markdown_cell(TERM_SUMMARY))
    nb.cells.insert(3, nbformat.v4.new_code_cell(check))
    return upgrade_recovery(nb, crawler=crawler)
SUMMARY = """## Local data parity (no online access)

The shared `bluebooks_local` pipeline builds all local reference/entity/evidence
tables and whole-page search documents from saved corpus data and local inputs.
It recovers complete saved-HTML section bodies while retaining existing section
IDs and image/reference associations; exceptions are recorded in build provenance.
Code-only morphology lines use the page title as a fallback term. Explicit OMIM
identifiers are stored separately in entity_identifiers, never as ICD-O evidence.
Entity tables include fifth- and sixth-edition books; original code formats are
preserved and edition is joined through books. The Step 7 spreadsheet examples
may focus on sixth-edition books, but the shared refresh covers both editions.
It can mirror those tables to SQL Server and verify every row value.
See [DATA_DICTIONARY.md](DATA_DICTIONARY.md) in the crawler folder for all tables,
their sources and refresh order. Agent activity is untouched; book 70 and crawl
bookkeeping differences are accepted. Back up before refresh/mirror.
Schema provisioning includes the recommended page/book/TOC lookup indexes,
preserves all existing relationships, and consolidates only the two reviewed
SQL Server redundant indexes after dependency checks. No new FT index is needed.
Do not run login/discovery/crawl or package-download cells for local validation.
"""

REFRESH = """# Local-only enrichment: run after a crawl, or on the existing corpus.
from pathlib import Path
import bluebooks_local as local
DB = CRAWLER_DIR / config["db_path"]
print(local.backup_databases(DB, CRAWLER_DIR / "local_backups"))
local_result = local.refresh_local(DB)
print(local_result["counts"])
recovery = local_result["section_recovery"]
print({key: len(value) if isinstance(value, list) else value
       for key, value in recovery.items()})
"""
MIRROR = """# Mirror approved data only; agent activity and crawl bookkeeping are untouched.
import bluebooks_local as local
DB = CRAWLER_DIR / config["db_path"]
print(local.backup_databases(DB, CRAWLER_DIR / "local_backups", SQLSERVER, DATABASE))
parity = local.mirror(DB, SQLSERVER, DATABASE, include_book70=False)
print({table: result["match"] for table, result in parity.items()})
"""
SEARCH_SERVER = """# Verify section/title/whole-page FULLTEXT; fail explicitly on timeout.
import bluebooks_local as local
with local.connect_server(SQLSERVER, DATABASE) as cn:
    print(local.server_search(cn))
    print(local.search(cn, "carcinoma", backend="sqlserver", limit=3))
"""


def upgrade_runner(nb):
    for cell in nb.cells:
        src = cell.source
        if cell.cell_type != "code":
            continue
        if ("bluebooks_fts.py" in src and "run_script" in src) or src.startswith("# Local-only enrichment:"):
            if "7.0" not in src and "7·0" not in src:
                cell.source = REFRESH
        if 'tables = ["books"' in src:
            start = src.index('tables = ["books"')
            end = src.index("counts = []", start)
            cell.source = src[:start] + "import bluebooks_local as local\ntables = local.TABLES\n" + src[end:]
        if "COPY_ORDER =" in src or src.startswith("# Mirror approved data"):
            cell.source = MIRROR
        if "schema_sqlserver.sql" in src and ("read_text" in src or "open(" in src):
            cell.source = """# Bootstrap the complete data schema, not activity metadata.
import bluebooks_local as local
with local.connect_sqlite(CRAWLER_DIR / config["db_path"]) as src, local.connect_server(SQLSERVER, DATABASE) as dst:
    local.migrate_sqlite(src)
    local.ensure_server_schema(src, dst)
print("Complete local data schema ready.")
"""
        if "FT_CATALOG =" in src or src.startswith("# Verify section/title"):
            cell.source = SEARCH_SERVER
        if "CONTAINS" in src and cell.source != SEARCH_SERVER and src.startswith("# Cell 7c.2"):
            cell.source = SEARCH_SERVER
        if cell.source != src:
            cell.outputs = []
            cell.execution_count = None
    for cell in nb.cells:
        if cell.cell_type == "markdown" and cell.source.startswith(MARKER):
            cell.source = SUMMARY
    if not any(c.source.startswith(MARKER) for c in nb.cells):
        nb.cells.insert(1, nbformat.v4.new_markdown_cell(SUMMARY))
    return upgrade_terms(nb, crawler=True)


def upgrade_explorer(nb):
    setup = """# Shared local pipeline setup; never contacts Blue Books online.
from pathlib import Path
import local_pipeline as local
LOCAL_SQLITE = Path(SQLITE_PATH) if "SQLITE_PATH" in globals() else local.CRAWLER / "bluebooks.db"
if "MIRROR_SQLSERVER" not in globals():
    MIRROR_SQLSERVER = False  # Set True once to mirror subsequent refreshes.
"""
    build = """# Back up and refresh all local derived data; optional complete mirror.
print(local.backup_databases(LOCAL_SQLITE, local.CRAWLER / "local_backups",
                            "localhost" if MIRROR_SQLSERVER else None))
local_result = local.refresh_local(LOCAL_SQLITE)
print(local_result["counts"])
recovery = local_result["section_recovery"]
print({key: len(value) if isinstance(value, list) else value
       for key, value in recovery.items()})
if MIRROR_SQLSERVER:
    print(local.mirror(LOCAL_SQLITE))
    with local.connect_server() as cn:
        print(local.server_search(cn))
"""
    for cell in nb.cells:
        src = cell.source
        if cell.cell_type == "code":
            if src.startswith("# Shared local pipeline setup;"):
                start = src.index("# Back up and refresh")
                cell.source = setup + src[start:]
            if "S.sync_book_corpus" in src and "ALL_BOOKS =" not in src:
                cell.source = setup + build
            if "S.sync_book_corpus" in src and "ALL_BOOKS =" in src:
                # Preserve workbook generation logic, remove the old partial pushes.
                lines = src.splitlines()
                lines = [l for l in lines if not any(x in l for x in (
                    "S.store_book(", "S.sync_book_corpus(", "S.push_to_sqlserver("))]
                cell.source = setup + build + "\n" + "\n".join(lines)
            if "CL.import_sqlite(" in src:
                start = src.index("import bb_icdo_lookup")
                cell.source = setup + build + "\n" + src[start:].split("_counts =")[0] + """
_con = local.connect_sqlite(LOCAL_SQLITE)
LOOKUP = CL.CodeLookup(_con)
print("Lookup ready from canonical local reference tables.")
"""
            if "SQLITE_PATH =" in src:
                import re
                cell.source = re.sub(r'^SQLITE_PATH\s*=\s*["\']bluebooks_demo\.db["\'].*$', 'SQLITE_PATH = str(__import__("pathlib").Path.cwd().parent / "BBCrawler Notebook" / "bluebooks.db")',
                                     cell.source, flags=re.M)
            if "_srv = S.connect_sqlserver().cursor()" in cell.source:
                start = cell.source.index("_srv = S.connect_sqlserver().cursor()")
                end = cell.source.index("\nshow(pd.DataFrame", start)
                cell.source = cell.source[:start] + """from contextlib import closing
_rows = []
for _bid in ALL_BOOKS:
    _title = _con.execute("SELECT title FROM books WHERE book_id=?", (_bid,)).fetchone()[0]
    _rows.append((_bid, _title, "sqlite", *_con.execute(_audit, (_bid,) * 4).fetchone()))
if MIRROR_SQLSERVER:
    with closing(local.connect_server()) as _server:
        for _bid in ALL_BOOKS:
            _title = _con.execute("SELECT title FROM books WHERE book_id=?", (_bid,)).fetchone()[0]
            _rows.append((_bid, _title, "sqlserver", *_server.cursor().execute(_audit, *([_bid] * 4)).fetchone()))
""" + cell.source[end:]
            if "WHERE t.name = 'pages'" in cell.source and "sys.fulltext_indexes" in cell.source:
                cell.source = cell.source.replace("WHERE t.name = 'pages'",
                    "WHERE t.name IN ('pages','sections','page_search_documents')")
            if "QUERY =" in src and "pages_fts" in src:
                cell.source = """# Whole-page search over equivalent documents on either engine.
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
            if cell.source != src:
                cell.outputs = []
                cell.execution_count = None
        elif "A future crawler pass" in src:
            cell.source = src.replace("A future crawler pass should parse", "The shared local pipeline now parses")
    for cell in nb.cells:
        if cell.cell_type == "markdown" and cell.source.startswith(MARKER):
            cell.source = (SUMMARY.replace("(DATA_DICTIONARY.md)", "(../BBCrawler%20Notebook/DATA_DICTIONARY.md)") +
                           "\nRun Step 7.3 to rebuild local enrichment. SQL Server mirroring is opt-in.")
    if not any(c.source.startswith(MARKER) for c in nb.cells):
        nb.cells.insert(1, nbformat.v4.new_markdown_cell(
            SUMMARY.replace("(DATA_DICTIONARY.md)", "(../BBCrawler%20Notebook/DATA_DICTIONARY.md)") +
            "\nRun Step 7.3 to rebuild local enrichment. SQL Server mirroring is opt-in."))
    return upgrade_terms(nb)


def upgrade_sites(nb):
    for cell in nb.cells:
        src = cell.source
        if cell.cell_type != "code":
            continue
        if src.startswith("# Cell 1.0"):
            cell.source = """# Use the existing local environment; do not install/download in this workflow.
import pandas, sqlalchemy, matplotlib
"""
        if src.startswith("# Cell 1.1") and "# Connection details" in src:
            start = src.index("# Connection details")
            end = src.index("\n\ndef show_df", start)
            cell.source = src[:start] + """# Select a backend; both use the same local derived tables.
from pathlib import Path
from local_queries import read_frame
import local_pipeline as local
DB_KIND = "sqlite"  # or "sqlserver"
SQLITE_PATH = local.CRAWLER / "bluebooks.db"
if DB_KIND == "sqlite":
    con = local.connect_sqlite(SQLITE_PATH, readonly=True)
elif DB_KIND == "sqlserver":
    connection_string = "DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost;DATABASE=BlueBooks;Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes"
    engine = create_engine(f"mssql+pyodbc:///?odbc_connect={quote_plus(connection_string)}", future=True)
    con = engine
else:
    raise ValueError("DB_KIND must be sqlite or sqlserver")
print("Connected to", DB_KIND)
""" + src[end:]
        cell.source = cell.source.replace("pd.read_sql(", "read_frame(")
        if cell.source != src:
            cell.outputs = []
            cell.execution_count = None
    for cell in nb.cells:
        if cell.cell_type == "markdown" and cell.source.startswith(MARKER):
            cell.source = (SUMMARY.replace("(DATA_DICTIONARY.md)", "(../BBCrawler%20Notebook/DATA_DICTIONARY.md)") +
                           "\nThis notebook is read-only. Build tables using Runner Step 5 or Explorer Step 7.3.")
    if not any(c.source.startswith(MARKER) for c in nb.cells):
        nb.cells.insert(1, nbformat.v4.new_markdown_cell(
            SUMMARY.replace("(DATA_DICTIONARY.md)", "(../BBCrawler%20Notebook/DATA_DICTIONARY.md)") +
            "\nThis notebook is read-only. Build tables using Runner Step 5 or Explorer Step 7.3."))
    return upgrade_terms(nb)


def backup_notebook(path: Path) -> Path | None:
    if not path.exists():
        return None
    backup = Path(__file__).resolve().parent / "local_backups" / (
        "notebooks-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    )
    backup.mkdir(parents=True)
    target = backup / path.name
    shutil.copy2(path, target)
    if target.read_bytes() != path.read_bytes():
        raise OSError(f"Notebook backup verification failed: {target}")
    return target


def main():
    root = Path(__file__).resolve().parent
    for path, fn in (
        (root / "Crawler_Runner.ipynb", upgrade_runner),
        (root.parent / "BBNotebook" / "BlueBooks_Explorer_3.ipynb", upgrade_explorer),
        (root.parent / "BBNotebook" / "BlueBooks_Explorer_2.ipynb", upgrade_explorer),
        (root.parent / "BBNotebook" / "Querying_Site_Specific_Terms.ipynb", upgrade_sites),
    ):
        backup_notebook(path)
        nb = nbformat.read(path, as_version=4)
        nbformat.write(fn(nb), path)
        print(f"Integrated local workflow: {path.name}")


if __name__ == "__main__":
    main()
