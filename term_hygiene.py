"""Term-only hygiene and indexed display/comparison keys for both databases."""
from __future__ import annotations

from functools import lru_cache
import re
import sqlite3

from clean_term2 import _CHAR_REPLACEMENTS, _truncate_nvarchar4000, clean2

TERM_SOURCES = {
    "entity_codes": ("entity_code_id", "term"),
    "entity_related_terms": ("related_term_id", "term"),
    "page_icdo_codes": ("code_id", "term_in_coding_section"),
    "page_term_mentions": ("mention_id", "term_original"),
    "page_entity_evidence": ("evidence_id", "term_clean"),
}
TERM_COLUMNS = ("TermUS", "TermNormUS")
DISPLAY_COLUMNS = {
    "entity_identifiers": ("identifier_id", ("term",)),
    "entity_term_provenance": ("provenance_id", ("recovered_term",)),
    "entity_term_code_matches": ("match_id", ("official_term",)),
    "icdo4_morphology": ("row_id", ("term", "term_clean")),
    "cpc_morph_codes": ("row_id", ("term", "term_norm", "term_clean")),
    "icdo_site_specific_terms": (
        "term_id", ("icdo_term", "term_normalized", "term_clean", "preferred_term"),
    ),
}
_SPELLINGS = (
    ("naev", "nev"), ("grey", "gray"), ("oesophag", "esophag"),
    ("oestr", "estr"), ("foet", "fet"), ("coeli", "celi"),
    ("oedema", "edema"), ("apnoea", "apnea"), ("dyspnoea", "dyspnea"),
    ("rhoe", "rhe"), ("gynaec", "gynec"), ("caec", "cec"),
    ("faec", "fec"), ("melaen", "melen"), ("orthopaed", "orthoped"),
    ("paed", "ped"), ("aem", "em"), ("paen", "pen"),
    ("umour", "umor"), ("centre", "center"), ("phaeo", "pheo"),
    ("goitre", "goiter"), ("mould", "mold"), ("fibre", "fiber"),
    ("sulph", "sulf"), ("ischaem", "ischem"), ("anaesth", "anesth"),
    ("catalogu", "catalog"), ("morphoe", "morphe"), ("metre", "meter"),
    ("colour", "color"), ("haviour", "havior"),
)
BRITISH_REPLACEMENTS = tuple(_CHAR_REPLACEMENTS.items()) + tuple(
    pair
    for before, after in _SPELLINGS
    for pair in ((before, after), (before.capitalize(), after.capitalize()),
                 (before.upper(), after.upper()))
)
_FOOTNOTE_TAIL = re.compile(r"[\s\u2020\u2021\u00a7\u00b6*.;:]+$")
_BULLET = re.compile(r"^\s*(?:\*\s+|\u2022\s*)")


@lru_cache(maxsize=32768)
def clean_term_ending(value: str | None) -> str | None:
    """Remove term-list decoration, not scientific signs or numeric scripts."""
    if value is None:
        return None
    text = _FOOTNOTE_TAIL.sub("", value.strip())
    text = re.split(r"\s*\[\[", text, maxsplit=1)[0]
    text = re.sub(r"\s*\(\s*see(?=\s|[.:,;)]|$).*$", "", text, flags=re.I | re.S)
    text = re.sub(r"\s*<<\s*see(?=\s|[.:,;>]|$).*?>>\s*$", "", text, flags=re.I | re.S)
    return _FOOTNOTE_TAIL.sub("", _BULLET.sub("", text.strip())).strip()


def upper_initial(value: str | None) -> str | None:
    """Change only an initial ASCII lowercase character, not scientific symbols."""
    if value and "a" <= value[0] <= "z":
        return value[0].upper() + value[1:]
    return value


def clean_display_term(value: str | None) -> str | None:
    return upper_initial(clean_term_ending(value))


@lru_cache(maxsize=32768)
def clean_british_spelling2(value: str | None) -> str | None:
    """Exact case-sensitive port of dbo.CleanBritishSpelling2, not dbo.Clean."""
    if value is None:
        return None
    value = _truncate_nvarchar4000(value)
    for before, after in BRITISH_REPLACEMENTS:
        value = value.replace(before, after)
    return re.sub(" +", " ", value.replace("\x07", "")).strip(" ")


