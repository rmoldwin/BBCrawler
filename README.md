# Blue Books Crawler — Runner Notebook

**`Crawler_Runner.ipynb`** is a novice-friendly, **VS Code-ready** Jupyter notebook that runs the WHO Blue
Books crawler end to end and builds the searchable database — no command line
required. You edit a few clearly marked settings, then press ▶ Run on each cell.

This is the companion to **`BlueBooks_Explorer.ipynb`** (which *queries* the
finished database). **`Crawler_Runner.ipynb`** *builds* it.

---

## ⚠️ Run this locally, not in a cloud kernel

Steps 2–4 open a **real Chromium browser** and use **your logged-in
BlueBooksOnline session**. They must run on **your own machine** (VS Code with
the Jupyter extension), where a browser window can appear and reach the
licensed site. A remote/headless kernel cannot log in for you. Steps 5–8
(inspect / load to SQL Server / search) are pure database work and run anywhere.

## 📄 Licensing

WHO/IARC tumour-classification content is copyrighted and subscription-gated.
Use extracts for **private, licensed, non-commercial study** only, and keep the
resulting database (and `auth_state.json`) private.
Reference files and extracted source text under `Library/` are local-only and
excluded from Git; supply them locally only under your applicable access terms.

---

## What's in this folder

```
Crawler_Runner.ipynb      ← the notebook (the deliverable)
build_notebook.py         ← regenerates the notebook (edit here, then re-run)
README.md                 ← this file
requirements-crawler.txt  ← the crawler's own dependency (playwright)
SESSION_FIX_LOG_2026-07-21.md      ← consolidated fix log from this session
SQLSERVER_CONNECTION_VARIANTS.md    ← SQL Server naming/connection notes
00_dbo_Clean.sql         ← authoritative dbo.Clean function body for SQL Server

# crawler scripts (called by the notebook) — same as the bluebooks-crawler bundle
bluebooks_auth.py         bluebooks_books.py    bluebooks_crawl.py
bluebooks_fts.py          search.py
schema.sql                schema_sqlserver.sql  config.example.json
```

If you already have the `bluebooks-crawler` bundle unpacked elsewhere, you can
drop **just** `Crawler_Runner.ipynb` next to those scripts instead — or set
`CRAWLER_DIR` in Step 0 to point at them.

## Quick start (in VS Code)

1. Install the **Python** and **Jupyter** extensions in VS Code.
2. Open this folder, then open **`Crawler_Runner.ipynb`**.
3. Pick a Python 3.9+ interpreter (top-right kernel picker).
4. Run the cells top to bottom. Steps 0–1 set up; Step 2 logs you in; Steps 3–5
   discover/crawl/index; Step 6 checks results; Step 7 (optional) loads SQL
   Server; Step 8 is a search sanity check.

## The steps

For the implemented SQLite/SQL Server parity workflow and current completion
results, see the [completion report](DATABASE_PARITY_COMPLETION_REPORT.md).
The superseded 2026-10-06 assessment and proposed plan are preserved in
[Archive](Archive/DATABASE_PARITY_REPORT_AND_PLAN.md) as historical planning evidence.

## Local-only refresh and parity

### Distinct page code-term output

Schema version 10 provides `v_page_code_terms` in SQLite and `dbo.v_page_code_terms`
in SQL Server: editable `alias`, original `edition` (neither renamed), full `book_name` from `books.title`, chapter and `ch_order`,
page title/URL, relevant sections,
TermUS, TermNormUS (the `Clean2` match key from the indexed source `TermNormUS`
columns), candidateTermUS, ICDO32/ICDO4 and coding/review metadata. Each
page/edition/code/TermUS pair occurs once; codes and terms are never concatenated.
Different terms sharing a code remain separate. Only sections, metadata and
candidate page-level topography codes (confidence >= 0.9) are concatenated.
These site hints are not verified term-specific or patient sites.
Unmapped terms retain NULL codes; source codes are never translated into the
other edition. The match view now displays US `official_term`/`candidateTermUS`
and retains raw reference spelling in `official_term_source`.

