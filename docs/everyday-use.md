# Everyday use

This guide explains the usual BBCrawler tasks and what each one changes. Start
with [Getting started](getting-started.md) if the workspace or notebook has not
been set up yet.

## Collect pages from the website

Use this when you need to discover or capture new Blue Books pages.

1. Open `Crawler_Runner.ipynb` in VS Code and select the project's Python
   kernel.
2. Follow its website collection path. Review the selected books and collection
   options before starting a crawl.
3. Complete the login step in the browser opened on your own computer. The
   notebook reuses the saved local session when possible.
4. Check the notebook's completion output and per-book status before moving on
   to database refresh or search.

This workflow requires authorized website access. Do not use a remote kernel
that cannot open a browser on your machine. If login expires, sign in again
through the notebook and resume using its indicated recovery steps. Do not
delete or publish `auth_state.json`.

## Refresh from saved material

Use this when the pages and local reference files are already available. It
does not require login, website discovery, or crawling.

From the repository root, run:

```powershell
python app\bluebooks_local.py --sqlite bluebooks.db
```

The refresh updates the SQLite database using saved page data and the
configured local references. It rebuilds derived terminology and search data.
The process validates its inputs and uses database safeguards; do not bypass an
input or provenance error by substituting an unrelated workbook or deleting
database files. Resolve the input issue first, then rerun the refresh.

The reference matcher keeps printed Blue Books codes separate from proposed
official-reference matches. A proposal is not a verified diagnosis or a
substitute for the source assignment. See
[Reference matching](technical/reference-matching.md) for the contract.

## Inspect and search results

- Use the runner's inspection task to check the local database and sample pages
  and URLs.
- Use the companion query/Explorer notebook in the neighboring `BBNotebook`
  project for interactive searches and more detailed result inspection.
- SQLite full-text search uses the local search index. SQL Server search is an
  optional workflow and may require its full-text index to finish populating
  after data is mirrored.

Search results are retrieval aids, not clinical conclusions. Read the linked
page and the surrounding source context before interpreting a term, code, or
site hint.

## Optional SQL Server mirror

SQL Server is not required for the local SQLite workflow. If your project is
configured for SQL Server, use the notebook's optional mirror task after a
successful local refresh. Confirm the target server and database before
running it. The connection must use an installed Microsoft ODBC Driver 17 or
18 and the Python `pyodbc` package; authentication and permissions are
environment-specific.

## If the task fails

Stop rather than retrying with guessed paths or by deleting the database or
SQLite sidecar files. Check the matching topic in
[Troubleshooting](troubleshooting.md), then inspect
[the current backlog](../issues/README.md) if the problem is a known deferred
feature.
