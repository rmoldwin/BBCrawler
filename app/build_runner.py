"""Build the runner, preserving reader settings and additional cells."""
import ast
import copy
import nbformat
from project_paths import ROOT
from notebook_local import backup_notebook

LEGACY_IDS = set("""
68543d09 62d8f673 f53fb5d9 de99e1fb a1d7c014 ac4727c4 494efece 1cb44f2a
5b506049 d0b5e932 58c94f92 259dc9d9 d329ee1d 82dcc21b e25f035b 09cc1c52
a7baeed7 92ccaee9 fc664889 decce416 53f884b0 4ddb76d3 d597e440 737fa05c
ee9f6bc9 17d5f5be 1f0ce711 082f5ebd 0d38ee00 d79e1787 bfe74ff6 2a67b086
5bc425bf 6740e0af 3d1b1df1 501d12f7 c1a567cf f8c3a36b 94d993e2 fc918cdd
75bf693a a77e70fe 7f11e2fc b0ee0c67 f4b0b9d0 c6ee923d 9312c979 a6e7ea02
0999c05f b4dc7769
""".split())
SETTING_NAMES = {
    "BOOKS", "TOC_ONLY", "LIMIT", "NO_IMAGES", "RESCRAPE", "SQLSERVER",
    "DATABASE", "QUERY", "PROJECT_FOLDER",
}


def cell(kind, name, text):
    make = nbformat.v4.new_markdown_cell if kind == "markdown" else nbformat.v4.new_code_cell
    result = make(text.strip())
    result["id"] = f"runner-{name}"
    result.metadata["bbcrawler_managed"] = True
    return result


def settings_from(nb):
    settings = {}
    for entry in nb.cells:
        if entry.cell_type != "code":
            continue
        if not entry.metadata.get("bbcrawler_managed") and entry.get("id") not in LEGACY_IDS:
            continue
        for node in ast.parse(entry.source).body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1:
                target = node.targets[0]
                if isinstance(target, ast.Name) and target.id in SETTING_NAMES:
                    settings[target.id] = ast.literal_eval(node.value)
    return settings


