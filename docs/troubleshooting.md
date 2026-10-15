# Troubleshooting

Use this guide to resolve setup and workflow problems without risking saved
data. Start with the task-specific steps in [Everyday use](everyday-use.md).
Keep the complete error message, the task you were running, and the selected
Python environment when reporting a problem; remove credentials and private
source text first.

## Notebook cannot find project files

- Open the repository root, not just the notebook file, as the VS Code
  workspace.
- Confirm that the expected `BBNotebook` companion modules are available next
  to the repository and that the repository's `Library` link resolves to its
  local reference collection. Some terminology matching also needs the
  neighboring `CancerPathCHART` reference folder.
- Run commands from the repository root. The local refresh entry command is
  `python app\bluebooks_local.py --sqlite bluebooks.db`.
- Keep the live root `config.json`, `auth_state.json`, and `bluebooks.db` at
  their existing paths. `config\config.example.json` is an example, not a
  replacement for live settings.

If a reference file is missing, verify the local folder and filename against
the expected input. Do not silently use a different edition or an older
workbook. A refresh can stop when required inputs are absent or their recorded
identity no longer matches.

## Import or package errors

The notebook kernel and terminal may be using different Python installations.
Select the project environment in the notebook kernel picker and use the same
environment to install dependencies from `requirements\requirements-local.txt`
or, for website collection, `requirements\requirements-crawler.txt`.

If Playwright reports that Chromium is unavailable, install it using the
project's Python environment:

```powershell
python -m playwright install chromium
```

Do not assume a successful `pip install` also installed a Windows system ODBC
driver; that driver is separate and is needed only for the optional SQL Server
workflow.

## Login or website collection fails

- Website login and collection must run on your own computer in a kernel that
  can open a browser. A headless or remote kernel cannot complete an
  interactive login.
- If the saved website session has expired, use the notebook's login task to
  sign in again, then retry or resume the collection as directed.
- Confirm that your account is authorized to access the selected material and
  that the target site is reachable.
- Do not edit, share, or commit `auth_state.json`.

## SQLite refresh or search problem

- Close other applications or notebook kernels that are actively writing to
  `bluebooks.db`, then retry the normal refresh command.
- Never delete `bluebooks.db-wal`, `bluebooks.db-shm`, or other SQLite
  journal/sidecar files manually. Close the database cleanly instead.
- If refresh fails on an input or provenance check, resolve the local reference
  or saved-source discrepancy before refreshing. Do not work around it by
  dropping tables or replacing the database.
- If a search returns unexpected results after changing saved pages, rerun the
  full local refresh so derived documents and the SQLite search index are
  current.

## SQL Server connection

SQL Server is optional. A connection needs both the Python `pyodbc` package and
a separately installed Microsoft ODBC Driver 17 or 18 for SQL Server.

For a local instance, use the exact server/instance name that works in your
environment; common local names include `(local)`, `localhost`, `.`, or a
named instance such as `.\SQLEXPRESS`. Windows integrated authentication is
often the simplest local option. SQL login credentials must not be saved in
the repository or pasted into reports.

Common errors:

| Message or symptom | Check |
|---|---|
| Server not found or login timeout | Server/instance spelling, SQL Server service state, network access, and firewall |
| Driver not found | Install the Windows ODBC Driver 17 or 18; installing `pyodbc` alone is not enough |
| Login failed | Authentication mode, account permissions, and the selected database |
| Works in a database client but not the notebook | Python environment, Windows account context, driver architecture, and server name |
| Search is not ready after a mirror | SQL Server full-text population is asynchronous; allow the notebook's readiness check to finish |

For an unexpected failure, preserve the original database and local inputs,
then report the error through the repository's agreed support channel. See
[Maintaining the project](technical/maintaining-the-project.md) and
[the issue backlog](../issues/README.md).
