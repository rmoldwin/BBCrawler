"""Local-only enrichment, verified mirroring and full-text search.

No browser, HTTP or scraping entry points are invoked. See DATA_DICTIONARY.md.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from contextlib import closing, ExitStack
from datetime import datetime, timezone
from decimal import Decimal
import hashlib
import importlib
import json
from pathlib import Path
import re
import sqlite3
import sys
import time
import term_hygiene
import term_recovery
import term_pipeline

ROOT = Path(__file__).resolve().parent
COMPANION = ROOT.parent / "BBNotebook"
VERSION = 11
TABLES = (
    "books", "chapters", "page_groups", "pages", "sections", "authors", "images",
    "page_links", "references", "entity_pages", "entity_codes",
    "entity_related_terms", "entity_term_provenance", "entity_term_code_matches",
    "entity_identifiers", "cpc_curation", "icdo4_morphology", "cpc_morph_codes",
    "icdo_site_specific_terms", "icdo_site_specific_term_sites", "page_icdo_codes",
    "page_term_mentions", *term_pipeline.TABLES, "page_site_hints", "page_entity_evidence",
    "page_search_documents", "enum_values",
)
EXCLUDED = ("agent_jobs", "crawl_queue", "crawl_runs", "sysdiagrams")
DERIVED = (
    "entity_pages", "entity_codes", "entity_related_terms",
    "entity_term_provenance", "entity_term_code_matches", "entity_identifiers", "icdo4_morphology",
    "cpc_morph_codes", "icdo_site_specific_terms", "icdo_site_specific_term_sites",
    "page_icdo_codes", "page_term_mentions", *term_pipeline.TABLES, "page_site_hints",
    "page_entity_evidence", "page_search_documents",
)


def companion(name: str):
    if not COMPANION.is_dir():
        raise FileNotFoundError(f"Companion modules required at {COMPANION}")
    if str(COMPANION) not in sys.path:
        sys.path.insert(0, str(COMPANION))
    return importlib.import_module(name)


def connect_sqlite(path: Path, *, readonly: bool = False) -> sqlite3.Connection:
    path = Path(path).resolve()
    con = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True) if readonly else sqlite3.connect(path)
    con.execute("PRAGMA foreign_keys=ON")
    con.create_function("Clean", 1, companion("clean_term").clean, deterministic=True)
    term_hygiene.register_sqlite(con)
    return con


def columns(con: sqlite3.Connection, table: str) -> list[str]:
    if table not in TABLES + ("crawl_queue", "crawl_runs"):
        raise ValueError(f"Unmanaged table: {table}")
    return [r[1] for r in con.execute(f'PRAGMA table_info("{table}")')]


def _migrate_entity_identifier_key(con: sqlite3.Connection) -> None:
    expected = ["page_id", "system", "identifier", "source_heading", "term"]
    for index in con.execute('PRAGMA index_list("entity_identifiers")'):
        if index[2] and [
            row[2] for row in con.execute(f'PRAGMA index_info("{index[1]}")')
        ] == expected:
            return
    con.execute(
        "CREATE TABLE entity_identifiers_new ("
        "identifier_id INTEGER PRIMARY KEY,"
        "page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),"
        "system TEXT NOT NULL CHECK(system IN ('OMIM')),"
        "identifier TEXT NOT NULL, term TEXT NOT NULL,"
        "source_kind TEXT NOT NULL DEFAULT 'section_text',"
        "source_heading TEXT NOT NULL, raw_text TEXT NOT NULL,"
        "UNIQUE(page_id,system,identifier,source_heading,term))"
    )
    con.execute(
        "INSERT INTO entity_identifiers_new "
        "(identifier_id,page_id,system,identifier,term,source_kind,source_heading,raw_text) "
        "SELECT identifier_id,page_id,system,identifier,term,source_kind,source_heading,raw_text "
        "FROM entity_identifiers"
    )
    con.execute("DROP TABLE entity_identifiers")
    con.execute("ALTER TABLE entity_identifiers_new RENAME TO entity_identifiers")
    con.execute(
        "CREATE INDEX IF NOT EXISTS ix_entity_identifiers_lookup "
        "ON entity_identifiers(system,identifier)"
    )


def _migrate_page_icdo_codes_nullable(con: sqlite3.Connection) -> None:
    info = {r[1]: r for r in con.execute('PRAGMA table_info("page_icdo_codes")')}
    if not info or not info.get("icdo_code", (None, None, None, 0))[3]:
        return
    cols = columns(con, "page_icdo_codes")
    for view in ("v_page_code_terms", "v_entity_term_code_matches", "v_entity_term_provenance", "v_entity_terms"):
        con.execute(f'DROP VIEW IF EXISTS "{view}"')
    con.execute(
        "CREATE TABLE page_icdo_codes_new ("
        "code_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES pages(page_id),"
        "icdo_code TEXT, icdo_code_raw TEXT, term_in_coding_section TEXT,"
        "section_heading TEXT, term_role TEXT, term_source TEXT, line_indent INTEGER NOT NULL DEFAULT 0,"
        "TermUS TEXT, TermNormUS TEXT)"
    )
    common_cols = [c for c in cols if c in ("code_id", "page_id", "icdo_code", "icdo_code_raw", "term_in_coding_section", "section_heading", "term_role", "term_source", "line_indent", "TermUS", "TermNormUS")]
    common_names = ",".join(f'"{c}"' for c in common_cols)
    con.execute(f"INSERT INTO page_icdo_codes_new ({common_names}) SELECT {common_names} FROM page_icdo_codes")
    con.execute("DROP TABLE page_icdo_codes")
    con.execute("ALTER TABLE page_icdo_codes_new RENAME TO page_icdo_codes")
    con.execute("CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_code ON page_icdo_codes(icdo_code,page_id)")
    con.execute("CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_page ON page_icdo_codes(page_id)")
    con.execute("CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_TermUS ON page_icdo_codes(TermUS)")
    con.execute("CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_TermNormUS ON page_icdo_codes(TermNormUS)")


def migrate_sqlite(con: sqlite3.Connection) -> None:
    if con.in_transaction:
        raise RuntimeError("Commit caller changes before migration")
    con.executescript((ROOT / "schema.sql").read_text(encoding="utf-8"))
    book_cols = columns(con, "books")
    if "alias" not in book_cols:
        con.execute("ALTER TABLE books ADD COLUMN alias TEXT")
    for book_id, title, edition in con.execute(
        "SELECT book_id,title,edition FROM books WHERE alias IS NULL OR trim(alias)=''"
    ).fetchall():
        con.execute(
            "UPDATE books SET alias=? WHERE book_id=?",
            (term_recovery.book_version_alias(title, edition), book_id),
        )
    existing = columns(con, "pages")
    for name in ("title_norm", "icdo_code_hint"):
        if name not in existing:
            con.execute(f'ALTER TABLE pages ADD COLUMN "{name}" TEXT')
    if "source_anchor" not in columns(con, "sections"):
        con.execute("ALTER TABLE sections ADD COLUMN source_anchor TEXT")
    con.commit()
    con.executescript((ROOT / "schema_enrichment.sql").read_text(encoding="utf-8"))
    if "source_kind" not in columns(con, "entity_identifiers"):
        con.execute(
            "ALTER TABLE entity_identifiers ADD COLUMN "
            "source_kind TEXT NOT NULL DEFAULT 'section_text'"
        )
    _migrate_entity_identifier_key(con)
    _migrate_page_icdo_codes_nullable(con)
    ec_cols = columns(con, "entity_codes")
    if "term_role" not in ec_cols:
        con.execute("ALTER TABLE entity_codes ADD COLUMN term_role TEXT")
    ert_cols = columns(con, "entity_related_terms")
    if "term_role" not in ert_cols:
        con.execute("ALTER TABLE entity_related_terms ADD COLUMN term_role TEXT")
    pic_cols = columns(con, "page_icdo_codes")
    if "term_role" not in pic_cols:
        con.execute("ALTER TABLE page_icdo_codes ADD COLUMN term_role TEXT")
    if "term_source" not in pic_cols:
        con.execute("ALTER TABLE page_icdo_codes ADD COLUMN term_source TEXT")
    if "line_indent" not in pic_cols:
        con.execute("ALTER TABLE page_icdo_codes ADD COLUMN line_indent INTEGER NOT NULL DEFAULT 0")
    ptm_cols = columns(con, "page_term_mentions")
    for col, col_type in (
        ("url", "TEXT"),
        ("term_source", "TEXT"),
        ("extraction_method", "TEXT"),
        ("term_role", "TEXT"),
        ("code_origin", "TEXT"),
        ("parent_mention_id", "INTEGER"),
        ("review_status", "TEXT"),
        ("reviewed_by", "TEXT"),
    ):
        if col not in ptm_cols:
            con.execute(f'ALTER TABLE page_term_mentions ADD COLUMN "{col}" {col_type}')
    con.create_function("Clean", 1, companion("clean_term").clean, deterministic=True)
    term_hygiene.ensure_sqlite(con)
    term_recovery.ensure_sqlite_views(con)
    term_pipeline.migrate(con)
    if con.execute("SELECT 1 FROM term_lookup_evaluations LIMIT 1").fetchone():
        term_pipeline.ensure_views(con)
    con.execute(f"PRAGMA user_version={VERSION}")
    con.commit()


def _insert(con: sqlite3.Connection, table: str, cols: list[str], rows: list[tuple]) -> None:
    names = ",".join(f'"{c}"' for c in cols)
    marks = ",".join("?" for _ in cols)
    con.executemany(f'INSERT INTO "{table}" ({names}) VALUES ({marks})', rows)


def reference_rows() -> tuple[dict[str, list[tuple]], dict[str, str]]:
    """Validate all required local inputs before any existing data is cleared."""
    site = companion("build_site_specific_terms")
    lookup = companion("bb_icdo_lookup")
    import pandas as pd

    workbook = Path(site.EXCEL_FILE)
    csv = lookup.latest_csv()
    for path in (workbook, lookup.MORPH_XLSX, csv):
        if not path.is_file():
            raise FileNotFoundError(f"Required local reference file missing: {path}")
    rows: dict[str, list[tuple]] = {
        "icdo4_morphology": lookup.read_morphology(),
        "cpc_morph_codes": lookup.read_cpc_csv(csv)[0],
        "icdo_site_specific_terms": [], "icdo_site_specific_term_sites": [],
    }
    term_id = 0
    for sheet, source in site.SHEETS.items():
        frame = pd.read_excel(workbook, sheet_name=sheet, header=4)
        frame = frame.dropna(subset=["ICDO32 Code"]).reset_index(drop=True)
        uncertain = source == "uncertain"
        code_col = "Proposed Valid Sites (C-codes)" if uncertain else "Site Subset (C-codes)"
        label_col = "Proposed Valid Sites (Labels)" if uncertain else "Site Subset (Labels)"
        count_col = "Proposed Site Count" if uncertain else "Subset Site Count"
        for _, row in frame.iterrows():
            term_id += 1
            term = site._str_val(row, "ICDO32 Term")
            raw = site._str_val(row, "ICDO32 Code")
            rows["icdo_site_specific_terms"].append((
                term_id, source, site.normalize_code(raw), raw, term,
                site._str_val(row, "Normalized Term"), site.clean(term),
                site._str_val(row, "ICDO32 Preferred Term"),
                site._str_val(row, "Site-Specific?"), site._str_val(row, code_col),
                site._str_val(row, label_col), site._int_val(row, count_col),
                site._int_val(row, "Code's SMVL-Valid Site Count"),
                site._str_val(row, "Code's SMVL-Valid Sites (organ summary)"),
                site._str_val(row, "Code's SMVL-Valid Sites (all C-codes)"),
                site._str_val(row, "Rationale"), site._str_val(row, "Source (URL)"),
                site._str_val(row, "Source Reference"),
            ))
            labels = site._parse_site_labels(site._str_val(row, label_col))
            for code in sorted(set(site._parse_c_codes(site._str_val(row, code_col)))):
                rows["icdo_site_specific_term_sites"].append((term_id, code, labels.get(code)))
    for table, data in rows.items():
        if not data:
            raise ValueError(f"Reference input produced no rows: {table}")
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in (workbook, lookup.MORPH_XLSX, csv)}
    return rows, hashes


def backfill_sections(con: sqlite3.Connection) -> dict:
    """Recover saved body text without adding empty entity sections."""
    extractor = companion("bb_entity_extract")
    entity_page_ids = {row[0] for row in con.execute("SELECT page_id FROM entity_pages")}
    report = {"pages_parsed": 0, "sections_filled": 0, "sections_added": 0,
              "missing_html": [], "unparsed_pages": [], "conflicts": [],
              "unmatched_existing_sections": []}

    def key(text):
        return re.sub(r"\s+", " ", text or "").strip().casefold()

    for page_id, raw in con.execute("SELECT page_id,raw_html FROM pages ORDER BY page_id"):
        if not raw:
            report["missing_html"].append(page_id)
            continue
        parsed = extractor.cached_saved_sections(con, page_id, raw)
        if not parsed:
            report["unparsed_pages"].append(page_id)
            continue
        report["pages_parsed"] += 1
        existing = list(con.execute(
            "SELECT section_id,heading,body_text,ord,source_anchor FROM sections "
            "WHERE page_id=? ORDER BY ord,section_id", (page_id,)
        ))
        next_order = max((r[3] or 0 for r in existing), default=0) + 1
        used = set()
        for section in parsed:
            if page_id in entity_page_ids and not key(section.body_text):
                continue
            candidates = [r for r in existing if r[0] not in used and section.anchor
                          and r[4] == section.anchor and key(r[1]) == key(section.heading)]
            if not candidates:
                candidates = [r for r in existing if r[0] not in used
                              and key(r[1]) == key(section.heading)]
            exact = [r for r in candidates if key(r[2]) == key(section.body_text)]
            empty = [r for r in candidates if not key(r[2])]
            chosen = exact[0] if exact else empty[0] if len(empty) == 1 else None
            if chosen:
                used.add(chosen[0])
                con.execute(
                    "UPDATE sections SET body_text=?,source_anchor=? WHERE section_id=?",
                    (chosen[2] if key(chosen[2]) else section.body_text,
                     section.anchor or chosen[4], chosen[0]),
                )
                if not key(chosen[2]) and key(section.body_text):
                    report["sections_filled"] += 1
            else:
                if candidates:
                    report["conflicts"].append({
                        "page_id": page_id, "heading": section.heading,
                        "existing_section_ids": [r[0] for r in candidates],
                        "action": "retained existing; added saved HTML section",
                    })
                con.execute(
                    "INSERT INTO sections(page_id,heading,body_text,ord,source_anchor) VALUES(?,?,?,?,?)",
                    (page_id, section.heading, section.body_text, next_order, section.anchor),
                )
                next_order += 1
                report["sections_added"] += 1
        report["unmatched_existing_sections"].extend(r[0] for r in existing if r[0] not in used)
    return report


def prune_empty_entity_sections(con: sqlite3.Connection) -> int:
    """Remove empty entity sections only when no image/reference points at them."""
    cur = con.execute(
        "DELETE FROM sections WHERE trim(coalesce(body_text,''))='' "
        "AND page_id IN (SELECT page_id FROM entity_pages) "
        "AND section_id NOT IN ("
        "SELECT section_id FROM images WHERE section_id IS NOT NULL "
        "UNION SELECT section_id FROM \"references\" WHERE section_id IS NOT NULL)"
    )
    return cur.rowcount


def _entities(con: sqlite3.Connection, stamp: str) -> None:
    extractor = companion("bb_entity_extract")
    for (book_id,) in con.execute(
        "SELECT book_id FROM books WHERE edition IN ('5th','6th') ORDER BY book_id"
    ).fetchall():
        for record in extractor.extract_book_entities(con, book_id):
            entity = record["entity"]
            page_id = record["page_id"]
            con.execute(
                "INSERT INTO entity_pages VALUES (?,?,?,?,?,?,?,?) "
                "ON CONFLICT(page_id) DO UPDATE SET definition=excluded.definition,"
                "extracted_at=excluded.extracted_at",
                (page_id, book_id, record["chapter"], record["category"],
                 record["subcategory"], entity.title, entity.definition, stamp),
            )
            for ordinal, code in enumerate(list(entity.coded_terms) + list(entity.subtypes)):
                if term_hygiene.is_standalone_placeholder(code.term):
                    continue
                if con.execute(
                    "SELECT 1 FROM entity_codes WHERE page_id=? AND term=? AND code=? AND is_subtype=?",
                    (page_id, code.term, code.code, int(code.is_subtype)),
                ).fetchone():
                    continue
                con.execute(
                    "INSERT INTO entity_codes(page_id,ordinal,term,code,is_subtype,term_role) VALUES(?,?,?,?,?,?)",
                    (page_id, ordinal, code.term, code.code, int(code.is_subtype),
                     "subtype" if code.is_subtype else "preferred"),
                )
            for kind, terms in (("acceptable", entity.acceptable),
                                ("not_recommended", entity.not_recommended),
                                ("other", getattr(entity, "related_other", []) or [])):
                role = "synonym" if kind == "acceptable" else ("not_recommended" if kind == "not_recommended" else "related")
                con.executemany(
                    "INSERT INTO entity_related_terms(page_id,kind,term,term_role) "
                    "SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM entity_related_terms "
                    "WHERE page_id=? AND kind=? AND term=?)",
                    [(page_id, kind, term, role, page_id, kind, term) for term in terms
                     if not term_hygiene.is_standalone_placeholder(term)],
                )
            con.executemany(
                "INSERT INTO entity_identifiers(page_id,system,identifier,term,source_kind,source_heading,raw_text) "
                "VALUES(?,?,?,?,?,?,?)",
                [(page_id, item.system, item.identifier, item.term, item.source_kind,
                  item.source_heading, item.raw_text)
                 for item in entity.identifiers],
            )


def _codes(con: sqlite3.Connection) -> None:
    rules = companion("build_agent_tables")
    rows = []
    seen = set()
    coding_pages = {r[0] for r in con.execute("SELECT page_id FROM pages WHERE page_type='icdo_coding'")}
    sources = con.execute(
        "SELECT page_id,heading,body_text FROM sections ORDER BY page_id,ord,section_id"
    )
    for page_id, heading, body in sources:
        if page_id in coding_pages:
            h_lower = (heading or "").lower()
            if (re.search(r"^c\d{2}", h_lower) or "topograph" in h_lower or "note" in h_lower
                    or "introduction" in h_lower or "author" in h_lower or "attachment" in h_lower
                    or "feedback" in h_lower):
                continue
            for line in (body or "").split("\n"):
                line_str = line.strip()
                if not line_str or len(line_str) < 3:
                    continue
                if (line_str.startswith("[[") or line_str.startswith("http")
                        or "These morphology codes" in line_str or "Please note" in line_str
                        or "Behaviour is coded" in line_str or "This classification is modified" in line_str
                        or "ICD-O label" in line_str or "ICD-O-3" in line_str
                        or "classification of tumour types" in line_str
                        or re.search(r"^c\d{2}", line_str, re.I)):
                    continue
                code_match = re.match(r"^(\s*|\xa0*)(\d{4,5}/\d)\s*(.*)$", line)
                if code_match:
                    leading, raw_code, term_part = code_match.groups()
                    term_text = term_hygiene.clean_display_term(term_part.strip())
                    if not term_text:
                        continue
                    m_norm = re.match(r"^(\d{4,5})/(\d)$", raw_code)
                    norm_code = rules.normalize_code(*m_norm.groups()) if m_norm else raw_code
                    indent = 1 if len(leading) >= 4 or (len(line) - len(line.lstrip(" \xa0"))) >= 4 or "   " in line[:20] else 0
                    role = "subtype" if indent else "preferred"
                    row = (page_id, norm_code, raw_code, term_text, heading, role, "icdo_coding_page", indent)
                    if row not in seen:
                        seen.add(row)
                        rows.append(row)
                else:
                    term_text = term_hygiene.clean_display_term(line_str)
                    if not term_text or not re.search(r"[A-Za-z]", term_text):
                        continue
                    leading_spaces = len(line) - len(line.lstrip(" \xa0"))
                    indent = 1 if leading_spaces >= 4 else 0
                    role = "uncoded_subtype" if indent else "uncoded_preferred"
                    row = (page_id, None, None, term_text, heading, role, "icdo_coding_page", indent)
                    if row not in seen:
                        seen.add(row)
                        rows.append(row)
        else:
            for match in rules.CODE_RE.finditer(body or ""):
                pre, behavior, term = match.groups()
                raw_code = f"{pre}/{behavior}"
                display = code_display_term(con, page_id, raw_code, heading, term)
                names = [display] if display else contextual_code_terms(
                    con, page_id, raw_code, heading, body or "",
                )
                h_is_subtype = bool(heading and "subtype" in heading.lower())
                role = "subtype" if h_is_subtype else "preferred"
                src = "subtype_section" if h_is_subtype else "entity_coding_section"
                indent = 1 if h_is_subtype else 0
                for name in names or [None]:
                    row = (page_id, rules.normalize_code(pre, behavior), raw_code, name, heading, role, src, indent)
                    if row not in seen:
                        seen.add(row)
                        rows.append(row)
    # Parsed entity codes supplement section extraction for both supported editions.
    for page_id, code, term, subtype in con.execute(
        "SELECT page_id,code,term,is_subtype FROM entity_codes ORDER BY page_id,ordinal"
    ):
        match = re.fullmatch(r"(\d{4,5})\s*/\s*(\d)", code or "")
        if match:
            role = "subtype" if subtype else "preferred"
            src = "subtype_section" if subtype else "entity_coding_section"
            heading = "Subtype(s)" if subtype else "ICD-O coding"
            row = (page_id, rules.normalize_code(*match.groups()), code, term,
                   heading, role, src, int(subtype))
            if row not in seen:
                seen.add(row)
                rows.append(row)
    _insert(con, "page_icdo_codes",
            [c for c in columns(con, "page_icdo_codes")[1:] if c not in term_hygiene.TERM_COLUMNS], rows)


def explicit_code_terms(body: str, raw_code: str) -> list[str]:
    """Recover explicit name/code pairs, never infer a parent-page assignment."""
    parser = companion("bb_entity_extract")
    code = re.escape(raw_code)
    names = []
    for chunk in re.split(r"[;\n]", body):
        chunk = re.sub(r"^\s*(?:Acceptable|Not recommended)\s*:\s*", "", chunk, flags=re.I)
        chunk = re.sub(r"^.*?\bclassification applies to\s+", "", chunk, flags=re.I)
        # Named parentheticals after a code are examples, not the parent diagnosis.
        for match in re.finditer(rf"\b{code}\s*\(([^()]+)\)", chunk):
            names.append(match.group(1))
        for part in re.split(r"(?<=\)),\s+(?:and\s+)?", chunk):
            match = re.fullmatch(rf"\s*(.+?)\s*\(\s*{code}\s*\)\s*[.,]?\s*", part)
            if match:
                names.append(match.group(1))
            else:
                match = re.fullmatch(rf"\s*(.+?)\s+{code}\s*[.,]?\s*", part)
                if match:
                    names.append(match.group(1))
    result = []
    for name in names:
        name = term_hygiene.clean_display_term(name)
        if name and re.search(r"\w", name) and not parser.is_term_prose(name):
            if name not in result:
                result.append(name)
    return result


def contextual_code_terms(con: sqlite3.Connection, page_id: int, raw_code: str,
                          heading: str | None, body: str | None = None) -> list[str]:
    bodies = [body] if body is not None else [
        row[0] or "" for row in con.execute(
            "SELECT body_text FROM sections WHERE page_id=? AND heading IS ? ORDER BY ord,section_id",
            (page_id, heading),
        )
    ]
    structured = [
        term_hygiene.clean_display_term(row[0]) for row in con.execute(
            "SELECT term FROM entity_codes WHERE page_id=? AND code=? ORDER BY ordinal,entity_code_id",
            (page_id, raw_code),
        )
    ]
    names = []
    for text in bodies:
        for name in explicit_code_terms(text, raw_code):
            if "\ufffd" in name:
                pattern = re.escape(name).replace("\ufffd", ".")
                matches = {term for term in structured if term and re.fullmatch(pattern, term, re.I)}
                if len(matches) != 1:
                    raise ValueError(f"Undecodable source term on page {page_id}: {name!r}")
                name = matches.pop()
            if name not in names:
                names.append(name)
    return names


def code_display_term(con: sqlite3.Connection, page_id: int, raw_code: str,
                      heading: str | None, term: str | None) -> str | None:
    """Do not mistake text after a parenthesized/prose code for its entity name."""
    term = term_hygiene.clean_display_term(term)
    parser = companion("bb_entity_extract")
    if term and re.search(r"\w", term) and not (
        parser.is_term_prose(term) or re.search(r"\b\d{4,5}/\d\b", term)
    ):
        return term
    if (heading or "").casefold() not in {"icd-o coding", "subtype(s)"}:
        return None
    names = {
        term_hygiene.clean_term_ending(row[0])
        for row in con.execute(
            "SELECT term FROM entity_codes WHERE page_id=? AND code=? AND is_subtype=?",
            (page_id, raw_code, int((heading or "").casefold() == "subtype(s)")),
        )
    }
    return next(iter(names)) if len(names) == 1 else None


def split_compound_term(term: str) -> list[str]:
    """Detects compound diagnostic terms (e.g., A and B of the X, Benign and premalignant X, A / B) and splits them."""
    if not term:
        return []
    m = re.match(r"^(.*?)\s+and\s+(.*?)\s+(of the\s+.*)$", term, re.I)
    if m:
        t1 = f"{m.group(1)} {m.group(3)}"
        t2 = f"{m.group(2)} {m.group(3)}"
        return [t1.strip(), t2.strip()]
    m = re.match(r"^(Benign)\s+and\s+(premalignant|malignant)\s+(.*)$", term, re.I)
    if m:
        return [f"{m.group(1)} {m.group(3)}".strip(), f"{m.group(2).capitalize()} {m.group(3)}".strip()]
    if " / " in term:
        parts = [p.strip() for p in term.split(" / ") if p.strip()]
        if len(parts) > 1:
            return parts
    m = re.match(r"^([A-Za-z]+)\s+and\s+([A-Za-z]+)\s+([A-Za-z\s]+)$", term)
    if m and len(m.group(3).split()) <= 3:
        return [f"{m.group(1)} {m.group(3)}".strip(), f"{m.group(2)} {m.group(3)}".strip()]
    if " and " in term and not re.search(r"\b(syndrome|associated|related|complex)\b", term, re.I):
        parts = [p.strip() for p in term.split(" and ") if p.strip()]
        if len(parts) == 2 and all(len(p.split()) <= 4 for p in parts):
            return parts
    return []


def _evidence(con: sqlite3.Connection) -> None:
    rules = companion("build_agent_tables")
    clean = companion("clean_term").clean
    lexicon = defaultdict(list)
    for code, term, key, preferred, normalized in con.execute(
        "SELECT DISTINCT icdo_code,icdo_term,term_clean,preferred_term,term_normalized "
        "FROM icdo_site_specific_terms WHERE site_specific_flag IN ('Yes','Uncertain') "
        "AND term_clean IS NOT NULL ORDER BY term_clean,icdo_code,icdo_term"
    ):
        if key.strip():
            lexicon[key.strip()].append((code, term or preferred or normalized or key))
    if not lexicon:
        raise ValueError("Required site-specific term lexicon is empty")
    page_urls = dict(con.execute("SELECT page_id, url FROM pages"))
    page_types = dict(con.execute("SELECT page_id, page_type FROM pages"))
    mentions = []
    seen = set()

    def add(page_id, source_kind, heading, text, forced=None, term_source=None, term_role=None, code_origin=None):
        policy, positive, confidence = rules._heading_policy(heading or "")
        url = page_urls.get(page_id)
        effective_source = term_source or (
            ("icdo_coding_page" if page_types.get(page_id) == "icdo_coding" else "entity_coding_section")
            if source_kind == "coding_section"
            else source_kind
        )
        effective_role = term_role or (
            "entity_name" if source_kind in ("page_title", "toc_page_title")
            else ("grouper" if source_kind == "toc_group_label" else "mention")
        )
        effective_origin = code_origin or (
            ("printed_on_coding_page" if page_types.get(page_id) == "icdo_coding" else "printed_with_term")
            if forced else "proposed_match"
        )
        for candidate in rules._split_text_candidates(text or ""):
            candidate = term_hygiene.clean_term_ending(candidate) or ""
            key = term_hygiene.upper_initial(clean(term_hygiene.clean_display_term(candidate)))
            if not key:
                continue
            matches = lexicon.get(key, [])
            if not matches and not forced:
                continue
            components = split_compound_term(candidate)
            parent_role = "grouper" if components and effective_role in ("mention", "grouper") else effective_role
            for code, matched in matches or [(forced, candidate)]:
                code = forced or code
                flag = rules._section_flag(heading or "", source_kind, candidate)
                identity = (page_id, code, key, source_kind, heading or "", policy, flag)
                if identity in seen:
                    continue
                seen.add(identity)
                parent_mention_id = len(mentions) + 1
                mentions.append((
                    page_id, url, code, candidate, key, candidate, key, matched, clean(matched),
                    effective_source, "lexicon_match" if matches else "html_parse",
                    parent_role, effective_origin, None,
                    source_kind, heading, flag, heading, policy, int(positive), confidence,
                    candidate[:1000], "accepted", "rule",
                ))
                if components:
                    for comp in components:
                        comp_cleaned = term_hygiene.clean_term_ending(comp) or ""
                        comp_key = term_hygiene.upper_initial(clean(term_hygiene.clean_display_term(comp_cleaned)))
                        if not comp_key:
                            continue
                        comp_matches = lexicon.get(comp_key, [])
                        comp_code = comp_matches[0][0] if comp_matches else code
                        comp_matched = comp_matches[0][1] if comp_matches else matched
                        mentions.append((
                            page_id, url, comp_code, comp_cleaned, comp_key, comp_cleaned, comp_key,
                            comp_matched, clean(comp_matched),
                            effective_source, "compound_split",
                            "component", "proposed_match", parent_mention_id,
                            source_kind, heading, flag, heading, policy, int(positive), confidence,
                            comp_cleaned[:1000], "accepted", "rule",
                        ))

    for page_id, title in con.execute("SELECT page_id,title FROM pages ORDER BY page_id"):
        add(page_id, "page_title", None, title, term_source="page_title", term_role="entity_name")
        add(page_id, "toc_page_title", "Table of Contents", title, term_source="toc_page_title", term_role="entity_name")
    for page_id, label in con.execute(
        "SELECT p.page_id, g.label FROM pages p "
        "JOIN page_groups g ON g.group_id=p.group_id WHERE g.label IS NOT NULL ORDER BY p.page_id"
    ):
        add(page_id, "toc_group_label", "Table of Contents", label, term_source="toc_group_label", term_role="grouper")
    for page_id, heading, term, code, role, source in con.execute(
        "SELECT page_id,section_heading,term_in_coding_section,icdo_code,term_role,term_source "
        "FROM page_icdo_codes ORDER BY code_id"
    ):
        add(page_id, "coding_section", heading, term, forced=code, term_source=source, term_role=role)
    for page_id, heading, body in con.execute(
        "SELECT page_id,heading,body_text FROM sections ORDER BY page_id,ord,section_id"
    ):
        add(page_id, "section_heading", heading, heading)
        add(page_id, "section_body", heading, body)
    for page_id, kind, term, role in con.execute(
        "SELECT r.page_id,r.kind,r.term,r.term_role FROM entity_related_terms r "
        "WHERE NOT EXISTS(SELECT 1 FROM entity_term_provenance p "
        "WHERE p.related_term_id=r.related_term_id AND p.is_added_term=1) "
        "ORDER BY r.related_term_id"
    ):
        heading = {"acceptable": "Acceptable terminology",
                   "not_recommended": "Not recommended terminology",
                   "other": "Related terminology"}.get(kind, "Related terminology")
        source = "subtype_section" if (kind == "subtype" or role == "subtype_section") else "related_terminology_section"
        add(page_id, "entity_related_term", heading, term, term_source=source, term_role=role)
    for page_id, caption in con.execute("SELECT page_id,caption FROM images ORDER BY image_id"):
        add(page_id, "image_caption", "image", caption)
    for page_id, label in con.execute("SELECT page_id,link_text FROM page_links ORDER BY link_id"):
        add(page_id, "link_text", "linked_content", label)
    mention_cols = [
        "page_id", "url", "icdo_code", "term_original", "term_original_norm",
        "term_text", "term_clean", "matched_term_original", "matched_term_norm",
        "term_source", "extraction_method", "term_role", "code_origin",
        "parent_mention_id", "source_kind", "source_heading", "section_flag",
        "section_location", "evidence_policy", "is_positive_evidence",
        "confidence_score", "snippet", "review_status", "reviewed_by",
    ]
    _insert(con, "page_term_mentions", mention_cols, mentions)
    hints = set()
    for page_id, code in con.execute(
        "SELECT DISTINCT m.page_id,s.c_code FROM page_term_mentions m "
        "JOIN icdo_site_specific_terms t ON t.term_clean=m.term_clean "
        "AND (m.icdo_code IS NULL OR m.icdo_code=t.icdo_code) "
        "JOIN icdo_site_specific_term_sites s ON s.term_id=t.term_id WHERE m.is_positive_evidence=1"
    ):
        hints.add((page_id, code, "term_site_match", 0.9))
    for page_id, title in con.execute("SELECT p.page_id,b.title FROM pages p JOIN books b ON b.book_id=p.book_id"):
        for keyword, prefixes in rules.BOOK_SITE_PREFIX_HINTS.items():
            if keyword in (title or "").lower():
                hints.update((page_id, prefix, "book_title_family", 0.45) for prefix in prefixes)
    _insert(con, "page_site_hints", columns(con, "page_site_hints")[1:], sorted(hints))
    site_map = defaultdict(set)
    for page_id, code, _, _ in hints:
        site_map[page_id].add(code)
    code_set = set(con.execute("SELECT page_id,icdo_code FROM page_icdo_codes"))
    grouped = defaultdict(list)
    for mention in mentions:
        grouped[(mention[0], mention[2], mention[6])].append(mention)
    evidence = []
    for (page_id, code, term), group in sorted(grouped.items(), key=lambda x: (x[0][0], x[0][1] or "", x[0][2])):
        positive = sum(m[19] for m in group)
        excluded = len(group) - positive
        has_code = int((page_id, code) in code_set)
        evidence.append((
            page_id, code, term, positive, excluded,
            ",".join(sorted({m[14] for m in group})), has_code,
            ",".join(sorted(site_map[page_id])) or None,
            positive - excluded * 0.5 + has_code * 0.5,
        ))
    _insert(con, "page_entity_evidence",
            [c for c in columns(con, "page_entity_evidence")[1:] if c not in term_hygiene.TERM_COLUMNS], evidence)


def build_documents(con: sqlite3.Connection) -> None:
    con.execute("DELETE FROM page_search_documents")
    sections = defaultdict(list)
    for page_id, heading, body in con.execute(
        "SELECT page_id,heading,body_text FROM sections ORDER BY page_id,ord,section_id"
    ):
        if body and body.strip():
            text = " ".join(x for x in (heading, body) if x)
            if text not in sections[page_id]:
                sections[page_id].append(text)
    for page_id, title, definition in con.execute("SELECT page_id,title,definition FROM entity_pages ORDER BY page_id"):
        current = "\n".join(sections[page_id])
        for text in (title, definition):
            if text and text not in current:
                sections[page_id].append(text)
    for page_id, term in con.execute(
        "SELECT page_id,term FROM entity_codes UNION SELECT page_id,term FROM entity_related_terms "
        "UNION SELECT page_id,raw_text FROM entity_identifiers ORDER BY page_id,term"
    ):
        if term and term not in "\n".join(sections[page_id]):
            sections[page_id].append(term)
    con.executemany(
        "INSERT INTO page_search_documents VALUES(?,?,?,?)",
        [(page_id, book, title, "\n".join(sections[page_id]))
         for page_id, book, title in con.execute("SELECT page_id,book_id,title FROM pages ORDER BY page_id")],
    )


def rebuild_sqlite_search(con: sqlite3.Connection) -> None:
    con.execute("INSERT INTO sections_fts(sections_fts) VALUES('delete-all')")
    con.execute(
        "INSERT INTO sections_fts(rowid,heading,body_text,title,book_id,page_id) "
        "SELECT s.section_id,COALESCE(s.heading,''),COALESCE(s.body_text,''),"
        "COALESCE(p.title,''),p.book_id,s.page_id FROM sections s JOIN pages p ON p.page_id=s.page_id"
    )
    con.execute("INSERT INTO pages_fts(pages_fts) VALUES('delete-all')")
    con.execute(
        "INSERT INTO pages_fts(rowid,title,full_text,book_id,page_id) "
        "SELECT page_id,COALESCE(title,''),full_text,book_id,page_id FROM page_search_documents"
    )
    for table in ("sections_fts", "pages_fts"):
        con.execute(f"INSERT INTO {table}({table}) VALUES('integrity-check')")


def refresh_local(path: Path) -> dict:
    refs, hashes = reference_rows()
    official_refs, official_hashes = term_pipeline.read_references()
    hashes.update(official_hashes)
    clean = companion("clean_term").clean
    stamp = datetime.now(timezone.utc).isoformat()
    with closing(connect_sqlite(path)) as con:
        migrate_sqlite(con)
        with con:
            section_report = backfill_sections(con)
            for table in reversed(DERIVED):
                if table in ("entity_pages", "entity_codes", "entity_related_terms",
                             *term_recovery.TABLES, "page_term_mentions", *term_pipeline.TABLES):
                    continue
                con.execute(f'DELETE FROM "{table}"')
            for table, rows in refs.items():
                _insert(con, table, columns(con, table), rows)
            con.executemany(
                "UPDATE pages SET title_norm=?,icdo_code_hint=? WHERE page_id=?",
                [(clean(title), match.group(0) if (match := re.search(r"\b\d{4}/\d\b", subtitle or "")) else None, page_id)
                 for page_id, title, subtitle in con.execute("SELECT page_id,title,subtitle FROM pages")],
            )
            _entities(con, stamp)
            pruned_empty_sections = prune_empty_entity_sections(con)
            _codes(con)
            term_hygiene.refresh_terms(con)
            recovery_result = term_pipeline.run(con, official_refs)
            term_hygiene.refresh_terms(con)
            term_hygiene.validate_terms(con)
            build_documents(con)
            rebuild_sqlite_search(con)
            violations = con.execute("PRAGMA foreign_key_check").fetchall()
            if violations:
                raise ValueError(f"SQLite FK violations: {violations[:5]}")
        term_pipeline.ensure_views(con)
        result = {"version": VERSION, "completed_at": stamp, "reference_hashes": hashes,
                  "counts": inventory(con), "corpus_hashes": corpus_hashes(con),
                  "section_recovery": section_report,
                  "term_recovery": recovery_result,
                  "empty_entity_sections_pruned": pruned_empty_sections}
    # Sidecar is build provenance, never agent-activity metadata.
    Path(str(path) + ".local-build.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result


def inventory(con: sqlite3.Connection) -> dict[str, int]:
    return {table: con.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0] for table in TABLES}


def repair_term_display(path: Path, server: str = "localhost", database: str = "BlueBooks") -> dict:
    """Backed-up case-only display repair and source-backed NULL-name recovery."""
    path = Path(path).resolve()
    sidecar = Path(str(path) + ".local-build.json")
    build = json.loads(sidecar.read_text(encoding="utf-8"))
    with closing(connect_sqlite(path, readonly=True)) as con:
        if build["corpus_hashes"] != corpus_hashes(con):
            raise ValueError("Corpus changed since enrichment")
    hashes = validate_reference_hashes(build["reference_hashes"])
    backups = backup_databases(path, path.parent / "local_backups", server, database)
    tables = tuple(term_hygiene.TERM_SOURCES) + tuple(term_hygiene.DISPLAY_COLUMNS)
    with closing(connect_sqlite(path)) as src, closing(connect_server(server, database)) as cn:
        before = {table: dict((row[0], tuple(row)) for row in src.execute(
            f"SELECT * FROM [{table}] ORDER BY 1")) for table in tables}
        counts_before = inventory(src)
        untouched = {table: table_digest(src.execute(f"SELECT * FROM [{table}] ORDER BY 1"))
                     for table in TABLES if table not in tables + ("page_search_documents",)}
        repairs = []
        for row_id, page_id, code, raw, heading, term in src.execute(
            "SELECT code_id,page_id,icdo_code,icdo_code_raw,section_heading,term_in_coding_section "
            "FROM page_icdo_codes WHERE term_in_coding_section IS NULL "
            "OR TRIM(term_in_coding_section)=')' ORDER BY code_id"
        ):
            names = contextual_code_terms(src, page_id, raw, heading)
            if not names:
                raise ValueError(f"No explicit source name for coding row {row_id}; no guessing permitted")
            repairs.append({"code_id": row_id, "page_id": page_id, "code": code,
                            "raw_code": raw, "heading": heading, "before": term, "names": names})
        migrate_sqlite(src)
        ensure_server_schema(src, cn)
        added = []
        try:
            for repair in repairs:
                src.execute("UPDATE page_icdo_codes SET term_in_coding_section=? WHERE code_id=?",
                            (repair["names"][0], repair["code_id"]))
                for name in repair["names"][1:]:
                    exists = src.execute(
                        "SELECT 1 FROM page_icdo_codes WHERE page_id=? AND icdo_code_raw=? "
                        "AND section_heading IS ? AND UpperInitial(term_in_coding_section)=?",
                        (repair["page_id"], repair["raw_code"], repair["heading"], name),
                    ).fetchone()
                    if not exists:
                        new_id = src.execute(
                            "INSERT INTO page_icdo_codes(page_id,icdo_code,icdo_code_raw,"
                            "term_in_coding_section,section_heading) VALUES(?,?,?,?,?)",
                            (repair["page_id"], repair["code"], repair["raw_code"], name, repair["heading"]),
                        ).lastrowid
                        added.append(new_id)
            changed = term_hygiene.refresh_terms(src)
            validation = term_hygiene.validate_terms(src)
            build_documents(src)
            rebuild_sqlite_search(src)
            for table, digest in untouched.items():
                if digest != table_digest(src.execute(f"SELECT * FROM [{table}] ORDER BY 1")):
                    raise ValueError(f"Display repair changed unrelated data: {table}")
            allowed = {
                table: set(term_hygiene.assignments(table, "")) if table in term_hygiene.TERM_SOURCES
                else set(term_hygiene.display_assignments(table, "")) for table in tables
            }
            cur = cn.cursor()
            updates = {}
            for table in tables:
                cols = columns(src, table)
                pk = cols[0]
                update_cols = [col for col in cols if col in allowed[table]]
                updates[table] = 0
                for row in src.execute(f"SELECT * FROM [{table}] ORDER BY 1"):
                    original = before[table].get(row[0])
                    if original is None:
                        if table != "page_icdo_codes" or row[0] not in added:
                            raise ValueError(f"Unexpected added row in {table}")
                        identity = any(r[3] for r in _server_columns(cur, table))
                        if identity:
                            cur.execute(f"SET IDENTITY_INSERT dbo.[{table}] ON")
                        try:
                            cur.execute(
                                f"INSERT INTO dbo.[{table}] (" + ",".join(f"[{c}]" for c in cols) +
                                ") VALUES(" + ",".join("?" for _ in cols) + ")", *row,
                            )
                        finally:
                            if identity:
                                cur.execute(f"SET IDENTITY_INSERT dbo.[{table}] OFF")
                    elif tuple(row) != original:
                        for col, old, new in zip(cols, original, row):
                            if col not in allowed[table] and old != new:
                                raise ValueError(f"Unexpected change to {table}.{col} row {row[0]}")
                        cur.execute(
                            f"UPDATE dbo.[{table}] SET " +
                            ",".join(f"[{c}]=?" for c in update_cols) + f" WHERE [{pk}]=?",
                            *[row[cols.index(c)] for c in update_cols], row[0],
                        )
                        updates[table] += 1
                if not before[table].keys() <= {row[0] for row in src.execute(f"SELECT [{pk}] FROM [{table}]")}:
                    raise ValueError(f"Display repair deleted rows from {table}")
            for page_id, title, full_text in src.execute("SELECT page_id,title,full_text FROM page_search_documents"):
                cur.execute("UPDATE dbo.page_search_documents SET title=?,full_text=? WHERE page_id=?",
                            title, full_text, page_id)
            parity = verify_parity(src, cn)
            src.commit()
            cn.commit()
        except Exception:
            src.rollback()
            cn.rollback()
            raise
        search_status = server_search(cn)
        report = {
            "backups": backups, "completed_at": datetime.now(timezone.utc).isoformat(),
            "null_repairs": repairs, "added_code_row_ids": added, "changed_rows": changed,
            "updated_rows": updates, "counts_before": counts_before, "counts_after": inventory(src),
            "validation": validation, "parity": parity, "search": search_status,
            "clean2_changed": False, "original_ids_codes_and_evidence_preserved": True,
        }
        build.update(version=VERSION, counts=report["counts_after"], reference_hashes=hashes,
                     term_display=report)
        sidecar.write_text(json.dumps(build, indent=2), encoding="utf-8")
    return report


def deploy_term_views(path: Path, server: str = "localhost", database: str = "BlueBooks") -> dict:
    """Back up both engines, persist candidate US labels, and verify the view contract."""
    path = Path(path).resolve()
    sidecar = Path(str(path) + ".local-build.json")
    build = json.loads(sidecar.read_text(encoding="utf-8"))
    with closing(connect_sqlite(path, readonly=True)) as con:
        if build["corpus_hashes"] != corpus_hashes(con):
            raise ValueError("Corpus changed since enrichment")
    validate_reference_hashes(build["reference_hashes"])
    backups = backup_databases(path, path.parent / "local_backups", server, database)
    with closing(connect_sqlite(path)) as src, closing(connect_server(server, database)) as cn:
        cur = cn.cursor()
        ambiguous = src.execute(
            "SELECT t.page_id,t.TermUS,m.edition,m.code,COUNT(DISTINCT m.official_term) "
            "FROM v_entity_terms t JOIN entity_term_provenance p ON p.page_id=t.page_id "
            "AND ((t.term_table='entity_codes' AND p.entity_code_id=t.term_id) OR "
            "(t.term_table='entity_related_terms' AND p.related_term_id=t.term_id)) "
            "JOIN entity_term_code_matches m ON m.provenance_id=p.provenance_id "
            "GROUP BY t.page_id,t.TermUS,m.edition,m.code HAVING COUNT(DISTINCT m.official_term)>1"
        ).fetchone()
        if ambiguous:
            raise ValueError(f"Conflicting official labels for one code-term pair: {ambiguous}")
        original = {}
        for table in TABLES:
            cols = [c for c in columns(src, table) if c != "official_termUS"]
            names = ",".join(f"[{c}]" for c in cols)
            for engine, cursor, prefix in (("sqlite", src, ""), ("sqlserver", cur, "dbo.")):
                original[(engine, table)] = (names, table_digest(cursor.execute(
                    f"SELECT {names} FROM {prefix}[{table}] ORDER BY 1")))
        migrate_sqlite(src)
        try:
            ensure_server_schema(src, cn)
            cur.execute("UPDATE dbo.entity_term_code_matches SET official_termUS="
                        "dbo.UpperInitial(dbo.CleanBritishSpelling2(official_term))")
            validation = term_hygiene.validate_terms(src)
            for (engine, table), (names, digest) in original.items():
                cursor, prefix = (src, "") if engine == "sqlite" else (cur, "dbo.")
                if table_digest(cursor.execute(
                        f"SELECT {names} FROM {prefix}[{table}] ORDER BY 1")) != digest:
                    raise ValueError(f"View deployment modified original data: {engine}.{table}")
            view_checks = {}
            for view in ("v_entity_term_code_matches", "v_page_code_terms"):
                a = src.execute(f"SELECT * FROM {view}").fetchall()
                b = cur.execute(f"SELECT * FROM dbo.{view}").fetchall()
                if sorted(_row_bytes(r) for r in a) != sorted(_row_bytes(r) for r in b):
                    raise ValueError(f"View value parity failed: {view}")
                view_checks[view] = len(a)
            for cursor, prefix in ((src, ""), (cur, "dbo.")):
                duplicate = cursor.execute(
                    "SELECT page_id,code_edition,morphology_code,TermUS,candidateTermUS,COUNT(*) "
                    f"FROM {prefix}v_page_code_terms "
                    "GROUP BY page_id,code_edition,morphology_code,TermUS,candidateTermUS "
                    "HAVING COUNT(*)>1"
                ).fetchone()
                if duplicate:
                    raise ValueError(f"Duplicate code-term candidate row: {duplicate}")
            parity = verify_parity(src, cn)
            src.commit()
            cn.commit()
        except Exception:
            src.rollback()
            cn.rollback()
            raise
        report = {"backups": backups, "completed_at": datetime.now(timezone.utc).isoformat(),
                  "views": view_checks, "validation": validation, "parity": parity,
                  "original_data_preserved": True}
        build.update(version=VERSION, term_views=report)
        sidecar.write_text(json.dumps(build, indent=2), encoding="utf-8")
        return report


def repair_term_tables(path: Path, server: str = "localhost",
                       database: str = "BlueBooks") -> dict:
    """Back up, repair in place and verify both databases without re-crawling."""
    path = Path(path).resolve()
    sidecar = Path(str(path) + ".local-build.json")
    build = json.loads(sidecar.read_text(encoding="utf-8"))
    backups = backup_databases(path, path.parent / "local_backups", server, database)
    with closing(connect_sqlite(path)) as src, closing(connect_server(server, database)) as cn:
        if build["corpus_hashes"] != corpus_hashes(src):
            raise ValueError("Corpus changed since enrichment; run the full refresh instead")
        reference_hashes = validate_reference_hashes(build["reference_hashes"])
        counts = inventory(src)
        removals = plan_nonterm_removal(src)
        contextual = []
        for row_id, page_id, raw_code, heading, term in src.execute(
            "SELECT code_id,page_id,icdo_code_raw,section_heading,term_in_coding_section "
            "FROM page_icdo_codes"
        ):
            display = code_display_term(src, page_id, raw_code, heading, term)
            if display != term_hygiene.clean_term_ending(term):
                contextual.append((row_id, display))
        for table, (pk, column) in term_hygiene.TERM_SOURCES.items():
            excluded = set(removals.get(table, []))
            for row_id, value in src.execute(f"SELECT [{pk}],[{column}] FROM [{table}]"):
                if row_id in excluded:
                    continue
                term_hygiene.term_keys(value)
        migrate_sqlite(src)
        ensure_server_schema(src, cn)
        try:
            cur = cn.cursor()
            for table, ids in removals.items():
                pk = term_hygiene.TERM_SOURCES[table][0]
                for row_id in ids:
                    src.execute(f"DELETE FROM [{table}] WHERE [{pk}]=?", (row_id,))
                    cur.execute(f"DELETE FROM dbo.[{table}] WHERE [{pk}]=?", row_id)
            for row_id, display in contextual:
                src.execute(
                    "UPDATE page_icdo_codes SET term_in_coding_section=? WHERE code_id=?",
                    (display, row_id),
                )
                cur.execute(
                    "UPDATE dbo.page_icdo_codes SET term_in_coding_section=? WHERE code_id=?",
                    display, row_id,
                )
            changed = term_hygiene.refresh_terms(src)
            validation = term_hygiene.validate_terms(src)
            for table, (pk, column) in term_hygiene.TERM_SOURCES.items():
                names = ",".join(f"[{col}]" for col in columns(src, table))
                sqlite_digest = table_digest(src.execute(
                    f"SELECT {names} FROM [{table}] ORDER BY [{pk}]"
                ))
                server_digest = table_digest(cur.execute(
                    f"SELECT {names} FROM dbo.[{table}] ORDER BY [{pk}]"
                ))
                if sqlite_digest != server_digest:
                    cur.execute(f"UPDATE dbo.[{table}] SET [{column}]=[{column}]")
            for table, (_, cols) in term_hygiene.DISPLAY_COLUMNS.items():
                cur.execute(f"UPDATE dbo.[{table}] SET [{cols[0]}]=[{cols[0]}]")
            parity = verify_parity(src, cn)
            expected = {table: count - len(removals.get(table, []))
                        for table, count in counts.items()}
            if expected != inventory(src):
                raise ValueError("Term repair changed rows beyond confirmed non-term prose")
            src.commit()
            cn.commit()
        except Exception:
            src.rollback()
            cn.rollback()
            raise
    stamp = datetime.now(timezone.utc).isoformat()
    report = {"backups": backups, "completed_at": stamp, "changed_rows": changed,
              "validation": validation, "removed_nonterm_ids": removals,
              "contextual_code_terms_repaired": len(contextual),
              "genuine_rows_preserved": True, "parity": parity}
    if "term_hygiene" in build:
        build.setdefault("term_hygiene_history", []).append(build["term_hygiene"])
    build.update(version=VERSION, term_hygiene=report, counts=expected,
                 reference_hashes=reference_hashes)
    sidecar.write_text(json.dumps(build, indent=2), encoding="utf-8")
    return report


def plan_nonterm_removal(con: sqlite3.Connection) -> dict[str, list[int]]:
    """Require saved-HTML confirmation before removing approved prose-only rows."""
    parser = companion("bb_entity_extract")
    candidates = []
    for table in ("entity_codes", "entity_related_terms"):
        pk = term_hygiene.TERM_SOURCES[table][0]
        cols = "code,is_subtype" if table == "entity_codes" else "kind"
        for row in con.execute(f"SELECT [{pk}],page_id,term,{cols} FROM [{table}]"):
            recovery_column = "entity_code_id" if table == "entity_codes" else "related_term_id"
            if con.execute(
                f"SELECT 1 FROM entity_term_provenance WHERE [{recovery_column}]=?",
                (row[0],),
            ).fetchone():
                continue
            if table == "entity_codes":
                if row[3]:
                    continue
                suspect = (parser.is_term_prose(row[2]) or parser._is_placeholder(row[2])
                           or len(row[2]) > 200)
            else:
                suspect = row[3] == "other" or parser.is_term_prose(row[2]) or len(row[2]) > 200
            if suspect:
                candidates.append((table, row))
    parsed = {}
    result = {"entity_codes": [], "entity_related_terms": []}
    for table, row in candidates:
        page_id = row[1]
        if page_id not in parsed:
            html, title = con.execute(
                "SELECT raw_html,title FROM pages WHERE page_id=?", (page_id,)
            ).fetchone()
            if not html:
                raise ValueError(f"Saved HTML required to confirm non-term row: page {page_id}")
            parsed[page_id] = parser.parse_entity_page(html, title)
        entity = parsed[page_id]
        key = term_hygiene.clean_display_term(parser.normalize_dashes(row[2]))
        if table == "entity_codes":
            expected = {term_hygiene.clean_display_term(parser.normalize_dashes(item.term))
                        for item in list(entity.coded_terms) + list(entity.subtypes)
                        if not item.code and int(item.is_subtype) == row[4]}
        else:
            names = {"acceptable": entity.acceptable, "not_recommended": entity.not_recommended,
                     "other": entity.related_other}[row[3]]
            expected = {term_hygiene.clean_display_term(parser.normalize_dashes(term)) for term in names}
        confirmed_prose = (parser.is_term_prose(key or "")
                           or parser._is_placeholder(key or "")
                           or row[2].strip() in parser.KNOWN_HEADINGS
                           or "]]" in row[2])
        if table == "entity_related_terms" and row[3] == "other":
            confirmed_prose |= any(
                key == term_hygiene.clean_display_term(parser.normalize_dashes(body))
                for heading, body in entity.sections.items()
                if heading not in {"Related terminology", "ICD-O coding", "Subtype(s)"}
            )
        if key not in expected and confirmed_prose:
            result[table].append(row[0])
    return result


def corpus_hashes(con: sqlite3.Connection) -> dict[str, str]:
    result = {}
    for table in TABLES:
        if table in DERIVED or table in ("cpc_curation", "enum_values"):
            continue
        keys = sorted((r for r in con.execute(f'PRAGMA table_info("{table}")') if r[5]), key=lambda r: r[5])
        order = ",".join(f'"{r[1]}"' for r in keys)
        table_columns = columns(con, table)
        if table == "books":
            table_columns = [name for name in table_columns if name != "alias"]
        names = ",".join(f'"{c}"' for c in table_columns)
        result[table] = table_digest(con.execute(f'SELECT {names} FROM "{table}" ORDER BY {order}'))[1]
    return result


def validate_reference_hashes(hashes: dict[str, str]) -> dict[str, str]:
    """Accept the documented Library relocation only when file bytes are identical."""
    result = {}
    for filename, expected in hashes.items():
        source = Path(filename)
        if not source.is_file() and source.is_relative_to(COMPANION):
            relocated = COMPANION / "Library" / source.relative_to(COMPANION)
            if relocated.is_file():
                source = relocated
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Reference changed since enrichment: {source}; run refresh_local")
        result[str(source)] = expected
    return result


def check_freshness(path: Path, con: sqlite3.Connection) -> None:
    sidecar = Path(str(path) + ".local-build.json")
    if not sidecar.is_file():
        raise ValueError("Local build provenance missing; run refresh_local before mirroring")
    build = json.loads(sidecar.read_text(encoding="utf-8"))
    if build.get("version") != VERSION or build.get("corpus_hashes") != corpus_hashes(con):
        raise ValueError("Corpus changed since enrichment; run refresh_local before mirroring")
    validate_reference_hashes(build["reference_hashes"])


def connect_server(server: str = "(local)", database: str = "BlueBooks"):
    import pyodbc
    available = pyodbc.drivers()
    driver = next((d for d in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server") if d in available), None)
    if not driver:
        raise RuntimeError("Microsoft ODBC Driver 17/18 is required")
    if server.lower() == "(local)":
        server = "localhost"
    return pyodbc.connect(
        f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};Trusted_Connection=yes;"
        "Encrypt=yes;TrustServerCertificate=yes", timeout=10,
    )


def backup_databases(path: Path, directory: Path, server: str | None = None,
                     database: str = "BlueBooks") -> dict:
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    sqlite_backup = directory / f"bluebooks-{stamp}.db"
    with closing(connect_sqlite(path, readonly=True)) as src, closing(sqlite3.connect(sqlite_backup)) as dst:
        src.backup(dst)
        integrity = dst.execute("PRAGMA quick_check").fetchall()
        if integrity != [("ok",)]:
            raise ValueError(f"SQLite backup integrity check failed: {sqlite_backup}: {integrity}")
    result = {"sqlite_backup": str(sqlite_backup)}
    if server:
        with closing(connect_server(server, database)) as cn:
            cn.autocommit = True
            cur = cn.cursor()
            folder = cur.execute("SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(4000))").fetchone()[0]
            if not folder:
                raise RuntimeError("SQL Server default backup directory is unavailable")
            target = str(Path(folder) / f"BlueBooks-local-parity-{stamp}.bak")
            db = database.replace("]", "]]")
            cur.execute(f"BACKUP DATABASE [{db}] TO DISK=? WITH COPY_ONLY, CHECKSUM", target)
            while cur.nextset():
                pass
            cur.execute("RESTORE VERIFYONLY FROM DISK=? WITH CHECKSUM", target)
            while cur.nextset():
                pass
            result["sqlserver_backup"] = target
    return result


def _server_columns(cur, table: str) -> list[tuple]:
    return list(cur.execute(
        "SELECT c.name,ty.name,c.max_length,c.is_identity,c.is_nullable FROM sys.columns c "
        "JOIN sys.types ty ON ty.user_type_id=c.user_type_id "
        "WHERE c.object_id=OBJECT_ID(?) AND c.is_computed=0 ORDER BY c.column_id",
        f"dbo.{table}",
    ))


def _server_type(name: str, kind: str, table: str | None = None) -> str:
    if name in ("observation_key", "evaluation_key", "candidate_key", "decision_key",
                "target_key", "reference_key", "reference_sha256", "evidence_hash",
                "legacy_match_key"):
        return "NVARCHAR(64)"
    if name in ("edition", "matcher_version", "scope", "outcome", "context_class",
                "term_origin", "extraction_tier", "evidence_tier"):
        return "NVARCHAR(60)"
    if name in ("candidateTermUS", "candidateTermNormUS"):
        return "NVARCHAR(600)"
    if name == "migration_key":
        return "NVARCHAR(100)"
    if table == "books" and name == "alias":
        return "NVARCHAR(250)"
    if table in term_recovery.TABLES:
        if name in ("provenance_key", "match_key", "reference_sha256"):
            return "NVARCHAR(64)"
        if name in ("edition", "code"):
            return "NVARCHAR(40)"
        if name in ("source_kind", "source_table", "suggested_qualifier",
                    "terminology_status", "review_status", "match_type", "proposal_batch"):
            return "NVARCHAR(60)"
        if name in ("recovered_term", "official_term", "official_termUS", "official_termNormUS"):
            return "NVARCHAR(600)"
    if table == "entity_identifiers" and name == "source_heading":
        return "NVARCHAR(100)"
    if table == "enum_values":
        if name in ("enum_group", "enum_value"):
            return "NVARCHAR(60)"
        return "NVARCHAR(MAX)"
    if "INT" in kind.upper() or name in ("parent_mention_id", "line_indent"):
        return "INT"
    if "DECIMAL" in kind.upper():
        return kind
    if name.endswith("_at"):
        return "DATETIME2"
    if name in ("icdo_code", "icdo_code_raw", "icdo_code_hint", "code", "c_code",
                "icdo4", "icdo4_code", "icdo32_code", "morph_beh", "system", "identifier"):
        return "NVARCHAR(40)"
    if name == "url":
        return "NVARCHAR(1000)"
    if name in ("term_clean", "term", "term_norm", "title_norm", "term_original_norm",
                "TermUS", "TermNorm", "TermNormUS", "official_termNormUS"):
        return "NVARCHAR(600)"
    if name in ("evidence_policy", "source_kind", "source_sheet", "site_specific_flag", "section_flag", "provenance", "kind",
                "term_role", "term_source", "extraction_method", "code_origin", "review_status", "reviewed_by",
                "enum_group", "enum_value"):
        return "NVARCHAR(60)"
    return "NVARCHAR(MAX)"


def _foreign_key_name(table: str, child_column: str, parent_table: str) -> str:
    return f"fk_local_{table}_{child_column}_{parent_table}"


def _available_object_name(cur, requested: str) -> str:
    name = requested
    suffix = 1
    while cur.execute("SELECT 1 FROM sys.objects WHERE name=?", name).fetchone():
        name = f"{requested}_local{suffix}"
        suffix += 1
    return name


def server_default(default: str | None) -> str:
    if default is None:
        return ""
    if re.fullmatch(r"\(*\s*datetime\(\s*'now'\s*\)\s*\)*", default, re.I):
        return " DEFAULT SYSUTCDATETIME()"
    if "datetime(" in default.lower():
        raise ValueError(f"Unsupported SQLite default for SQL Server: {default}")
    return f" DEFAULT {default}"


def server_indexes(cur, table: str) -> list[dict]:
    if table not in TABLES:
        raise ValueError(f"Unmanaged table: {table}")
    rows = list(cur.execute(
        "SELECT name,index_id,type,is_unique,is_primary_key,is_unique_constraint,"
        "has_filter,filter_definition,is_disabled,fill_factor,is_padded,ignore_dup_key,"
        "allow_row_locks,allow_page_locks,data_space_id FROM sys.indexes "
        "WHERE object_id=OBJECT_ID(?) AND index_id>0", f"dbo.{table}"
    ))
    result = []
    for row in rows:
        parts = list(cur.execute(
            "SELECT c.name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column "
            "FROM sys.index_columns ic JOIN sys.columns c "
            "ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
            "WHERE ic.object_id=OBJECT_ID(?) AND ic.index_id=? ORDER BY ic.key_ordinal,c.name",
            f"dbo.{table}", row[1],
        ))
        result.append({
            "name": row[0], "id": row[1], "type": row[2], "unique": bool(row[3]),
            "protected": bool(row[4] or row[5]), "filter": row[7],
            "disabled": bool(row[8]), "options": tuple(row[9:]),
            "keys": tuple((r[0], bool(r[2])) for r in parts if r[1] > 0),
            "include": tuple(sorted(r[0] for r in parts if r[3])),
            "compression": tuple(r[0] for r in cur.execute(
                "SELECT data_compression FROM sys.partitions WHERE object_id=OBJECT_ID(?) "
                "AND index_id=? ORDER BY partition_number", f"dbo.{table}", row[1])),
        })
    return result


def index_covers(index: dict, cols: list[str], unique: bool) -> bool:
    return (index["type"] in (1, 2) and not index["disabled"]
            and index["filter"] is None
            and index["keys"] == tuple((c, False) for c in cols)
            and (index["unique"] or not unique))


def consolidate_server_indexes(cur) -> None:
    # Only remove the two reviewed ordinary indexes; never drop constraints/clustered keys.
    for table, redundant in (("pages", "ux_local_pages_url"),
                             ("page_icdo_codes", "ix_page_icdo_codes_code")):
        indexes = server_indexes(cur, table)
        victim = next((i for i in indexes if i["name"] == redundant), None)
        if victim is None:
            continue
        candidates = [i for i in indexes if i["name"] != redundant
                      and not i["disabled"] and i["type"] in (1, 2)
                      and all(i[k] == victim[k] for k in
                              ("unique", "filter", "keys", "include", "options", "compression"))]
        if not candidates:
            continue
        if victim["protected"] or victim["type"] != 2:
            raise ValueError(f"Cannot safely consolidate {table}.{redundant}: definition drift")
        dependency = cur.execute(
            "SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID(?) AND key_index_id=? "
            "UNION ALL SELECT 1 FROM sys.fulltext_indexes WHERE object_id=OBJECT_ID(?) AND unique_index_id=?",
            f"dbo.{table}", victim["id"], f"dbo.{table}", victim["id"],
        ).fetchone()
        if dependency:
            raise ValueError(f"Index has a constraint/full-text dependency: {table}.{redundant}")
        cur.execute(f"DROP INDEX [{redundant}] ON dbo.[{table}]")


def ensure_server_schema(src: sqlite3.Connection, cn) -> None:
    """Create missing managed tables and indexes; never inspect/alter activity schemas."""
    cur = cn.cursor()
    identifier_key_index = "ux_local_entity_identifiers_page_id_system_identifier_term"
    if identifier_key_index in {i["name"] for i in server_indexes(cur, "entity_identifiers")}:
        index = next(i for i in server_indexes(cur, "entity_identifiers")
                     if i["name"] == identifier_key_index)
        if index["protected"]:
            raise ValueError("Cannot migrate protected entity_identifiers unique key")
        dependency = cur.execute(
            "SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id=OBJECT_ID(?) AND key_index_id=? "
            "UNION ALL SELECT 1 FROM sys.fulltext_indexes WHERE object_id=OBJECT_ID(?) AND unique_index_id=?",
            "dbo.entity_identifiers", index["id"], "dbo.entity_identifiers", index["id"],
        ).fetchone()
        if dependency:
            raise ValueError("Legacy entity_identifiers index has a constraint/full-text dependency")
        cur.execute("DROP INDEX [ux_local_entity_identifiers_page_id_system_identifier_term] "
                    "ON dbo.[entity_identifiers]")
    for table in TABLES:
        info = src.execute(f'PRAGMA table_info("{table}")').fetchall()
        if not _server_columns(cur, table):
            pk = sorted((r for r in info if r[5]), key=lambda r: r[5])
            declarations = []
            for _, name, kind, required, default, _ in info:
                typ = _server_type(name, kind, table)
                nullable = "NOT NULL" if required or name in [r[1] for r in pk] else "NULL"
                declarations.append(f"[{name}] {typ} {nullable}" + server_default(default))
            if pk:
                declarations.append("PRIMARY KEY (" + ",".join(f"[{r[1]}]" for r in pk) + ")")
            cur.execute(f"CREATE TABLE dbo.[{table}] (" + ",".join(declarations) + ")")
        existing = {r[0] for r in _server_columns(cur, table)}
        if table == "page_icdo_codes":
            cur.execute("SELECT c.is_nullable FROM sys.columns c WHERE c.object_id=OBJECT_ID('dbo.page_icdo_codes') AND c.name='icdo_code'")
            row = cur.fetchone()
            if row and not row[0]:
                cur.execute(
                    "SELECT i.name FROM sys.indexes i "
                    "JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id "
                    "JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
                    "WHERE i.object_id=OBJECT_ID('dbo.page_icdo_codes') AND c.name='icdo_code'"
                )
                for (idx_name,) in cur.fetchall():
                    cur.execute(f"DROP INDEX [{idx_name}] ON dbo.[page_icdo_codes]")
                cur.execute("ALTER TABLE dbo.[page_icdo_codes] ALTER COLUMN [icdo_code] NVARCHAR(40) NULL")
        if "TermNorm" in existing and "TermNormUS" not in existing and "TermNormUS" in [r[1] for r in info]:
            cur.execute(
                "SELECT i.name FROM sys.indexes i "
                "JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id "
                "JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id "
                "WHERE i.object_id=OBJECT_ID(?) AND c.name='TermNorm'",
                f"dbo.{table}",
            )
            for (idx_to_drop,) in cur.fetchall():
                cur.execute(f"DROP INDEX [{idx_to_drop}] ON dbo.[{table}]")
            cur.execute(f"EXEC sp_rename 'dbo.[{table}].[TermNorm]', 'TermNormUS', 'COLUMN'")
            existing.remove("TermNorm")
            existing.add("TermNormUS")
        for _, name, kind, required, _, _ in info:
            if name not in existing:
                if not ((table == "pages" and name in ("title_norm", "icdo_code_hint"))
                        or (table == "books" and name == "alias")
                        or (table == "sections" and name == "source_anchor")
                        or (table == "entity_identifiers" and name == "source_kind")
                        or (table == "entity_term_code_matches" and name in ("official_termUS", "official_termNormUS"))
                        or (table == "entity_term_provenance" and name in ("TermUS", "TermNormUS"))
                        or (table in term_hygiene.TERM_SOURCES and name in term_hygiene.TERM_COLUMNS)
                        or (table == "page_icdo_codes" and name in ("term_role", "term_source", "line_indent"))
                        or (table == "page_term_mentions" and name in ("url", "term_source", "extraction_method", "term_role", "code_origin", "parent_mention_id", "review_status", "reviewed_by", *term_pipeline.MENTION_COLUMNS))
                        or (table == "entity_codes" and name == "term_role")
                        or (table == "entity_related_terms" and name == "term_role")):
                    raise ValueError(f"Unexpected SQL Server schema drift: {table}.{name}")
                if table == "entity_identifiers" and name == "source_kind":
                    cur.execute(
                        "ALTER TABLE dbo.[entity_identifiers] ADD [source_kind] "
                        "NVARCHAR(60) NOT NULL CONSTRAINT "
                        "[DF_entity_identifiers_source_kind] DEFAULT N'section_text' WITH VALUES"
                    )
                else:
                    cur.execute(
                        f"ALTER TABLE dbo.[{table}] ADD [{name}] "
                        f"{_server_type(name, kind, table)} NULL"
                    )
        extra = existing - {r[1] for r in info}
        if extra:
            raise ValueError(f"Unmapped SQL Server columns in {table}: {sorted(extra)}")
        if table == "entity_identifiers":
            heading_type = next(r for r in _server_columns(cur, table)
                                if r[0] == "source_heading")
            if heading_type[1] == "nvarchar" and heading_type[2] != 200:
                max_heading = src.execute(
                    "SELECT MAX(length(source_heading)) FROM entity_identifiers"
                ).fetchone()[0] or 0
                if max_heading > 100:
                    raise ValueError(
                        "entity_identifiers.source_heading exceeds the 100-character "
                        "SQL Server index-key limit"
                    )
                cur.execute(
                    "ALTER TABLE dbo.[entity_identifiers] ALTER COLUMN "
                    "[source_heading] NVARCHAR(100) NOT NULL"
                )
    # Core null defaults intentionally remain backend-compatible rather than tightening live source rows.
    for table in TABLES:
        indexes = server_indexes(cur, table)
        for index in src.execute(f'PRAGMA index_list("{table}")'):
            name = index[1]
            if index[3] == "pk":
                continue
            cols = [r[2] for r in src.execute(f'PRAGMA index_info("{name}")')]
            if name.startswith("sqlite_"):
                name = f"ux_local_{table}_" + "_".join(cols)
            nullable_observation = table == "page_term_mentions" and cols == ["observation_key"]
            if nullable_observation and any(
                i["unique"] and i["keys"] == (("observation_key", False),)
                and re.sub(r"[\s\[\]()]", "", i["filter"] or "").casefold() == "observation_keyisnotnull"
                for i in indexes
            ):
                continue
            if not nullable_observation and any(index_covers(i, cols, bool(index[2])) for i in indexes):
                continue
            if any(i["name"] == name for i in indexes):
                raise ValueError(f"Index definition drift: {table}.{name}")
            cur.execute(f"CREATE {'UNIQUE ' if index[2] else ''}INDEX [{name}] ON dbo.[{table}] (" +
                        ",".join(f"[{c}]" for c in cols) + ")" +
                        (" WHERE [observation_key] IS NOT NULL" if nullable_observation else ""))
            indexes = server_indexes(cur, table)
    consolidate_server_indexes(cur)
    for table in TABLES:
        for fk in src.execute(f'PRAGMA foreign_key_list("{table}")'):
            parent, child_col, parent_col = fk[2], fk[3], fk[4]
            if parent not in TABLES:
                continue
            exists = cur.execute(
                "SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID(?) "
                "AND referenced_object_id=OBJECT_ID(?) AND "
                "COL_NAME(parent_object_id,parent_column_id)=? AND "
                "COL_NAME(referenced_object_id,referenced_column_id)=?",
                f"dbo.{table}", f"dbo.{parent}", child_col, parent_col,
            ).fetchone()
            if not exists:
                name = _foreign_key_name(table, child_col, parent)
                cur.execute(f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT "
                            f"[{name}] FOREIGN KEY ([{child_col}]) "
                            f"REFERENCES dbo.[{parent}] ([{parent_col}])")
    for table, col, check in (
        ("entity_related_terms", "kind", "[kind] IN ('acceptable','not_recommended','other')"),
        ("entity_codes", "is_subtype", "[is_subtype] IN (0,1)"),
        ("cpc_curation", "is_icdo41", "[is_icdo41] IN (0,1)"),
        ("entity_identifiers", "system", "[system] IN ('OMIM')"),
    ):
        base_name = f"ck_local_{table}_{col}"
        existing_names = {
            row[0] for row in cur.execute(
                "SELECT name FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(?)",
                f"dbo.{table}",
            )
        }
        if not any(name == base_name or name.startswith(base_name + "_local")
                   for name in existing_names):
            name = _available_object_name(cur, base_name)
            cur.execute(f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT [{name}] CHECK ({check})")
    for table, checks in (term_recovery.server_checks() | term_pipeline.server_checks()).items():
        for label, check in checks.items():
            name = f"ck_local_{table}_{label}"
            if not cur.execute(
                "SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(?) AND name=?",
                f"dbo.{table}", name,
            ).fetchone():
                cur.execute(f"ALTER TABLE dbo.[{table}] WITH CHECK ADD CONSTRAINT [{name}] CHECK ({check})")
    for batch in re.split(r"(?im)^\s*GO\s*$", term_recovery.view_sql(sqlserver=True)):
        if batch.strip():
            cur.execute(batch)
    for batch in re.split(r"(?im)^\s*GO\s*$", term_pipeline.view_sql(sqlserver=True)):
        if batch.strip():
            cur.execute(batch)
    cur.execute(
        "CREATE OR ALTER TRIGGER dbo.tr_term_review_append_only ON dbo.term_review_decisions "
        "INSTEAD OF UPDATE, DELETE AS BEGIN "
        "THROW 51000, 'Review decisions are append-only', 1; END"
    )
    cur.execute(
        "CREATE OR ALTER VIEW dbo.v_search AS SELECT s.section_id,s.page_id,s.heading,s.body_text,"
        "p.title,p.page_type,p.url,p.book_id,b.title AS book_title,b.edition "
        "FROM dbo.sections s JOIN dbo.pages p ON p.page_id=s.page_id JOIN dbo.books b ON b.book_id=p.book_id"
    )
    for batch in re.split(r"(?im)^\s*GO\s*$", (ROOT / "00_dbo_Clean.sql").read_text(encoding="utf-8")):
        if batch.strip():
            cur.execute(batch)
    # Install the exact spelling/comparison composition before write-time maintenance.
    for script in (term_hygiene.normalizer_sql(),
                   (ROOT / "00_dbo_Clean2.sql").read_text(encoding="utf-8")):
        for batch in re.split(r"(?im)^\s*GO\s*$", script):
            if batch.strip():
                cur.execute(batch)
    for table in term_hygiene.TERM_SOURCES:
        cur.execute(term_hygiene.server_trigger_sql(table))
    for table in term_hygiene.DISPLAY_COLUMNS:
        cur.execute(term_hygiene.server_display_trigger_sql(table))
    cn.commit()


def _value(value):
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc).isoformat(timespec="microseconds")
    if isinstance(value, str):
        # Compare persisted UTC datetimes consistently across backend representations.
        if re.match(r"^\d{4}-\d{2}-\d{2}[ T]\d{2}:", value):
            try:
                return datetime.fromisoformat(value).replace(tzinfo=timezone.utc).isoformat(timespec="microseconds")
            except ValueError:
                return value
    if isinstance(value, bool):
        return str(int(value))
    if isinstance(value, (Decimal, float, int)):
        return format(Decimal(str(value)).normalize(), "f")
    return value


def _row_bytes(row) -> bytes:
    return (json.dumps([_value(v) for v in row], ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def table_digest(rows) -> tuple[int, str]:
    digest = hashlib.sha256()
    count = 0
    for row in rows:
        digest.update(_row_bytes(row))
        count += 1
    return count, digest.hexdigest()


def verify_parity(src: sqlite3.Connection, cn, *, include_book70: bool = False) -> dict:
    cur = cn.cursor()
    results = {}
    for table in TABLES:
        cols = columns(src, table)
        meta = _server_columns(cur, table)
        if {r[0] for r in meta} != set(cols):
            raise ValueError(f"Column mismatch: {table}")
        pk = [r[1] for r in sorted(src.execute(f'PRAGMA table_info("{table}")'), key=lambda r: r[5]) if r[5]]
        order = ",".join(f"[{c}]" for c in pk)
        names = ",".join(f"[{c}]" for c in cols)
        where = " WHERE book_id<>70" if table == "books" and not include_book70 else ""
        hashes, counts = [], []
        for rows in (src.execute(f"SELECT {names} FROM [{table}]{where} ORDER BY {order}"),
                     cur.execute(f"SELECT {names} FROM dbo.[{table}]{where} ORDER BY {order}")):
            digest = hashlib.sha256()
            count = 0
            for row in rows:
                digest.update(_row_bytes(row))
                count += 1
            hashes.append(digest.hexdigest())
            counts.append(count)
        results[table] = {"sqlite": counts[0], "sqlserver": counts[1],
                          "match": hashes[0] == hashes[1], "sha256": hashes[0]}
    failures = [t for t, r in results.items() if not r["match"]]
    if failures:
        raise ValueError(f"Row-value parity failed: {failures}")
    return results


def mirror(path: Path, server: str = "(local)", database: str = "BlueBooks",
           *, include_book70: bool = False) -> dict:
    with ExitStack() as stack:
        src = stack.enter_context(closing(connect_sqlite(path, readonly=True)))
        src.execute("BEGIN")
        check_freshness(path, src)
        cn = stack.enter_context(closing(connect_server(server, database)))
        ensure_server_schema(src, cn)
        cur = cn.cursor()
        # Preflight payload lengths and FK integrity before clearing any target rows.
        if src.execute("PRAGMA foreign_key_check").fetchone():
            raise ValueError("Source SQLite FK violations")
        for table in TABLES:
            for name, kind, size, _, required in _server_columns(cur, table):
                if kind in ("nvarchar", "varchar") and size != -1:
                    limit = size // 2 if kind == "nvarchar" else size
                    length = src.execute(f'SELECT MAX(length("{name}")) FROM "{table}"').fetchone()[0] or 0
                    if length > limit:
                        # Existing bounded enrichment fields may be narrower than valid local extraction.
                        cur.execute(f"ALTER TABLE dbo.[{table}] ALTER COLUMN [{name}] {kind}(MAX) " +
                                    ("NULL" if required else "NOT NULL"))
        cn.commit()
        try:
            unchanged = set()
            for table in TABLES:
                cols = columns(src, table)
                pk = [r[1] for r in src.execute(f'PRAGMA table_info("{table}")') if r[5]]
                names = ",".join(f"[{c}]" for c in cols)
                order = ",".join(f"[{c}]" for c in pk)
                where = " WHERE book_id<>70" if table == "books" and not include_book70 else ""
                a = table_digest(src.execute(f"SELECT {names} FROM [{table}]{where} ORDER BY {order}"))
                b = table_digest(cur.execute(f"SELECT {names} FROM dbo.[{table}]{where} ORDER BY {order}"))
                if a == b:
                    unchanged.add(table)
            # Derived FK dependencies must be refreshed together.
            if any(t not in unchanged for t in DERIVED):
                unchanged.difference_update(t for t in DERIVED if t != "term_review_decisions")
            for table in reversed(TABLES):
                # Preserve manual overlay and core corpus; canonical update/insert below.
                if table not in unchanged and table not in ("cpc_curation", "books", "chapters", "page_groups", "pages",
                                 "sections", "authors", "images", "page_links", "references",
                                 "term_review_decisions"):
                    cur.execute(f"DELETE FROM dbo.[{table}]")
            for table in TABLES:
                if table in unchanged:
                    print(f"Mirror {table}: already identical", flush=True)
                    continue
                cur = cn.cursor()
                cols = columns(src, table)
                pk = [r[1] for r in src.execute(f'PRAGMA table_info("{table}")') if r[5]]
                identity = any(r[3] for r in _server_columns(cur, table))
                names = ",".join(f"[{c}]" for c in cols)
                where = " WHERE book_id<>70" if table == "books" and not include_book70 else ""
                rows = src.execute(f"SELECT {names} FROM [{table}]{where}")
                retained = table not in DERIVED or table == "term_review_decisions"
                if identity:
                    cur.execute(f"SET IDENTITY_INSERT dbo.[{table}] ON")
                try:
                    nonkey = [c for c in cols if c not in pk]
                    condition = " AND ".join(f"[{c}]=?" for c in pk)
                    if not retained and table != "page_search_documents":
                        # Explicit bounded bindings avoid the variable-length MAX driver crash.
                        import pyodbc
                        server_meta = {r[0]: r for r in _server_columns(cur, table)}
                        meta = [server_meta[c] for c in cols]
                        cur.fast_executemany = True
                        while chunk := rows.fetchmany(500):
                            bindings = []
                            for i, (_, kind, _, _, _) in enumerate(meta):
                                if kind in ("nvarchar", "varchar"):
                                    size = max((len(str(r[i])) for r in chunk if r[i] is not None), default=1)
                                    sql_type = pyodbc.SQL_WLONGVARCHAR if size > 4000 else pyodbc.SQL_WVARCHAR
                                    bindings.append((sql_type, max(size, 1), 0))
                                elif kind == "datetime2":
                                    # ISO text avoids driver-dependent datetime2 precision binding.
                                    bindings.append((pyodbc.SQL_WVARCHAR, 27, 0))
                                elif kind == "decimal":
                                    bindings.append((pyodbc.SQL_DECIMAL, 10, 2))
                                else:
                                    bindings.append((pyodbc.SQL_INTEGER, 0, 0))
                            cur.setinputsizes(bindings)
                            cur.executemany(f"INSERT INTO dbo.[{table}] ({names}) VALUES (" +
                                            ",".join("?" for _ in cols) + ")", [
                                                tuple(datetime.fromisoformat(v).replace(tzinfo=None).isoformat(timespec="microseconds")
                                                      if meta[i][1] == "datetime2" and isinstance(v, str) else v
                                                      for i, v in enumerate(row)) for row in chunk
                                            ])
                        cur.fast_executemany = False
                        cur.setinputsizes(None)
                    for row in rows if retained or table == "page_search_documents" else ():
                        values = dict(zip(cols, row))
                        if retained and cur.execute(f"SELECT 1 FROM dbo.[{table}] WHERE {condition}",
                                                    *[values[c] for c in pk]).fetchone():
                            if table in ("cpc_curation", "term_review_decisions"):
                                target = cur.execute(f"SELECT {names} FROM dbo.[{table}] WHERE {condition}",
                                                     *[values[c] for c in pk]).fetchone()
                                if _row_bytes(target) != _row_bytes(row):
                                    raise ValueError(f"{table} conflict: reconcile manually before mirroring")
                            elif nonkey:
                                target = cur.execute(f"SELECT {names} FROM dbo.[{table}] WHERE {condition}",
                                                     *[values[c] for c in pk]).fetchone()
                                changed = [c for c, v in zip(cols, target) if c not in pk and
                                           _row_bytes([v]) != _row_bytes([values[c]])]
                                if changed:
                                    cur.execute(f"UPDATE dbo.[{table}] SET " +
                                                ",".join(f"[{c}]=?" for c in changed) + f" WHERE {condition}",
                                                *[values[c] for c in changed + pk])
                        else:
                            cur.execute(f"INSERT INTO dbo.[{table}] ({names}) VALUES (" +
                                        ",".join("?" for _ in cols) + ")", *row)
                finally:
                    if identity:
                        cur.execute(f"SET IDENTITY_INSERT dbo.[{table}] OFF")
                print(f"Mirror {table}: copied", flush=True)
            if "sections" not in unchanged:
                cur.execute(
                    "DELETE s FROM dbo.sections s "
                    "JOIN dbo.entity_pages e ON e.page_id=s.page_id "
                    "WHERE NULLIF(LTRIM(RTRIM(s.body_text)),N'') IS NULL "
                    "AND s.section_id NOT IN ("
                    "SELECT section_id FROM dbo.images WHERE section_id IS NOT NULL "
                    "UNION SELECT section_id FROM dbo.[references] WHERE section_id IS NOT NULL)"
                )
            # Value-level verification occurs inside the transaction; mismatch rolls back data.
            result = verify_parity(src, cn, include_book70=include_book70)
            cn.commit()
        except Exception:
            cn.rollback()
            raise
        return result


def server_search(cn, *, timeout: int = 240) -> dict:
    cn.commit()
    cn.autocommit = True
    cur = cn.cursor()
    if not cur.execute("SELECT CAST(SERVERPROPERTY('IsFullTextInstalled') AS int)").fetchone()[0]:
        raise RuntimeError("SQL Server Full-Text Search is not installed")
    cur.execute("IF NOT EXISTS(SELECT 1 FROM sys.fulltext_catalogs WHERE name='BlueBooksFT') "
                "CREATE FULLTEXT CATALOG BlueBooksFT")
    for table, expected in (("sections", ("heading", "body_text")),
                            ("pages", ("title",)),
                            ("page_search_documents", ("title", "full_text"))):
        existing = {r[0] for r in cur.execute(
            "SELECT c.name FROM sys.fulltext_index_columns f JOIN sys.columns c "
            "ON c.object_id=f.object_id AND c.column_id=f.column_id WHERE f.object_id=OBJECT_ID(?)",
            f"dbo.{table}",
        )}
        if existing and existing != set(expected):
            raise ValueError(f"Unexpected full-text columns: {table}: {existing}")
        if not existing:
            key = cur.execute(
                "SELECT name FROM sys.indexes WHERE object_id=OBJECT_ID(?) AND is_primary_key=1",
                f"dbo.{table}",
            ).fetchone()
            if not key:
                raise RuntimeError(f"Full-text key missing: {table}")
            cur.execute(f"CREATE FULLTEXT INDEX ON dbo.[{table}] (" +
                        ",".join(f"[{c}] LANGUAGE 1033" for c in expected) +
                        f") KEY INDEX [{key[0]}] ON BlueBooksFT WITH CHANGE_TRACKING AUTO")
        else:
            cur.execute(f"ALTER FULLTEXT INDEX ON dbo.[{table}] ENABLE")
            cur.execute(f"ALTER FULLTEXT INDEX ON dbo.[{table}] SET CHANGE_TRACKING AUTO")
    deadline = time.monotonic() + timeout
    while True:
        states = list(cur.execute(
            "SELECT OBJECT_NAME(object_id),CAST(OBJECTPROPERTYEX(object_id,'TableFulltextPopulateStatus') AS int),"
            "CAST(OBJECTPROPERTYEX(object_id,'TableFulltextPendingChanges') AS bigint),has_crawl_completed "
            "FROM sys.fulltext_indexes WHERE object_id IN "
            "(OBJECT_ID('dbo.sections'),OBJECT_ID('dbo.pages'),OBJECT_ID('dbo.page_search_documents'))"
        ))
        if len(states) == 3 and all(r[1] == 0 and r[2] == 0 and r[3] for r in states):
            break
        if time.monotonic() >= deadline:
            raise TimeoutError(f"Full-text population did not complete: {states}")
        time.sleep(1)
    return {table: cur.execute(
        f"SELECT COUNT_BIG(*) FROM dbo.[{table}] WHERE CONTAINS(" +
        ("(heading,body_text)" if table == "sections" else "(title,full_text)") + ",'carcinoma')"
    ).fetchone()[0] for table in ("sections", "page_search_documents")}


def search(con, query: str, *, backend: str = "sqlite", book_id: int | None = None,
           limit: int = 25):
    if not 1 <= limit <= 1000:
        raise ValueError("Search limit must be 1..1000")
    if backend == "sqlite":
        sql = ("SELECT p.page_id,p.title,p.url,d.full_text FROM pages_fts f "
               "JOIN pages p ON p.page_id=f.rowid JOIN page_search_documents d ON d.page_id=p.page_id "
               "WHERE pages_fts MATCH ?")
        params = [query]
        if book_id is not None:
            sql += " AND p.book_id=?"
            params.append(book_id)
        return con.execute(sql + " ORDER BY bm25(pages_fts),p.page_id LIMIT ?", params + [limit]).fetchall()
    if backend != "sqlserver":
        raise ValueError(f"Unknown backend: {backend}")
    sql = (f"SELECT TOP ({limit}) p.page_id,p.title,p.url,d.full_text "
           "FROM dbo.page_search_documents d JOIN dbo.pages p ON p.page_id=d.page_id "
           "WHERE CONTAINS((d.title,d.full_text),?)")
    params = [query]
    if book_id is not None:
        sql += " AND p.book_id=?"
        params.append(book_id)
    return con.cursor().execute(sql + " ORDER BY p.page_id", *params).fetchall()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sqlite", type=Path, default=ROOT / "bluebooks.db")
    parser.add_argument("--mirror", action="store_true")
    parser.add_argument("--server", default="(local)")
    parser.add_argument("--database", default="BlueBooks")
    parser.add_argument("--include-book70", action="store_true")
    parser.add_argument("--backup-dir", type=Path, default=ROOT / "local_backups")
    args = parser.parse_args()
    backups = backup_databases(args.sqlite, args.backup_dir,
                               args.server if args.mirror else None, args.database)
    print(json.dumps(backups, indent=2), flush=True)
    result = refresh_local(args.sqlite)
    summary = dict(result)
    summary["section_recovery"] = {
        key: len(value) if isinstance(value, list) else value
        for key, value in result["section_recovery"].items()
    }
    print(json.dumps(summary, indent=2), flush=True)
    print("Detailed extraction exceptions: " + str(args.sqlite) + ".local-build.json", flush=True)
    if args.mirror:
        print(json.dumps(mirror(args.sqlite, args.server, args.database,
                                include_book70=args.include_book70), indent=2), flush=True)
        with closing(connect_server(args.server, args.database)) as cn:
            print("SQL Server search:", server_search(cn), flush=True)


if __name__ == "__main__":
    main()
