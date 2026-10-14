"""Persistent recovered vocabulary; proposed mappings are never source codes."""
from __future__ import annotations

from contextlib import closing
import hashlib
import json
from pathlib import Path
import re
import sqlite3

from term_hygiene import clean_term_ending, term_keys

MANIFEST = Path(__file__).parent / "Library" / "recovered_terms.json"
TABLES = ("entity_term_provenance", "entity_term_code_matches")
REVIEW_STATUSES = {"proposed", "approved", "rejected", "needs_review"}
QUALIFIERS = {"synonym", "related", "subtype", "grouper", "other"}

BOOK_ALIAS_PREFIXES = (
    ("Digestive System", "GI"),
    ("Breast Tumours", "Breast"),
    ("Soft Tissue and Bone", "Soft tissue/bone"),
    ("Female Genital", "Female genital"),
    ("Thoracic", "Thoracic"),
    ("Urinary and Male Genital", "GU"),
    ("Paediatric", "Pediatric"),
    ("Central Nervous System", "CNS"),
    ("Head and Neck", "Head/neck"),
    ("Endocrine and Neuroendocrine", "Endocrine/NET"),
    ("Haematolymphoid", "Hematolymphoid"),
    ("Skin", "Skin"),
    ("Eye and Orbit", "Eye/orbit"),
    ("Genetic Tumour", "Genetic syndromes"),
    ("WHO Reporting System for Lung", "Lung"),
    ("WHO Reporting System for Lymph Node", "LN/spleen/thymus"),
    ("WHO Reporting System for Pancreaticobiliary", "Pancreaticobiliary"),
    ("WHO Reporting System for Soft Tissue", "Soft tissue"),
    ("WHO Reporting System for Breast", "Breast"),
)


def book_version_alias(title: str, edition: str | None) -> str:
    """Return the legacy short book/version label used by v_page_code_terms."""
    title = (title or "").strip()
    label = next(
        (alias for prefix, alias in BOOK_ALIAS_PREFIXES
         if title.casefold().startswith(prefix.casefold())),
        title,
    )
    suffix = {
        "5th": ", v5",
        "6th": ", v6",
        "cytopathology": ", cyto",
    }.get((edition or "").casefold(), "")
    return f"{label}{suffix}"


def identity(term: str) -> str:
    us, _ = term_keys(term)
    if not us:
        raise ValueError("Recovery terms must have a nonempty spelling key")
    return re.sub(r"\s+", " ", us).casefold()


def key(*parts: object) -> str:
    return hashlib.sha256(json.dumps(parts, ensure_ascii=True).encode()).hexdigest()


def load_manifest(path: Path = MANIFEST) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest["version"] != 1 or manifest["source_kind"] != "AI_recovered_prose":
        raise ValueError("Unsupported recovery manifest")
    for reference in manifest["reference_files"]:
        source = Path(reference["path"])
        if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != reference["sha256"]:
            raise ValueError(f"Recovery reference missing or changed: {source}")
    import openpyxl
    official_rows = {}
    for reference in manifest["reference_files"]:
        workbook = openpyxl.load_workbook(reference["path"], read_only=True, data_only=True)
        try:
            sheet_name = "ICD-O-3.2 Morphology" if reference["edition"] == "ICD-O-3.2" else "Morphology"
            official_rows[reference["edition"]] = {
                number: (row[0], row[2])
                for number, row in enumerate(
                    workbook[sheet_name].iter_rows(min_row=3, values_only=True), 3
                )
            }
        finally:
            workbook.close()
    for item in manifest["terms"]:
        if clean_term_ending(item["term"]) != item["term"]:
            raise ValueError(f"Recovery label contains term-list decoration: {item['term']}")
        identity(item["term"])
        if item["suggested_qualifier"] not in QUALIFIERS or not item["sources"]:
            raise ValueError(f"Invalid recovery metadata: {item['term']}")
        for match in item["matches"]:
            pattern = r"\d{4}/[013269]" if match["edition"] == "ICD-O-3.2" else r"\d{4}[0-9A-F]/[013269]"
            if not re.fullmatch(pattern, match["code"]):
                raise ValueError(f"Invalid edition-specific morphology: {match}")
            if not any(r["term"] == match["official_term"] and r["row"] == match["reference_row"]
                       for r in match["code_term_evidence"]):
                raise ValueError("Official term lacks exact reference-row evidence")
            if official_rows[match["edition"]].get(match["reference_row"]) != (match["code"], match["official_term"]):
                raise ValueError(f"Official workbook row disagrees with recovery mapping: {match}")
            for evidence in match["code_term_evidence"]:
                if official_rows[match["edition"]].get(evidence["row"]) != (match["code"], evidence["term"]):
                    raise ValueError("Code-associated synonym evidence disagrees with official workbook")
    return manifest


