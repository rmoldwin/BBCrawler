"""
Builds Crawler_Runner.ipynb — a novice-friendly, VS Code-ready notebook that
drives the WHO Blue Books crawler scripts (auth -> discover -> crawl -> index)
and optionally loads the finished SQLite database into SQL Server.

Cells are emitted as alternating markdown / code via nbformat.
Triple-quoted SQL / docstrings inside a code() cell are written as \"\"\" so they
don't close the outer r\"\"\"...\"\"\" wrapper; code() converts them back.
"""
import nbformat as nbf

nb = nbf.v4.new_notebook()
cells = []


def md(text: str):
    cells.append(nbf.v4.new_markdown_cell(text.strip("\n")))


def code(src: str):
    src = src.replace('\\"\\"\\"', '"""')
    src = src.replace('\\"', '"')
    cells.append(nbf.v4.new_code_cell(src.strip("\n")))


# ===========================================================================
# TITLE
# ===========================================================================
md(r"""
# 🕮 Blue Books Crawler — Runner Notebook

This notebook **runs the WHO Blue Books crawler** step by step and builds the
searchable database — no command-line experience needed. You edit a few clearly
marked settings, then press ▶ Run on each cell.

It walks you through the whole pipeline:

1. **Set up** Python + the browser engine the crawler uses.
2. **Configure** your settings (`config.json`).
3. **Log in** once in a real browser window and save the session.
4. **Discover** which Blue Books volumes your subscription exposes.
5. **Crawl** the volume(s) you choose (resumable, polite rate limits).
6. **Build the search index** (FTS5).
7. **Check** what you collected.
8. *(Optional)* **Copy the data into SQL Server.**

> ### ⚠️ Run this on YOUR computer, not in a cloud kernel
> Steps 3–5 open a **real Chromium browser** and use **your logged-in
> BlueBooksOnline session**. They must run **locally** (VS Code on your own
> machine), where a browser window can appear and reach the licensed site.
> A remote/headless kernel cannot log in for you.
>
> ### 📄 Licensing
> WHO/IARC tumour-classification content is copyrighted and subscription-gated.
> Use extracts for **private, licensed, non-commercial study** only; keep the
> resulting database private. The crawler uses polite delays by default.
""")

# ===========================================================================
# STEP 0 — SETUP
# ===========================================================================
md(r"""
## Step 0 — One-time setup

The crawler needs **Python 3.9+** and **Playwright** (the library that drives a
real browser). Step 6 uses **pandas** for quick tables, and the optional SQL
Server load uses **pyodbc**. Run the cell below once. It:

1. checks you're running a **local** kernel (warns if it looks remote),
2. installs `playwright`, `pandas`, and `pyodbc` if missing, and
3. downloads the **Chromium** browser Playwright uses.

The Chromium download is ~100–150 MB and only happens the first time.

> `pyodbc` covers the Python package. For Step 7 you still need a Microsoft
> SQL Server ODBC driver installed on Windows (typically Driver 17 or 18).

**Expected outcome:** kernel details print, required packages are present,
and Playwright Chromium finishes with `✅ Chromium ready.`
""")

md(r"""
### Before you start (quick checklist)

- You are running this notebook on your local machine (not a remote kernel).
- You are comfortable keeping `auth_state.json` and `bluebooks.db` private.
- You expect a first-run Chromium download (~100–150 MB).
- SQL Server steps are optional; Steps 1–6 and Step 8 work with SQLite only.
- If you need SQL Server later, keep these references handy:
    - `SESSION_FIX_LOG_2026-07-21.md`
    - `SQLSERVER_CONNECTION_VARIANTS.md`
""")
code(r"""
import sys, os, subprocess, platform, socket

print("Python:", sys.version.split()[0], "on", platform.system(), platform.release())

# --- gentle "are we local?" heuristic (informational only) ---
host = socket.gethostname().lower()
looks_remote = any(x in host for x in ("e2b", "sandbox", "runner", "colab", "container"))
if looks_remote or "COLAB_GPU" in os.environ:
    print("\n⚠️  This looks like a REMOTE/cloud kernel:", host)
    print("   The login + crawl steps need a LOCAL browser window and your BB session.")
    print("   Open this notebook in VS Code on your own computer before running Steps 3–5.")
else:
    print("Kernel host:", host, "(looks local — good)")

def _ensure(pkg, import_name=None):
    import importlib
    try:
        importlib.import_module(import_name or pkg)
        print(f"✅ {pkg} already installed")
    except ImportError:
        print(f"⏳ installing {pkg} …")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", pkg])
        print(f"✅ {pkg} installed")

_ensure("playwright")
_ensure("pandas")
_ensure("pyodbc")

# Download the Chromium browser Playwright drives (idempotent — safe to re-run).
print("\n⏳ Ensuring Chromium is installed for Playwright …")
try:
    subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"])
    print("✅ Chromium ready.")
except Exception as e:
    print("⚠️  Could not auto-install Chromium:", e)
    print("   Run this once in a terminal:  python -m playwright install chromium")
""")

