# SQL Server Connection and Account Variants for BlueBooks Notebook

This note summarizes the SQL Server naming and authentication variants used when running Step 7 in the notebook workflow.

## 1. Server name variants (SQL_SERVER)

These values usually point to the local machine, but they may target different SQL Server instances.

- `localhost`: Local machine hostname.
- `(local)`: SQL Server alias for local machine.
- `.`: SQL Server shorthand for local machine.
- `local`: Sometimes resolves, but less reliable than `localhost`, `(local)`, or `.`.
- `MACHINE_NAME`: Explicit Windows computer name.

If you use a named instance, include it with a backslash:

- `.\\SQLEXPRESS`
- `localhost\\SQLEXPRESS`
- `MACHINE_NAME\\SQLEXPRESS`

## 2. Local alias and server names

`(local)` is a SQL Server alias for the local machine. In your setup, it resolves to the BlueBooks SQL Server you actually use.

Common local targets:

- `(local)`
- `MACHINE_NAME`
- `localhost`
- `.`

Notes:

- Use the exact target that connects in your environment.
- `MACHINE_NAME` may work directly as the server name even when `(local)` is the alias you prefer to use.

## 3. Authentication variants

### Windows Integrated Authentication (recommended for local dev)

Uses your current Windows identity.

Example connection string:

```text
Driver={ODBC Driver 18 for SQL Server};Server=SERVER_OR_INSTANCE;Database=BlueBooks;Trusted_Connection=Yes;Encrypt=Yes;TrustServerCertificate=Yes
```

Benefits:

- No SQL username/password in notebook settings.
- Usually simplest local setup.

### SQL Server Authentication (SQL login)

Uses SQL Server username/password.

Example connection string:

```text
Driver={ODBC Driver 18 for SQL Server};Server=SERVER_OR_INSTANCE;Database=BlueBooks;UID=SQL_USER;PWD=SQL_PASSWORD;Encrypt=Yes;TrustServerCertificate=Yes
```

Benefits:

- Works when Windows auth is not available.
- Useful for cross-machine access patterns.

Caution:

- Do not commit SQL credentials to source control.

## 4. Python package vs system ODBC driver

Both are required for Step 7 SQL loading:

- Python package: `pyodbc`
- Windows system driver: Microsoft ODBC Driver 17 or 18 for SQL Server

If `pyodbc` is installed but no ODBC driver is installed, database connections will still fail.

## 5. Quick checks

### Check installed ODBC drivers from Python

```python
import pyodbc
print(pyodbc.drivers())
```

You should see one of:

- `ODBC Driver 18 for SQL Server`
- `ODBC Driver 17 for SQL Server`

### Minimal connection smoke test

Use the same `Server` and authentication style you plan to use in Step 7, then run a simple `SELECT 1`.

## 6. Practical defaults for this project

1. Try Windows integrated auth first.
2. Prefer these server values in this order:
  - `(local)`
  - `MACHINE_NAME`
  - `localhost`
  - `.`
3. Keep `Encrypt=Yes;TrustServerCertificate=Yes` for local self-signed scenarios.

## 7. Common failure patterns

- `server not found` or login timeout:
  - Wrong instance name, SQL service not running, or firewall/network issue.
- `data source name not found` or `driver not found`:
  - ODBC Driver 17/18 is missing from Windows.
- `login failed for user`:
  - Wrong authentication mode, wrong credentials, or missing permissions.
- Works in SSMS but not notebook:
  - Different account context, different server string, or different environment.