def term_keys(value: str | None) -> tuple[str | None, str | None]:
    if value is not None and len(value.encode("utf-16-le")) > 8000:
        raise ValueError("Term exceeds the normalizers' 4000 UTF-16-unit input limit")
    us = upper_initial(clean_british_spelling2(clean_display_term(value)))
    norm = upper_initial(clean2(us))
    if any(text is not None and len(text.encode("utf-16-le")) > 1200
           for text in (us, norm)):
        raise ValueError("TermUS/TermNormUS exceeds the indexed 600 UTF-16-unit limit")
    return us, norm


def register_sqlite(con: sqlite3.Connection) -> None:
    con.create_function("CleanTermEnding", 1, clean_term_ending, deterministic=True)
    con.create_function("UpperInitial", 1, upper_initial, deterministic=True)
    con.create_function("CleanDisplayTerm", 1, clean_display_term, deterministic=True)
    con.create_function("CleanBritishSpelling2", 1, clean_british_spelling2, deterministic=True)
    con.create_function("Clean2", 1, clean2, deterministic=True)
    con.create_function("TermUSValue", 1, lambda value: term_keys(value)[0], deterministic=True)
    con.create_function("TermNormValue", 1, lambda value: term_keys(value)[1], deterministic=True)


def assignments(table: str, prefix: str, *, sqlserver: bool = False) -> dict[str, str]:
    source = TERM_SOURCES[table][1]
    fn = "dbo." if sqlserver else ""
    ref = lambda col: f"{prefix}[{col}]"
    result = {source: f"{fn}CleanDisplayTerm({ref(source)})"}
    if table == "page_term_mentions":
        for col in ("term_text", "matched_term_original"):
            result[col] = f"{fn}CleanDisplayTerm({ref(col)})"
        for col, raw in (("term_original_norm", "term_original"),
                         ("term_clean", "term_text"),
                         ("matched_term_norm", "matched_term_original")):
            result[col] = f"{fn}UpperInitial({fn}Clean({fn}CleanDisplayTerm({ref(raw)})))"
    if sqlserver:
        us = f"dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm({ref(source)})))"
        result["TermUS"] = us
        result["TermNormUS"] = f"dbo.UpperInitial(dbo.Clean2({us}))"
    else:
        result["TermUS"] = f"TermUSValue({ref(source)})"
        result["TermNormUS"] = f"TermNormValue({ref(source)})"
    return result