md(r"""
### Where are the crawler scripts?

This notebook calls the crawler's Python scripts (`bluebooks_auth.py`,
`bluebooks_books.py`, `bluebooks_crawl.py`, `bluebooks_fts.py`, `search.py`).
By default it looks in the **same folder as this notebook**. If you keep the
scripts elsewhere, set `CRAWLER_DIR` below.
""")
code(r"""
from pathlib import Path

# Folder containing the crawler .py scripts (default: this notebook's folder).
CRAWLER_DIR = Path(".").resolve()      # e.g. Path(r"C:\Users\you\bluebooks-crawler")

REQUIRED = ["bluebooks_auth.py", "bluebooks_books.py", "bluebooks_crawl.py",
            "bluebooks_fts.py", "search.py", "schema.sql"]
missing = [f for f in REQUIRED if not (CRAWLER_DIR / f).exists()]
if missing:
    print("❌ Missing crawler files in", CRAWLER_DIR)
    for m in missing:
        print("   -", m)
    print("\nSet CRAWLER_DIR to the folder that holds the crawler scripts, then re-run.")
else:
    print("✅ Found all crawler scripts in:", CRAWLER_DIR)
""")

md(r"""
### A small helper to run the crawler and show its output live

Every step below calls one crawler script. This `run_script()` helper runs it
and **streams the output into the notebook as it happens**, so you can watch a
long crawl progress. It returns the exit code (0 = success).
""")
code(r"""
import os, subprocess, sys
from pathlib import Path

def run_script(script, *args, cwd=None):
    \"\"\"Run a crawler script with live output. Returns the process exit code.\"\"\"
    cwd = Path(cwd) if cwd else CRAWLER_DIR
    cmd = [sys.executable, str(cwd / script), *map(str, args)]
    print("▶", " ".join(cmd), "\n" + "-" * 70)
    env = os.environ.copy()
    # Force UTF-8 between parent/child so notebook output doesn't show mojibake.
    env.setdefault("PYTHONUTF8", "1")
    env.setdefault("PYTHONIOENCODING", "utf-8")
    proc = subprocess.Popen(cmd, cwd=str(cwd), stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                            errors="replace", bufsize=1, env=env)
    try:
        for line in proc.stdout:
            print(line, end="")
    finally:
        proc.wait()
    print("-" * 70)
    print(("✅ done" if proc.returncode == 0 else f"⚠️ exited with code {proc.returncode}"),
          f"({script})")
    return proc.returncode

print("run_script() ready.")
""")

# ===========================================================================
# STEP 1 — CONFIG
# ===========================================================================
md(r"""
## Step 1 — Configure the crawler (`config.json`)

The scripts read their settings from a `config.json` file. Edit the values
below and run the cell to write it. You rarely need to change more than
`db_path`.

| Setting | What it does |
|---|---|
| `base_url` | The Blue Books site root. Leave as-is. |
| `db_path` | Where the SQLite database is written (your corpus). |
| `auth_state_path` | Where your saved login session is stored (Step 3). |
| `headless` | `false` for login (a window must appear); the crawl itself can run headless. |
| `capture_images` | `true` stores image URLs; `false` = smaller/faster DB (links still kept). |
| `login_wait_seconds` | Fallback wait if you can't press Enter (non-interactive). |
| `nav_timeout_ms` | Per-navigation timeout. |
| `polite_delay_seconds` | Pause between page fetches (be a good citizen). |
| `keepalive_seconds` | Activity ping to fend off the ~15-min session timeout. |

**Expected outcome:** writes/updates `config.json` and echoes the settings.
""")
code(r"""
import json
from pathlib import Path

config = {
    "base_url": "https://tumourclassification.iarc.who.int",
    "db_path": "bluebooks.db",
    "auth_state_path": "auth_state.json",
    "headless": True,             # Step 3 (auth) forces a visible window regardless
    "capture_images": True,       # set False for a smaller, faster DB
    "login_wait_seconds": 120,
    "nav_timeout_ms": 30000,
    "polite_delay_seconds": 1.0,
    "keepalive_seconds": 240,
}

CONFIG_PATH = CRAWLER_DIR / "config.json"
CONFIG_PATH.write_text(json.dumps(config, indent=2), encoding="utf-8")
print(f"✅ Wrote {CONFIG_PATH}")
print(json.dumps(config, indent=2))
""")