def reference_hashes(manifest: dict, path: Path = MANIFEST) -> dict[str, str]:
    return {str(path): hashlib.sha256(path.read_bytes()).hexdigest(),
            **{r["path"]: r["sha256"] for r in manifest["reference_files"]}}


def snapshot_reviews(con: sqlite3.Connection) -> dict:
    return {
        "provenance": {row[0]: tuple(row[1:]) for row in con.execute(
            "SELECT provenance_key,review_status,suggested_qualifier,note FROM entity_term_provenance")},
        "matches": {row[0]: tuple(row[1:]) for row in con.execute(
            "SELECT match_key,review_status FROM entity_term_code_matches")},
    }


def plan(con: sqlite3.Connection, manifest: dict) -> list[dict]:
    existing: dict[tuple[int, str], list[tuple[str, int, str]]] = {}
    for table, pk in (("entity_codes", "entity_code_id"),
                      ("entity_related_terms", "related_term_id")):
        for row_id, page_id, term in con.execute(f"SELECT {pk},page_id,term FROM {table} ORDER BY {pk}"):
            existing.setdefault((page_id, identity(term)), []).append((table, row_id, term))
    result: dict[tuple[int, str], dict] = {}
    pages = {r[0]: r[1] for r in con.execute("SELECT page_id,title FROM entity_pages")}
    for item in manifest["terms"]:
        for source in item["sources"]:
            page_id = source["page_id"]
            if page_id not in pages:
                raise ValueError(f"Recovery requires original entity page {page_id}")
            if pages[page_id] != source["page_title"]:
                raise ValueError(f"Recovery page title changed: {page_id}")
            group = (page_id, identity(item["term"]))
            row = result.setdefault(group, {
                "page_id": page_id, "term": item["term"],
                "term_key": key(*group), "item": item,
                "existing": existing.get(group, []), "sources": [],
            })
            if source not in row["sources"]:
                row["sources"].append(source)
            if row["item"]["matches"] != item["matches"]:
                raise ValueError(f"Conflicting recovery mappings for {group}")
    return list(result.values())


def populate(con: sqlite3.Connection, manifest: dict, reviews: dict | None = None) -> dict:
    """Idempotent within caller's transaction; refresh re-links regenerated IDs."""
    reviews = reviews or snapshot_reviews(con)
    rows = plan(con, manifest)
    added = provenance_added = matches_added = 0
    for row in rows:
        item = row["item"]
        if row["existing"]:
            table, row_id, _ = row["existing"][0]
            was_added = con.execute(
                "SELECT MAX(is_added_term) FROM entity_term_provenance "
                "WHERE page_id=? AND (entity_code_id=? OR related_term_id=?)",
                (row["page_id"], row_id if table == "entity_codes" else None,
                 row_id if table == "entity_related_terms" else None),
            ).fetchone()[0] or 0
        else:
            table = "entity_related_terms"
            row_id = con.execute(
                "INSERT INTO entity_related_terms(page_id,kind,term) VALUES(?,'other',?)",
                (row["page_id"], row["term"]),
            ).lastrowid
            was_added = 1
            added += 1
        target = (row_id, None) if table == "entity_codes" else (None, row_id)
        anchor = None
        for source in row["sources"]:
            provenance_key = key(row["term_key"], source["table"], source["row_id"])
            saved = reviews["provenance"].get(provenance_key)
            review, qualifier, note = saved or ("proposed", item["suggested_qualifier"], item["note"])
            found = con.execute(
                "SELECT provenance_id FROM entity_term_provenance WHERE provenance_key=?",
                (provenance_key,),
            ).fetchone()
            if found:
                provenance_id = found[0]
            else:
                provenance_id = con.execute(
                    "INSERT INTO entity_term_provenance "
                    "(provenance_key,page_id,entity_code_id,related_term_id,source_kind,source_table,"
                    "source_row_id,original_text,recovered_term,suggested_qualifier,terminology_status,"
                    "review_status,is_added_term,proposal_batch,note) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    (provenance_key, row["page_id"], *target, manifest["source_kind"],
                     source["table"], source["row_id"], source["original_text"], row["term"],
                     qualifier, item["terminology_status"], review, was_added, manifest["batch"], note),
                ).lastrowid
                provenance_added += 1
            if anchor is None:
                anchor = provenance_id
        for match in item["matches"]:
            match_key = key(row["term_key"], match["edition"], match["code"], match["reference_row"])
            if con.execute("SELECT 1 FROM entity_term_code_matches WHERE match_key=?", (match_key,)).fetchone():
                continue
            review = reviews["matches"].get(match_key, ("proposed",))[0]
            con.execute(
                "INSERT INTO entity_term_code_matches "
                "(match_key,provenance_id,edition,code,official_term,match_type,candidate_order,"
                "conditions,reference_file,reference_sheet,reference_row,reference_sha256,"
                "code_term_evidence,review_status) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (match_key, anchor, match["edition"], match["code"], match["official_term"],
                 match["match_type"], match["candidate_order"], match["conditions"],
                 match["reference_file"], match["reference_sheet"], match["reference_row"],
                 match["reference_sha256"], json.dumps(match["code_term_evidence"], ensure_ascii=True), review),
            )
            matches_added += 1
    validate(con)
    return {"new_related_terms": added, "new_provenance_links": provenance_added,
            "new_code_matches": matches_added, "page_terms": len(rows)}