def ensure_sqlite(con: sqlite3.Connection) -> None:
    register_sqlite(con)
    matches_cols = {row[1] for row in con.execute("PRAGMA table_info(entity_term_code_matches)")}
    if "official_termUS" not in matches_cols:
        con.execute("ALTER TABLE entity_term_code_matches ADD COLUMN official_termUS TEXT")
    con.execute("CREATE INDEX IF NOT EXISTS ix_entity_term_code_matches_official_termUS "
                "ON entity_term_code_matches(official_termUS)")
    con.execute("UPDATE entity_term_code_matches SET official_termUS=UpperInitial("
                "CleanBritishSpelling2(official_term)) WHERE official_termUS IS NOT "
                "UpperInitial(CleanBritishSpelling2(official_term))")
    if "official_termNormUS" not in matches_cols:
        con.execute("ALTER TABLE entity_term_code_matches ADD COLUMN official_termNormUS TEXT")
    con.execute("CREATE INDEX IF NOT EXISTS ix_entity_term_code_matches_official_termNormUS "
                "ON entity_term_code_matches(official_termNormUS)")
    con.execute("UPDATE entity_term_code_matches SET official_termNormUS=UpperInitial("
                "Clean2(official_termUS)) WHERE official_termUS IS NOT NULL AND official_termNormUS IS NOT "
                "UpperInitial(Clean2(official_termUS))")

    prov_cols = {row[1] for row in con.execute("PRAGMA table_info(entity_term_provenance)")}
    for col in ("TermUS", "TermNormUS"):
        if col not in prov_cols:
            con.execute(f'ALTER TABLE entity_term_provenance ADD COLUMN "{col}" TEXT')
        con.execute(f'CREATE INDEX IF NOT EXISTS "ix_entity_term_provenance_{col}" ON entity_term_provenance("{col}")')
    con.execute("UPDATE entity_term_provenance SET TermUS=TermUSValue(recovered_term), "
                "TermNormUS=TermNormValue(recovered_term) WHERE recovered_term IS NOT NULL "
                "AND (TermUS IS NULL OR TermNormUS IS NULL)")

    for view in ("v_page_code_terms", "v_entity_term_code_matches", "v_entity_term_provenance", "v_entity_terms"):
        con.execute(f'DROP VIEW IF EXISTS "{view}"')

    for table, (pk, _) in TERM_SOURCES.items():
        existing = {row[1] for row in con.execute(f'PRAGMA table_info("{table}")')}
        if "TermNorm" in existing and "TermNormUS" not in existing:
            con.execute(f'ALTER TABLE "{table}" RENAME COLUMN "TermNorm" TO "TermNormUS"')
            existing.remove("TermNorm")
            existing.add("TermNormUS")
        for col in TERM_COLUMNS:
            if col not in existing:
                con.execute(f'ALTER TABLE "{table}" ADD COLUMN "{col}" TEXT')
            con.execute(f'CREATE INDEX IF NOT EXISTS "ix_{table}_{col}" ON "{table}"("{col}")')
        values = assignments(table, "NEW.")
        changed = " OR ".join(f'NEW.[{col}] IS NOT {expr}' for col, expr in values.items())
        update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
        for event in ("INSERT", "UPDATE"):
            name = f"tr_term_hygiene_{table}_{event.lower()}"
            con.execute(f'DROP TRIGGER IF EXISTS "{name}"')
            con.execute(
                f'CREATE TRIGGER "{name}" AFTER {event} ON "{table}" '
                f"WHEN {changed} BEGIN UPDATE [{table}] SET {update} "
                f"WHERE [{pk}]=NEW.[{pk}]; END"
            )
    for table, (pk, cols) in DISPLAY_COLUMNS.items():
        values = display_assignments(table, "NEW.")
        changed = " OR ".join(f'NEW.[{col}] IS NOT {expr}' for col, expr in values.items())
        update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
        for event in ("INSERT", "UPDATE"):
            name = f"tr_term_display_{table}_{event.lower()}"
            con.execute(f'DROP TRIGGER IF EXISTS "{name}"')
            con.execute(
                f'CREATE TRIGGER "{name}" AFTER {event} ON "{table}" '
                f"WHEN {changed} BEGIN UPDATE [{table}] SET {update} WHERE [{pk}]=NEW.[{pk}]; END"
            )


def refresh_terms(con: sqlite3.Connection) -> dict[str, int]:
    """In-place migration: retain IDs, codes, policies, snippets and source prose."""
    report = {}
    for table in TERM_SOURCES:
        values = assignments(table, "")
        changed = " OR ".join(f'[{col}] IS NOT {expr}' for col, expr in values.items())
        update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
        report[table] = con.execute(f"UPDATE [{table}] SET {update} WHERE {changed}").rowcount
    for table in DISPLAY_COLUMNS:
        values = display_assignments(table, "")
        changed = " OR ".join(f'[{col}] IS NOT {expr}' for col, expr in values.items())
        update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
        report[table] = con.execute(f"UPDATE [{table}] SET {update} WHERE {changed}").rowcount
    return report


def validate_terms(con: sqlite3.Connection) -> dict[str, int]:
    report = {}
    for table in TERM_SOURCES:
        values = assignments(table, "")
        changed = " OR ".join(f'[{col}] IS NOT {expr}' for col, expr in values.items())
        count = con.execute(f"SELECT COUNT(*) FROM [{table}] WHERE {changed}").fetchone()[0]
        if count:
            raise ValueError(f"Term hygiene/key mismatch in {table}: {count} rows")
        report[table] = count
    for table in DISPLAY_COLUMNS:
        values = display_assignments(table, "")
        changed = " OR ".join(f'[{col}] IS NOT {expr}' for col, expr in values.items())
        count = con.execute(f"SELECT COUNT(*) FROM [{table}] WHERE {changed}").fetchone()[0]
        if count:
            raise ValueError(f"Initial term case mismatch in {table}: {count} rows")
        report[table] = count
    return report