# ===========================================================================
# STEP 2 — (about auth)
# ===========================================================================
md(r"""
## Step 2 — Log in once and save your session

The crawler never sees your password. Instead you log in **once** in a real
browser window, and Playwright saves the resulting session (cookies) to
`auth_state.json`. The crawler then reuses that session headlessly.

**What happens when you run the next cell:**

1. A **Chromium window opens** on the BlueBooksOnline home page.
2. **Log in normally** (institution / username+password / SSO — whatever you use).
3. When you can see your subscribed content, **come back here** — the script is
   waiting. Because this runs inside the notebook, it can't read your keyboard,
   so it waits `login_wait_seconds` (default 120s) and then captures the session
   automatically. Make sure you're fully logged in before that timer ends.

> Sessions expire after ~15 minutes of inactivity. If a later step reports
> `auth_expired`, just run this cell again to refresh `auth_state.json`, then
> resume the crawl.

> If you'd rather press Enter yourself (more reliable), run this **in a terminal**
> instead: `python bluebooks_auth.py --config config.json`
""")
code(r"""
# Opens a REAL browser window — must be run on your local machine.
# Give yourself time to finish logging in before login_wait_seconds elapses.
rc = run_script("bluebooks_auth.py", "--config", "config.json")
auth_file = CRAWLER_DIR / config["auth_state_path"]
if auth_file.exists():
    print(f"\n✅ Session saved to {auth_file} — you're ready to discover & crawl.")
else:
    print("\n⚠️ No auth_state file yet. Re-run this cell and finish logging in "
          "before the timer ends (or run bluebooks_auth.py in a terminal).")
""")

# ===========================================================================
# STEP 3 — DISCOVER + LIST
# ===========================================================================
md(r"""
## Step 3 — Discover the volumes your subscription exposes

`discover` opens the site (using your saved session) and harvests every book it
can see across all edition tabs (5th, 6th, Cytopathology / Reporting Systems),
saving them into the `books` table. Run it once; re-run only when new volumes
appear.
""")
code(r"""
rc = run_script("bluebooks_books.py", "--config", "config.json", "discover")
""")

md(r"""
### List the inventory with crawl status

`list` prints every known book with its per-book status: **Pages** already
stored, **Pend**ing in the queue, and **Err**ors. Use this to decide what to
crawl next, and to watch progress between crawl runs.

Known IDs from earlier discovery (yours may differ):

| Edition | Book | ID |
|---|---|---|
| 5th | Digestive System | 31 |
| 5th | Central Nervous System | 45 |
| 5th | Genetic Tumour Syndromes (Beta) | 67 |
| 6th | Digestive System (Beta) | 72 |
| 6th | Breast (Beta) | 84 |
| Cytopathology | Lung Reporting System | 48 |
""")
code(r"""
rc = run_script("bluebooks_books.py", "--config", "config.json", "list")
""")

# ===========================================================================
# STEP 4 — CRAWL
# ===========================================================================
md(r"""
## Step 4 — Crawl the volume(s) you choose

Pick one or more book IDs in `BOOKS` below. The crawler harvests the table of
contents, queues every leaf page, then fetches and stores each one. It's
**resumable**: re-running picks up only `pending`/`error` pages, so it's cheap
to stop and continue.

**Options** (set the flags in the cell):

- `TOC_ONLY = True` — only harvest the TOC into the queue (no page fetching yet).
- `LIMIT = 5` — stop after N pages per book — perfect for a first **smoke test**.
- `NO_IMAGES = True` — skip image capture (smaller, faster DB; links still kept).
- `RESCRAPE = True` — purge this book's stored data and re-fetch it fresh
  (use when a Beta became Print, or an earlier crawl was incomplete).

**Start small.** Try one book with `LIMIT = 5` first to confirm everything works,
then re-run with `LIMIT = 0` to crawl it fully.
""")
code(r"""
# ----------------------- choose what to crawl -----------------------
BOOKS     = [31]        # one or more book IDs, e.g. [31, 45, 72]
TOC_ONLY  = False       # True = only queue the TOC, don't fetch pages yet
LIMIT     = 5           # 0 = all pages; a small number = smoke test
NO_IMAGES = False       # True = skip images (smaller DB)
RESCRAPE  = False       # True = purge & re-fetch these books fresh
# --------------------------------------------------------------------

args = ["--config", "config.json", "--book", *map(str, BOOKS)]
if TOC_ONLY:  args.append("--toc-only")
if LIMIT:     args += ["--limit", str(LIMIT)]
if NO_IMAGES: args.append("--no-images")
if RESCRAPE:  args.append("--rescrape")

rc = run_script("bluebooks_crawl.py", *args)
if rc != 0:
    print("\nℹ️ If this said 'auth_expired', re-run Step 2 to refresh your session, "
          "then run this cell again — it resumes where it stopped.")
""")

md(r"""
**Full crawl after a good smoke test.** Once `LIMIT = 5` looks right, set
`LIMIT = 0` above and run the cell again to finish the book. Then re-run the
**Step 3 list** cell to watch `Pend` drop toward 0.
""")

# ===========================================================================
# STEP 5 — FTS INDEX
# ===========================================================================
md(r"""
## Step 5 — Build the keyword search index (FTS5)

After crawling, build the full-text index so you can search the corpus. This
(re)builds two FTS5 tables from the stored sections: `sections_fts` (per-section)
and `pages_fts` (per-page). Safe to run repeatedly — run it again whenever you
crawl more pages.
""")
code(r"""
rc = run_script("bluebooks_fts.py", "--config", "config.json")
""")