`terminology_kind` records source provenance using five atomic values: `coding`
(ICD-O coding/Subtype(s) section), `contextual` (section-text code mention),
`acceptable`, `not_recommended` and `other` (related terminology, including
recovered alternate terms). Multiple origins are combined alphabetically with
`; `. See [TERMINOLOGY_KIND_VALUES.md](TERMINOLOGY_KIND_VALUES.md).

For an existing paired build, call `bluebooks_local.deploy_term_views(Path("bluebooks.db"))`.
It makes verified paired backups, adds the trigger-maintained/indexed
`entity_term_code_matches.official_termUS`, replaces views and checks original
data and cross-engine parity without re-extracting terms. Refresh/mirror and
the notebook generators retain these changes. See the
[data dictionary](DATA_DICTIONARY.md) for the full contract.

[bluebooks_local.py](bluebooks_local.py) is the canonical producer for **23
managed tables**. The [data dictionary](DATA_DICTIONARY.md) documents every
column, source and refresh owner. SQLite now populates the reference/evidence
tables, fifth- and sixth-edition entities and normalized page fields; SQL Server mirrors
their values. Agent activity is untouched. Book 70 is an optional inventory-only
exception; crawl queues/run logs are not reconciled.

Build version 6 recovers complete saved-HTML section bodies and source anchors
before enrichment. Nonempty sections and empty sections with image/reference
links are retained; only empty, unlinked entity-page sections are pruned.
Missing sections are appended, with conflicts and unparsed pages recorded in
the private provenance sidecar. Both section and whole-page indexes use
recovered prose, not only definitions. Code-only ICD-O lines use the page title
as a fallback term; substantive embedded coding subsections take precedence
over Beta placeholders. MIM-numbering rows and inline MIM references are
stored in `entity_identifiers`, separately from morphology terms. The
`source_kind` column distinguishes coding-section entries from section-text
mentions. Related-terminology extraction splits semicolons only outside
balanced parentheses, preserving terms such as `t(15;19) carcinoma`; it also
separates qualified Acceptable/Not recommended labels and excludes editorial
cross-references and explanatory prose from term rows. A full refresh
re-extracts these values from saved page HTML.

Keep the neighboring `BBNotebook` modules and local workbook/CSV inputs.
[requirements-local.txt](requirements-local.txt) lists dependencies; no browser
is needed for local processing. From this folder:

```powershell
python bluebooks_local.py --sqlite bluebooks.db
python bluebooks_local.py --sqlite bluebooks.db --mirror --server localhost --database BlueBooks
```

Both commands back up before refresh; `--mirror` also creates/verifies a SQL
Server COPY_ONLY backup. Missing inputs fail before replacement. Enrichment and
mirroring are transactional; row-value hashes must match before SQL copy commits.
Provenance checks reject stale corpus/reference inputs. Manual curation is
preserved; conflicts fail rather than overwrite decisions.
Run these commands, or Runner Step 5 then Step 7, **without login/discovery/crawl
cells** when using local data only.

[validate_local.py](validate_local.py) runs read-only live hashes/search/
normalization checks and the site-query notebook on both backends.
Its saved-body and six-code spot tests verify content, not just index readiness;
`--baseline <pre-build SQLite backup>` also checks original section IDs/text and
protected corpus/curation/bookkeeping values.
[build_local_docs.py](build_local_docs.py) regenerates the dictionary and schemas.
Notebook regeneration preserves unrelated existing cells/settings.

### Index tuning (2026-10-06)

Both databases include page-first indexes for code evidence, term mentions and
authors, plus book/chapter/parent-group navigation indexes. Existing primary keys
and all existing managed relationships remain intact; no new FT index was needed.
SQL provisioning recognizes equivalent ordered index keys regardless of name.
Reviewed redundant ordinary indexes are consolidated only after definition,
storage-option and dependency checks; URL uniqueness and the existing clustered
code index are retained. See the tuning section of the completion report.