def normalizer_sql() -> str:
    def literal(text: str) -> str:
        if len(text) == 1 and (ord(text) > 127 or ord(text) < 32):
            return f"NCHAR({ord(text)})"
        return "N'" + text.replace("'", "''") + "'"

    whitespace = (
        "(9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,"
        "8200,8201,8202,8232,8233,8239,8287,12288)"
    )
    trim_tail = (
        " WHILE DATALENGTH(@s)>0 AND UNICODE(RIGHT(@s,1)) IN "
        "(9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,"
        "8200,8201,8202,8232,8233,8239,8287,12288,8224,8225,167,182,42,46,59,58)\n"
        "  SET @s=LEFT(@s,DATALENGTH(@s)/2-1);\n"
    )
    statements = [
        "SET ANSI_NULLS ON\nGO\nSET QUOTED_IDENTIFIER ON\nGO",
        # Remove old schema binding before replacing the wrapper's dependencies.
        "IF OBJECT_ID('dbo.CleanDisplayTerm','FN') IS NOT NULL\n"
        " EXEC(N'CREATE OR ALTER FUNCTION dbo.CleanDisplayTerm(@s NVARCHAR(4000)) "
        "RETURNS NVARCHAR(4000) AS BEGIN "
        "RETURN dbo.UpperInitial(dbo.CleanTermEnding(@s)); END');\nGO",
        "CREATE OR ALTER FUNCTION dbo.CleanBritishSpelling2(@StringIn NVARCHAR(4000))\n"
        "RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS\nBEGIN\n"
        " DECLARE @s NVARCHAR(4000)=@StringIn;",
    ]
    statements.extend(
        f" SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,{literal(before)},{literal(after)});"
        for before, after in BRITISH_REPLACEMENTS
    )
    statements.extend([
        " SET @s=REPLACE(@s,NCHAR(7),N'');",
        " SET @s=REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2,"
        "N' ',N' '+NCHAR(7)),NCHAR(7)+N' ',N''),NCHAR(7),N'');",
        " RETURN TRIM(@s);\nEND\nGO",
        "CREATE OR ALTER FUNCTION dbo.CleanTermEnding(@value NVARCHAR(4000))\n"
        "RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS\nBEGIN\n"
        " DECLARE @s NVARCHAR(4000)=@value;\n"
        + trim_tail +
        " IF CHARINDEX(N'[[',@s COLLATE Latin1_General_100_BIN2)>0\n"
        "  SET @s=LEFT(@s,CHARINDEX(N'[[',@s COLLATE Latin1_General_100_BIN2)-1);\n"
        " DECLARE @pos INT=CHARINDEX(N'(',@s), @start INT;\n"
        " WHILE @pos>0\n BEGIN\n"
        "  SET @start=@pos+1;\n"
        f"  WHILE UNICODE(SUBSTRING(@s,@start,1)) IN {whitespace} SET @start=@start+1;\n"
        "  IF LOWER(SUBSTRING(@s,@start,3)) COLLATE Latin1_General_100_BIN2=N'see'\n"
        f"   AND (SUBSTRING(@s,@start+3,1)=N'' OR UNICODE(SUBSTRING(@s,@start+3,1)) IN {whitespace}"
        " OR SUBSTRING(@s,@start+3,1) IN (N'.',N':',N',',N';',N')'))\n"
        "  BEGIN SET @s=LEFT(@s,@pos-1); BREAK; END;\n"
        "  SET @pos=CHARINDEX(N'(',@s,@pos+1);\n END;\n"
        " DECLARE @tail INT=DATALENGTH(@s)/2;\n"
        f" WHILE UNICODE(SUBSTRING(@s,@tail,1)) IN {whitespace} SET @tail=@tail-1;\n"
        " IF SUBSTRING(@s,@tail-1,2)=N'>>'\n BEGIN\n"
        "  SET @pos=CHARINDEX(N'<<',@s);\n"
        "  WHILE @pos>0\n  BEGIN\n"
        "   SET @start=@pos+2;\n"
        f"   WHILE UNICODE(SUBSTRING(@s,@start,1)) IN {whitespace} SET @start=@start+1;\n"
        "   IF LOWER(SUBSTRING(@s,@start,3)) COLLATE Latin1_General_100_BIN2=N'see'\n"
        f"    AND (SUBSTRING(@s,@start+3,1)=N'' OR UNICODE(SUBSTRING(@s,@start+3,1)) IN {whitespace}"
        " OR SUBSTRING(@s,@start+3,1) IN (N'.',N':',N',',N';',N'>'))\n"
        "   BEGIN SET @s=LEFT(@s,@pos-1); BREAK; END;\n"
        "   SET @pos=CHARINDEX(N'<<',@s,@pos+1);\n  END;\n END;\n"
        " WHILE LEN(@s)>0 AND UNICODE(LEFT(@s,1)) IN "
        "(9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,"
        "8200,8201,8202,8232,8233,8239,8287,12288)\n"
        "  SET @s=SUBSTRING(@s,2,4000);\n"
        " IF LEFT(@s,1)=N'*' AND UNICODE(SUBSTRING(@s,2,1)) IN "
        "(9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,"
        "8200,8201,8202,8232,8233,8239,8287,12288) SET @s=SUBSTRING(@s,2,4000);\n"
        " IF UNICODE(LEFT(@s,1))=8226 SET @s=SUBSTRING(@s,2,4000);\n"
        " WHILE LEN(@s)>0 AND UNICODE(LEFT(@s,1)) IN "
        "(9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,"
        "8200,8201,8202,8232,8233,8239,8287,12288) SET @s=SUBSTRING(@s,2,4000);\n"
        + trim_tail +
        " RETURN TRIM(@s);\nEND\nGO",
    ])
    statements += [
        "CREATE OR ALTER FUNCTION dbo.UpperInitial(@s NVARCHAR(4000))\n"
        "RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS\nBEGIN\n"
        " RETURN CASE WHEN UNICODE(LEFT(@s,1)) BETWEEN 97 AND 122 "
        "THEN NCHAR(UNICODE(LEFT(@s,1))-32)+SUBSTRING(@s,2,4000) ELSE @s END;\nEND\nGO",
        "CREATE OR ALTER FUNCTION dbo.CleanDisplayTerm(@s NVARCHAR(4000))\n"
        "RETURNS NVARCHAR(4000) AS\nBEGIN\n"
        " RETURN dbo.UpperInitial(dbo.CleanTermEnding(@s));\nEND\nGO",
    ]
    return "\n".join(statements) + "\n"