# ===========================================================================
# STEP 6 — INSPECT
# ===========================================================================
md(r"""
## Step 6 — Check what you collected

A quick look inside the SQLite database: row counts per table, books with their
page counts, and a few sample pages with their clickable URLs. (This is
read-only.)
""")
code(r"""
import sqlite3, pandas as pd
from pathlib import Path

DB = CRAWLER_DIR / config["db_path"]
print("Database:", DB, f"({DB.stat().st_size/1e6:.1f} MB)" if DB.exists() else "(not created yet)")
con = sqlite3.connect(DB)

def show(df, n=25):
    from IPython.display import display
    display(df.head(n))
    if len(df) > n: print(f"… {len(df)-n} more row(s).")

print("\nRow counts:")
tables = ["books","chapters","page_groups","pages","sections",
          "authors","images","page_links","references","crawl_queue","crawl_runs"]
counts = []
for t in tables:
    try:
        (c,) = con.execute(f'SELECT COUNT(*) FROM \"{t}\"').fetchone()
    except Exception:
        c = "—"
    counts.append({"table": t, "rows": c})
show(pd.DataFrame(counts), n=50)
""")
code(r"""
print("Books and how many pages are stored / pending / errored:")
show(pd.read_sql_query(\"\"\"
    SELECT b.book_id, b.title, b.edition, b.status,
           SUM(p.crawl_status='done')    AS pages_done,
           SUM(p.crawl_status='pending') AS pending,
           SUM(p.crawl_status='error')   AS errors
    FROM books b LEFT JOIN pages p ON p.book_id = b.book_id
    GROUP BY b.book_id, b.title, b.edition, b.status
    ORDER BY b.book_id
\"\"\", con))
""")
code(r"""
print("Sample crawled pages (with their Blue Books URLs):")
sample_pages = pd.read_sql_query(\"\"\"
    SELECT p.page_id, b.edition, p.page_type, p.title, p.url
    FROM pages p JOIN books b ON b.book_id = p.book_id
    WHERE p.crawl_status = 'done'
    ORDER BY b.edition, p.page_type, p.title
    LIMIT 25
\"\"\", con)
with pd.option_context("display.max_colwidth", None):
    show(sample_pages)
""")

# ===========================================================================
# STEP 7 — LOAD INTO SQL SERVER (optional)
# ===========================================================================
md(r"""
## Step 7 — (Optional) Copy the corpus into SQL Server

If you want the data in **SQL Server** (e.g. to run the cross-walk queries from
the *Explorer* notebook against a shared server), this step executes:

0. **rebuilds the SQLite FTS5 index** so the data you copy is fully indexed,
1. creates the schema from **`schema_sqlserver.sql`** (7a),
2. **deploys `dbo.Clean`** and verifies it (7a-clean),
3. **bulk-copies** every table from your finished SQLite DB into `dbo.*` (7b), and
4. **rebuilds the SQL Server FULLTEXT index** (7c).

### Preflight

- `pyodbc` installed in this Python environment.
- Microsoft **ODBC Driver 17/18 for SQL Server** installed.
- Target database already exists and you can write to it.
- SQL Server Full-Text Search feature is recommended for Step 7c `CONTAINS`.

### Execution order

Run these cells in order: **7·0 → 7a → 7a·clean → 7b → 7c**.

> This copies the **already-crawled** SQLite data — it does not re-crawl. Run
> Steps 4–5 first so the SQLite DB is complete.

**Expected outcome:** tables load into `dbo.*`, `dbo.Clean` verifies, and the
full-text catalog/index are rebuilt and populated.
""")

md(r"""
### Rerun safety map

- Safe to rerun anytime: **Step 5, 7·0, 7a, 7a·clean, 7c, 8**.
- Usually rerun only when needed: **Step 2** (renew login), **Step 4** (crawl more content).
- After any large reload in 7b, rerun **7c** so SQL Server full-text search reflects new data.
""")

md(r"""
### 7·0 — Rebuild the SQLite FTS5 index first

Before copying to SQL Server, make sure the **SQLite** search index reflects
everything you've crawled. This is the same rebuild as Step 5, repeated here so
the corpus you load is fully indexed (handy if you crawled more pages since you
last ran Step 5). Safe to run again — it rebuilds `sections_fts` / `pages_fts`
from scratch.
""")
code(r"""
rc = run_script("bluebooks_fts.py", "--config", "config.json")
if rc == 0:
    print("✅ SQLite FTS5 index is current — ready to load SQL Server.")
""")

