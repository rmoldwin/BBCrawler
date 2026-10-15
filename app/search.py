"""
Step 4 — Query the corpus with FTS5 (with snippets), or filter structurally.

Examples:
    python search.py --config config.json "neuroendocrine AND oesophagus"
    python search.py --config config.json "Barrett dysplasia" --book 31 --limit 20
    python search.py --config config.json --page-type tumour_entity --list
    python search.py --config config.json --pmid 12345678
"""
import argparse
import json
import re
import sqlite3
import sys
from project_paths import DEFAULT_CONFIG, load_config

if hasattr(sys.stdout, "reconfigure"):
    # Prefer UTF-8 console output on Windows to avoid mojibake in captured output.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def connect(cfg):
    con = sqlite3.connect(cfg["db_path"])
    con.row_factory = sqlite3.Row
    return con


def page_search(con, query, book_id=None, limit=25):
    """Page-level FTS: multi-term AND matches across sections of a page."""
    # Note: pages_fts is contentless, so snippet() cannot reconstruct text.
    # We match in FTS, then pull a snippet from the source sections below.
    sql = """
      SELECT f.rowid AS page_id,
             p.title, p.book_id,
             p.url, p.page_type, b.edition, b.title AS book_title,
             bm25(pages_fts) AS score
      FROM pages_fts f
      JOIN pages p ON p.page_id = f.rowid
      JOIN books b ON b.book_id = p.book_id
      WHERE pages_fts MATCH ?
    """
    params = [query]
    if book_id:
        sql += " AND p.book_id = ?"
        params.append(book_id)
    sql += " ORDER BY score LIMIT ?"
    params.append(limit)
    return con.execute(sql, params).fetchall()


def _first_terms(query):
    """Extract plain search terms from an FTS expression for snippet highlighting."""
    import re as _re
    toks = _re.findall(r"[A-Za-z0-9]+", query)
    return [t for t in toks if t.upper() not in ("AND", "OR", "NOT", "NEAR")]


NOISY_PHRASES = (
    "Attachment",
    "Authors",
    "Send us Feedback",
    "Add Personal Note",
    "Tables From",
)


def _clean_snippet_text(text: str) -> str:
    """Remove repeated site chrome noise and collapse delimiter clutter."""
    cleaned = text or ""

    # Strip common UI labels repeatedly scraped into section text.
    for phrase in NOISY_PHRASES:
        cleaned = re.sub(rf"\b{re.escape(phrase)}\b:?", " ", cleaned, flags=re.I)

    # Collapse long colon runs and excess whitespace left by removals.
    cleaned = re.sub(r"(?:\s*:\s*){2,}", ": ", cleaned)
    cleaned = re.sub(r"^(?:\s*:\s*)+", "", cleaned)
    cleaned = re.sub(r"(?::\s*)+(?:…|\.\.\.)$", " …", cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned)
    cleaned = re.sub(r"\s+([,.;:])", r"\1", cleaned)
    return cleaned.strip()


