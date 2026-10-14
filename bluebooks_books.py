"""
Book discovery + inventory.

Two modes:

  discover  — open the site (authenticated), harvest every available book across
              all edition tabs (5th, 6th, Cytopathology / Reporting Systems),
              and upsert them into the `books` table.
  list      — print the book inventory from the DB with per-book crawl status
              (queued / done / error page counts) so you can decide what to
              crawl or re-crawl.

Usage:
    python bluebooks_books.py --config config.json discover
    python bluebooks_books.py --config config.json list
    python bluebooks_books.py --config config.json list --json

Then feed chosen ids to the crawler:
    python bluebooks_crawl.py --config config.json --book 31 72 --no-images
"""
import argparse
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
import term_recovery

# Lazy import so `list` mode works without the browser package.
try:
    from playwright.sync_api import sync_playwright
except ModuleNotFoundError:
    sync_playwright = None


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def db(cfg) -> sqlite3.Connection:
    con = sqlite3.connect(cfg["db_path"])
    con.execute("PRAGMA foreign_keys=ON")
    con.row_factory = sqlite3.Row
    return con


def init_db(con) -> None:
    import os
    schema_path = os.path.join(os.path.dirname(__file__), "schema.sql")
    with open(schema_path, encoding="utf-8") as f:
        con.executescript(f.read())
    con.commit()


def looks_logged_out(page) -> bool:
    """Heuristic: explicit login page or clear login UI without auth markers."""
    url = (page.url or "").lower()
    if "/login" in url or "/account/login" in url:
        return True

    # Avoid treating authenticated /home layouts as logged out just because
    # they use different content containers than chapter pages.
    try:
        return bool(page.evaluate("""
            () => {
                const hasJwt = !!localStorage.getItem('jwt');
                const hasLogoutUi = !!document.querySelector(
                    'a[href*="logout" i], button[aria-label*="logout" i], [class*="profile" i], [class*="user-menu" i]'
                );
                const hasLoginUi = !!document.querySelector(
                    'input[type="password"], form[action*="login" i], a[href*="login" i], button[class*="login" i], button[id*="login" i]'
                );

                // Auth markers present -> not logged out.
                if (hasJwt || hasLogoutUi) return false;
                // No auth markers and login widgets visible -> logged out.
                return hasLoginUi;
            }
        """))
    except Exception:
        return False


# Harvest all /chapters/{id} links on the current page, with nearby label text
# and any edition/status hints available in the surrounding markup.
BOOKS_JS = r"""
() => {
  const base = location.origin;
  const out = [];
  const seen = new Set();

    const parseBookId = (href, el) => {
        const txt = href || '';
        let m = txt.match(/\/chapters\/(\d+)/i);
        if (m) return parseInt(m[1], 10);

        // Some views expose chapter pages directly: /chaptercontent/{bookId}/{pageId}
        m = txt.match(/\/chaptercontent\/(\d+)\/(\d+)/i);
        if (m) return parseInt(m[1], 10);

        // Query-string fallback patterns.
        m = txt.match(/[?&](?:bookid|book_id|chapterid|chapter_id)=(\d+)/i);
        if (m) return parseInt(m[1], 10);

        // Data attributes fallback.
        if (el) {
            const attrs = [
                'data-book-id', 'data-bookid', 'data-chapter-id',
                'data-chapterid', 'book-id', 'bookid'
            ];
            for (const a of attrs) {
                const v = el.getAttribute(a);
                if (v && /^\d+$/.test(v)) return parseInt(v, 10);
            }
        }
        return null;
    };

    const anchors = Array.from(document.querySelectorAll('a[href]')).filter(a => {
        const href = (a.getAttribute('href') || '').toLowerCase();
        return href.includes('/chapters/') || href.includes('/chaptercontent/')
            || href.includes('bookid=') || href.includes('chapterid=');
    });

    anchors.forEach(a => {
    const href = a.getAttribute('href') || '';
        const id = parseBookId(href, a);
        if (!id) return;
    if (seen.has(id)) return;
    seen.add(id);

        let title = (a.innerText || a.textContent || '').trim();
        if (!title) {
            const cardTitle = a.closest('.card, .book, li, .col, .book-card, article')
                ?.querySelector('h1, h2, h3, h4, .title, .book-title');
            title = (cardTitle?.innerText || cardTitle?.textContent || '').trim();
        }

    // Look for a status chip (Beta / Print) near the link.
    let status = '';
        const card = a.closest('.card, .book, li, .col, .book-card, article') || a.parentElement;
    if (card) {
      const t = (card.innerText || '');
      if (/beta/i.test(t)) status = 'Beta';
      else if (/print/i.test(t)) status = 'Print';
    }
    out.push({ book_id: id, title, status, url: new URL(href, base).href });
  });
  return out;
}
"""