code(r"""
# ---------------------- SQL Server connection ----------------------
SQLSERVER = "(local)"                    # preferred server / instance (edit for your setup)
SQLSERVER_CANDIDATES = [
    SQLSERVER,
    "MACHINE_NAME",
    ".",
    "localhost",
]
DATABASE  = "BlueBooks"                  # target database (must already exist)
TRUSTED   = True                          # True = Windows login; False = SQL login
USERNAME  = ""                            # if TRUSTED = False
PASSWORD  = ""                            # leave blank to be prompted securely
DRIVER    = ""                            # blank = auto-pick 18 then 17 if installed
ENCRYPT   = True
# -------------------------------------------------------------------

def mssql_connect():
    import pyodbc, getpass

    def pick_driver():
        installed = [d.strip() for d in pyodbc.drivers()]
        if DRIVER:
            if DRIVER in installed:
                return DRIVER
            raise RuntimeError(f"Requested DRIVER not installed: {DRIVER}. Installed: {installed}")
        for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"):
            if d in installed:
                return d
        raise RuntimeError("No SQL Server ODBC driver found. Install ODBC Driver 18 or 17.")

    def unique_servers(items):
        out = []
        seen = set()
        for s in items:
            s = str(s).strip()
            if s and s.lower() not in seen:
                seen.add(s.lower())
                out.append(s)
        return out

    pwd = PASSWORD
    if not TRUSTED and not pwd:
        pwd = getpass.getpass(f"Password for {USERNAME}@{SQLSERVER}: ")
    driver = pick_driver()
    attempts = []
    for server in unique_servers(SQLSERVER_CANDIDATES):
        parts = [f"DRIVER={{{driver}}}", f"SERVER={server}", f"DATABASE={DATABASE}"]
        parts.append("Trusted_Connection=yes" if TRUSTED else f"UID={USERNAME};PWD={pwd}")
        parts.append("Encrypt=yes" if ENCRYPT else "Encrypt=no")
        parts.append("TrustServerCertificate=yes")
        parts.append("Connection Timeout=5")
        try:
            cn = pyodbc.connect(";".join(parts), autocommit=False)
            globals()["SQLSERVER"] = server
            print(f"✅ Connected to SQL Server using: {server} (driver: {driver})")
            return cn
        except Exception as e:
            attempts.append(f"{server}: {str(e).splitlines()[0][:140]}")

    raise RuntimeError(
        "Could not connect to any configured SQL Server target. Tried:\n- "
        + "\n- ".join(attempts)
        + "\nEdit SQLSERVER or SQLSERVER_CANDIDATES in this cell, then re-run it."
    )

print("Configured SQL Server target:", SQLSERVER, "/", DATABASE)
print("Run the next cell to create the schema, then the one after to copy data.")
""")

md(r"""
### 7a — Create the SQL Server schema

Runs `schema_sqlserver.sql` (splitting on `GO` batches). Existing tables are
left alone (`IF OBJECT_ID(...) IS NULL`), so it's safe to re-run.

**Expected outcome:** `✅ Applied X/Y schema batches` (with possible informative
"already exists" skips on reruns).

If this fails: first re-run the SQL Server connection cell above, then re-run 7a.
""")
code(r"""
import re

def split_tsql_batches(sql_text: str):
    # Remove /* ... */ blocks first so 'GO' inside comments does not split batches.
    no_block_comments = re.sub(r"/\*.*?\*/", "", sql_text, flags=re.S)
    return [b.strip() for b in re.split(r"(?im)^\s*GO\s*$", no_block_comments) if b.strip()]

def is_fulltext_installed(cur):
    cur.execute("SELECT CAST(SERVERPROPERTY('IsFullTextInstalled') AS INT)")
    return (cur.fetchone()[0] or 0) == 1

sql_path = CRAWLER_DIR / "schema_sqlserver.sql"
if not sql_path.exists():
    print("⚠️ schema_sqlserver.sql not found next to the notebook.")
else:
    ddl = sql_path.read_text(encoding="utf-8")
    batches = split_tsql_batches(ddl)
    total_batches = len(batches)
    try:
        cn = mssql_connect(); cur = cn.cursor()
    except Exception as e:
        print(f"❌ SQL Server connection failed: {e}")
        print("Update SQLSERVER / SQLSERVER_CANDIDATES in the previous cell, then run 7a again.")
        raise
    fts_batches = [b for b in batches if "CREATE FULLTEXT" in b.upper()]
    if fts_batches:
        batches = [b for b in batches if b not in fts_batches]
    if not is_fulltext_installed(cur):
        fts_batches = []
        print("⚠️ Full-Text Search is not installed on this SQL Server instance.")
        print("   Schema loading is incomplete until FTS is installed, because the last two batches")
        print("   in schema_sqlserver.sql create the full-text catalog and full-text index.")
        print("   Current SQL Server major version: 17.x / SQL Server 2025.")
        print("   Install it in SQL Server Setup by modifying this instance and adding the")
        print("   'Full-Text and Semantic Extractions for Search' feature (or the Full-Text Search")
        print("   feature name shown by your installer), then rerun Step 7a.")
        print("   Generic downloads page: https://www.microsoft.com/en-us/sql-server/sql-server-downloads")
        print("   Installation guide: https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server?view=sql-server-ver17")
    else:
        cur.execute(\"\"\"
            SELECT i.name
            FROM sys.indexes i
            WHERE i.object_id = OBJECT_ID('dbo.sections') AND i.is_primary_key = 1
        \"\"\")
        row = cur.fetchone()
        pk_index = row[0] if row else None
    ok = 0
    for b in batches:
        try:
            cur.execute(b); ok += 1
        except Exception as e:
            msg = str(e).lower()
            if "42s11" in msg or "already exists" in msg:
                ok += 1
                print("… batch already exists, skipped.")
            else:
                print("… batch skipped:", str(e).splitlines()[0][:120])
    cn.commit(); cn.close()
    if fts_batches:
        cn = mssql_connect(); cn.autocommit = True; cur = cn.cursor()
        for b in fts_batches:
            try:
                if 'PK__sections' in b and pk_index:
                    b = b.replace('PK__sections', pk_index)
                cur.execute(b); ok += 1
            except Exception as e:
                msg = str(e).lower()
                if "already exists" in msg:
                    ok += 1
                    print("… FTS batch already exists, skipped.")
                else:
                    print("… FTS batch skipped:", str(e).splitlines()[0][:120])
        cn.close()
    print(f"✅ Applied {ok}/{total_batches} schema batches to {DATABASE}.")
""")