def view_sql(*, sqlserver: bool = False) -> str:
    prefix = "dbo." if sqlserver else ""
    create = "CREATE OR ALTER VIEW" if sqlserver else "CREATE VIEW IF NOT EXISTS"
    base = f"""{create} {prefix}v_entity_terms AS
SELECT 'entity_codes' AS term_table,entity_code_id AS term_id,page_id,term,TermUS,TermNormUS,
       code AS source_code,is_subtype,
       COALESCE(term_role, CASE WHEN is_subtype=1 THEN 'subtype' ELSE 'preferred' END) AS term_role,
       'coding' AS terminology_kind
FROM {prefix}entity_codes
UNION ALL
SELECT 'entity_related_terms',related_term_id,page_id,term,TermUS,TermNormUS,
       NULL,0,
       COALESCE(term_role, CASE kind WHEN 'acceptable' THEN 'related_acceptable' WHEN 'not_recommended' THEN 'related_not_recommended' ELSE 'related_unlabeled' END),
       kind FROM {prefix}entity_related_terms"""
    provenance = f"""{create} {prefix}v_entity_term_provenance AS
SELECT t.*,p.provenance_id,p.source_kind,p.source_table,p.source_row_id,
       p.original_text,p.recovered_term,p.suggested_qualifier,p.terminology_status,
       p.review_status,p.is_added_term,p.proposal_batch,p.note
FROM {prefix}v_entity_terms t LEFT JOIN {prefix}entity_term_provenance p
ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))"""
    matches = f"""{create} {prefix}v_entity_term_code_matches AS
SELECT t.*,p.source_kind,p.suggested_qualifier,p.is_added_term,p.proposal_batch,
       m.match_id,m.edition,m.code AS suggested_code,m.official_termUS AS official_term,
       m.official_termUS AS candidateTermUS,m.official_termNormUS AS candidateTermNormUS,m.official_term AS official_term_source,m.match_type,
       m.candidate_order,m.conditions,m.review_status,m.reference_file,
       m.reference_sheet,m.reference_row,m.reference_sha256,m.code_term_evidence
FROM {prefix}v_entity_terms t
LEFT JOIN {prefix}entity_term_provenance p ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))
 AND p.provenance_id=(SELECT MIN(p2.provenance_id) FROM {prefix}entity_term_provenance p2
 WHERE p2.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND p2.entity_code_id=t.term_id) OR
  (t.term_table='entity_related_terms' AND p2.related_term_id=t.term_id)))
LEFT JOIN {prefix}entity_term_code_matches m ON m.provenance_id=p.provenance_id"""
    return ("\nGO\n" if sqlserver else ";\n").join(
        (base, provenance, matches, page_code_terms_sql(sqlserver=sqlserver))
    ) + ("\nGO\n" if sqlserver else ";\n")


