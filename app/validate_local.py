"""Read-only live parity/search/normalization and notebook validation."""
from contextlib import closing, redirect_stdout
import argparse
import io
import json
from pathlib import Path
import re
import sqlite3
import sys

import nbformat
import bluebooks_local as local


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, help="Pre-recovery SQLite backup for preservation checks")
    args = parser.parse_args()
    result = {}
    with closing(local.connect_sqlite(local.ROOT / "bluebooks.db", readonly=True)) as src, \
         closing(local.connect_server()) as dst:
        result["parity"] = local.verify_parity(src, dst)
        result["sqlite_integrity"] = src.execute("PRAGMA quick_check").fetchone()[0]
        if result["sqlite_integrity"] != "ok" or src.execute("PRAGMA foreign_key_check").fetchone():
            raise AssertionError("SQLite integrity failure")
        result["search"] = {"sqlite": {}, "sqlserver": {}}
        def hit_count(con, query, backend):
            if backend == "sqlite":
                return con.execute("SELECT COUNT(*) FROM pages_fts WHERE pages_fts MATCH ?",
                                   (query,)).fetchone()[0]
            return con.cursor().execute(
                "SELECT COUNT_BIG(*) FROM dbo.page_search_documents WHERE CONTAINS((title,full_text),?)",
                query
            ).fetchone()[0]

        def page_has_hit(con, query, backend, page_id):
            if backend == "sqlite":
                return con.execute(
                    "SELECT 1 FROM pages_fts WHERE pages_fts MATCH ? AND rowid=? LIMIT 1",
                    (query, page_id),
                ).fetchone() is not None
            return con.cursor().execute(
                "SELECT 1 FROM dbo.page_search_documents "
                "WHERE page_id=? AND CONTAINS((title,full_text),?)",
                page_id, query,
            ).fetchone() is not None

        for backend, con in (("sqlite", src), ("sqlserver", dst)):
            for query in ("carcinoma", '"hepatocellular carcinoma"', "carcinoma AND liver",
                          "carcinoma OR hepatoblastoma"):
                hits = local.search(con, query, backend=backend, limit=1)
                result["search"][backend][query] = hit_count(con, query, backend)
                if not hits:
                    raise AssertionError(f"No hits: {backend} / {query}")
            prefix = "carc*" if backend == "sqlite" else '"carc*"'
            prefix_hits = local.search(con, prefix, backend=backend, limit=1)
            filtered = local.search(con, "carcinoma", backend=backend, book_id=72, limit=1)
            if not prefix_hits or not filtered or any(
                src.execute("SELECT book_id FROM pages WHERE page_id=?", (r[0],)).fetchone()[0] != 72
                for r in filtered
            ):
                raise AssertionError(f"Prefix/book-filter failure: {backend}")
            result["search"][backend]["prefix"] = hit_count(con, prefix, backend)
            result["search"][backend]["book72"] = len(filtered)
        fixtures = [None, "", "Oesophageal adenocarcinoma, NOS", "Tumour type III",
                    "Hepatoblastoma", "Clear-cell carcinoma", "Carcinoma (NOS)",
                    "Grade II", "Haematolymphoid tumour", "A\u00a0B", "Nodule\u2019s",
                    "Tumour TYPE III", "Tumour grade II", "A nos", "A NOS",
                    "A Type", "(specify test)", "A (Specify test)"]
        clean = local.companion("clean_term").clean
        mismatches = []
        for text in fixtures:
            actual = dst.cursor().execute("SELECT dbo.Clean(?)", text).fetchone()[0]
            if actual != clean(text):
                mismatches.append({"input": text, "python": clean(text), "sqlserver": actual})
        result["normalization_mismatches"] = mismatches
        if mismatches:
            raise AssertionError(f"Normalization parity failed: {mismatches}")
        result["sixth_edition"] = [
            tuple(row) for row in src.execute(
                "SELECT p.book_id,COUNT(*),"
                "SUM((SELECT COUNT(*) FROM page_icdo_codes c WHERE c.page_id=p.page_id)),"
                "SUM((SELECT COUNT(*) FROM page_term_mentions m WHERE m.page_id=p.page_id)) FROM pages p "
                "WHERE p.book_id IN (72,84,85,87) GROUP BY p.book_id"
            )
        ]
        result["entity_editions"] = [
            tuple(row) for row in src.execute(
                "SELECT b.edition,COUNT(*) FROM entity_pages e "
                "JOIN books b ON b.book_id=e.book_id GROUP BY b.edition ORDER BY b.edition"
            )
        ]
        if {edition for edition, count in result["entity_editions"] if count} != {"5th", "6th"}:
            raise AssertionError("Both supported editions must have parsed entities")
        result["entity_books"] = [
            tuple(row) for row in src.execute(
                "SELECT b.book_id,b.edition,COUNT(DISTINCT e.page_id),COUNT(c.code),"
                "SUM(CASE WHEN c.code<>'' THEN 1 ELSE 0 END) "
                "FROM books b JOIN entity_pages e ON e.book_id=b.book_id "
                "LEFT JOIN entity_codes c ON c.page_id=e.page_id "
                "GROUP BY b.book_id,b.edition ORDER BY b.book_id"
            )
        ]
        extractor = local.companion("bb_entity_extract")
        invalid_entities = [
            page_id for page_id, category, page_type in src.execute(
                "SELECT e.page_id,e.category,p.page_type FROM entity_pages e "
                "JOIN pages p ON p.page_id=e.page_id"
            )
            if not category or page_type in extractor.NON_ENTITY_PAGE_TYPES
        ]
        invalid_codes = [
            (page_id, code) for page_id, code in src.execute(
                "SELECT page_id,code FROM entity_codes WHERE code<>''"
            )
            if not re.fullmatch(r"\d{4}[0-9A-Z]?/\d", code)
        ]
        result["invalid_entity_pages"] = len(invalid_entities)
        result["invalid_entity_codes"] = len(invalid_codes)
        if invalid_entities or invalid_codes:
            raise AssertionError(
                f"Entity classification/code validation failed: {invalid_entities[:10]}, {invalid_codes[:10]}"
            )
        result["saved_body_coverage"] = {"pages_parsed": 0, "sections_checked": 0,
                                         "missing_sections": [], "missing_documents": [],
                                         "unparsed_pages": []}
        result["independent_prose_coverage"] = {"paragraphs_checked": 0, "unmatched": []}
        normalize = lambda text: re.sub(r"\s+", " ", text or "").strip()
        for page_id, raw, document in src.execute(
            "SELECT p.page_id,p.raw_html,d.full_text FROM pages p "
            "JOIN page_search_documents d ON d.page_id=p.page_id ORDER BY p.page_id"
        ):
            if not raw:
                continue
            checked, unmatched = extractor.audit_saved_body_coverage(raw, document)
            result["independent_prose_coverage"]["paragraphs_checked"] += checked
            if unmatched:
                result["independent_prose_coverage"]["unmatched"].append(
                    {"page_id": page_id, "paragraphs": unmatched}
                )
            parsed = extractor.extract_saved_sections(raw)
            coverage = result["saved_body_coverage"]
            if not parsed:
                coverage["unparsed_pages"].append(page_id)
                continue
            coverage["pages_parsed"] += 1
            bodies = {normalize(r[0]) for r in src.execute(
                "SELECT body_text FROM sections WHERE page_id=?", (page_id,)
            )}
            for section in parsed:
                body = normalize(section.body_text)
                if not body:
                    continue
                coverage["sections_checked"] += 1
                if body not in bodies:
                    coverage["missing_sections"].append((page_id, section.heading))
                if body not in normalize(document):
                    coverage["missing_documents"].append((page_id, section.heading))
        if coverage["missing_sections"] or coverage["missing_documents"]:
            raise AssertionError("Saved section bodies missing from stored sections/search documents")
        if result["independent_prose_coverage"]["unmatched"]:
            raise AssertionError(
                "Independent saved prose missing from search documents: "
                f"{result['independent_prose_coverage']['unmatched'][:5]}"
            )
        result["body_spot_tests"] = {}
        for backend, con in (("sqlite", src), ("sqlserver", dst)):
            query = '"teratoma of the lung"'
            if not page_has_hit(con, query, backend, 2751):
                raise AssertionError(f"44/444 body phrase not searchable: {backend}")
            if backend == "sqlite":
                section_hit = con.execute(
                    "SELECT 1 FROM sections_fts f JOIN sections s ON s.section_id=f.rowid "
                    "WHERE s.page_id=? AND sections_fts MATCH ? LIMIT 1",
                    (2751, query),
                ).fetchone()
            else:
                section_hit = con.cursor().execute(
                    "SELECT 1 FROM dbo.sections WHERE page_id=? AND CONTAINS(body_text,?)",
                    2751, query,
                ).fetchone()
            if not section_hit:
                raise AssertionError(f"44/444 section phrase not searchable: {backend}")
            result["body_spot_tests"][backend] = hit_count(con, query, backend)
        expected_codes = {1033: "8503/2", 4683: "8890/3", 4700: "9570/0",
                          4735: "9132/0", 4738: "9120/0", 4796: "8823/1"}
        for page_id, code in expected_codes.items():
            for table, column in (("entity_codes", "code"), ("page_icdo_codes", "icdo_code_raw")):
                if not src.execute(f"SELECT 1 FROM {table} WHERE page_id=? AND {column}=?",
                                   (page_id, code)).fetchone():
                    raise AssertionError(f"Missing recovered code: {table}: {page_id}: {code}")
        if src.execute("SELECT 1 FROM entity_codes WHERE page_id=4227 AND code<>''").fetchone():
            raise AssertionError("GLPD must not acquire a morphology code")
        for book_id, site_id in ((52, 83), (65, 137)):
            page_id = src.execute("SELECT page_id FROM pages WHERE book_id=? AND site_page_id=?",
                                  (book_id, site_id)).fetchone()[0]
            if not src.execute(
                "SELECT 1 FROM entity_related_terms WHERE page_id=? AND kind='not_recommended' "
                "AND lower(term)='low-grade cribriform cystadenocarcinoma'", (page_id,)
            ).fetchone():
                raise AssertionError(f"Missing salivary terminology: {book_id}/{site_id}")
            for backend, con in (("sqlite", src), ("sqlserver", dst)):
                if not page_has_hit(
                    con, '"low-grade cribriform cystadenocarcinoma"', backend, page_id
                ):
                    raise AssertionError(
                        f"Salivary terminology not searchable: {backend}: {book_id}/{site_id}"
                    )
        salivary_id = src.execute(
            "SELECT page_id FROM pages WHERE book_id=52 AND site_page_id=83"
        ).fetchone()[0]
        if src.execute("SELECT COUNT(*) FROM entity_codes WHERE page_id=? AND code='8500/2'",
                       (salivary_id,)).fetchone()[0] != 5:
            raise AssertionError("Salivary intraductal carcinoma must retain all five 8500/2 rows")
        result["recovered_code_spot_tests"] = expected_codes
        result["omim_rows"] = src.execute("SELECT COUNT(*) FROM entity_identifiers").fetchone()[0]
        if not src.execute(
            "SELECT 1 FROM entity_identifiers WHERE identifier='609310' AND page_id=319"
        ).fetchone() or src.execute(
            "SELECT 1 FROM entity_codes WHERE term LIKE '609310 %'"
        ).fetchone():
            raise AssertionError("OMIM identifier separation failed")
        for backend, con in (("sqlite", src), ("sqlserver", dst)):
            if not page_has_hit(con, "609310", backend, 319):
                raise AssertionError(f"OMIM source identifier not searchable: {backend}")
        result["unrecovered_coding_codes"] = []
        result["explanatory_code_examples"] = []
        for page_id, raw, title in src.execute(
            "SELECT p.page_id,p.raw_html,p.title FROM pages p JOIN entity_pages e ON e.page_id=p.page_id"
        ):
            parsed = extractor.parse_entity_page(raw, title)
            coding = parsed.sections.get("ICD-O coding", "")
            if "does not have an ICD-O code" in coding and "for example," in coding:
                result["explanatory_code_examples"].append(page_id)
                continue
            expected = set(re.findall(r"(?<!\d)\d{4}[0-9A-Z]?/\d\b", coding))
            actual = {r[0] for r in src.execute(
                "SELECT code FROM entity_codes WHERE page_id=? AND code<>''", (page_id,)
            )}
            result["unrecovered_coding_codes"].extend((page_id, code) for code in expected - actual)
        if result["unrecovered_coding_codes"]:
            raise AssertionError(f"Unrecovered ICD-O block codes: {result['unrecovered_coding_codes'][:20]}")
        residual_identifiers = []
        for page_id, ordinal, term in src.execute(
            "SELECT page_id,ordinal,term FROM entity_codes WHERE code=''"
        ):
            if (re.search(r"\bMIM\b|\bOMIM\b", term, re.IGNORECASE)
                    or re.match(r"\s*#?\s*\d{6}\b", term)
                    or re.fullmatch(
                        r"\s*(?:other\s+)?MIM\s+(?:number(?:ing)?|related\b.*?)"
                        r"\s*:?\s*(?:none)?\s*",
                        term,
                        re.IGNORECASE,
                    )):
                residual_identifiers.append((page_id, ordinal, term))
        result["residual_omim_code_terms"] = residual_identifiers
        if residual_identifiers:
            raise AssertionError(
                f"OMIM references/labels remain in entity_codes: {residual_identifiers[:20]}"
            )
        if args.baseline:
            with closing(local.connect_sqlite(args.baseline, readonly=True)) as before:
                result["preserved_tables"] = []
                for table in ("books", "chapters", "page_groups", "pages", "authors",
                              "images", "page_links", "references", "cpc_curation",
                              "crawl_queue", "crawl_runs"):
                    cols = local.columns(before, table)
                    names = ",".join(f'"{c}"' for c in cols)
                    pk = [r[1] for r in before.execute(f'PRAGMA table_info("{table}")') if r[5]]
                    order = ",".join(f'"{c}"' for c in pk)
                    query = f'SELECT {names} FROM "{table}" ORDER BY {order}'
                    if local.table_digest(before.execute(query)) != local.table_digest(src.execute(query)):
                        raise AssertionError(f"Recovery changed protected/core table: {table}")
                    result["preserved_tables"].append(table)
                current = {r[0]: tuple(r) for r in src.execute(
                    "SELECT section_id,page_id,heading,body_text,ord FROM sections"
                )}
                protected = 0
                pruned = 0
                for row in before.execute("SELECT section_id,page_id,heading,body_text,ord FROM sections"):
                    old = tuple(row)
                    new = current.get(old[0])
                    if new is None:
                        linked = before.execute(
                            "SELECT EXISTS(SELECT 1 FROM images WHERE section_id=?) OR "
                            "EXISTS(SELECT 1 FROM \"references\" WHERE section_id=?)",
                            (old[0], old[0]),
                        ).fetchone()[0]
                        is_entity = before.execute(
                            "SELECT 1 FROM entity_pages WHERE page_id=?", (old[1],)
                        ).fetchone()
                        if (old[3] or "").strip() or not is_entity or linked:
                            raise AssertionError(
                                f"Unexpected original section deletion: {old[0]}"
                            )
                        pruned += 1
                        continue
                    if (old[:3] != new[:3] or old[4] != new[4]
                            or ((old[3] or "").strip() and old[3] != new[3])):
                        raise AssertionError(f"Original section ID/text association changed: {old[0]}")
                    protected += 1
                result["preserved_original_section_ids"] = protected
                result["pruned_unlinked_empty_entity_sections"] = pruned
                original_codes = {tuple(r) for r in before.execute(
                    "SELECT page_id,code FROM entity_codes WHERE code<>''"
                )}
                current_codes = {tuple(r) for r in src.execute(
                    "SELECT page_id,code FROM entity_codes WHERE code<>''"
                )}
                lost_codes = sorted(original_codes - current_codes)
                if lost_codes:
                    raise AssertionError(f"Baseline morphology codes lost: {lost_codes[:20]}")
                result["preserved_baseline_page_codes"] = len(original_codes)
        result["fulltext"] = [
            tuple(row) for row in dst.cursor().execute(
                "SELECT OBJECT_NAME(object_id),"
                "CAST(OBJECTPROPERTYEX(object_id,'TableFulltextItemCount') AS bigint),"
                "CAST(OBJECTPROPERTYEX(object_id,'TableFulltextPopulateStatus') AS int),"
                "CAST(OBJECTPROPERTYEX(object_id,'TableFulltextPendingChanges') AS bigint),"
                "has_crawl_completed,is_enabled,change_tracking_state_desc "
                "FROM sys.fulltext_indexes WHERE object_id IN "
                "(OBJECT_ID('dbo.sections'),OBJECT_ID('dbo.pages'),"
                "OBJECT_ID('dbo.page_search_documents'))"
            )
        ]
        if len(result["fulltext"]) != 3 or any(
            status or pending or not completed or not enabled or tracking != "AUTO"
            for table, items, status, pending, completed, enabled, tracking in result["fulltext"]
        ):
            raise AssertionError(f"Full-text indexes are not ready: {result['fulltext']}")
        for table, items, *_ in result["fulltext"]:
            expected = src.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
            if items != expected:
                raise AssertionError(f"Incomplete full-text coverage: {table}: {items}/{expected}")
        result["missing_title_norm"] = src.execute(
            "SELECT COUNT(*) FROM pages WHERE title IS NOT NULL AND title_norm IS NULL"
        ).fetchone()[0]
        result["agent_job_rows"] = dst.cursor().execute("SELECT COUNT_BIG(*) FROM dbo.agent_jobs").fetchone()[0]
        result["agent_job_columns"] = [r[0] for r in dst.cursor().execute(
            "SELECT name FROM sys.columns WHERE object_id=OBJECT_ID('dbo.agent_jobs') ORDER BY column_id"
        )]
    for path in (local.ROOT / "Crawler_Runner.ipynb",
                 local.COMPANION / "BlueBooks_Explorer_2.ipynb",
                 local.COMPANION / "BlueBooks_Explorer_3.ipynb",
                 local.COMPANION / "Querying_Site_Specific_Terms.ipynb"):
        nb = nbformat.read(path, 4)
        nbformat.validate(nb)
        for cell in nb.cells:
            if cell.cell_type == "code" and not any(l.lstrip().startswith(("%", "!")) for l in cell.source.splitlines()):
                compile(cell.source, str(path), "exec")
    sys.path.insert(0, str(local.COMPANION))
    import os
    os.chdir(local.COMPANION)
    import pandas as pd
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    explorer = nbformat.read(local.COMPANION / "BlueBooks_Explorer_3.ipynb", 4)
    result["explorer_search"] = {}
    for backend in ("sqlite", "sqlserver"):
        namespace = {"sqlite3": sqlite3, "pd": pd, "clean": local.companion("clean_term").clean}
        with redirect_stdout(io.StringIO()):
            for cell in explorer.cells:
                if cell.cell_type == "code" and cell.source.startswith("# Step 1.2"):
                    exec(cell.source, namespace)
                    namespace["DB_KIND"] = backend
                elif cell.cell_type == "code" and cell.source.startswith(("# Step 1.4", "# Step 1.6")):
                    exec(cell.source, namespace)
            if namespace.get("_engine") != backend:
                raise AssertionError(f"Explorer connection failed: {backend}")
            captured = []
            namespace["show"] = captured.append
            for cell in explorer.cells:
                if cell.cell_type == "code" and cell.source.startswith("# Whole-page search"):
                    exec(cell.source, namespace)
            if len(captured) != 1 or captured[0].empty:
                raise AssertionError(f"Explorer whole-page search failed: {backend}")
            result["explorer_search"][backend] = len(captured[0])
        namespace["con"].close()
    nb = nbformat.read(local.COMPANION / "Querying_Site_Specific_Terms.ipynb", 4)
    result["site_notebook_cells"] = {}
    for backend in ("sqlite", "sqlserver"):
        namespace = {}
        executed = 0
        namespace["plt"] = plt
        namespace["display"] = lambda *args, **kwargs: None
        namespace["plt"].show = lambda *args, **kwargs: None
        with redirect_stdout(io.StringIO()):
            for cell in nb.cells:
                if cell.cell_type != "code":
                    continue
                source = cell.source.replace('DB_KIND = "sqlite"', f'DB_KIND = "{backend}"')
                exec(compile(source, "site-query-notebook", "exec"), namespace)
                executed += 1
        if backend == "sqlite":
            namespace["con"].close()
        else:
            namespace["engine"].dispose()
        result["site_notebook_cells"][backend] = executed
    plt.close("all")
    local.LOCAL.mkdir(exist_ok=True)
    (local.LOCAL / "validation.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "parity"}, indent=2))
    print("All", len(result["parity"]), "managed table hashes match.")


if __name__ == "__main__":
    main()
