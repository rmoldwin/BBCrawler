"""Generate current table documentation and optional schema snapshots."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
import shutil
import bluebooks_local as local
import term_hygiene
import term_pipeline
import term_recovery
from project_paths import ROOT, SQL, COMPANION

SOURCES = {
    "books": "Saved volume inventory. alias is an editable short label; title and edition are retained independently.",
    "chapters": "Saved table-of-contents chapters.",
    "page_groups": "Saved nested table-of-contents groups.",
    "pages": "Saved page HTML, titles, subtitles, URLs and collection state. title_norm is a matching key; icdo_code_hint is subtitle-only.",
    "sections": "Saved sections and recovered section bodies. IDs and image/reference associations are preserved. Exceptions are recorded in private build information.",
    "authors": "Saved page authors and roles.",
    "images": "Saved figure metadata, captions and local paths; local refresh does not download images.",
    "page_links": "Saved page link labels and targets.",
    "references": "Saved citation text and PMID tokens.",
    "entity_pages": "Eligible entity pages parsed from saved HTML. Edition comes from the linked book; front matter is excluded.",
    "entity_codes": "Terms and codes printed in coding/subtype sections. Code formats are retained without conversion between editions. is_subtype is deprecated.",
    "entity_related_terms": "Acceptable, not recommended and other related terms, including explicitly attributed recovered names. Balanced scientific parentheses are preserved.",
    "entity_term_provenance": "Source links for recovered names, including original text and row identifiers. Saved manual review details survive rebuilds.",
    "entity_term_code_matches": "Legacy edition-specific proposals with official wording, workbook evidence and conditions; never source assignments.",
    "entity_identifiers": "OMIM/MIM identifiers and their section context; these are not morphology codes.",
    "cpc_curation": "Manual decisions. Refresh does not clear them; conflicting mirror changes require reconciliation.",
    "icdo4_morphology": "Morphology rows from the current local ICD-O-4 reference workbook. Annex loading is separate work.",
    "cpc_morph_codes": "Newest dated local CPC morphology-code CSV, with original labels and retirement information.",
    "icdo_site_specific_terms": "Terms from the local site-specific workbook, including screened and uncertain items.",
    "icdo_site_specific_term_sites": "One workbook term/site-code relationship per row.",
    "page_icdo_codes": "Codes found in saved section text, with any explicitly supported term and section context.",
    "page_term_mentions": "Observed titles, coding/related labels and known reference phrases, independent of whether a code was found. Context, origin and evidence identity are retained.",
    "term_saved_sections": "Saved section cache keyed by source hash and parser definition; raw HTML remains the source.",
    "term_reference_rows": "Edition, file hash, sheet, physical row and original/canonical reference labels. Earlier reference revisions remain identifiable.",
    "term_lookup_evaluations": "Edition-specific matching outcomes, linked to observations and reference/evidence revisions.",
    "term_code_candidates": "Proposed official mappings, wording, evidence tiers, conditions and supporting workbook rows.",
    "term_review_decisions": "Append-only scoped review decisions. Changed evidence can reopen review; previous decisions are not overwritten.",
    "term_pipeline_migrations": "One-time migration records; historical recovery is not replayed on every refresh.",
    "page_site_hints": "Supporting page-level site hints, not verified term-specific sites or patient assertions.",
    "page_entity_evidence": "Mention summary with positive/excluded counts and code evidence. Scores are not probabilities.",
    "page_search_documents": "One search document per page, combining saved/recovered prose without duplicated additions.",
    "enum_values": "Allowed values for controlled status, origin, role and review fields.",
}

VIEW_CONTRACT = """
## Terms and code suggestions

`v_page_code_terms` pairs ICDO32 and ICDO4 on the exact, case-sensitive
`page_id` and `TermUS`. There is no public `code_edition` column.
The row identity is `page_id`, `TermUS`, `ICDO32`, `ICDO4`,
`candidateTermUS32`, `candidateTermUS4`. When either edition has several
possibilities, every scalar combination is shown. This is not a code crosswalk.
Within an edition, a blank-code row is suppressed when a populated code exists.

Use the independent `32` and `4` fields for edition-specific interpretation:
`candidateTermUS32/4`, `is_proposed_code32/4`, `is_proposed_term32/4`,
`lookup_outcome32/4`, `match_type32/4`, `conditions32/4`, `review_status32/4`.
Shared `candidateTermUS` and `morphology_code` prefer ICD-O-4, falling back to
ICD-O-3.2. Shared proposal flags mean either edition; shared textual metadata
combines differing values. Neither field pairing nor reference matching proves
a diagnosis or approves an assignment.

`alias`, `book_name` (the full book title) and original `edition` are separate.
`terminology_kind` describes where a term came from: `coding`, `contextual`,
`acceptable`, `not_recommended`, or `other`. Multiple origins are joined with
`; `. This is not a statement of code validity or preferred wording.

