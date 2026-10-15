# Getting started

This guide prepares a local BBCrawler workspace and gets you to the notebook
task that fits your goal. For the three common workflows, see
[Everyday use](everyday-use.md).

## What you need

- This repository opened in VS Code with the Python and Jupyter extensions.
- A supported Python installation compatible with the dependency lists under
  `requirements\`.
- The project’s expected neighboring `BBNotebook` helper modules and local
  reference files. The repository’s `Library` link must resolve to the local
  reference collection; a sibling `CancerPathCHART` reference folder is also
  used by some matching operations. Neither local reference material nor those
  companion folders are distributed as part of a self-contained installation.
- For website collection only: a browser that can open on your computer and
  authorized BlueBooksOnline access. SQL Server is optional; local database
  processing can use SQLite.

## Set up the workspace

1. Open the repository root in VS Code. Keep the root `config.json`,
   `auth_state.json`, and `bluebooks.db` in place if they already exist; they
   are active local files, not example files.
2. Select a Python interpreter that is compatible with the project’s declared
   dependencies. Install the relevant dependency list for your task:

   ```powershell
   python -m pip install -r requirements\requirements-local.txt
   ```

   Website collection also needs the crawler requirements:

   ```powershell
   python -m pip install -r requirements\requirements-crawler.txt
   python -m playwright install chromium
   ```

   Use the same Python environment for the notebook kernel and terminal
   commands. If setup reports a missing package or executable, see
   [Troubleshooting](troubleshooting.md).
3. If this is a new workspace with no root `config.json`, copy the safe example:

   ```powershell
   Copy-Item config\config.example.json config.json
   ```

   Do not overwrite existing settings. Open your local `config.json` and check
   `db_path` and `auth_state_path`. Relative file paths are interpreted beside
   that settings file, not beside a script. The example keeps both at the root.
   An existing database is needed to inspect or refresh saved pages; collecting
   for the first time creates one through discovery.

4. Open [`Crawler_Runner.ipynb`](../Crawler_Runner.ipynb) and select that same
   Python environment as the kernel.
5. Run section 1 to open the workspace. Then choose section 2 to inspect saved
   results, section 3 to refresh, section 4 to collect, or section 5 to copy to
   SQL Server. Do not use "Run All": each task has its own prerequisites.
   Start with a small collection
   if you are learning the workflow; do not replace a useful local database
   until you have checked the selected settings and backup behavior.

## Choose a workflow

- **Collect new pages:** Use the notebook’s website collection path. Login and
  browser steps run locally on your computer and require authorized access.
- **Refresh from pages already saved locally:** You can skip login, discovery,
  and crawling. From the repository root, run:

  ```powershell
  python app\bluebooks_local.py --sqlite bluebooks.db
  ```

  The refresh needs the expected local reference and companion inputs. Missing
  or changed inputs may stop the build so the saved database is not silently
  replaced with incomplete results.
- **Inspect or search existing results:** Use the inspection/search workflow
  described in [Everyday use](everyday-use.md#inspect-and-search-results).

For a SQL Server mirror, first configure and validate the optional SQL Server
environment; see [Troubleshooting](troubleshooting.md#sql-server-connection).

## Keep private files private

`config.json` and `auth_state.json` can contain local settings or login state;
the database and local reference files can contain protected material. Do not
publish them, add them to commits, or replace them with files from another
workspace without checking their provenance.