def make_snippet(con, page_id, terms, width=240):
    """Build a readable snippet from the page's concatenated section text."""
    if con.execute("SELECT 1 FROM sqlite_master WHERE name='page_search_documents'").fetchone():
        row = con.execute("SELECT full_text AS t FROM page_search_documents WHERE page_id=?", (page_id,)).fetchone()
    else:
        row = con.execute(
            "SELECT COALESCE(GROUP_CONCAT(heading || ': ' || body_text, '  '), '') t "
            "FROM sections WHERE page_id=?", (page_id,)).fetchone()
    text = _clean_snippet_text((row["t"] if row else "") or "")
    low = text.lower()
    pos = -1
    for t in terms:
        p = low.find(t.lower())
        if p != -1 and (pos == -1 or p < pos):
            pos = p
    if pos == -1:
        return text[:width].strip()
    start = max(0, pos - width // 3)
    seg = text[start:start + width].strip()
    return ("… " if start > 0 else "") + seg + " …"


def fts_search(con, query, book_id=None, limit=25):
    # sections_fts is contentless; select the source body_text and snippet in Python.
    sql = """
          SELECT s.page_id, s.section_id,
              TRIM(COALESCE(s.heading, '') || ' ' || COALESCE(s.body_text, '')) AS section_text,
             s.heading, p.title, p.book_id,
             p.url, p.page_type, b.edition, b.title AS book_title,
             bm25(sections_fts) AS score
      FROM sections_fts f
      JOIN sections s ON s.section_id = f.rowid
      JOIN pages p ON p.page_id = s.page_id
      JOIN books b ON b.book_id = p.book_id
      WHERE sections_fts MATCH ?
    """
    params = [query]
    if book_id:
        sql += " AND p.book_id = ?"
        params.append(book_id)
    sql += " ORDER BY score LIMIT ?"
    params.append(limit)
    return con.execute(sql, params).fetchall()


def main() -> int:
    ap = argparse.ArgumentParser(description="Search the Blue Books corpus.")
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("query", nargs="?", help="FTS5 MATCH expression")
    ap.add_argument("--book", type=int, default=None)
    ap.add_argument("--limit", type=int, default=25)
    ap.add_argument("--page-type", default=None, help="Filter/list by page_type")
    ap.add_argument("--pmid", default=None, help="Find pages citing a PMID")
    ap.add_argument("--list", action="store_true", help="List matching pages (structural, no FTS)")
    ap.add_argument("--sections", action="store_true",
                    help="Search per-section (default is page-level, which matches AND across sections)")
    args = ap.parse_args()
    cfg = load_config(args.config)
    con = connect(cfg)

    if args.pmid:
        rows = con.execute(
            'SELECT DISTINCT p.title, p.url, p.page_type FROM "references" r '
            "JOIN pages p ON p.page_id=r.page_id "
            "WHERE r.token_format='pmid_curly' AND r.token=? LIMIT ?",
            (args.pmid, args.limit)).fetchall()
        for r in rows:
            print(f"- {r['title']}  [{r['page_type']}]\n    {r['url']}")
        print(f"\n{len(rows)} page(s) cite PMID {args.pmid}.")
        return 0

    if args.list or (args.page_type and not args.query):
        sql = "SELECT title, page_type, url, book_id FROM pages WHERE 1=1"
        params = []
        if args.page_type:
            sql += " AND page_type=?"; params.append(args.page_type)
        if args.book:
            sql += " AND book_id=?"; params.append(args.book)
        sql += " ORDER BY book_id, title LIMIT ?"; params.append(args.limit)
        rows = con.execute(sql, params).fetchall()
        for r in rows:
            print(f"- [{r['page_type']:<22}] {r['title']}  ({r['url']})")
        print(f"\n{len(rows)} page(s).")
        return 0

    if not args.query:
        print("Provide an FTS query, or use --list / --pmid. See --help.")
        return 1

    if args.sections:
        rows = fts_search(con, args.query, args.book, args.limit)
        terms = _first_terms(args.query)
        for r in rows:
            body = _clean_snippet_text(r["section_text"] or "")
            low = body.lower(); pos = -1
            for t in terms:
                p = low.find(t.lower())
                if p != -1 and (pos == -1 or p < pos):
                    pos = p
            start = max(0, pos - 60) if pos != -1 else 0
            snip = ("… " if start > 0 else "") + body[start:start + 240].strip() + " …"
            print(f"\n■ {r['title']}  — {r['heading']}")
            print(f"  {r['book_title']} ({r['edition']}) · {r['page_type']}")
            print(f"  {r['url']}")
            print(f"  {snip}")
    else:
        rows = page_search(con, args.query, args.book, args.limit)
        terms = _first_terms(args.query)
        for r in rows:
            print(f"\n■ {r['title']}")
            print(f"  {r['book_title']} ({r['edition']}) · {r['page_type']}")
            print(f"  {r['url']}")
            print(f"  {make_snippet(con, r['page_id'], terms)}")
    print(f"\n{len(rows)} hit(s) for: {args.query}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
