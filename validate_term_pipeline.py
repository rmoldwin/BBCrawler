"""Read-only acceptance checks for deployed observation pipelines and backups."""
from contextlib import closing
from collections import Counter
from decimal import Decimal
from pathlib import Path
import argparse
import json
import time

import bluebooks_local as local
import term_hygiene
import term_pipeline


def _normalize_view_row(row: tuple) -> tuple:
    """Cross-engine value normalization for parity checks."""
    vals = list(row)
    # v_page_code_terms page_sections: stable semantic set, delimiter ordering
    # can differ by engine collation and aggregate ordering.
    if len(vals) > 9 and isinstance(vals[9], str) and ";" in vals[9]:
        parts = [p.strip() for p in vals[9].split(";") if p.strip()]
        vals[9] = "; ".join(sorted(dict.fromkeys(parts), key=str.casefold))
    for i, value in enumerate(vals):
        if isinstance(value, Decimal):
            vals[i] = float(value)
    return tuple(vals)


def validate(path, baseline=None, server=False):
    with closing(local.connect_sqlite(path, readonly=True)) as con:
        if con.execute("PRAGMA foreign_key_check").fetchone():
            raise AssertionError("Foreign-key violation")
        missing = con.execute(
            "SELECT e.page_id FROM entity_pages e WHERE NOT EXISTS(SELECT 1 "
            "FROM page_term_mentions m WHERE m.page_id=e.page_id AND m.term_source='page_title' "
            "AND m.is_current=1 AND m.term_origin='source')").fetchall()
        assert not missing, missing
        placeholders = {}
        for table, field in (("entity_codes", "term"), ("entity_related_terms", "term"),
                             ("page_icdo_codes", "term_in_coding_section"),
                             ("page_term_mentions", "term_original"),
                             ("term_code_candidates", "candidateTermUS"),
                             ("term_reference_rows", "official_term"),
                             ("entity_term_provenance", "recovered_term"),
                             ("entity_term_code_matches", "official_term")):
            invalid = [r[0] for r in con.execute(f"SELECT {field} FROM {table}")
                       if term_hygiene.is_standalone_placeholder(r[0])]
            placeholders[table] = len(invalid)
        assert not any(placeholders.values())
        assert not con.execute(
            "SELECT 1 FROM page_term_mentions WHERE is_current=1 "
            "AND term_source='page_title' AND term_origin='source' "
            "AND is_current=1 AND lower(trim(term_original))='not applicable'").fetchone()
        gyn = con.execute(
            "SELECT ICDO32,ICDO4 FROM v_page_code_terms WHERE page_id=4941 "
            "AND TermUS='Gynandroblastoma'").fetchall()
        assert any(r[1] == "86320/1" for r in gyn), gyn
        assert con.execute("SELECT 1 FROM entity_pages WHERE page_id=5029").fetchone()
        titles = con.execute("SELECT COUNT(*) FROM entity_pages").fetchone()[0]
        legacy = local.term_recovery.validate(con)
        official = con.execute(
            "SELECT edition,COUNT(*),COUNT(DISTINCT reference_sha256) "
            "FROM term_reference_rows GROUP BY edition").fetchall()
        assert {r[0] for r in official} == set(term_pipeline.EDITIONS)
        missing_reference = con.execute(
            "SELECT COUNT(*) FROM term_code_candidates c JOIN term_lookup_evaluations e "
            "ON e.evaluation_id=c.evaluation_id WHERE e.is_current=1 "
            "AND c.match_type<>'legacy_curated' AND NOT EXISTS("
            "SELECT 1 FROM term_reference_rows r WHERE r.edition=e.edition "
            "AND r.code=c.code AND r.official_termUS=c.candidateTermUS "
            "AND r.reference_sha256=e.reference_sha256)").fetchone()[0]
        assert missing_reference == 0, missing_reference
        qualifiers = con.execute(
            "SELECT DISTINCT term FROM entity_codes WHERE lower(term) LIKE '%not applicable%'").fetchall()
        changes = {}
        if baseline:
            with closing(local.connect_sqlite(baseline, readonly=True)) as old:
                for table, pk, field in (("entity_codes", "entity_code_id", "term"),
                                         ("entity_related_terms", "related_term_id", "term")):
                    cols = local.columns(old, table)
                    names = ",".join(f'"{c}"' for c in cols)
                    original = {r[cols.index(pk)]: tuple(r) for r in old.execute(f"SELECT {names} FROM {table}")}
                    current = {r[cols.index(pk)]: tuple(r) for r in con.execute(f"SELECT {names} FROM {table}")}
                    removed = [r for i, r in original.items() if i not in current]
                    assert all(term_hygiene.is_standalone_placeholder(r[cols.index(field)]) for r in removed), removed
                    changed = [i for i, r in original.items() if i in current and current[i] != r]
                    assert not changed, (table, changed[:10])
                    changes[table] = {"preserved": len(original)-len(removed),
                                      "removed_placeholders": len(removed),
                                      "added": len(current.keys()-original.keys())}
                for table in local.term_recovery.TABLES + ("books",):
                    assert local.table_digest(old.execute(f"SELECT * FROM {table} ORDER BY 1")) == local.table_digest(con.execute(f"SELECT * FROM {table} ORDER BY 1")), table
        queries = {
            "observations": "SELECT mention_id FROM page_term_mentions WHERE page_id=4941 AND TermNormUS='Gynandroblastoma'",
            "evaluations": "SELECT evaluation_id FROM term_lookup_evaluations WHERE mention_id=1 AND edition='ICD-O-4' AND is_current=1",
            "candidates": "SELECT candidate_id FROM term_code_candidates WHERE evaluation_id=1",
            "reviews": "SELECT decision_id FROM term_review_decisions WHERE target_key='test' ORDER BY decision_id",
        }
        plans = {name: con.execute("EXPLAIN QUERY PLAN "+query).fetchall() for name, query in queries.items()}
        assert all(any("SEARCH" in r[3] for r in plan) for plan in plans.values())
        started = time.perf_counter()
        examples = con.execute("SELECT COUNT(*) FROM v_page_code_terms WHERE page_id=4941").fetchone()[0]
        elapsed = time.perf_counter()-started
        available_tables = {
            row[0] for row in con.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }
        inventory = {
            table: con.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            for table in local.TABLES if table in available_tables
        }
        report = {"title_coverage": titles, "missing_titles": len(missing),
                  "placeholders": placeholders, "source_assignment_comparison": changes,
                  "legacy": legacy, "official_references": official, "gynandroblastoma": gyn,
                  "candidate_reference_discrepancies": missing_reference,
                  "retained_nonstandalone_qualifiers": qualifiers,
                  "nested_page_5029": True, "query_plans": plans,
                  "representative_view_rows": examples, "representative_view_seconds": elapsed,
                  "counts": inventory,
                  "unmigrated_pipeline_tables": sorted(set(local.TABLES)-available_tables)}
    if server:
        with closing(local.connect_sqlite(path, readonly=True)) as src, closing(local.connect_server()) as cn:
            report["parity"] = local.verify_parity(src, cn)
            cur = cn.cursor()
            view_parity = {}
            for view in ("v_page_code_terms", "v_entity_terms", "v_entity_term_provenance",
                         "v_entity_term_code_matches", "v_term_candidate_evidence"):
                sqlite_rows = Counter(
                    local._row_bytes(_normalize_view_row(row))
                    for row in src.execute(f"SELECT * FROM {view}")
                )
                server_rows = Counter(
                    local._row_bytes(_normalize_view_row(row))
                    for row in cur.execute(f"SELECT * FROM dbo.{view}")
                )
                view_parity[view] = {"sqlite_rows": sum(sqlite_rows.values()),
                                     "sqlserver_rows": sum(server_rows.values()),
                                     "match": sqlite_rows == server_rows}
                assert sqlite_rows == server_rows, (
                    view, "Cross-engine view values differ", view_parity[view],
                    "sqlite-only", list((sqlite_rows-server_rows).keys())[:1],
                    "server-only", list((server_rows-sqlite_rows).keys())[:1])
            report["view_parity"] = view_parity
            cur.execute("SET SHOWPLAN_XML ON")
            xml = {}
            try:
                for name, query in queries.items():
                    xml[name] = str(cur.execute(query).fetchone()[0])
            finally:
                cur.execute("SET SHOWPLAN_XML OFF")
            report["sqlserver_query_plan_index_access"] = {
                name: ("Index Seek" in plan or "Clustered Index Seek" in plan)
                for name, plan in xml.items()}
            report["sqlserver_query_plan_indexes"] = {
                name: sorted(set(__import__("re").findall(r'Index="([^"]+)"', plan)))
                for name, plan in xml.items()}
            started = time.perf_counter()
            cur.execute("SELECT COUNT(*) FROM dbo.v_page_code_terms WHERE page_id=4941").fetchone()
            report["sqlserver_view_seconds"] = time.perf_counter()-started
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sqlite", type=Path, default=Path("bluebooks.db"))
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--server", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = validate(args.sqlite, args.baseline, args.server)
    text = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    print(text)