| Step | Does | Calls |
|---|---|---|
| 0 | Environment check; install Playwright + Chromium; locate scripts; live-output `run_script()` helper | — |
| 1 | Write `config.json` from an editable settings cell | — |
| 2 | Headed login → save `auth_state.json` (session reused headlessly) | `bluebooks_auth.py` |
| 3 | Discover available volumes; list inventory with per-book status | `bluebooks_books.py discover` / `list` |
| 4 | Crawl chosen book(s): `BOOKS`, `TOC_ONLY`, `LIMIT`, `NO_IMAGES`, `RESCRAPE`. Resumable | `bluebooks_crawl.py` |
| 5 | Back up; populate reference/entity/evidence tables and whole-page documents; rebuild FTS5 | `bluebooks_local.refresh_local` |
| 6 | Inspect the SQLite DB: row counts, per-book status, sample pages + URLs | — |
| 7 | *(Optional)* Provision complete schema; deploy `dbo.Clean`; back up and mirror 23 managed tables; wait for section/title/whole-page FULLTEXT | `bluebooks_local`, `00_dbo_Clean.sql`, `pyodbc` |
| 8 | Quick search sanity check | `search.py` |

## Tips

### Term hygiene and lookup keys (2026-10-10)

Five term-bearing tables (`entity_codes`, `entity_related_terms`,
`page_icdo_codes`, `page_term_mentions`, `page_entity_evidence`) now have
indexed `TermUS` and `TermNormUS` values. Term-list footnotes, punctuation and
citation tails are cleaned at extraction and on database INSERT/UPDATE; medical
signs and numeric superscripts/subscripts are preserved. Raw saved sources remain
unchanged. `TermUS` uses `CleanBritishSpelling2`; `TermNormUS` uses `Clean2(TermUS)`.
Saved-HTML-confirmed misplaced prose is removed only from uncoded entity and
related-term rows. Contextual punctuation/prose after codes is replaced with an
unambiguous structured name, otherwise NULL; code evidence is never deleted.
The approved deployed Clean2 v3 is shared verbatim with the local Python rule
executor, not replaced by the older comparison function.

Version 9 adds source-backed recovery for the 58 contextual coding names left
NULL by the earlier repair. Shared-code alternatives and nested section headings
are handled without inventing a parent-entity assignment. Optional absent workbook
preferred terms remain NULL.

All managed term displays and term keys uppercase only an initial ASCII `a-z`;
digits, Greek symbols, punctuation-led values and all remaining characters are
unchanged. `Clean2` itself remains unchanged. The shared display helper and
write-time triggers cover the reference, identifier and recovery tables too.
Original prose and exact workbook evidence JSON are not rewritten.
Use `bluebooks_local.repair_term_display(Path("bluebooks.db"))` for this
backed-up, row-preserving repair and 25-table verification.

Use `bluebooks_local.repair_term_tables(Path("bluebooks.db"))` for the existing
two-database snapshot: verified backups precede the in-place repair, and all 23
managed tables are checked for row-value parity. Future refreshes/mirrors retain
the new fields automatically. Use `connect_sqlite` for writes so required UDFs
are registered. Each active notebook documents the rules, includes read-only
checks, and is backed up before regeneration. See [DATA_DICTIONARY.md](DATA_DICTIONARY.md)
for column sources, indexing, provenance and conservative-cleanup limitations.

- **Start small.** In Step 4, crawl one book with `LIMIT = 5` first. When it
  looks right, set `LIMIT = 0` and re-run to finish it. Re-run the Step 3 list
  cell to watch `Pend` drop to 0.
- **Sessions expire** after ~15 min idle. If a crawl reports `auth_expired`,
  re-run Step 2, then run the crawl cell again — it resumes where it stopped.
- **Smaller DB:** set `NO_IMAGES = True` (or `capture_images: false` in config)
  to skip image capture; page links are still stored.
- **SQL Server load** copies the *already-crawled* SQLite data — run Steps 4–5
  first. Needs the Microsoft **ODBC Driver 17/18 for SQL Server** and `pyodbc`.
- **Verify FULLTEXT after loading (Step 7c).** SQL Server AUTO change tracking
  populates asynchronously. The provisioner enables indexing, finds actual
  keys, waits with a bounded timeout and verifies `CONTAINS`. Whole-page search
  indexes `page_search_documents(title,full_text)`, not just titles. SQLite uses
  the same documents in `pages_fts`; rebuild after corpus changes. Native
  stemming/ranking are engine-specific.