DISCOVERY_DEBUG_JS = r"""
() => {
    const hrefs = Array.from(document.querySelectorAll('a[href]'))
        .map(a => a.getAttribute('href') || '')
        .filter(h => /chapters|chaptercontent|bookid=|chapterid=/i.test(h));
    return {
        title: document.title || '',
        totalAnchors: document.querySelectorAll('a[href]').length,
        matchingAnchors: hrefs.length,
        sampleHrefs: hrefs.slice(0, 8),
    };
}
"""

# The edition tabs / navigation entry points to click through.
EDITION_TABS = [
    ("5th", "5th"),
    ("6th", "6th"),
    ("Cytopathology", "cytopathology"),
    ("Reporting Systems", "cytopathology"),
]


def discover(page, cfg, con) -> int:
    page.goto(cfg["base_url"] + "/home", wait_until="networkidle")
    if looks_logged_out(page):
        raise RuntimeError("AUTH_EXPIRED")
    page.wait_for_timeout(2000)

    found = {}  # book_id -> record

    def parse_title_status(raw_text: str) -> tuple[str, str]:
        txt = re.sub(r"\s+", " ", (raw_text or "")).strip()
        parts = [p.strip() for p in txt.split("|") if p.strip()]
        title = parts[0] if parts else txt
        status = ""
        for p in parts[1:]:
            low = p.lower()
            if "beta" in low:
                status = "Beta"
                break
            if "print" in low:
                status = "Print"
                break
        return title, status

    def harvest(edition_label):
        page.wait_for_timeout(1200)
        recs = page.evaluate(BOOKS_JS)
        label = edition_label or "default"
        print(f"[discover] {label}: {len(recs)} candidate book(s) at {page.url}")
        for rec in recs:
            bid = rec["book_id"]
            if bid not in found:
                rec["edition"] = edition_label
                found[bid] = rec
            elif not found[bid].get("edition"):
                found[bid]["edition"] = edition_label

    def harvest_clickable_cards(edition_label: str, tab_text: str) -> None:
        cards = page.locator("div.cursor-pointor:visible")
        total = cards.count()
        print(f"[discover] {edition_label or 'default'}: {total} visible card(s)")

        for i in range(total):
            cards = page.locator("div.cursor-pointor:visible")
            if i >= cards.count():
                break

            card = cards.nth(i)
            raw = card.inner_text()
            title, status = parse_title_status(raw)
            try:
                card.click(timeout=4500)
                page.wait_for_timeout(1500)
                m = re.search(r"/chapters/(\d+)", page.url)
                if m:
                    bid = int(m.group(1))
                    rec = {
                        "book_id": bid,
                        "title": title or f"Book {bid}",
                        "status": status,
                        "url": page.url,
                        "edition": edition_label,
                    }
                    if bid not in found:
                        found[bid] = rec
                    else:
                        found[bid]["title"] = found[bid].get("title") or rec["title"]
                        found[bid]["status"] = found[bid].get("status") or rec["status"]
                        found[bid]["url"] = found[bid].get("url") or rec["url"]
                        if not found[bid].get("edition"):
                            found[bid]["edition"] = edition_label
            except Exception:
                pass
            finally:
                page.goto(cfg["base_url"] + "/home", wait_until="networkidle")
                page.wait_for_timeout(900)
                click_edition_tab(tab_text)

    def click_edition_tab(tab_text):
        # Try common accessible roles first.
        for getter in (
            lambda: page.get_by_role("tab", name=tab_text, exact=False).first,
            lambda: page.get_by_role("button", name=tab_text, exact=False).first,
            lambda: page.get_by_role("link", name=tab_text, exact=False).first,
            lambda: page.get_by_text(tab_text, exact=False).first,
        ):
            try:
                loc = getter()
                if loc.count() > 0:
                    loc.click(timeout=3500)
                    page.wait_for_timeout(1500)
                    return True
            except Exception:
                continue

        # Last-resort DOM text match click.
        try:
            clicked = page.evaluate(
                """
                (txt) => {
                  const norm = (s) => (s || '').toLowerCase();
                  const want = norm(txt);
                  const nodes = Array.from(document.querySelectorAll('a,button,[role="tab"],li,div,span'));
                  for (const n of nodes) {
                    if (norm(n.innerText).includes(want)) {
                      n.click();
                      return true;
                    }
                  }
                  return false;
                }
                """,
                tab_text,
            )
            if clicked:
                page.wait_for_timeout(1500)
                return True
        except Exception:
            pass
        return False

    # Click each edition tab if present, then harvest via both href parsing and
    # card click-through fallback (newer UI exposes cards without chapter hrefs).
    for tab_text, edition_label in EDITION_TABS:
        try:
            if click_edition_tab(tab_text):
                harvest(edition_label)
                harvest_clickable_cards(edition_label, tab_text)
            else:
                print(f"[discover] tab not found/clickable: {tab_text}")
        except Exception:
            continue

    if not found:
        dbg = page.evaluate(DISCOVERY_DEBUG_JS)
        print("[discover] parser found 0 books. Debug context:")
        print(f"  URL: {page.url}")
        print(f"  Title: {dbg.get('title', '')}")
        print(f"  Total anchors: {dbg.get('totalAnchors', 0)}")
        print(f"  Matching anchors: {dbg.get('matchingAnchors', 0)}")
        for href in dbg.get("sampleHrefs", []):
            print(f"    - {href}")

    # Upsert into books table.
    n = 0
    for rec in found.values():
        con.execute(
            "INSERT INTO books(book_id, title, alias, edition, status, url) VALUES(?,?,?,?,?,?) "
            "ON CONFLICT(book_id) DO UPDATE SET "
            "  title=excluded.title, "
            "  alias=COALESCE(NULLIF(books.alias,''),excluded.alias), "
            "  edition=COALESCE(NULLIF(excluded.edition,''), books.edition), "
            "  status=COALESCE(NULLIF(excluded.status,''), books.status), "
            "  url=excluded.url",
            (rec["book_id"], rec["title"] or f"Book {rec['book_id']}",
             term_recovery.book_version_alias(
                 rec["title"] or f"Book {rec['book_id']}", rec.get("edition")
             ),
             rec.get("edition") or None, rec.get("status") or None, rec["url"]),
        )
        n += 1
    con.commit()
    print(f"[discover] found and recorded {n} book(s).")
    return n