`TermUS` provides US spelling. `TermNormUS` simplifies that display value for
matching through Clean2. Both are stored and indexed; neither is a unique term
identifier. Read-only connections need no custom normalization function.
Writes must use the shared connection helper so automatic maintenance works.

See [the data guide](data-guide.md) for interpretation and
[text matching](reference-matching.md) for matching rules and evidence limits.
"""


def export_deployed_clean2():
    """Explicitly snapshot the deployed function without altering SQL Server."""
    path = SQL / "00_dbo_Clean2.sql"
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    backup = ROOT / "local_backups"
    backup.mkdir(exist_ok=True)
    shutil.copy2(path, backup / f"Clean2-before-{stamp}.sql")
    with closing(local.connect_server()) as connection:
        definition = connection.cursor().execute(
            "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.Clean2'))").fetchone()[0]
        if not definition or "WITH SCHEMABINDING" not in definition:
            raise ValueError("Expected schema-bound dbo.Clean2 definition is unavailable")
    definition = definition.replace("CREATE FUNCTION", "CREATE OR ALTER FUNCTION", 1)
    path.write_text("SET ANSI_NULLS ON\nGO\nSET QUOTED_IDENTIFIER ON\nGO\n" +
                    definition + "\nGO\n", encoding="utf-8")


def table_reference(connection):
    doc = [
        "# Table and column reference", "",
        "This is the detailed map of stored data, generated from the local database.",
        "Start with [the data guide](data-guide.md) if you are choosing what to query.",
        "Required means a value must be present. Key identifies a row; lookup indexes",
        "make searches faster. PK means primary key. References connect related rows.", "",
        "The generator reads metadata only. It does not refresh or modify data.", "",
    ]
    for table in local.TABLES:
        info = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
        if not info:
            raise ValueError(f"Required table is absent: {table}")
        doc += [f"## `{table}`", "", SOURCES[table], "",
                "| Column | SQLite type | Required | Key / notes | Default |",
                "|---|---|---|---|---|"]
        for _, name, kind, required, default, pk in info:
            note = "Primary key" if pk else ""
            if name == "is_subtype":
                note = "Deprecated; use explicit source/relationship fields"
            doc.append(f"| `{name}` | {kind} | {'yes' if required or pk else 'no'} | {note} | {default or ''} |")
        doc.append("")
        for fk in connection.execute(f'PRAGMA foreign_key_list("{table}")'):
            doc.append(f"- `{fk[3]}` refers to `{fk[2]}.{fk[4]}`.")
        doc += ["", "Lookup indexes:", ""]
        for index in connection.execute(f'PRAGMA index_list("{table}")'):
            if index[3] == "pk":
                continue
            columns = [row[2] for row in connection.execute(f'PRAGMA index_info("{index[1]}")')]
            doc.append(f"- {'Unique ' if index[2] else ''}`{index[1]}`: " +
                       ", ".join(f"`{column}`" for column in columns))
        doc.append("")
    doc += [VIEW_CONTRACT, "## Database-specific storage", "",
            "SQL Server uses Unicode text, UTC timestamps and compatible numeric types.",
            "The mirror compares normalized values rather than database-specific representations.",
            "Search indexes and activity/collection logs are not mirrored as managed data.", ""]
    return "\n".join(doc)


def server_schema(connection):
    ddl = ["-- Generated managed data schema; activity and collection history excluded.",
           "-- For upgrades use bluebooks_local.ensure_server_schema.", ""]
    for table in local.TABLES:
        info = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
        keys = sorted((row for row in info if row[5]), key=lambda row: row[5])
        columns = [
            f"  [{name}] {local._server_type(name, kind, table)} " +
            ("NOT NULL" if required or pk else "NULL") + local.server_default(default)
            for _, name, kind, required, default, pk in info
        ]
        columns.append("  PRIMARY KEY (" + ",".join(f"[{row[1]}]" for row in keys) + ")")
        ddl += [f"IF OBJECT_ID('dbo.{table}','U') IS NULL",
                f"CREATE TABLE dbo.[{table}] (", ",\n".join(columns), ");", "GO"]
    for table in local.TABLES:
        for index in connection.execute(f'PRAGMA index_list("{table}")'):
            if index[3] == "pk":
                continue
            columns = [row[2] for row in connection.execute(f'PRAGMA index_info("{index[1]}")')]
            name = index[1]
            if name.startswith("sqlite_"):
                name = f"ux_local_{table}_" + "_".join(columns)
            filtered = table == "page_term_mentions" and columns == ["observation_key"]
            keys = " AND ".join(
                "EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c "
                "ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
                f"WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id "
                f"AND ic.key_ordinal={n} AND ic.is_descending_key=0 AND c.name='{column}')"
                for n, column in enumerate(columns, 1))
            ddl += [
                "IF NOT EXISTS(SELECT 1 FROM sys.indexes i "
                f"WHERE i.object_id=OBJECT_ID('dbo.{table}') AND i.type IN (1,2) AND i.is_disabled=0 " +
                ("AND i.has_filter=1 AND i.filter_definition LIKE '%observation_key%IS NOT NULL%' "
                 if filtered else "AND i.has_filter=0 ") +
                ("AND i.is_unique=1 " if index[2] else "") +
                f"AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id "
                f"AND ic.index_id=i.index_id AND ic.key_ordinal>0)={len(columns)} AND {keys})",
                f"CREATE {'UNIQUE ' if index[2] else ''}INDEX [{name}] ON dbo.[{table}] (" +
                ",".join(f"[{column}]" for column in columns) + ")" +
                (" WHERE [observation_key] IS NOT NULL" if filtered else "") + ";", "GO"]
        for fk in connection.execute(f'PRAGMA foreign_key_list("{table}")'):
            if fk[2] not in local.TABLES:
                continue
            ddl += [
                "IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns "
                f"WHERE parent_object_id=OBJECT_ID('dbo.{table}') "
                f"AND referenced_object_id=OBJECT_ID('dbo.{fk[2]}') "
                f"AND COL_NAME(parent_object_id,parent_column_id)='{fk[3]}' "
                f"AND COL_NAME(referenced_object_id,referenced_column_id)='{fk[4]}')",
                f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT "
                f"[{local._foreign_key_name(table, fk[3], fk[2])}] "
                f"FOREIGN KEY ([{fk[3]}]) REFERENCES dbo.[{fk[2]}] ([{fk[4]}]);", "GO"]
    ddl += ["CREATE OR ALTER VIEW dbo.v_search AS",
            "SELECT s.section_id,s.page_id,s.heading,s.body_text,p.title,p.page_type,p.url,p.book_id,",
            "b.title AS book_title,b.edition FROM dbo.sections s JOIN dbo.pages p ON p.page_id=s.page_id",
            "JOIN dbo.books b ON b.book_id=p.book_id;", "GO",
            (SQL / "00_dbo_Clean.sql").read_text(encoding="utf-8"),
            term_hygiene.normalizer_sql(),
            (SQL / "00_dbo_Clean2.sql").read_text(encoding="utf-8")]
    for table in term_hygiene.TERM_SOURCES:
        ddl += [term_hygiene.server_trigger_sql(table), "GO"]
    for table in term_hygiene.DISPLAY_COLUMNS:
        ddl += [term_hygiene.server_display_trigger_sql(table), "GO"]
    ddl += [term_recovery.view_sql(sqlserver=True), term_pipeline.view_sql(sqlserver=True),
            "CREATE OR ALTER TRIGGER dbo.tr_term_review_append_only ON dbo.term_review_decisions "
            "INSTEAD OF UPDATE, DELETE AS BEGIN "
            "THROW 51000, 'Review decisions are append-only', 1; END", "GO"]
    for table, checks in (term_recovery.server_checks() | term_pipeline.server_checks()).items():
        for label, check in checks.items():
            name = f"ck_local_{table}_{label}"
            ddl += [
                f"IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.{table}') AND name='{name}')",
                f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT [{name}] CHECK ({check});", "GO"]
    return "\n".join(ddl)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", action="store_true", help="Also regenerate SQL Server schema snapshot")
    parser.add_argument("--companion-schema", action="store_true", help="Also write the neighboring SQLite schema")
    parser.add_argument("--sync-clean2", action="store_true", help="Explicitly snapshot deployed SQL Server Clean2")
    args = parser.parse_args()
    if args.sync_clean2:
        export_deployed_clean2()
        return
    with closing(local.connect_sqlite(ROOT / "bluebooks.db", readonly=True)) as connection:
        destination = ROOT / "docs" / "technical" / "table-columns.md"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(table_reference(connection), encoding="utf-8")
        if args.schema:
            (SQL / "schema_sqlserver.sql").write_text(server_schema(connection), encoding="utf-8")
    if args.companion_schema:
        text = "\n".join((SQL / name).read_text(encoding="utf-8") for name in (
            "schema.sql", "schema_enrichment.sql", "schema_term_pipeline.sql"))
        text += "\n" + term_recovery.view_sql() + "\n"
        text += "".join(f"DROP VIEW IF EXISTS {view};\n" for view in (
            "v_entity_terms", "v_entity_term_provenance", "v_entity_term_code_matches", "v_page_code_terms"))
        (COMPANION / "schema.sql").write_text(text + term_pipeline.view_sql() + ";\n", encoding="utf-8")
    print("Wrote table documentation; database values unchanged.")


if __name__ == "__main__":
    main()