- **`dbo.Clean` is deployed automatically (Step 7a·clean)** from the bundled
  `00_dbo_Clean.sql` (the authoritative corrected 2026-07-09 body, mirrored by
  the Python `clean()`), using `CREATE OR ALTER` so it's safe to re-run. A
  verification cell then checks `OBJECT_ID('dbo.Clean','FN')` and runs
  normalization smoke tests (e.g. `Oesophageal adenocarcinoma, NOS` →
  `Esophageal adenocarcinoma`). This is what the PathCHART cross-walk needs on
  the server.
- **Step 7·0 rebuilds the SQLite FTS5 index** (same as Step 5) right before the
  load, so the corpus you copy to SQL Server is fully indexed even if you
  crawled more pages since last running Step 5.

## Maintenance Notes (2026-07-21)

### Added file

- `SESSION_FIX_LOG_2026-07-21.md` — complete log of bugs/oddities fixed in this session.
## Copilot Memory Locations

For a quick reference to where Copilot memory is stored on Windows, see your
local VS Code Copilot memory-location notes.

Summary:

- Global memory (shared across repos) lives under your VS Code user `globalStorage` path.
- Repo memory (workspace-specific) lives under your VS Code `workspaceStorage` path.

### Changed files

- `Crawler_Runner.ipynb` — Step 7 SQL Server flow and Step 8 output behavior updated.
- `build_notebook.py` — generator kept in sync with notebook fixes.
- `search.py` — UTF-8 output handling and focused snippet-cleanup pass.
- `SQLSERVER_CONNECTION_VARIANTS.md` — aligned with real `(local)`/host usage.

### Practical advice from this work

- Keep `Crawler_Runner.ipynb` and `build_notebook.py` synchronized. If you change a notebook cell directly, mirror it in the generator before regenerating.
- Run SQL Server full-text DDL (`CREATE/DROP FULLTEXT ...`) on an autocommit connection path.
- Never hard-code the `dbo.sections` PK index name for full-text creation; resolve it at runtime from `sys.indexes`.
- Use a base-table `CONTAINS` verification query (`dbo.sections` + `dbo.pages`) for Step 7c smoke tests.
- Preserve UTF-8 subprocess settings in the Step 0 helper so Step 8 output does not mojibake on Windows.
- Keep snippet-cleanup rules in `search.py` close to observed site-chrome artifacts; adjust the noisy phrase list if source pages change.

## Regenerating the notebook

The notebook is generated from `build_notebook.py`. To change a cell, edit the
builder and run:

```bash
pip install nbformat
python build_notebook.py
```
# Recovered alternate diagnostic terms

The version-8 local pipeline recovers valid names embedded in the previously
removed prose, without restoring sentences as terms or inventing source codes.
The approved extraction is persisted in `Library/recovered_terms.json`.

- Names are in `entity_related_terms` (`kind='other'`), or reuse an existing
  `entity_codes`/`entity_related_terms` row.
- `entity_term_provenance` flags `source_kind='AI_recovered_prose'`, records the
  original page/table/row/text, suggested qualifier and review status.
- `entity_term_code_matches` stores proposed official-reference mappings by edition,
  including alternatives and conditions. `exact`, `synonym`, `broader` and
  `conditional` are distinct; original 3.2 is not conflated with later CPC additions.
- `v_entity_terms` includes every term once. `v_entity_term_provenance` includes
  source links; `v_entity_term_code_matches` includes candidates without multiplying
  them by source citations and retains unmapped terms through LEFT JOINs.
- Never replace `entity_codes.code` or `page_icdo_codes` with these suggested codes.
  New recovered names are not treated as positive source-code mention evidence.
- Full refresh validates the manifest/reference hashes, re-applies recovery and
  preserves review status, qualifiers and notes while re-linking regenerated IDs.
  Both new tables are mirrored and hash-verified.

Initial approved plan per engine: 171 new term rows, 17 existing targets reused,
215 provenance links and 398 candidate mappings; 16 of 188 page-term targets have
no defensible match. Recovered labels receive indexed TermUS/TermNormUS normally.
Use `term_recovery.dry_run(Path("bluebooks.db"))` for read-only planning;
`term_recovery.apply_recovery(Path("bluebooks.db"))` takes verified paired backups
before applying. These are vocabulary proposals, not diagnoses in actual patients
or assertions of registry reportability. See `DATA_DICTIONARY.md`.