md(r"""
### 7a·clean — Deploy `dbo.Clean` and verify it

The PathCHART cross-walk (in the *Explorer* notebook) and any term matching on
the server rely on the **`dbo.Clean`** normalization function — the SQL Server
twin of the Python `clean()` used everywhere else. This cell deploys the
**authoritative** function body from **`00_dbo_Clean.sql`** (the corrected
2026-07-09 version, mirrored 1:1 by `python/clean_term.py`) using
`CREATE OR ALTER`, so it's safe to run repeatedly.
""")
code(r"""
import re

def split_tsql_batches(sql_text: str):
    # Remove /* ... */ blocks first so 'GO' inside comments does not split batches.
    no_block_comments = re.sub(r"/\*.*?\*/", "", sql_text, flags=re.S)
    return [b.strip() for b in re.split(r"(?im)^\s*GO\s*$", no_block_comments) if b.strip()]

clean_path = CRAWLER_DIR / "00_dbo_Clean.sql"
if not clean_path.exists():
    print("⚠️ 00_dbo_Clean.sql not found next to the notebook.")
    print("   Copy it from the term-normalizer bundle (sqlserver/00_dbo_Clean.sql) and re-run.")
else:
    body = clean_path.read_text(encoding="utf-8")
    batches = split_tsql_batches(body)
    cn = mssql_connect(); cur = cn.cursor()
    ok = 0
    for b in batches:
        try:
            cur.execute(b); ok += 1
        except Exception as e:
            print("⚠️ batch failed:", str(e).splitlines()[0][:160])
    cn.commit(); cn.close()
    print(f"✅ Deployed dbo.Clean ({ok}/{len(batches)} batch(es) executed).")
""")

md(r"""
**Verify `dbo.Clean` exists and behaves.** This confirms the function is
present on the server and runs a few normalization smoke tests (US spelling,
`NOS`/`type` stripping, `/`→space, Roman-numeral handling). Compare the output
to what the Python `clean()` produces — they must match.
""")
code(r"""
cn = mssql_connect(); cur = cn.cursor()

# 1) Does the scalar function exist?
cur.execute("SELECT OBJECT_ID('dbo.Clean', 'FN')")
if cur.fetchone()[0] is None:
    print("❌ dbo.Clean is NOT present on the server. Run the deploy cell above first.")
else:
    print("✅ dbo.Clean exists on", f"{SQLSERVER}/{DATABASE}.")
    # 2) Smoke tests: (input, expected)
    tests = [
        ("Oesophageal adenocarcinoma, NOS", "Esophageal adenocarcinoma"),
        ("Follicular lymphoma, duodenal-type", "Follicular lymphoma duodenal"),
        ("AIN III",                            "AIN 3"),
        ("Adenocarcinoma/NOS",                 "Adenocarcinoma"),
    ]
    print(f"\n{'input':45} {'dbo.Clean output':35} {'expected':35} ok?")
    print("-" * 125)
    all_ok = True
    for src, exp in tests:
        cur.execute("SELECT dbo.Clean(?)", src)
        got = cur.fetchone()[0]
        ok = (got == exp)
        all_ok &= ok
        print(f"{src:45} {str(got):35} {exp:35} {'✓' if ok else '✗'}")
    print("-" * 125)
    print("✅ All smoke tests passed." if all_ok else
          "⚠️ Some outputs differ — confirm this is the corrected dbo.Clean "
          "(re-deploy from 00_dbo_Clean.sql).")
cn.close()
""")