def list_books(con, as_json=False) -> None:
    rows = con.execute("""
      SELECT b.book_id, b.title, b.edition, b.status,
             (SELECT COUNT(*) FROM pages p WHERE p.book_id=b.book_id) AS pages_done,
             (SELECT COUNT(*) FROM crawl_queue q WHERE q.book_id=b.book_id AND q.status='pending') AS pending,
             (SELECT COUNT(*) FROM crawl_queue q WHERE q.book_id=b.book_id AND q.status='error') AS errors
      FROM books b
      ORDER BY b.edition, b.book_id
    """).fetchall()

    if as_json:
        print(json.dumps([dict(r) for r in rows], indent=2))
        return

    if not rows:
        print("No books recorded yet. Run:  python bluebooks_books.py discover")
        return

    print(f"\n{'ID':>4}  {'Edition':<14} {'Status':<6} {'Pages':>6} {'Pend':>5} {'Err':>4}  Title")
    print("-" * 90)
    for r in rows:
        print(f"{r['book_id']:>4}  {(r['edition'] or ''):<14} {(r['status'] or ''):<6} "
              f"{r['pages_done']:>6} {r['pending']:>5} {r['errors']:>4}  {r['title']}")
    print(f"\n{len(rows)} book(s). To crawl:  python bluebooks_crawl.py --book <id> [<id> ...]\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="Discover and inventory Blue Books volumes.")
    ap.add_argument("--config", default="config.json")
    ap.add_argument("mode", choices=["discover", "list"])
    ap.add_argument("--json", action="store_true", help="For 'list': emit JSON.")
    args = ap.parse_args()
    cfg = json.load(open(args.config, encoding="utf-8"))

    con = db(cfg)
    init_db(con)

    if args.mode == "list":
        list_books(con, as_json=args.json)
        return 0

    # discover
    if sync_playwright is None:
        print("[!] Playwright is not installed. Run:  pip install -r requirements.txt "
              "&& python -m playwright install chromium")
        return 3
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=cfg.get("headless", True))
        ctx = browser.new_context(storage_state=cfg["auth_state_path"])
        page = ctx.new_page()
        page.set_default_navigation_timeout(cfg.get("nav_timeout_ms", 30000))
        try:
            discover(page, cfg, con)
        except RuntimeError as e:
            if str(e) == "AUTH_EXPIRED":
                print("[!] Not logged in. Run bluebooks_auth.py first.")
                browser.close()
                return 2
            raise
        finally:
            browser.close()
    list_books(con)
    return 0


if __name__ == "__main__":
    sys.exit(main())
