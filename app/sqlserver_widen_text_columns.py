import argparse
import sqlite3
from pathlib import Path

import pyodbc

COPY_ORDER = [
    "books",
    "chapters",
    "page_groups",
    "pages",
    "sections",
    "authors",
    "images",
    "page_links",
    "references",
    "crawl_queue",
    "crawl_runs",
]


def pick_driver(explicit_driver: str) -> str:
    installed = [d.strip() for d in pyodbc.drivers()]
    if explicit_driver:
        if explicit_driver in installed:
            return explicit_driver
        raise RuntimeError(f"Requested ODBC driver is not installed: {explicit_driver}")
    for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"):
        if d in installed:
            return d
    raise RuntimeError("No SQL Server ODBC Driver 18/17 found.")


def connect_sqlserver(server: str, database: str, trusted: bool, username: str, password: str, driver: str, encrypt: bool):
    parts = [
        f"DRIVER={{{driver}}}",
        f"SERVER={server}",
        f"DATABASE={database}",
        "Connection Timeout=15",
        "TrustServerCertificate=yes",
        "Encrypt=yes" if encrypt else "Encrypt=no",
    ]
    if trusted:
        parts.append("Trusted_Connection=yes")
    else:
        parts.append(f"UID={username};PWD={password}")

    return pyodbc.connect(";".join(parts), autocommit=False)


def qident(name: str) -> str:
    return '"' + str(name).replace('"', '""') + '"'


def sqlite_columns(scon: sqlite3.Connection, table: str):
    return [r[1] for r in scon.execute(f"PRAGMA table_info({qident(table)})")]


def sqlite_max_text_lengths_one_pass(scon: sqlite3.Connection, table: str, cols: list[str]) -> dict[str, int]:
    if not cols:
        return {}
    exprs = ", ".join(
        f"MAX(LENGTH(CAST({qident(c)} AS TEXT))) AS {qident(c)}" for c in cols
    )
    row = scon.execute(f"SELECT {exprs} FROM {qident(table)}").fetchone()
    if row is None:
        return {c: 0 for c in cols}
    return {c: int((row[i] or 0)) for i, c in enumerate(cols)}


def mssql_text_metadata(cur, table: str) -> dict[str, dict]:
    cur.execute(
        """
        SELECT c.name, ty.name, c.max_length, c.is_nullable, c.collation_name
        FROM sys.columns c
        JOIN sys.tables t ON t.object_id = c.object_id
        JOIN sys.types ty ON ty.user_type_id = c.user_type_id
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        WHERE s.name = 'dbo' AND t.name = ? AND c.is_computed = 0
        """,
        table,
    )
    out = {}
    for col_name, type_name, max_len_bytes, is_nullable, collation_name in cur.fetchall():
        t = str(type_name).lower()
        if t in ("nvarchar", "nchar", "varchar", "char"):
            out[col_name] = {
                "type_name": t,
                "max_len_bytes": int(max_len_bytes),
                "is_nullable": bool(is_nullable),
                "collation_name": collation_name,
            }
    return out


def current_char_limit(meta: dict):
    b = meta["max_len_bytes"]
    if b == -1:
        return None
    if meta["type_name"] in ("nvarchar", "nchar"):
        return b // 2
    return b


def target_decl(meta: dict, use_max_types: bool, needed_chars: int) -> str | None:
    t = meta["type_name"]
    if t in ("nvarchar", "nchar"):
        if use_max_types:
            return "nvarchar(max)"
        return f"nvarchar({max(1, min(needed_chars, 4000))})"
    if t in ("varchar", "char"):
        if use_max_types:
            return "varchar(max)"
        return f"varchar({max(1, min(needed_chars, 8000))})"
    return None


def widen_table(cur, table: str, src_max_lens: dict[str, int], use_max_types: bool) -> int:
    md = mssql_text_metadata(cur, table)
    if not md:
        return 0

    plans = []
    for col, needed in src_max_lens.items():
        meta = md.get(col)
        if not meta or needed <= 0:
            continue

        cur_limit = current_char_limit(meta)
        if cur_limit is None or needed <= cur_limit:
            continue

        decl = target_decl(meta, use_max_types, needed)
        if not decl:
            continue

        null_sql = "NULL" if meta["is_nullable"] else "NOT NULL"
        coll_sql = f" COLLATE {meta['collation_name']}" if meta.get("collation_name") else ""
        plans.append((col, decl, coll_sql, null_sql, cur_limit, needed))

    altered = 0
    for col, decl, coll_sql, null_sql, old_lim, needed in plans:
        cur.execute(f"ALTER TABLE dbo.[{table}] ALTER COLUMN [{col}] {decl}{coll_sql} {null_sql}")
        altered += 1
        print(f"ALTER dbo.{table}.{col}: {old_lim} -> {decl} (needed {needed})")

    return altered


def main():
    ap = argparse.ArgumentParser(description="Widen SQL Server text columns based on SQLite max lengths.")
    from project_paths import ROOT
    ap.add_argument("--sqlite", default=str(ROOT / "bluebooks.db"), help="Path to SQLite DB (default: project database)")
    ap.add_argument("--server", default="(local)")
    ap.add_argument("--database", default="BlueBooks")
    ap.add_argument("--trusted", action="store_true", default=True)
    ap.add_argument("--username", default="")
    ap.add_argument("--password", default="")
    ap.add_argument("--driver", default="")
    ap.add_argument("--encrypt", action="store_true", default=True)
    ap.add_argument("--precise-width", action="store_true", help="Use bounded widths instead of MAX types")
    args = ap.parse_args()

    sqlite_path = Path(args.sqlite)
    if not sqlite_path.exists():
        raise FileNotFoundError(f"SQLite DB not found: {sqlite_path}")

    driver = pick_driver(args.driver)
    print(f"Using ODBC driver: {driver}")

    scon = sqlite3.connect(sqlite_path)
    try:
        mcn = connect_sqlserver(
            server=args.server,
            database=args.database,
            trusted=args.trusted,
            username=args.username,
            password=args.password,
            driver=driver,
            encrypt=args.encrypt,
        )
    except Exception:
        scon.close()
        raise

    total_altered = 0
    try:
        cur = mcn.cursor()
        use_max_types = not args.precise_width

        for table in COPY_ORDER:
            try:
                scols = sqlite_columns(scon, table)
            except Exception:
                print(f"SKIP {table}: no SQLite table")
                continue

            sql_text_cols = set(mssql_text_metadata(cur, table).keys())
            if not sql_text_cols:
                print(f"OK   {table}: no SQL text columns to assess")
                continue

            candidate_cols = [c for c in scols if c in sql_text_cols]
            if not candidate_cols:
                print(f"OK   {table}: no shared text columns")
                continue

            src_max = sqlite_max_text_lengths_one_pass(scon, table, candidate_cols)
            altered = widen_table(cur, table, src_max, use_max_types=use_max_types)
            if altered:
                mcn.commit()
                total_altered += altered
                print(f"OK   {table}: altered {altered} column(s)")
            else:
                print(f"OK   {table}: no widening needed")

        print(f"\nDone. Total altered text columns: {total_altered}")
    except Exception:
        mcn.rollback()
        raise
    finally:
        mcn.close()
        scon.close()


if __name__ == "__main__":
    main()
