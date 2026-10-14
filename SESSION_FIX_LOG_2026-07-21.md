# BBCrawler Notebook Fix Log (2026-07-21)

This file captures bugs, oddities, and special-case fixes implemented in this session.

## Scope

- Workspace: `BBCrawler Notebook`
- Key files touched:
  - `Crawler_Runner.ipynb`
  - `build_notebook.py`
  - `search.py`
  - `SQLSERVER_CONNECTION_VARIANTS.md`

## 1) SQL Server connection target mismatch (Step 7)

### Symptom

- SQL Server connection attempts failed/time out when using assumptions like `SQLEXPRESS` or LocalDB naming.

### Root cause

- Local environment uses the `(local)` SQL Server alias; host-specific naming is omitted from committed guidance.

### Fix

- Updated Step 7 connection defaults/candidates to prioritize `(local)`.
- Updated connection-variants documentation to match real environment.

### Validation

- Notebook connected successfully using ODBC Driver 18.

## 2) FTS setup ambiguity on SQL Server 17.x / 2025

### Symptom

- Unclear whether SQL Server Full-Text Search needed a separate package.

### Root cause

- Feature-install confusion: FTS is optional engine feature, not standalone package.

### Fix

- Added guidance in Step 7a messaging:
  - Current major version context (`17.x / SQL Server 2025`)
  - Generic downloads page
  - Install guide URL
  - Feature name: `Full-Text and Semantic Extractions for Search`

### Validation

- `FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')` reported installed (`1`).

## 3) FTS DDL transaction failure in Step 7a/7c

### Symptom

- Full-text DDL failed with transaction-related errors.

### Root cause

- SQL Server does not allow `CREATE FULLTEXT CATALOG` and `CREATE FULLTEXT INDEX` in a user transaction.

### Fix

- Split normal schema work from FTS work.
- Executed FTS DDL under autocommit path.

### Validation

- Step 7a completed and applied schema batches cleanly.
- Step 7c recreated full-text index successfully.

## 4) Full-text key index placeholder mismatch (`PK__sections`)

### Symptom

- Full-text index creation can fail because hard-coded key index name does not match actual auto-generated PK name.

### Root cause

- SQL Server auto-generates PK index names (for example `PK__sections__F842676AAB386F47`).

### Fix

- Runtime lookup of actual PK index from `sys.indexes`.
- Substitute discovered PK name into full-text index DDL.

### Validation

- Step 7c used discovered key index and recreated FTS index successfully.

## 5) Step 7c SQL syntax error near `QUOTENAME`

### Symptom

- `Incorrect syntax near 'QUOTENAME'` in catalog creation branch.

### Root cause

- Parameterized dynamic SQL pattern around `QUOTENAME(?)` caused parse/prepare failure in that execution form.

### Fix

- Replaced with explicit existence check + direct DDL string for catalog creation.
- Replaced conditional drop/recreate logic with explicit existence checks.

### Validation

- Step 7c ran through catalog/index rebuild path successfully.

## 6) `CONTAINS` smoke test skipped despite successful FTS rebuild

### Symptom

- Rebuild succeeded, but verification query printed `CONTAINS test skipped`.

### Root cause

- Smoke test query shape through `dbo.v_search` could be rejected by SQL Server in this context.

### Fix

- Switched smoke test to query base full-text indexed table (`dbo.sections`) joined to `dbo.pages`.

### Validation

- Step 7c completed and smoke test ran without skip (`0 row(s)` is acceptable when term absent).

## 7) Notebook-generator parser break in `build_notebook.py`

### Symptom

- `python -m py_compile build_notebook.py` failed near `code(r"""`.

### Root cause

- Literal triple-quoted SQL blocks inside outer raw `code(r""" ... """)` strings prematurely terminated the wrapper.

### Fix

- Escaped embedded triple quotes (`\"\"\"`) inside generator cell strings.

### Validation

- `build_notebook.py` compiles successfully.

## 8) Mojibake in Step 8 output (`â€¦`, `â–`, `Â·`)

### Symptom

- Search output in notebook showed corrupted symbols.

### Root cause

- Encoding mismatch in subprocess output capture (UTF-8 content decoded via incompatible Windows code page path).

### Fix

- Updated notebook `run_script()` helper and generator template:
  - Set `PYTHONUTF8=1`
  - Set `PYTHONIOENCODING=utf-8`
  - Use `subprocess.Popen(..., text=True, encoding='utf-8', errors='replace')`
- Updated `search.py` to reconfigure stdout/stderr to UTF-8 when available.

### Validation

- Step 8 output now renders symbols correctly (`■`, `·`, `…`).

## 9) Noisy snippet text from scraped site chrome

### Symptom

- Snippets included repetitive UI labels (`Attachment`, `Authors`, `Send us Feedback`, `Add Personal Note`, `Tables From`) and colon clutter.

### Root cause

- Page text extraction included navigation/chrome fragments.

### Fix

- Added focused snippet sanitization in `search.py`:
  - Remove known noisy phrases
  - Collapse repeated colon delimiters and excess whitespace
  - Trim leading/trailing delimiter artifacts
- Applied cleanup for both page-level and section-level snippet rendering.

### Validation

- Step 8 snippets now show concise topic text without UI-chrome tails.

## 10) Synchronization discipline: notebook vs generator

### Special case

- Manual acceptance of isolated notebook edits can cause drift from `build_notebook.py`.

### Fix approach used

- Applied matching logic updates to both:
  - live notebook (`Crawler_Runner.ipynb`)
  - generator (`build_notebook.py`)

### Outcome

- Current runtime behavior and future regenerated notebook behavior are aligned.

## Quick checklist for future edits

1. If editing SQL Server notebook cells, mirror the change in `build_notebook.py`.
2. Keep FTS DDL on autocommit path.
3. Always resolve real PK index name at runtime for full-text index creation.
4. Keep Step 7c `CONTAINS` smoke test on base FTS table shape.
5. Preserve UTF-8 subprocess settings in `run_script()`.
6. Keep snippet-cleanup rules in sync with observed site-chrome artifacts.