def build(existing=None):
    settings = settings_from(existing) if existing else {}
    cells = []

    def md(name, text):
        cells.append(cell("markdown", name, text))

    def code(name, text):
        cells.append(cell("code", name, text))

    md("welcome", """
# Blue Books: collect, refresh, explore

This notebook helps you build and inspect a searchable collection from the
Blue Books material you can access. Start with **1. Open your workspace**.
Then choose the task you need; you do not have to run every section.

| Your goal | Sections to run |
|---|---|
| Inspect saved results | 1, then 2 |
| Update terms and suggested codes from saved pages | 1, then 3 |
| Collect from the website | 1, then 4; finally 3 |
| Copy the results to SQL Server | 1, then 5 |

Website steps need a browser on your own computer and your own access rights.
Saved-data work needs the local reference files and neighboring BBNotebook
helpers, but no login. Keep databases, reference material and login details
private. Use source material according to its access terms.

[First-use guide](docs/getting-started.md) |
[Everyday tasks](docs/everyday-use.md) |
[Help](docs/troubleshooting.md)
""")
    md("workspace-help", """
## 1. Open your workspace

Select your existing Python environment in the notebook's kernel picker.
The cell below finds the project and reads existing settings without changing
them. If the project is not found, set `PROJECT_FOLDER` to its full folder path.
If a package is missing, follow the first-use guide before continuing.

**Expected result:** the selected database path is printed. If anything fails,
stop and correct it before running a later section.
""")
    workspace = r'''
from pathlib import Path
import os
import sys
import subprocess
from contextlib import closing

PROJECT_FOLDER = None  # Or r"C:\your\BBCrawler folder"
start = Path(PROJECT_FOLDER).resolve() if PROJECT_FOLDER else Path.cwd().resolve()
ROOT = next((p for p in (start, *start.parents)
             if (p / "app" / "project_paths.py").is_file()), None)
if ROOT is None:
    raise FileNotFoundError("Set PROJECT_FOLDER to the BBCrawler project folder.")
if str(ROOT / "app") not in sys.path:
    sys.path.insert(0, str(ROOT / "app"))
import bluebooks_local as local
from project_paths import DEFAULT_CONFIG, load_config

CONFIG_PATH = DEFAULT_CONFIG
config = load_config(CONFIG_PATH)
DB = Path(config["db_path"])
CRAWLER_DIR = ROOT

def run_script(script, *args):
    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    command = [sys.executable, "-u", str(ROOT / "app" / script), *map(str, args)]
    with subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True, encoding="utf-8") as process:
        for line in process.stdout:
            print(line, end="")
        result = process.wait()
    if result:
        raise RuntimeError(f"{script} failed (exit {result}); correct the reported error.")
    return result

print("Workspace:", ROOT)
print("Database:", DB)
print("Settings loaded; no data has been changed.")
'''
    workspace = workspace.replace("PROJECT_FOLDER = None",
                                  f"PROJECT_FOLDER = {settings.get('PROJECT_FOLDER')!r}", 1)
    code("workspace", workspace)
    md("inspect-help", """
## 2. Inspect saved results

These cells read the database; they do not refresh or collect anything.
The first shows book names, short labels and editions. The second searches
saved text. Change `QUERY` to a word or phrase of interest.
The third shows terms alongside source or suggested codes.

An official reference match is a **suggestion**, not a diagnosis or an approved
code assignment. `is_proposed_code` and `is_proposed_term` distinguish suggestions
from what the source page actually says. Missing codes remain blank.
See the [data guide](docs/technical/data-guide.md) for column meanings.
""")
    code("inventory", '''
import pandas as pd
with closing(local.connect_sqlite(DB, readonly=True)) as connection:
    display(pd.read_sql_query(
        "SELECT book_id,title,alias,edition FROM books ORDER BY book_id", connection))
''')
    code("search", f'''
QUERY = {settings.get("QUERY", "neuroendocrine")!r}
with closing(local.connect_sqlite(DB, readonly=True)) as connection:
    display(pd.DataFrame(local.search(connection, QUERY, limit=10),
                         columns=["page_id", "title", "url", "full_text"]))
''')
    code("terms", '''
with closing(local.connect_sqlite(DB, readonly=True)) as connection:
    display(pd.read_sql_query(
        "SELECT alias,book_name,edition,page_title,TermUS,candidateTermUS,"
        "ICDO32,ICDO4,is_proposed_code,is_proposed_term,lookup_outcome,review_status "
        "FROM v_page_code_terms ORDER BY page_id,TermUS LIMIT 30", connection))
''')
    md("refresh-help", """
## 3. Update from saved pages

This rebuilds terms, reference matches and search text from material already on
disk. It does not log in or fetch website pages. Required reference files must
be present. A safety copy is made before changes begin.

Set `CONFIRM_REFRESH = True` only when ready. **Expected result:** table counts
are printed. If an error occurs, stop; keep the backup and use the help guide.
After this step, SQL Server is unchanged until you run section 5.
""")
    code("refresh", '''
CONFIRM_REFRESH = False
if not CONFIRM_REFRESH:
    raise RuntimeError("No changes made. Set CONFIRM_REFRESH = True to update saved data.")
print(local.backup_databases(DB, ROOT / "local_backups"))
result = local.refresh_local(DB)
print(result["counts"])
''')
    md("online-help", """
## 4. Collect from the website (optional)

Skip this entire section when working with saved data. You need Playwright and
its Chromium browser installed locally; the first-use guide explains how.

The login cell opens a browser and saves your session privately. Complete login
in that browser within `login_wait_seconds` from your settings (normally two
minutes). The session is saved automatically when that time ends. You do not
need to send a terminal Enter key from the notebook.
Discovery saves the volumes you can access. Inspect the list before choosing
book IDs for collection. Collection writes pages and may download images.

Every online action requires its own confirmation. If your session expires,
log in again before resuming. Start with a small `LIMIT`; zero means all pages.
`RESCRAPE = True` replaces existing collected content for the selected books,
so leave it false unless you intend that and have a backup.
""")
    code("login", '''
CONFIRM_LOGIN = False
if not CONFIRM_LOGIN:
    raise RuntimeError("No browser opened. Set CONFIRM_LOGIN = True to log in.")
run_script("bluebooks_auth.py", "--config", CONFIG_PATH,
           "--wait-seconds", config.get("login_wait_seconds", 120))
''')
    code("discover", '''
CONFIRM_DISCOVERY = False
if not CONFIRM_DISCOVERY:
    raise RuntimeError("No website access. Set CONFIRM_DISCOVERY = True to discover volumes.")
print(local.backup_databases(DB, ROOT / "local_backups") if DB.exists() else "First collection")
run_script("bluebooks_books.py", "--config", CONFIG_PATH, "discover")
run_script("bluebooks_books.py", "--config", CONFIG_PATH, "list")
''')
    values = {"BOOKS": [], "TOC_ONLY": False, "LIMIT": 5, "NO_IMAGES": True, "RESCRAPE": False}
    assignments = "\n".join(f"{name} = {settings.get(name, value)!r}" for name, value in values.items())
    code("collect", assignments + '''
CONFIRM_COLLECTION = False
if not CONFIRM_COLLECTION:
    raise RuntimeError("No collection started. Set CONFIRM_COLLECTION = True when ready.")
if not BOOKS:
    raise ValueError("Choose BOOKS from the discovered inventory before collecting.")
if DB.exists():
    print(local.backup_databases(DB, ROOT / "local_backups"))
args = ["--config", CONFIG_PATH, "--book", *map(str, BOOKS)]
if TOC_ONLY:
    args.append("--toc-only")
if LIMIT:
    args.extend(["--limit", str(LIMIT)])
if NO_IMAGES:
    args.append("--no-images")
if RESCRAPE:
    args.append("--rescrape")
run_script("bluebooks_crawl.py", *args)
print("Collection finished. Run section 3 to update terms and search results.")
''')
    md("mirror-help", """
## 5. Copy to SQL Server (optional)

This replaces managed data in the selected SQL Server database with the current
SQLite results and checks that their values match. Activity logs are not copied.
Use an existing SQL Server database, Windows authentication and Microsoft ODBC
Driver 17 or 18. This workflow does not take SQL-login passwords from a cell.

Run section 3 first if saved pages or reference inputs changed. Check the server
and database carefully, then set `CONFIRM_MIRROR = True`. Both databases are
backed up before replacement. **Expected result:** all table checks say `True`.
On failure, stop and keep the reported backups; do not repeatedly replace data.
""")
    code("mirror", f'''
SQLSERVER = {settings.get("SQLSERVER", "localhost")!r}
DATABASE = {settings.get("DATABASE", "BlueBooks")!r}
CONFIRM_MIRROR = False
if not CONFIRM_MIRROR:
    raise RuntimeError("SQL Server unchanged. Set CONFIRM_MIRROR = True when ready.")
print(local.backup_databases(DB, ROOT / "local_backups", SQLSERVER, DATABASE))
checks = local.mirror(DB, SQLSERVER, DATABASE, include_book70=False)
print({{table: check["match"] for table, check in checks.items()}})
with closing(local.connect_server(SQLSERVER, DATABASE)) as connection:
    print(local.server_search(connection))
''')
    md("next", """
## Where to go next

- [Everyday use](docs/everyday-use.md): choose a repeatable workflow.
- [Troubleshooting](docs/troubleshooting.md): resolve setup and connection issues.
- [Data guide](docs/technical/data-guide.md): understand source text, suggestions
  and saved review decisions.
- The neighboring BBNotebook project offers more detailed exploration notebooks.

Additional reader cells are preserved below when this notebook is regenerated.
They are not part of the standard workflow; inspect them before running them.
""")
    if existing:
        for entry in existing.cells:
            if not entry.metadata.get("bbcrawler_managed") and entry.get("id") not in LEGACY_IDS:
                extra = copy.deepcopy(entry)
                if extra.cell_type == "code":
                    extra.outputs = []
                    extra.execution_count = None
                cells.append(extra)
    nb = nbformat.v4.new_notebook(cells=cells)
    nb.metadata = copy.deepcopy(existing.metadata) if existing else {}
    nb.metadata["kernelspec"] = {"display_name": "Python 3", "language": "python", "name": "python3"}
    nb.metadata["language_info"] = {"name": "python"}
    return nb


def main():
    target = ROOT / "Crawler_Runner.ipynb"
    existing = nbformat.read(target, 4) if target.exists() else None
    result = build(existing)
    nbformat.validate(result)
    backup_notebook(target)
    nbformat.write(result, target)
    print(f"Wrote {target.name}: {len(result.cells)} cells; no cells executed.")


if __name__ == "__main__":
    main()