def ensure_sqlite_views(con: sqlite3.Connection) -> None:
    drops = "".join(f"DROP VIEW IF EXISTS {name};\n" for name in (
        "v_page_code_terms", "v_entity_term_code_matches", "v_entity_term_provenance", "v_entity_terms",
    ))
    con.executescript(drops + view_sql())


def page_code_terms_sql(*, sqlserver: bool = False) -> str:
    """One page/edition/code/US-term row; sections and metadata may have many sources."""
    prefix = "dbo." if sqlserver else ""
    create = "CREATE OR ALTER VIEW" if sqlserver else "CREATE VIEW IF NOT EXISTS"
    length = "LEN" if sqlserver else "LENGTH"
    exact = " COLLATE Latin1_General_100_BIN2" if sqlserver else " COLLATE BINARY"

    def aggregate(value: str) -> str:
        if sqlserver:
            return f"STRING_AGG(CAST({value} AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY {value})"
        return f"GROUP_CONCAT({value},'; ' ORDER BY {value})"

    book_label = "b.alias"
    code = "NULLIF(TRIM(c.code),'')"
    page_code = "NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),'')"
    edition = lambda expression: (
        f"CASE {length}({expression}) WHEN 6 THEN 'ICD-O-3.2' WHEN 7 THEN 'ICD-O-4' "
        "ELSE NULL END"
    )
    metadata = ("code_kind", "source_kind", "suggested_qualifier", "match_type",
                "terminology_kind", "conditions", "review_status", "term_table",
                "term_role", "term_source")
    tags = "\nUNION ALL\n".join(
        f"SELECT page_id,edition,code,TermUS,'{field}' AS field,{field} AS value "
        f"FROM raw_rows WHERE {field} IS NOT NULL AND {field}<>''"
        for field in metadata
    )
    if sqlserver:
        tag_values = ",".join(f"('{field}',CAST({field} AS NVARCHAR(MAX)))" for field in metadata)
        tags = (
            "SELECT page_id,edition,code,TermUS,v.field,v.value FROM raw_rows "
            f"CROSS APPLY (VALUES {tag_values}) v(field,value) "
            "WHERE v.value IS NOT NULL AND v.value<>''"
        )
    pivot = ",\n       ".join(
        f"MAX(CASE WHEN field='{field}' THEN values_text END) AS {field}"
        for field in metadata
    )
    return f"""{create} {prefix}v_page_code_terms AS
WITH raw_rows AS (
 SELECT c.page_id,{edition(code)} AS edition,{code} AS code,c.TermUS{exact} AS TermUS,
        c.TermNormUS{exact} AS TermNormUS,CAST(NULL AS VARCHAR(600)) AS candidateTermUS,CAST(c.is_subtype AS INT) AS is_subtype,
        'source_assignment' AS code_kind,'parsed_entity' AS source_kind,
        CAST(NULL AS VARCHAR(60)) AS suggested_qualifier,CAST(NULL AS VARCHAR(60)) AS match_type,
        'coding' AS terminology_kind,CAST(NULL AS VARCHAR(4000)) AS conditions,
        CAST(NULL AS VARCHAR(60)) AS review_status,'entity_codes' AS term_table,
        COALESCE(c.term_role, CASE WHEN c.is_subtype=1 THEN 'subtype' ELSE 'preferred' END) AS term_role,
        'entity_coding_section' AS term_source,
        CASE WHEN c.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END AS section_heading
 FROM {prefix}entity_codes c WHERE {code} IS NOT NULL
 UNION ALL
 SELECT c.page_id,{edition(page_code)},{page_code},c.TermUS{exact},c.TermNormUS{exact},NULL,
        COALESCE(e.is_subtype,0),'contextual_code','section_text',NULL,NULL,'contextual',
        NULL,NULL,'page_icdo_codes',
        COALESCE(c.term_role, CASE WHEN c.section_heading LIKE '%subtype%' THEN 'subtype_section' ELSE 'preferred' END),
        COALESCE(c.term_source, 'icdo_coding_page'),
        c.section_heading
 FROM {prefix}page_icdo_codes c
 LEFT JOIN (SELECT page_id,code,TermUS,MAX(CAST(is_subtype AS INT)) AS is_subtype
            FROM {prefix}entity_codes GROUP BY page_id,code,TermUS) e
 ON e.page_id=c.page_id AND e.code={page_code} AND e.TermUS{exact}=c.TermUS{exact}
 WHERE c.TermUS IS NOT NULL AND {page_code} IS NOT NULL
 UNION ALL
 SELECT c.page_id,NULL,NULL,c.TermUS{exact},c.TermNormUS{exact},NULL,
        0,'uncoded_term',COALESCE(c.term_source,'icdo_coding_page'),NULL,NULL,
        'icdo_coding_page',NULL,NULL,'page_icdo_codes',
        COALESCE(c.term_role, 'uncoded_preferred'),
        COALESCE(c.term_source, 'icdo_coding_page'),
        c.section_heading
 FROM {prefix}page_icdo_codes c
 WHERE c.TermUS IS NOT NULL AND {page_code} IS NULL
 UNION ALL
 SELECT m.page_id,m.edition,m.suggested_code,m.TermUS{exact},m.TermNormUS{exact},m.candidateTermUS,m.is_subtype,
        'candidate',m.source_kind,m.suggested_qualifier,m.match_type,m.terminology_kind,
        m.conditions,m.review_status,m.term_table,
        m.term_role,COALESCE(m.source_kind, 'parsed_entity'),
        CASE WHEN m.term_table='entity_related_terms' THEN 'Related terminology'
             WHEN m.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END
 FROM {prefix}v_entity_term_code_matches m
 WHERE m.match_id IS NOT NULL
 UNION ALL
 SELECT t.page_id,NULL,NULL,t.TermUS{exact},t.TermNormUS{exact},NULL,t.is_subtype,'uncoded_term',
        COALESCE(p.source_kind,'parsed_entity'),p.suggested_qualifier,NULL,t.terminology_kind,
        NULL,p.review_status,t.term_table,
        t.term_role,COALESCE(p.source_kind, 'parsed_entity'),
        CASE WHEN t.term_table='entity_related_terms' THEN 'Related terminology'
             WHEN t.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END
 FROM {prefix}v_entity_terms t LEFT JOIN {prefix}entity_term_provenance p
 ON p.provenance_id=(SELECT MIN(p2.provenance_id) FROM {prefix}entity_term_provenance p2
 WHERE p2.page_id=t.page_id AND
 ((t.term_table='entity_codes' AND p2.entity_code_id=t.term_id) OR
  (t.term_table='entity_related_terms' AND p2.related_term_id=t.term_id)))
 WHERE t.source_code IS NULL OR TRIM(t.source_code)=''
),
key_rows AS (
 SELECT page_id,edition,code,TermUS,MAX(TermNormUS) AS TermNormUS,
        MAX(is_subtype) AS is_subtype,
        MAX(term_role) AS term_role FROM raw_rows
 WHERE NOT (code IS NULL AND EXISTS(
   SELECT 1 FROM raw_rows coded WHERE coded.page_id=raw_rows.page_id
   AND coded.TermUS=raw_rows.TermUS AND coded.code IS NOT NULL))
 GROUP BY page_id,edition,code,TermUS
),
candidate_labels AS (
 SELECT DISTINCT page_id,edition,code,TermUS,candidateTermUS FROM raw_rows
 WHERE candidateTermUS IS NOT NULL
),
tags AS ({tags}),
distinct_tags AS (
 SELECT DISTINCT page_id,edition,code,TermUS,field,value FROM tags
),
tag_text AS (
 SELECT page_id,edition,code,TermUS,field,{aggregate("value")} AS values_text
 FROM distinct_tags GROUP BY page_id,edition,code,TermUS,field
),
metadata AS (
 SELECT page_id,edition,code,TermUS,{pivot}
 FROM tag_text GROUP BY page_id,edition,code,TermUS
),
section_rows AS (
 SELECT DISTINCT page_id,edition,code,TermUS,section_heading FROM raw_rows
 WHERE section_heading IS NOT NULL AND TRIM(section_heading)<>''
),
section_text AS (
 SELECT page_id,edition,code,TermUS,{aggregate("section_heading")} AS page_sections
 FROM section_rows GROUP BY page_id,edition,code,TermUS
),
site_rows AS (
 SELECT page_id,c_code,MAX(confidence_score) AS confidence_score
 FROM {prefix}page_site_hints WHERE confidence_score>=0.9 GROUP BY page_id,c_code
),
site_text AS (
 SELECT page_id,{aggregate("c_code")} AS candidate_topography_codes,
        MIN(confidence_score) AS site_confidence_min,MAX(confidence_score) AS site_confidence_max
 FROM site_rows GROUP BY page_id
)
SELECT {book_label} AS alias,b.title AS book_name,b.book_id,b.edition,k.page_id,
       COALESCE(ch.title,ep.chapter) AS chapter,ch.ord AS ch_order,
       pg.title AS page_title,pg.url AS page_url,
       s.page_sections,k.TermUS,k.TermNormUS,candidate.candidateTermUS,k.edition AS code_edition,
       CASE WHEN k.edition='ICD-O-3.2' THEN k.code END AS ICDO32,
       CASE WHEN k.edition='ICD-O-4' THEN k.code END AS ICDO4,
       k.code AS morphology_code,
       CASE WHEN k.term_role IN ('subtype','uncoded_subtype','icdo_indent_subtype','subtype_section') OR k.is_subtype=1 THEN 1 ELSE 0 END AS is_subtype,
       k.term_role,m.term_source,m.code_kind,m.source_kind,
       m.suggested_qualifier,m.match_type,m.terminology_kind,m.conditions,m.review_status,
       m.term_table AS source_tables,sites.candidate_topography_codes,
       sites.site_confidence_min,sites.site_confidence_max
FROM key_rows k JOIN {prefix}pages pg ON pg.page_id=k.page_id
JOIN {prefix}books b ON b.book_id=pg.book_id
LEFT JOIN {prefix}chapters ch ON ch.chapter_id=pg.chapter_id
LEFT JOIN {prefix}entity_pages ep ON ep.page_id=k.page_id
LEFT JOIN candidate_labels candidate ON candidate.page_id=k.page_id
 AND candidate.edition=k.edition AND candidate.code=k.code AND candidate.TermUS=k.TermUS
LEFT JOIN metadata m ON m.page_id=k.page_id AND m.TermUS=k.TermUS
 AND (m.edition=k.edition OR (m.edition IS NULL AND k.edition IS NULL))
 AND (m.code=k.code OR (m.code IS NULL AND k.code IS NULL))
LEFT JOIN section_text s ON s.page_id=k.page_id AND s.TermUS=k.TermUS
 AND (s.edition=k.edition OR (s.edition IS NULL AND k.edition IS NULL))
 AND (s.code=k.code OR (s.code IS NULL AND k.code IS NULL))
LEFT JOIN site_text sites ON sites.page_id=k.page_id"""