md(r"""
### 7b — Copy the data (SQLite ➜ SQL Server)

Streams each table from SQLite into `dbo.<table>` using batched `INSERT`s
(`fast_executemany` for speed). Set `TRUNCATE_FIRST = True` to clear the target
tables before copying (a clean reload). Column names are matched by name, so
extra/missing columns are handled gracefully.

> After copying, rebuild the SQL Server FULLTEXT index if needed (see
> `schema_sqlserver.sql`), and deploy `dbo.Clean` from the *term-normalizer*
> bundle if you'll run the PathCHART cross-walk here.
""")
code(r"""
import sqlite3

TRUNCATE_FIRST = True      # clear dbo.* tables before loading (clean reload)
BATCH = 500

# Load order respects foreign keys (parents first).
COPY_ORDER = ["books","chapters","page_groups","pages","sections",
              "authors","images","page_links","references","crawl_queue","crawl_runs"]

def sqlite_columns(scon, table):
    return [r[1] for r in scon.execute(f'PRAGMA table_info(\"{table}\")')]

def mssql_columns(mcur, table):
    mcur.execute(\"\"\"
        SELECT c.name FROM sys.columns c
        JOIN sys.tables t ON t.object_id = c.object_id
        WHERE t.name = ?  AND c.is_computed = 0
    \"\"\", table)
    return [r[0] for r in mcur.fetchall()]

scon = sqlite3.connect(CRAWLER_DIR / config["db_path"])
scon.row_factory = sqlite3.Row
mcn = mssql_connect(); mcur = mcn.cursor(); mcur.fast_executemany = True

total = 0
for table in COPY_ORDER:
    try:
        scols = sqlite_columns(scon, table)
    except Exception:
        continue
    if not scols:
        continue
    mcols = set(mssql_columns(mcur, table))
    cols = [c for c in scols if c in mcols]     # copy only shared columns
    if not cols:
        print(f"… {table}: no matching columns, skipped"); continue

    if TRUNCATE_FIRST:
        try: mcur.execute(f"DELETE FROM dbo.[{table}]")
        except Exception as e: print(f"… {table}: could not clear ({str(e).splitlines()[0][:80]})")

    collist = ",".join(f"[{c}]" for c in cols)
    qs = ",".join("?" * len(cols))
    ins = f"INSERT INTO dbo.[{table}] ({collist}) VALUES ({qs})"

    rows = scon.execute(f'SELECT {",".join(chr(34)+c+chr(34) for c in cols)} FROM \"{table}\"')
    n = 0; batch = []
    for r in rows:
        batch.append(tuple(r[c] for c in cols))
        if len(batch) >= BATCH:
            mcur.executemany(ins, batch); n += len(batch); batch = []
    if batch:
        mcur.executemany(ins, batch); n += len(batch)
    mcn.commit()
    total += n
    print(f"✅ {table}: copied {n} rows ({len(cols)} cols)")

mcn.close(); scon.close()
print(f"\nDone. Copied {total} rows into {DATABASE}.")
print("Next: run Step 7c to rebuild the FULLTEXT index; deploy dbo.Clean if you'll cross-walk here.")
""")

