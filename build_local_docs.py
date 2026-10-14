"""Generate the complete SQL Server schema and table dictionary from the manifest.

Reads schema metadata only; does not modify either database.
"""
from contextlib import closing
from pathlib import Path
from datetime import datetime, timezone
import shutil
import sys
import bluebooks_local as local
import term_hygiene
import term_recovery


def export_deployed_clean2():
    """Snapshot the maintainer-approved deployed function without altering SQL Server."""
    path = local.ROOT / "00_dbo_Clean2.sql"
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    shutil.copy2(path, local.ROOT / "local_backups" / f"Clean2-before-{stamp}.sql")
    with closing(local.connect_server()) as cn:
        definition = cn.cursor().execute(
            "SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.Clean2'))"
        ).fetchone()[0]
        if not definition or "WITH SCHEMABINDING" not in definition:
            raise ValueError("Expected schema-bound dbo.Clean2 definition is unavailable")
    definition = definition.replace("CREATE FUNCTION", "CREATE OR ALTER FUNCTION", 1)
    path.write_text(
        "SET ANSI_NULLS ON\nGO\nSET QUOTED_IDENTIFIER ON\nGO\n" + definition + "\nGO\n",
        encoding="utf-8",
    )

SOURCES = {
    "books": "Volume inventory; local discovery snapshot. alias stores the editable short book/version label used by v_page_code_terms. Book 70 is an optional inventory exception.",
    "chapters": "Stored TOC chapters; crawler output.",
    "page_groups": "Stored nested TOC groups; crawler output.",
    "pages": "Stored content/HTML and crawl status. Local build fills title_norm using clean_term.clean; icdo_code_hint is subtitle-only and may be NULL.",
    "sections": "Crawler sections plus saved-HTML body recovery. Shared extractor preserves headings, body text and source_anchor. Existing nonempty sections are retained; missing sections are appended. Empty entity-page sections are pruned only when no image/reference rows link to them. Conflicts/unmatched rows and cleanup counts are reported in private build provenance.",
    "authors": "Stored page author names/roles; crawler output.",
    "images": "Stored figure metadata/captions/local paths; no new images are downloaded.",
    "page_links": "Stored page link labels/targets; crawler output.",
    "references": "Stored PMID/citation tokens; crawler output.",
    "entity_pages": "Fifth- and sixth-edition entities re-parsed from saved raw_html by bb_entity_extract. TOC category and entity-content checks exclude front matter. Edition is obtained through book_id -> books; extraction UTC timestamp is copied, not regenerated on SQL Server.",
    "entity_codes": "Structured ICD-O coding/subtype terms from both editions. Original four-digit and five-character codes are preserved without cross-edition conversion. Non-term instructions, cross-references and explanatory sentences are excluded. The legacy is_subtype flag is deprecated; use term_role and explicit provenance instead. Some terms have blank codes; row counts are not counts of populated codes.",
    "entity_related_terms": "Structured acceptable/not_recommended/other terminology plus recovered alternate names. Semicolon lists split only outside balanced parentheses, preserving forms such as t(15;19). Qualified labels are parsed separately; editorial cross-references and explanatory prose are excluded. AI-recovered rows use kind=other and are flagged by entity_term_provenance, not by an official source-code assignment.",
    "entity_term_provenance": "One source link per recovered page-linked term and original deleted row. Library/recovered_terms.json retains original text, page, source IDs, AI provenance, qualifier, historical status and proposed review status. Target IDs are re-linked on rebuild; review status, qualifier and notes survive refresh.",
    "entity_term_code_matches": "Edition-aware proposed exact/synonym/broader/conditional mappings, linked to the first provenance record per target term. Original ICD-O-3.2 and supplied September ICD-O-4 reference terms, codes, workbook rows/hashes and candidate conditions are explicit. These are not source-supplied page codes.",
    "entity_identifiers": "MIM/OMIM identifiers from labeled numbering rows, qualified hereditary/predisposition coding rows and inline subtype citations. source_kind distinguishes coding_section from section_text; source_heading preserves exact section provenance. Clause fragments are not used as display terms, and full source text remains in raw_text. Never treated as ICD-O morphology evidence.",
    "cpc_curation": "Manual working-group decisions. Never cleared by enrichment; mirror conflicts fail for explicit reconciliation.",
    "icdo4_morphology": "Local CPC_ICDO4/1-s2.0-S1877782126000044-mmc1.xlsx, a) Morphology sheet.",
    "cpc_morph_codes": "Newest dated local CPC_ICDO4/CPC_MorphCodeList_*.csv. Original text, normalized keys, retired flag and source filename retained.",
    "icdo_site_specific_terms": "Local ICDO32_Site_Specific_Terms.xlsx: Site-Specific Terms, All Screened Terms, Uncertain Items, header row 5.",
    "icdo_site_specific_term_sites": "One child row per workbook term/C-code; source labels preserved.",
    "page_icdo_codes": "Section text plus saved-HTML entity_codes. Raw code retained; four-digit compatibility code normalized as in existing helpers. section_heading records coding/subtype context.",
    "page_term_mentions": "Lexicon-matched page titles, headings/body, image captions, link labels and structured related terms; coding rows can contribute unmonitored terms. Original/normalized text and source context retained.",
    "page_site_hints": "Positive term-to-workbook site mappings (0.90) and broad book-title family prefixes (0.45). C##* prefixes are hints, not verified exact sites.",
    "page_entity_evidence": "Deterministic mention rollup. Positive/excluded counts, source kinds, code-on-page and hints. Score = positive - 0.5*excluded + 0.5*has_code; not a probability.",
    "page_search_documents": "One deterministic page document: recovered section bodies plus existing stored text and nonduplicated entity definitions/terms/identifier text. Shared source for both whole-page search indexes. Coverage validation checks extracted bodies and independent saved-source prose, not merely index counts. Missing local prose cannot be recovered without new source data.",
    "enum_values": "Centralized lookup catalog for all system enumerations across source, status, role, match, and evidence domains with full definitions and legacy migration mappings.",
}