def server_checks() -> dict[str, dict[str, str]]:
    return {
        "entity_term_provenance": {
            "target": "(entity_code_id IS NOT NULL AND related_term_id IS NULL) OR (entity_code_id IS NULL AND related_term_id IS NOT NULL)",
            "source_kind": "source_kind='AI_recovered_prose'",
            "source_table": "source_table IN ('entity_codes','entity_related_terms')",
            "qualifier": "suggested_qualifier IN ('synonym','related','subtype','grouper','other')",
            "terminology_status": "terminology_status IN ('historical','unspecified')",
            "review": "review_status IN ('proposed','approved','rejected','needs_review')",
            "added": "is_added_term IN (0,1)",
        },
        "entity_term_code_matches": {
            "edition": "edition IN ('ICD-O-3.2','ICD-O-4')",
            "match_type": "match_type IN ('exact','synonym','broader','narrower','conditional')",
            "order": "candidate_order>0",
            "reference_row": "reference_row>0",
            "review": "review_status IN ('proposed','approved','rejected','needs_review')",
        },
    }


def validate(con: sqlite3.Connection) -> dict:
    invalid = con.execute(
        "SELECT p.provenance_id FROM entity_term_provenance p "
        "LEFT JOIN entity_codes c ON c.entity_code_id=p.entity_code_id "
        "LEFT JOIN entity_related_terms r ON r.related_term_id=p.related_term_id "
        "WHERE p.page_id<>COALESCE(c.page_id,r.page_id) "
        "OR COALESCE(c.page_id,r.page_id) IS NULL"
    ).fetchall()
    if invalid or con.execute("PRAGMA foreign_key_check").fetchone():
        raise ValueError(f"Recovery target/FK mismatch: {invalid[:5]}")
    for status, qualifier in con.execute("SELECT review_status,suggested_qualifier FROM entity_term_provenance"):
        if status not in REVIEW_STATUSES or qualifier not in QUALIFIERS:
            raise ValueError("Invalid recovery review metadata")
    return {table: con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in TABLES}