def server_display_trigger_sql(table: str) -> str:
    pk, cols = DISPLAY_COLUMNS[table]
    values = display_assignments(table, "i.", sqlserver=True)
    update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
    limits = " OR ".join(f"DATALENGTH(i.[{col}])>8000" for col in cols)
    return (
        f"CREATE OR ALTER TRIGGER dbo.[tr_term_display_{table}] ON dbo.[{table}] "
        "AFTER INSERT, UPDATE AS\nBEGIN\n SET NOCOUNT ON;\n"
        f" IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_{table}'))>1 RETURN;\n"
        f" IF EXISTS(SELECT 1 FROM inserted i WHERE {limits})\n"
        "  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;\n"
        f" UPDATE t SET {update} FROM dbo.[{table}] t JOIN inserted i "
        f"ON t.[{pk}]=i.[{pk}];\nEND"
    )


def display_assignments(table: str, prefix: str, *, sqlserver: bool = False) -> dict[str, str]:
    fn = "dbo." if sqlserver else ""
    values = {col: f"{fn}UpperInitial({prefix}[{col}])" for col in DISPLAY_COLUMNS[table][1]}
    if table == "entity_term_code_matches":
        values["official_termUS"] = (
            f"{fn}UpperInitial({fn}CleanBritishSpelling2({prefix}[official_term]))"
        )
        values["official_termNormUS"] = (
            f"{fn}UpperInitial({fn}Clean2({values['official_termUS']}))"
        )
    return values


def server_trigger_sql(table: str) -> str:
    pk, source = TERM_SOURCES[table]
    values = assignments(table, "i.", sqlserver=True)
    update = ", ".join(f'[{col}]={expr}' for col, expr in values.items())
    us = values["TermUS"]
    norm = values["TermNormUS"]
    return (
        f"CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_{table}] ON dbo.[{table}] "
        "AFTER INSERT, UPDATE AS\nBEGIN\n SET NOCOUNT ON;\n"
        f" IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_{table}'))>1 RETURN;\n"
        f" IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[{source}])>8000 "
        f"OR DATALENGTH({us})>1200 OR DATALENGTH({norm})>1200)\n"
        "  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;\n"
        f" UPDATE t SET {update} FROM dbo.[{table}] t JOIN inserted i "
        f"ON t.[{pk}]=i.[{pk}];\nEND"
    )