def main():
    root = local.ROOT
    with closing(local.connect_sqlite(root / "bluebooks.db", readonly=True)) as con:
        doc = [
            "# Local Blue Books data dictionary", "",
            f"Generated by `build_local_docs.py`; logical build/schema version {local.VERSION}.", "",
            "## Population contract", "",
            "Runner Step 5 or Explorer Step 7.3 calls `refresh_local`: validate local inputs, "
            "recover saved section bodies, prune only unlinked empty entity sections, import references, normalize pages, "
            "parse saved entities and OMIM identifiers, extract codes, mentions, "
            "site hints/evidence, then build search documents and FTS. Data replacement is transactional. "
            "Runner Step 7b optionally mirrors the managed snapshot with preserved keys/timestamps "
            "and verifies normalized row hashes before committing.", "",
            "Missing reference files fail before clearing data. No online access, login, discovery, "
            "or crawling is performed. `requirements-local.txt` lists local processing dependencies; "
            "pyodbc and ODBC 17/18 are needed only for SQL Server. The neighboring BBNotebook "
            "modules and local reference files are required.", "",
            "The `.local-build.json` sidecar records reference hashes, build version, UTC time and counts; "
            "it is not an agent-activity table. Corpus and reference hashes are checked before mirror; "
            "changed inputs require a full local refresh. Native stemming and ranking may differ.", "",
            "## Tables", "",
        ]
        ddl = ["-- Generated complete data schema; agent activity and crawl history are excluded.",
               "-- For upgrades use bluebooks_local.ensure_server_schema against the canonical SQLite schema.",
               "-- Full-text setup is performed by bluebooks_local.server_search (awaits readiness).", ""]
        for table in local.TABLES:
            info = con.execute(f'PRAGMA table_info("{table}")').fetchall()
            doc += [f"### `{table}`", "", SOURCES[table], "",
                    "Refresh owner: " + ("manual curation" if table == "cpc_curation" else
                    "crawler; local enrichment adds stored keys" if table == "pages" else
                    "shared local enrichment" if table in local.DERIVED else "stored crawler snapshot"),
                    "", "| Column | SQLite type | Required | Key / notes | Default |",
                    "|---|---|---|---|---|"]
            for _, name, kind, required, default, pk in info:
                key_note = "PK" if pk else ""
                if table == "entity_codes" and name == "is_subtype":
                    key_note = "Deprecated; use `term_role`"
                doc.append(f"| `{name}` | {kind} | {'yes' if required or pk else 'no'} | {key_note} | {default or ''} |")
            doc += ["", "SQL Server maps integer IDs to INT, flags to compatible INT/BIT, "
                    "text to Unicode strings, decimal scores to DECIMAL, and dates to UTC DATETIME2. "
                    "Backend representation differences are canonicalized for row comparisons.", ""]
            keys = sorted((r for r in info if r[5]), key=lambda r: r[5])
            decl = []
            for _, name, kind, required, default, pk in info:
                decl.append(f"  [{name}] {local._server_type(name, kind, table)} "
                            f"{'NOT NULL' if required or pk else 'NULL'}" +
                            local.server_default(default))
            decl.append("  PRIMARY KEY (" + ",".join(f"[{r[1]}]" for r in keys) + ")")
            ddl += [f"IF OBJECT_ID('dbo.{table}','U') IS NULL", f"CREATE TABLE dbo.[{table}] (",
                    ",\n".join(decl), ");", "GO", ""]
            for fk in con.execute(f'PRAGMA foreign_key_list("{table}")'):
                doc.append(f"Relationship: `{fk[3]}` references `{fk[2]}.{fk[4]}`. "
                           "Explicit dependency-ordered refresh/mirror handles deletion; no curation cascade is invoked.")
            doc += ["", "Lookup indexes:", ""]
            for index in con.execute(f'PRAGMA index_list("{table}")'):
                if index[3] == "pk":
                    continue
                cols = [r[2] for r in con.execute(f'PRAGMA index_info("{index[1]}")')]
                doc.append(f"- {'UNIQUE ' if index[2] else ''}`{index[1]}`: " +
                           ", ".join(f"`{c}`" for c in cols))
            doc.append("")
        for table in local.TABLES:
            for index in con.execute(f'PRAGMA index_list("{table}")'):
                if index[3] == "pk":
                    continue
                cols = [r[2] for r in con.execute(f'PRAGMA index_info("{index[1]}")')]
                name = index[1]
                if name.startswith("sqlite_"):
                    name = f"ux_local_{table}_" + "_".join(cols)
                keys = " AND ".join(
                    "EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c "
                    "ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
                    f"WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id "
                    f"AND ic.key_ordinal={n} AND ic.is_descending_key=0 AND c.name='{col}')"
                    for n, col in enumerate(cols, 1))
                ddl += [
                    "IF NOT EXISTS(SELECT 1 FROM sys.indexes i "
                    f"WHERE i.object_id=OBJECT_ID('dbo.{table}') AND i.type IN (1,2) "
                    "AND i.is_disabled=0 AND i.has_filter=0 " +
                    ("AND i.is_unique=1 " if index[2] else "") +
                    f"AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id "
                    f"AND ic.index_id=i.index_id AND ic.key_ordinal>0)={len(cols)} AND {keys})",
                    f"CREATE {'UNIQUE ' if index[2] else ''}INDEX [{name}] ON dbo.[{table}] (" +
                    ",".join(f"[{c}]" for c in cols) + ");", "GO",
                ]
            for fk in con.execute(f'PRAGMA foreign_key_list("{table}")'):
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
                    f"FOREIGN KEY ([{fk[3]}]) "
                    f"REFERENCES dbo.[{fk[2]}] ([{fk[4]}]);", "GO",
                ]
        ddl += ["-- Reviewed duplicate-index cleanup and validation constraints are applied",
                "-- by ensure_server_schema; deploy dbo.Clean from 00_dbo_Clean.sql.",
                "CREATE OR ALTER VIEW dbo.v_search AS",
                "SELECT s.section_id,s.page_id,s.heading,s.body_text,p.title,p.page_type,p.url,p.book_id,",
                "       b.title AS book_title,b.edition",
                "FROM dbo.sections s JOIN dbo.pages p ON p.page_id=s.page_id",
                "JOIN dbo.books b ON b.book_id=p.book_id;", "GO"]
        ddl += [
            "-- Term functions and write-time maintenance are part of the complete schema.",
            "-- Deploy legacy Clean first; Clean2 uses the maintainer-approved deployed definition.",
            (root / "00_dbo_Clean.sql").read_text(encoding="utf-8"),
            term_hygiene.normalizer_sql(),
            (root / "00_dbo_Clean2.sql").read_text(encoding="utf-8"),
        ]
        for table in term_hygiene.TERM_SOURCES:
            ddl += [term_hygiene.server_trigger_sql(table), "GO"]
        for table in term_hygiene.DISPLAY_COLUMNS:
            ddl += [term_hygiene.server_display_trigger_sql(table), "GO"]
        ddl += [term_recovery.view_sql(sqlserver=True)]
        for table, checks in term_recovery.server_checks().items():
            for label, check in checks.items():
                name = f"ck_local_{table}_{label}"
                ddl += [
                    f"IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.{table}') AND name='{name}')",
                    f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT [{name}] CHECK ({check});", "GO",
                ]
        doc += [
            "## Term hygiene and indexed derived columns (2026-10-10)", "",
            "The initial live audit found 674 footnote-suffixed rows in page_icdo_codes, "
            "673 in page_term_mentions (six text/key columns), and 558 in page_entity_evidence "
            "in each database. entity_codes and entity_related_terms had no such suffixes, "
            "but did contain trailing whitespace/punctuation and citation/cross-reference endings.", "",
            "The five tables have stored TermUS and TermNormUS columns and separate nonunique "
            "600-UTF-16-unit Unicode lookup indexes in SQL Server (TEXT indexes in SQLite). "
            "Overlength keys fail explicitly; no truncation or hash-only substitute is used.", "",
            "| Table | Authoritative display/key input |", "|---|---|",
            *[f"| `{table}` | `{source}` |" for table, (_, source) in term_hygiene.TERM_SOURCES.items()],
            "",
            "`TermUS = UpperInitial(CleanBritishSpelling2(CleanDisplayTerm(source)))`; "
            "`TermNormUS = UpperInitial(Clean2(TermUS))`. Clean2 preserves case and NULL; "
            "the display layer uppercases only an initial ASCII a-z, never Greek symbols, "
            "digits or later letters. Clean2 itself is unchanged. "
            "The maintainer selected the currently deployed SQL Server Clean2 v3 as authoritative. "
            "00_dbo_Clean2.sql is its snapshot; clean_term2.py executes that same restricted "
            "straight-line replacement program, failing on unsupported syntax rather than drifting. "
            "The initial 10,065-input Python/SQL comparison has zero discrepancies after alignment.", "",
            "CleanTermEnding removes trailing footnotes (dagger, double dagger, asterisk, "
            "section/paragraph marks), list punctuation/whitespace, leading bullets and "
            "unambiguous `[[citation]]` / `<< see ... >>` tails. Numeric superscripts/subscripts, "
            "scientific signs, balanced parentheses and meaningful words remain. "
            "Raw HTML, sections, snippets, identifier numbers and code assignments are untouched. "
            "The maintainer approved removal of saved-HTML-confirmed misplaced explanatory "
            "prose from uncoded entity/related rows. Genuine parenthetical qualifiers remain. "
            "Punctuation/prose-only contextual code terms use an unambiguous structured coding/"
            "subtype assignment, otherwise NULL; code evidence is retained. No reference/workbook "
            "tables showed the audited suffixes. Version 9 capitalizes their initial ASCII "
            "letter too, without changing the remaining reference text or legacy key rules.", "",
            "## Source-backed NULL-name recovery and display case (version 9)", "",
            "The version-9 audit found no isolated ')' in either current database. It found "
            "58 NULL coding-section display names (and their two derived keys), left by the "
            "prior conservative repair, plus 232 absent optional workbook preferred terms. "
            "All 58 coding names were recoverable as explicit name/code pairs in the same "
            "saved section. Shared-code alternatives are retained independently; nested headings "
            "and code-before-name examples are supported. A contextual code never acquires the "
            "parent-page diagnosis by inference. Missing preferred terms remain NULL.", "",
            "Display INSERT/UPDATE triggers also cover entity_identifiers.term, "
            "entity_term_provenance.recovered_term, entity_term_code_matches.official_term, "
            "icdo4_morphology term/term_clean, cpc_morph_codes term/term_norm/term_clean, "
            "and icdo_site_specific_terms icdo_term/term_normalized/term_clean/preferred_term. "
            "Only an initial ASCII a-z is uppercased. Original prose, source workbook files "
            "and code_term_evidence JSON remain verbatim. Reference matching and evidence grouping "
            "apply the same initial-case policy on refresh.", "",
            "`repair_term_display` creates paired verified backups, recovers source names, "
            "capitalizes displays and keys, preserves original IDs/codes/non-term fields, "
            "refreshes search and verifies all 25 managed tables. It fails explicitly when a "
            "NULL coding name lacks an explicit source-backed recovery; it does not fabricate a name.", "",
            "SQLite INSERT/UPDATE triggers register deterministic UDFs through connect_sqlite/"
            "migrate_sqlite; writes using a bare connection fail if functions are missing. "
            "SQL Server multirow triggers apply the same rules. Stored fields were preferred "
            "over calculated columns for cross-engine read compatibility and predictable indexing. "
            "Direct attempts to overwrite derived values are corrected by the triggers. "
            "Legacy mention keys retain dbo.Clean semantics but are rebuilt from cleaned terms. "
            "Evidence TermUS is derived from its existing term_clean grouping key; it cannot "
            "reconstruct British spelling already lost in that key.", "",
            "`repair_term_tables` takes verified backups and repairs both engines in place "
            "preserving genuine row IDs, scores, policies, code fields and raw provenance; "
            "only approved prose-removal IDs change row counts. "
            "It verifies all 23 managed row hashes before completing and updates build provenance. "
            "Runner, Explorer 2/3 and the site-query notebook include the contract and a read-only "
            "key validator. Notebook regeneration creates backups before rewriting.", "",
        ]
        doc += [
            "## Recovered alternate terms and suggested coding", "",
            "The initial approved recovery adds 171 related-term rows, 215 source links and 398 "
            "edition-specific proposed code matches per database, reusing 17 existing page-linked "
            "terms. The 188 page-term targets include 16 without a defensible mapping. "
            "No original entity_codes.code or page_icdo_codes assignment is changed. "
            "TermNormUS collisions are not used to discard distinct spelling labels.", "",
            "`Library/recovered_terms.json` is the persistent reviewed extraction manifest. "
            "It contains original evidence and frozen code-term reference rows; full refresh validates "
            "its reference hashes before replacement and re-applies it after entity extraction. "
            "Review status, suggested qualifier and review notes are retained and re-linked to new IDs. "
            "New proposals are not used as positive source-code mention evidence. "
            "Do not classify an exact match as a confirmed patient diagnosis or registry reportability.", "",
            "`v_entity_terms` combines every coding and related-term row exactly once. "
            "`v_entity_term_provenance` LEFT JOINs all source links; repeated rows represent "
            "multiple source citations. `v_entity_term_code_matches` LEFT JOINs proposed candidates "
            "once per target, without multiplying by source links, and retains uncoded/unmapped "
            "terms. `source_code` and `suggested_code` remain separate. All views exist in both engines. "
            "Filter edition in the JOIN or allow NULL edition if uncoded terms must remain visible.", "",
            "### Page code-term view (version 10)", "",
            "`v_page_code_terms` exists in both databases. Its `alias` comes from the "
            "editable `books.alias` value (for example `GI, v5`); `book_name` retains "
            "the full `books.title`, and `edition` retains the original `books.edition` name. It also shows chapter, "
            "`ch_order`, page title/URL, `page_sections`, scalar `TermUS` and "
            "`candidateTermUS`, `code_edition`, `ICDO32`, `ICDO4` and `morphology_code`. "
            "`TermNormUS` is the normalized match key for `TermUS` "
            "(`UpperInitial(Clean2(TermUS))`), taken from the indexed source `TermNormUS` "
            "columns; join external US-normalized terms to it rather than to `TermUS`. "
            "The grain is one page/edition/code/TermUS pair, not a code list or term list. "
            "Repeated occurrences collapse; different terms sharing a code remain separate. "
            "Raw source morphology codes are preserved, including ICD-O-4 letter variants; "
            "the opposite edition column is NULL unless its own separate assignment exists. "
            "Unmapped terms retain NULL codes; a separate uncoded duplicate is omitted when "
            "the same page/TermUS already has a source or proposed code. Views are unordered; "
            "specify `ORDER BY` in the consuming query when a display order is needed.", "",
            "`is_subtype` (deprecated compatibility field), `code_kind`, `source_kind`, `suggested_qualifier`, `match_type`, "
            "`terminology_kind`, `conditions`, `review_status` and `source_tables` distinguish "
            "source assignments, contextual coding sections and proposed matches. Only distinct "
            "sections and metadata are semicolon-separated. For extracted entity terms, "
            "section labels are semantic coding/subtype/related-terminology labels; contextual "
            "code rows retain their actual source section headings. Do not use deprecated "
            "`is_subtype` for new logic; use `term_role` and explicit provenance/relationship "
            "metadata. It remains available only for compatibility. Candidate labels are scalar "
            "official US terms; reference wording and workbook evidence are not altered.", "",
            "#### Deprecated legacy field: `is_subtype`", "",
            "**Deprecated:** do not use `is_subtype` in new queries, extraction logic, or "
            "schema design. It is retained only for backward compatibility and is not an "
            "inferred biological classification. Historically, in `entity_codes`, `1` meant "
            "the term came from a Blue Books **Subtype(s)** section (including nested subtype "
            "sections); `0` meant it came from the ordinary **ICD-O coding** section. "
            "`_parse_subtype_block` in the companion `bb_entity_extract.py` set this legacy flag.", "",
            "For backward compatibility, `v_page_code_terms` still exposes the deprecated "
            "field. Entity rows carry the stored flag. Contextual "
            "`page_icdo_codes` rows inherit the flag from a matching **page + raw code + "
            "TermUS** in `entity_codes`; otherwise they use `0`. Historically, repeated "
            "occurrences used `MAX(is_subtype)`. New consumers should use `term_role` and "
            "explicit provenance instead.", "",
            "Recovered alternate terms stored in `entity_related_terms` appear with "
            "deprecated `is_subtype=0`, even when recovery metadata has "
            "`suggested_qualifier='subtype'`. "
            "These describe different things:", "",
            "| Field | Meaning |",
            "|---|---|",
            "| Deprecated `is_subtype=1` | Legacy flag for extraction from a source subtype section |",
            "| `suggested_qualifier='subtype'` | Proposed relationship for a recovered term |", "",
            "**Deprecated `is_subtype=0` does not mean a diagnosis is not biologically a subtype.** "
            "It means the legacy source-subtype flag was not established by this extraction pathway. "
            "See [deprecated `is_subtype` assignment](IS_SUBTYPE_ASSIGNMENT.md) for historical behavior.", "",
            "#### `terminology_kind` values", "",
            "`terminology_kind` records where in the source page a term came from. It is "
            "provenance only, not code validity, preferred-term, synonym or registry status. "
            "There are five atomic values:", "",
            "| Value | Definition | Origin |",
            "|---|---|---|",
            "| `coding` | Term from the page's ICD-O coding or Subtype(s) section | `entity_codes` |",
            "| `contextual` | Term-code pair found in section text as a page-level code mention | `page_icdo_codes` |",
            "| `acceptable` | Related terminology labeled \"Acceptable\" by the source | `entity_related_terms.kind='acceptable'` |",
            "| `not_recommended` | Related terminology labeled \"Not recommended\" by the source | `entity_related_terms.kind='not_recommended'` |",
            "| `other` | Unlabeled related terminology, including recovered alternate terms | `entity_related_terms.kind='other'` |", "",
            "When one page/edition/code/`TermUS` row has more than one origin, distinct atomic "
            "values are combined alphabetically with `; ` (for example `coding; contextual`). "
            "Current combined values are `acceptable; coding`, `acceptable; not_recommended`, "
            "`coding; contextual`, `coding; other` and `contextual; other`; other sorted "
            "combinations can occur after refreshes, so filter with `LIKE` or split on `; `. "
            "See [terminology_kind values](TERMINOLOGY_KIND_VALUES.md) for counts.", "",
            "`candidate_topography_codes` contains distinct page-level site hints with "
            "`confidence_score >= 0.9`, alongside `site_confidence_min/max`. These are "
            "supporting page hints, not verified term-specific sites or patient assertions. "
            "Broad lower-confidence book-family prefixes are excluded. No qualifying hints "
            "produce NULL, not an invented site.", "",
            "`entity_term_code_matches.official_termUS` is a stored, indexed derived display "
            "maintained by INSERT/UPDATE triggers. Both editions are US-normalized. The existing "
            "match view now projects this as `official_term` and `candidateTermUS`, with the "
            "unchanged original reference label in `official_term_source`. The views can be "
            "read by plain SQLite connections without registering normalization functions. "
            "Writes still require the canonical connection helper, as for other term triggers. "
            "`local_pipeline.deploy_term_views(path)` / `bluebooks_local.deploy_term_views(path)` "
            "performs a backed-up view-only upgrade and verifies original-field preservation, "
            "unique pairs and cross-engine view/table parity. Normal migrations and full refresh "
            "install the same definitions.", "",
            "`term_recovery.dry_run(path)` reports proposed counts without writes. "
            "`term_recovery.apply_recovery(path)` makes verified paired database backups, "
            "applies the recovery and search documents, then uses the standard validated mirror "
            "and checks idempotence. Schema changes and paired engine commits are not a distributed "
            "transaction; errors are raised and backups are retained.", "",
            "## Completed term migration", "",
            "Both engines were repaired on 2026-10-11. Source values changed in 32 entity_codes, "
            "14 retained entity_related_terms, 1,279 page_icdo_codes, 814 page_term_mentions and "
            "672 page_entity_evidence rows. All retained rows received both new derived columns. "
            "A total of 44 uncoded entity rows and 41 related-term prose/heading rows were "
            "removed after saved-HTML confirmation. 465 contextual code terms were repaired: "
            "407 recovered structured names and 58 NULLs where no unambiguous name was available. "
            "No code assignments were deleted or converted.", "",
            "The final checks verify both nonunique indexes on every table (10 per engine), "
            "automatic multirow SQL updates/derived-key overwrite correction, no empty source/"
            "derived keys, no rule mismatches, idempotence and 23-table row-value parity. "
            "Normalization collisions are intentional many-to-one results, not unique identifiers. "
            "The detailed acceptance and backup record is in DATABASE_PARITY_COMPLETION_REPORT.md; "
            "exact removal IDs and backup paths are retained in .local-build.json history.", "",
            "## Related-term extraction repair (2026-10-13)", "",
            "The saved-HTML parser now splits related-term lists only at semicolons outside "
            "balanced parentheses, so cytogenetic names such as `t(15;19)` remain intact. "
            "Qualified Acceptable/Not recommended labels are parsed separately; editorial "
            "cross-references and prose are excluded. A backed-up full refresh and mirror "
            "replaced 90 malformed/prose entity_related_terms rows with 58 complete term rows "
            "(net 32 fewer), and removed 12 uncoded entity_codes rows that were instructions, "
            "cross-references or explanatory prose. The 398 curated proposed ICD-O match records "
            "were unchanged. Both databases have zero term-validation failures and matching "
            "managed-table values; exact example checks are in the completion report.", "",
            "## Excluded operational and engine objects", "",
            "| Object | Population / policy |", "|---|---|",
            "| `crawl_queue` | Crawler TOC/pending work state. Existing behavior retained; counts need not agree. |",
            "| `crawl_runs` | Crawler run log. Existing behavior retained; counts need not agree. |",
            "| `agent_jobs` and other agent activity | Existing agent-owned data/schema untouched; no SQLite clone or mirror. |",
            "| `sysdiagrams` and diagram procedures | SQL Server administration only. |",
            "| `sqlite_sequence` | SQLite-generated identity bookkeeping. |",
            "| `sections_fts` / `pages_fts` and shadow tables | SQLite FTS5 indexes, explicitly rebuilt after local data changes; never mirrored as data. |",
            "| SQL Server FULLTEXT catalog/indexes | Engine-owned section/title/whole-page indexes, automatic tracking and explicit readiness checks. |",
            "| `v_search` | Equivalent section/page/book metadata view, not separately populated. |",
            "| `Clean` / `dbo.Clean` | SQLite connection UDF / SQL Server scalar function; comparison keys, not raw search terms. |", "",
            "## Entry points and supported workflows", "",
            "Schema tuning adds page-first code/mention/author indexes and book/chapter/group "
            "navigation indexes. Existing managed relationships are preserved; entity_identifiers "
            "adds a page FK and a unique page/system/identifier/source-heading/term key, preserving "
            "separate mentions from different sections. "
            "SQL provisioning recognizes equivalent ordered keys under different names and "
            "preserves unique constraints and clustered access paths. The two reviewed redundant "
            "ordinary SQL indexes are removed only after matching options/compression and checking "
            "FK/full-text dependencies. No additional full-text indexes are needed.", "",
            "- `python bluebooks_local.py`: verified local backup and SQLite refresh.",
            "- `python bluebooks_local.py --mirror`: also backs up SQL Server, mirrors data and verifies search.",
            "- `--include-book70`: copies the existing optional inventory row, never fetches its content.",
            "- `bluebooks_fts.py`: rebuilds shared documents and SQLite FTS from current stored data.",
            "- `search.py`: SQLite whole-page/section search and readable snippets.",
            "- BBNotebook `build_agent_tables.py` / `build_site_specific_terms.py`: compatibility CLIs route to the shared pipeline.",
            "- `local_pipeline.py` exposes the same API to Explorer and site-query notebooks.",
            "- Site-specific query notebook supports SQLite and SQL Server with a bounded, read-only dialect adapter.",
            "- Both main notebook generators preserve unrelated existing cells/settings and upgrade managed local-data cells idempotently.",
            "", "Archived notebooks are historical; active Explorer versions 2 and 3 are integrated. "
            "Local-only use skips browser/package-download/demo-generation cells.", "",
        ]
        (root / "DATA_DICTIONARY.md").write_text("\n".join(doc), encoding="utf-8")
        (root / "schema_sqlserver.sql").write_text("\n".join(ddl), encoding="utf-8")
        (local.COMPANION / "schema.sql").write_text(
            "-- Generated from the shared crawler schemas by build_local_docs.py.\n"
            "-- Existing databases must be upgraded with local_pipeline.migrate_sqlite.\n" +
            (root / "schema.sql").read_text(encoding="utf-8") + "\n" +
            (root / "schema_enrichment.sql").read_text(encoding="utf-8") + "\n" +
            term_recovery.view_sql(), encoding="utf-8")


if __name__ == "__main__":
    if "--sync-clean2" in sys.argv:
        export_deployed_clean2()
    else:
        main()