def dry_run(path: Path, manifest: dict | None = None) -> dict:
    import bluebooks_local as local
    manifest = manifest or load_manifest()
    with closing(local.connect_sqlite(path, readonly=True)) as con:
        rows = plan(con, manifest)
    return {
        "new_related_terms": sum(not r["existing"] for r in rows),
        "existing_page_terms": sum(bool(r["existing"]) for r in rows),
        "page_terms": len(rows),
        "provenance_links": sum(len(r["sources"]) for r in rows),
        "code_matches": sum(len(r["item"]["matches"]) for r in rows),
        "no_match_page_terms": sum(not r["item"]["matches"] for r in rows),
    }


def apply_recovery(path: Path, server: str = "localhost", database: str = "BlueBooks") -> dict:
    """Verified paired backups precede schema/data writes; no distributed commit."""
    from datetime import datetime, timezone
    import bluebooks_local as local

    path = Path(path).resolve()
    manifest = load_manifest()
    proposed = dry_run(path, manifest)
    sidecar = Path(str(path) + ".local-build.json")
    build = json.loads(sidecar.read_text(encoding="utf-8"))
    with closing(local.connect_sqlite(path, readonly=True)) as src:
        if build["corpus_hashes"] != local.corpus_hashes(src):
            raise ValueError("Corpus changed since the local build")
    hashes = local.validate_reference_hashes(build["reference_hashes"])
    backups = local.backup_databases(path, path.parent / "local_backups", server, database)
    with closing(local.connect_sqlite(path)) as src, closing(local.connect_server(server, database)) as cn:
        local.migrate_sqlite(src)
        local.ensure_server_schema(src, cn)
        before = local.inventory(src)
        untouched = {table: local.table_digest(src.execute(f"SELECT * FROM [{table}] ORDER BY 1"))
                     for table in local.TABLES
                     if table not in TABLES + ("entity_related_terms", "page_search_documents")}
        try:
            with src:
                inserted = populate(src, manifest)
                local.build_documents(src)
                local.rebuild_sqlite_search(src)
                local.term_hygiene.validate_terms(src)
                for table, digest in untouched.items():
                    if digest != local.table_digest(src.execute(f"SELECT * FROM [{table}] ORDER BY 1")):
                        raise ValueError(f"Recovery unexpectedly changed {table}")
            # Commit SQLite and provenance first; SQL mirroring then uses the
            # standard validated mirror. Paired backups are the recovery path.
            build.update(version=local.VERSION, counts=local.inventory(src),
                         reference_hashes={**hashes, **reference_hashes(manifest)})
            build["term_recovery"] = {
                "backups": backups, "completed_at": datetime.now(timezone.utc).isoformat(),
                "dry_run": proposed, "inserted": inserted, "counts_before": before,
            }
            sidecar.write_text(json.dumps(build, indent=2), encoding="utf-8")
        except Exception:
            src.rollback()
            raise
    parity = local.mirror(path, server, database)
    with closing(local.connect_sqlite(path, readonly=True)) as src:
        second = populate_check(src, manifest)
    report = {**build["term_recovery"], "parity": parity, "idempotent": second}
    build["term_recovery"] = report
    sidecar.write_text(json.dumps(build, indent=2), encoding="utf-8")
    return report


def populate_check(con: sqlite3.Connection, manifest: dict) -> bool:
    rows = plan(con, manifest)
    if any(not r["existing"] for r in rows):
        raise ValueError("Recovery left terms missing")
    expected_sources = {key(r["term_key"], s["table"], s["row_id"])
                        for r in rows for s in r["sources"]}
    actual = {r[0] for r in con.execute("SELECT provenance_key FROM entity_term_provenance")}
    expected_matches = {key(r["term_key"], m["edition"], m["code"], m["reference_row"])
                        for r in rows for m in r["item"]["matches"]}
    matches = {r[0] for r in con.execute("SELECT match_key FROM entity_term_code_matches")}
    if not expected_sources <= actual or not expected_matches <= matches:
        raise ValueError("Recovery left provenance or matches missing")
    validate(con)
    return True