md(r"""
### 7c — Rebuild the SQL Server FULLTEXT index

SQL Server's full-text index does **not** repopulate itself when you bulk-load
rows the way FTS5 is rebuilt in Step 5. After a reload you must (re)create and
**fully populate** the index over `dbo.sections(heading, body_text)` so
`CONTAINS(...)` / the `dbo.v_search` view return the new content.

The cell below does this robustly:

1. checks the **Full-Text Search** feature is installed,
2. creates the `BlueBooksFT` catalog if missing,
3. looks up the **real primary-key index name** on `dbo.sections` (SQL Server
   auto-names it `PK__sections__…`, so the literal `PK__sections` placeholder in
   the schema won't match) — this is the required unique key index,
4. **drops any existing** full-text index and recreates it against that key, and
5. forces a **full population** and reports catalog status.

> Requires the SQL Server **Full-Text Search** component. If it's not installed,
> the cell says so and everything else (exact/`LIKE` queries, the cross-walk,
> the Explorer notebook's FTS on SQLite) still works — only server-side
> `CONTAINS` needs it.

**Expected outcome:** index recreation message, population status, and a
`CONTAINS` smoke-test result (`0 row(s)` is valid if the term is absent).

If this fails: run 7a first, confirm Full-Text Search is installed, then rerun 7c.
""")
code(r"""
FT_CATALOG = "BlueBooksFT"
WAIT_FOR_FULL_POPULATION = True     # block until the index finishes populating

cn = mssql_connect(); cur = cn.cursor()

# 1) Is Full-Text Search installed on this instance?
cur.execute("SELECT CAST(SERVERPROPERTY('IsFullTextInstalled') AS INT)")
if (cur.fetchone()[0] or 0) != 1:
    print("⚠️  Full-Text Search is NOT installed on this SQL Server instance.")
    print("    Install the 'Full-Text and Semantic Extractions for Search' feature,")
    print("    then re-run this cell. (Exact/LIKE queries work without it.)")
else:
    cn.commit()
    cn.autocommit = True
    cur = cn.cursor()
    # 2) Catalog
    cur.execute("SELECT 1 FROM sys.fulltext_catalogs WHERE name = ?", FT_CATALOG)
    if cur.fetchone() is None:
        cur.execute(f"CREATE FULLTEXT CATALOG [{FT_CATALOG}] AS DEFAULT")

    # 3) Real PK index name on dbo.sections (needed as the unique KEY INDEX)
    cur.execute(\"\"\"
        SELECT i.name
        FROM sys.indexes i
        WHERE i.object_id = OBJECT_ID('dbo.sections') AND i.is_primary_key = 1
    \"\"\")
    row = cur.fetchone()
    if not row:
        print("⚠️  dbo.sections has no primary-key index — cannot create a FULLTEXT index.")
        print("    Ensure Step 7a created dbo.sections with its PRIMARY KEY, then re-run.")
    else:
        pk_index = row[0]

        # 4) Drop existing FT index (if any) then recreate against the real key
        cur.execute("SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID('dbo.sections')")
        if cur.fetchone() is not None:
            cur.execute("DROP FULLTEXT INDEX ON dbo.sections")
        cn.commit()
        cur.execute(f\"\"\"
            CREATE FULLTEXT INDEX ON dbo.sections (heading, body_text)
                KEY INDEX [{pk_index}]
                ON [{FT_CATALOG}]
                WITH CHANGE_TRACKING AUTO
        \"\"\")
        cn.commit()
        print(f"✅ FULLTEXT index (re)created on dbo.sections using key index [{pk_index}].")

        # 5) Force a full population, then report status
        cur.execute("ALTER FULLTEXT INDEX ON dbo.sections START FULL POPULATION")
        cn.commit()

        if WAIT_FOR_FULL_POPULATION:
            import time
            print("⏳ Populating full-text index …", end="", flush=True)
            for _ in range(120):                 # up to ~4 min
                cur.execute(\"\"\"
                    SELECT FULLTEXTCATALOGPROPERTY(?, 'PopulateStatus')
                \"\"\", FT_CATALOG)
                status = cur.fetchone()[0]
                if status == 0:                    # 0 = idle (done)
                    break
                print(".", end="", flush=True); time.sleep(2)
            print(" done.")

        cur.execute(\"\"\"
            SELECT FULLTEXTCATALOGPROPERTY(?, 'ItemCount'),
                   FULLTEXTCATALOGPROPERTY(?, 'PopulateStatus')
        \"\"\", FT_CATALOG, FT_CATALOG)
        items, pop = cur.fetchone()
        pop_txt = {0:"idle (done)",1:"full population",2:"paused",
                   3:"throttled",4:"incremental",5:"building index",
                   6:"disk full",7:"change tracking"}.get(pop, str(pop))
        print(f"📊 Catalog '{FT_CATALOG}': {items} indexed item(s), status = {pop_txt}.")

        # 6) Verify with a CONTAINS query against the base full-text indexed table
        try:
            cur.execute(\"\"\"
                SELECT TOP 3 p.title, s.heading
                FROM dbo.sections s
                JOIN dbo.pages p ON p.page_id = s.page_id
                WHERE CONTAINS((s.body_text, s.heading), 'neuroendocrine')
            \"\"\")
            hits = cur.fetchall()
            print(f"🔎 CONTAINS test returned {len(hits)} row(s).",
                  "(0 is fine if your corpus has no matching term.)")
        except Exception as e:
            print("… CONTAINS test skipped:", str(e).splitlines()[0][:120])

cn.close()
""")

# ===========================================================================
# STEP 8 — SEARCH SANITY CHECK
# ===========================================================================
md(r"""
## Step 8 — Quick search sanity check

Confirm the index works by running the crawler's own search CLI. Change the
query to anything in your corpus.

**Expected outcome:** printed hits and `✅ done (search.py)`.

Notes:
- `0 hit(s)` can still be healthy if the query term is not present.
- Output is UTF-8 normalized and snippet text is cleaned to remove common site-chrome noise.
""")
code(r"""
QUERY = "neuroendocrine"
rc = run_script("search.py", "--config", "config.json", QUERY, "--limit", "10")
""")

md(r"""
### What next?

Choose your next path:

- Need more corpus data? Set `BOOKS` in **Step 4**, run it, then re-run **Step 5**.
- Need SQL Server analytics/search? Follow **7·0 → 7a → 7a·clean → 7b → 7c**.
- Need query exploration/cross-walks? Open **`BlueBooks_Explorer.ipynb`** and point it at `bluebooks.db` (or SQL Server).
- Need troubleshooting context from this session?
    - `SESSION_FIX_LOG_2026-07-21.md`
    - `SQLSERVER_CONNECTION_VARIANTS.md`

Always keep `auth_state.json` and `bluebooks.db` **private** (session + licensed content).
""")

# ---------------------------------------------------------------------------
nb["cells"] = cells
nb["metadata"] = {
    "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
    "language_info": {"name": "python"},
}
from pathlib import Path
from notebook_local import backup_notebook, upgrade_runner
target = Path(__file__).with_name("Crawler_Runner.ipynb")
# Existing cells include local fixes and settings not represented in older generator text.
if target.exists():
    nb = nbf.read(target, as_version=4)
nb = upgrade_runner(nb)
backup_notebook(target)
nbf.write(nb, target)
print(f"Wrote Crawler_Runner.ipynb with {len(cells)} cells "
      f"({sum(1 for c in cells if c.cell_type=='markdown')} markdown, "
      f"{sum(1 for c in cells if c.cell_type=='code')} code).")
