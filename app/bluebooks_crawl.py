"""
Step 2 — Crawl a book: harvest TOC -> queue pages -> extract -> store.

Resumable: rerun with the same --book to continue 'pending'/'error' pages.
Handles the ~15-min inactivity timeout by detecting a logged-out state,
recording progress, and exiting cleanly so you can re-auth and resume.

Usage:
    python bluebooks_crawl.py --config config.json --book 31
    python bluebooks_crawl.py --config config.json --book 31 --toc-only
    python bluebooks_crawl.py --config config.json --book 31 --limit 5   # smoke test

Grounded in live discovery:
    * URL model: /chapters/{book}  and  /chaptercontent/{book}/{pageId}
    * Non-contiguous, reused IDs -> harvest links, never guess ranges.
    * page_type taxonomy, image_type (figure/wsi/tables_boxes),
      link_kind, {PMID} + [[...]] reference formats.
"""
import argparse
import json
import re
import sqlite3
import sys
import time
from datetime import datetime, timezone
from urllib.parse import urljoin, urlparse
import term_recovery
from project_paths import DEFAULT_CONFIG, load_config

# Playwright is imported lazily inside main() so the pure-DB helpers
# (store_page, reset_book, extract_references, classify_page_type) can be
# imported and unit-tested without the browser package installed.
try:
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout
except ModuleNotFoundError:  # allows import for tests / list-only usage
    sync_playwright = None
    class PWTimeout(Exception):
        pass

# --------------------------------------------------------------------------- #
# Reference token patterns
# --------------------------------------------------------------------------- #
PMID_CURLY = re.compile(r"\{\s*(\d{5,9})\s*\}")
BRACKET_REF = re.compile(r"\[\[(.+?)\]\]", re.S)

# Fixed ~15-heading section index used by 5th-ed entity pages.
ENTITY_HEADINGS = {
    "definition", "icd-o coding", "icd-11 coding", "related terminology",
    "subtype(s)", "localization", "clinical features", "epidemiology",
    "etiology", "pathogenesis", "macroscopic appearance", "histopathology",
    "cytology", "diagnostic molecular pathology", "essential and desirable "
    "diagnostic criteria", "staging", "prognosis and prediction",
}

# Author-role label normalization (singular & plural variants observed).
ROLE_MAP = {
    "responsible editor": "responsible_editor",
    "responsible editors": "responsible_editor",
    "co-editor": "co_editor", "co-editors": "co_editor",
    "coeditor": "co_editor", "coeditors": "co_editor",
    "responsible author": "responsible_author",
    "responsible authors": "responsible_author",
    "co-author": "co_author", "co-authors": "co_author",
    "coauthor": "co_author", "coauthors": "co_author",
    "author": "responsible_author", "authors": "responsible_author",
    "editorial office": "editorial_office",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# --------------------------------------------------------------------------- #
# DB helpers
# --------------------------------------------------------------------------- #
def db(cfg) -> sqlite3.Connection:
    con = sqlite3.connect(cfg["db_path"])
    con.execute("PRAGMA foreign_keys=ON")
    con.row_factory = sqlite3.Row
    return con


def init_db(con: sqlite3.Connection) -> None:
    import os
    from project_paths import SQL
    schema_path = SQL / "schema.sql"
    with open(schema_path, encoding="utf-8") as f:
        con.executescript(f.read())
    con.commit()


# --------------------------------------------------------------------------- #
# Auth-state detection
# --------------------------------------------------------------------------- #
def looks_logged_out(page) -> bool:
    """Heuristic: explicit login page or clear login UI without auth markers."""
    url = (page.url or "").lower()
    if "/login" in url or "/account/login" in url:
        return True

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

                if (hasJwt || hasLogoutUi) return false;
                return hasLoginUi;
            }
        """))
    except Exception:
        return False


# --------------------------------------------------------------------------- #
# Page-type classification
# --------------------------------------------------------------------------- #
def classify_page_type(title: str, breadcrumb: str, headings: list[str], series: str) -> str:
    t = (title or "").strip().lower()
    b = (breadcrumb or "").lower()
    hset = {h.strip().lower() for h in headings}

    if "reporting system" in (series or "").lower() or "reporting systems" in b:
        return "reporting_system_section"
    if "editorial board" in t:
        return "editorial_board"
    if "how to cite" in t:
        return "how_to_cite"
    if t.startswith("foreword") or "corrigenda" in t:
        return "foreword"
    if "icd-o" in t and ("coding" in t or "topograph" in t):
        return "icdo_coding"
    if "tnm" in t or "staging" in t:
        return "tnm_staging"
    if "iccr" in t or "dataset" in t:
        return "iccr_datasets"
    if "copyright" in t or "declaration of interest" in t or "contributors" in t \
            or "acknowledgement" in t or "front matter" in t:
        return "front_matter"
    if "subcommittee" in t:
        return "subcommittee"
    if t.startswith("introduction") or "introduction" in t and len(hset) <= 3:
        return "chapter_intro"
    if hset & ENTITY_HEADINGS or ("definition" in hset and len(hset) > 3):
        return "tumour_entity"
    if "classification" in t and "overview" in t:
        return "classification_overview"
    return "other"


def normalize_role(label: str) -> str:
    return ROLE_MAP.get((label or "").strip().lower().rstrip(":"), "other")


GENERIC_PAGE_TITLES = {"bluebooksonline"}
SECTION_HEADING_STOPWORDS = {
    "definition", "icd-o coding", "icd-11 coding", "related terminology",
    "subtype(s)", "localization", "clinical features", "epidemiology",
    "etiology", "pathogenesis", "macroscopic appearance", "histopathology",
    "cytology", "diagnostic molecular pathology",
    "essential and desirable diagnostic criteria", "staging",
    "prognosis and prediction",
}


def is_generic_title(title: str | None) -> bool:
    return not title or title.strip().lower() in GENERIC_PAGE_TITLES


def split_breadcrumb(breadcrumb: str) -> list[str]:
    text = (breadcrumb or "").replace("\xa0", " ").replace("\n", " ")
    return [part.strip() for part in re.split(r"\s*//\s*", text) if part.strip()]


def split_numbered_heading(label: str) -> tuple[int | None, str]:
    m = re.match(r"^(\d+)\.\s*(.+)$", (label or "").strip())
    if not m:
        return None, (label or "").strip()
    return int(m.group(1)), m.group(2).strip()


def get_or_create_hierarchy(con, book_id: int, breadcrumb: str, page_title: str) -> tuple[int | None, int | None]:
    parts = split_breadcrumb(breadcrumb)
    if len(parts) < 2:
        return None, None

    chapter_number, chapter_title = split_numbered_heading(parts[1])
    row = con.execute(
        "SELECT chapter_id FROM chapters WHERE book_id=? AND title=?",
        (book_id, chapter_title),
    ).fetchone()
    if row:
        chapter_id = row["chapter_id"]
    else:
        ord_value = chapter_number if chapter_number is not None else len(parts)
        cur = con.execute(
            "INSERT INTO chapters(book_id, number, title, ord) VALUES(?,?,?,?)",
            (book_id, chapter_number, chapter_title, ord_value),
        )
        chapter_id = cur.lastrowid

    group_labels = parts[2:-1]
    if parts and parts[-1] == page_title:
        group_labels = parts[2:-1]
    else:
        group_labels = parts[2:]

    parent_group = None
    for level, label in enumerate(group_labels, start=1):
        row = con.execute(
            "SELECT group_id FROM page_groups WHERE chapter_id=? AND "
            "IFNULL(parent_group, -1)=IFNULL(?, -1) AND label=? AND level=?",
            (chapter_id, parent_group, label, level),
        ).fetchone()
        if row:
            parent_group = row["group_id"]
            continue
        cur = con.execute(
            "INSERT INTO page_groups(chapter_id, parent_group, label, level, ord) VALUES(?,?,?,?,?)",
            (chapter_id, parent_group, label, level, level),
        )
        parent_group = cur.lastrowid

    return chapter_id, parent_group


def extract_authors_from_text(text: str, page_title: str) -> list[dict[str, str]]:
    lines = [line.strip() for line in (text or "").replace("\xa0", " ").splitlines() if line.strip()]
    if not lines:
        return []

    role_labels = sorted({label for label in ROLE_MAP}, key=len, reverse=True)
    role_lookup = {label.lower(): label for label in role_labels}

    try:
        start = next(i for i, line in enumerate(lines) if line.lower() == "authors")
    except StopIteration:
        return []

    authors = []
    current_role = None
    for line in lines[start + 1:]:
        low = line.lower().rstrip(":")
        if line == page_title or low in SECTION_HEADING_STOPWORDS:
            break
        if low in {"add personal note", "send us feedback", "attachment", "tables from"}:
            break
        matched_role = role_lookup.get(low)
        if matched_role:
            current_role = matched_role
            continue
        if current_role:
            authors.append({"role_label": current_role, "name": line})
    return authors


# --------------------------------------------------------------------------- #
# TOC harvest
# --------------------------------------------------------------------------- #
TOC_JS = r"""
() => {
  const base = location.origin;
    const anchors = Array.from(document.querySelectorAll('a[href]')).filter(a => {
        const href = a.getAttribute('href') || '';
        return /(^|\/)chaptercontent\//i.test(href);
    });
  const seen = new Set();
  const leaves = [];
  for (const a of anchors) {
    const href = a.getAttribute('href');
    if (!href) continue;
    const abs = new URL(href, base).href;
    if (seen.has(abs)) continue;
    seen.add(abs);
    const text = (a.innerText || a.textContent || '').trim();
    const isPointer = /\(see\s+chapter/i.test(text);
    leaves.push({ href: abs, text, is_pointer: isPointer });
  }
    const titleNode = document.querySelector('h1, .book-title, .page-title, [class*="book" i][class*="title" i]');
    const title = (titleNode?.innerText || titleNode?.textContent || '').trim()
                                || document.title || '';
  return { title: title.trim(), leaves };
}
"""


def expand_toc(page) -> None:
    """Best-effort click of the expand-all control(s)."""
    selectors = [
        ".expand-all", "[aria-label*='expand' i]", ".fa-angle-double-down",
        "button:has-text('Expand all')", "button:has-text('Expand')",
    ]
    for sel in selectors:
        try:
            loc = page.locator(sel).first
            if loc.count() > 0:
                loc.click(timeout=2500)
                page.wait_for_timeout(800)
        except Exception:
            continue
    # Also click any collapsed accordion toggles to force lazy content.
    try:
        toggles = page.locator("button[aria-expanded='false']")
        n = min(toggles.count(), 200)
        for i in range(n):
            try:
                toggles.nth(i).click(timeout=800)
            except Exception:
                pass
        page.wait_for_timeout(800)
    except Exception:
        pass


def site_page_id_from_url(url: str) -> int | None:
    m = re.search(r"/chaptercontent/\d+/(\d+)", url)
    return int(m.group(1)) if m else None


def harvest_toc(page, cfg, con, book_id: int) -> dict:
    page.goto(f'{cfg["base_url"]}/chapters/{book_id}', wait_until="networkidle")
    if looks_logged_out(page):
        raise RuntimeError("AUTH_EXPIRED")
    expand_toc(page)
    data = page.evaluate(TOC_JS)

    existing = con.execute("SELECT title FROM books WHERE book_id=?", (book_id,)).fetchone()
    book_title = data.get("title") or ""
    if is_generic_title(book_title):
        book_title = existing["title"] if existing and existing["title"] else f"Book {book_id}"

    # Upsert book row.
    con.execute(
        "INSERT OR IGNORE INTO books(book_id, title, alias, url) VALUES(?,?,?,?)",
        (book_id, book_title, term_recovery.book_version_alias(book_title, None),
         f'{cfg["base_url"]}/chapters/{book_id}'),
    )
    if book_title and not is_generic_title(book_title):
        con.execute("UPDATE books SET title=? WHERE book_id=?",
                    (book_title, book_id))

    for ord_value, chapter_label in enumerate(
        page.locator("div.accordion-toggle").evaluate_all(
            "els => els.map(e => (e.innerText || e.textContent || '').trim()).filter(Boolean)"
        ),
        start=1,
    ):
        chapter_number, chapter_title = split_numbered_heading(chapter_label)
        row = con.execute(
            "SELECT chapter_id FROM chapters WHERE book_id=? AND title=?",
            (book_id, chapter_title),
        ).fetchone()
        if row:
            con.execute(
                "UPDATE chapters SET number=COALESCE(number, ?), ord=? WHERE chapter_id=?",
                (chapter_number, ord_value, row["chapter_id"]),
            )
        else:
            con.execute(
                "INSERT INTO chapters(book_id, number, title, ord) VALUES(?,?,?,?)",
                (book_id, chapter_number, chapter_title, ord_value),
            )

    queued = 0
    for leaf in data["leaves"]:
        spid = site_page_id_from_url(leaf["href"])
        if spid is None:
            continue
        con.execute(
            "INSERT OR IGNORE INTO crawl_queue(book_id, site_page_id, url, status, updated_at) "
            "VALUES(?,?,?, 'pending', ?)",
            (book_id, spid, leaf["href"], now_iso()),
        )
        queued += 1
    con.commit()
    return {"title": data.get("title"), "leaves": len(data["leaves"]), "queued": queued}


# --------------------------------------------------------------------------- #
# Page extraction
# --------------------------------------------------------------------------- #
PAGE_JS = r"""
() => {
  const base = location.origin;
  const pick = (sels) => { for (const s of sels){ const e=document.querySelector(s); if(e) return e; } return null; };

  const root = pick(['#content','.chapter-content','.content-pane','main article','.book-content','main']) || document.body;
    const breadcrumb = (pick(['.breadcrumb','nav.breadcrumb','.breadcrumbs','[class*="breadcrumb" i]']) || {}).innerText || '';
    const titleCandidates = Array.from(root.querySelectorAll('h1, h2, h3, h4, .entity-title, .chapter-title, .title'))
        .map(e => (e.innerText || e.textContent || '').trim())
        .filter(t => t && t.toLowerCase() !== 'attachment' && t.toLowerCase() !== 'authors'
            && t.toLowerCase() !== 'send us feedback' && t.toLowerCase() !== 'tables from:');
    let title = titleCandidates[0] || '';
    if (!title && breadcrumb.trim()) {
        const parts = breadcrumb.split(/\s*\/\/\s*/).map(s => s.trim()).filter(Boolean);
        if (parts.length) title = parts[parts.length - 1];
    }
    if (!title) title = document.title || '';
  const subtitle = (pick(['.subtitle','h2.sub']) || {}).innerText || '';

  // Sections: headings (h2..h4) and the text that follows until the next heading.
  const sections = [];
  const heads = Array.from(root.querySelectorAll('h2, h3, h4'));
  if (heads.length === 0) {
    sections.push({ heading: '', body_text: (root.innerText||'').trim() });
  } else {
    heads.forEach((h, i) => {
      const parts = [];
      let n = h.nextElementSibling;
      const stop = heads[i+1] || null;
      while (n && n !== stop) {
        if (/^H[2-4]$/.test(n.tagName)) break;
        parts.push(n.innerText || '');
        n = n.nextElementSibling;
      }
      sections.push({ heading: (h.innerText||'').trim(), body_text: parts.join('\n').trim() });
    });
  }

  // Authors: label:name pairs in an author/contributor block.
  const authors = [];
  root.querySelectorAll('.author, .authors, .contributor, .contributors, [class*="author" i]').forEach(el => {
    const txt = (el.innerText||'').trim();
    (txt.split('\n')).forEach(line => {
      const m = line.match(/^([A-Za-z\-\s]+?):\s*(.+)$/);
      if (m) authors.push({ role_label: m[1].trim(), name: m[2].trim() });
    });
  });

  // Images: capture real src/currentSrc (accessibility data alone is insufficient).
  const images = [];
  root.querySelectorAll('img').forEach(img => {
    const full = img.currentSrc || img.src || img.getAttribute('data-src') || '';
    if (!full) return;
    const abs = (() => { try { return new URL(full, base).href; } catch(e){ return full; } })();
    const cap = (img.closest('figure')?.querySelector('figcaption')?.innerText
                 || img.getAttribute('alt') || '').trim();
    let itype = 'figure';
    const hay = (abs + ' ' + cap).toLowerCase();
    if (hay.includes('wsi') || hay.includes('whole-slide') || hay.includes('whole slide')) itype = 'whole_slide_image';
    else if (hay.includes('box') || hay.includes('table')) itype = 'tables_boxes';
    images.push({ full_url: abs, thumb_url: img.getAttribute('data-thumb')||'', caption: cap, image_type: itype });
  });

  // Links.
  const links = [];
  root.querySelectorAll('a[href]').forEach(a => {
    const href = a.getAttribute('href') || '';
    let abs = href; try { abs = new URL(href, base).href; } catch(e){}
    const text = (a.innerText||'').trim();
    let kind = 'internal';
    if (href.startsWith('mailto:')) kind = 'mailto';
    else if (/^https?:\/\//i.test(href) && !abs.startsWith(base)) kind = 'external';
    else if (/chaptercontent/i.test(abs)) kind = /\(see\s+chapter/i.test(text) ? 'cross_reference' : 'internal';
    links.push({ link_text: text, target_url: abs, link_kind: kind });
  });

  return { title: title.trim(), subtitle: subtitle.trim(),
           breadcrumb: breadcrumb.trim(), html: root.innerHTML,
           text: (root.innerText||'').trim(),
           sections, authors, images, links };
}
"""


def extract_references(text: str):
    refs = []
    for m in PMID_CURLY.finditer(text or ""):
        refs.append({"token": m.group(1), "token_format": "pmid_curly", "raw_text": m.group(0)})
    for m in BRACKET_REF.finditer(text or ""):
        refs.append({"token": m.group(1).strip()[:400], "token_format": "bracket", "raw_text": m.group(0)[:1000]})
    return refs


def store_page(con, cfg, book_id, url, extracted, series, capture_images=True):
    spid = site_page_id_from_url(url)
    breadcrumb_parts = split_breadcrumb(extracted["breadcrumb"])
    page_title = extracted["title"]
    if is_generic_title(page_title) and breadcrumb_parts:
        page_title = breadcrumb_parts[-1]
    if not extracted["authors"]:
        extracted["authors"] = extract_authors_from_text(extracted["text"], page_title)
    chapter_id, group_id = get_or_create_hierarchy(con, book_id, extracted["breadcrumb"], page_title)
    headings = [s["heading"] for s in extracted["sections"] if s["heading"]]
    ptype = classify_page_type(page_title, extracted["breadcrumb"], headings, series)
    is_pointer = 1 if any(l["link_kind"] == "cross_reference" for l in extracted["links"]) \
                 and len(extracted["text"]) < 400 else 0

    cur = con.execute(
        "INSERT OR IGNORE INTO pages(book_id, chapter_id, group_id, site_page_id, url, title, subtitle, breadcrumb, "
        "page_type, is_pointer, raw_html, crawl_status, fetched_at) "
        "VALUES(?,?,?,?,?,?,?,?,?,?,?, 'done', ?)",
        (book_id, chapter_id, group_id, spid, url, page_title, extracted["subtitle"],
         extracted["breadcrumb"], ptype, is_pointer, extracted["html"], now_iso()),
    )
    row = con.execute("SELECT page_id FROM pages WHERE url=?", (url,)).fetchone()
    page_id = row["page_id"]
    con.execute("UPDATE pages SET chapter_id=?, group_id=?, title=?, page_type=?, raw_html=?, crawl_status='done', fetched_at=? WHERE page_id=?",
                (chapter_id, group_id, page_title, ptype, extracted["html"], now_iso(), page_id))

    # Clear any prior child rows (idempotent re-crawl).
    for tbl in ("sections", "authors", "images", "page_links", '"references"'):
        con.execute(f"DELETE FROM {tbl} WHERE page_id=?", (page_id,))

    section_ids = []
    for i, s in enumerate(extracted["sections"]):
        c = con.execute("INSERT INTO sections(page_id, heading, body_text, ord) VALUES(?,?,?,?)",
                        (page_id, s["heading"], s["body_text"], i))
        section_ids.append(c.lastrowid)

    for a in extracted["authors"]:
        con.execute("INSERT INTO authors(page_id, role, name) VALUES(?,?,?)",
                    (page_id, normalize_role(a["role_label"]), a["name"]))

    if capture_images:
        for img in extracted["images"]:
            con.execute(
                "INSERT INTO images(page_id, image_type, caption, thumb_url, full_url) VALUES(?,?,?,?,?)",
                (page_id, img["image_type"], img["caption"], img["thumb_url"], img["full_url"]))

    for l in extracted["links"]:
        con.execute("INSERT INTO page_links(page_id, link_text, target_url, link_kind) VALUES(?,?,?,?)",
                    (page_id, l["link_text"], l["target_url"], l["link_kind"]))

    for r in extract_references(extracted["text"]):
        con.execute('INSERT INTO "references"(page_id, token, token_format, raw_text) VALUES(?,?,?,?)',
                    (page_id, r["token"], r["token_format"], r["raw_text"]))

    con.commit()
    return page_id, ptype


def crawl_page(page, cfg, con, book_id, url, series, capture_images=True):
    page.goto(url, wait_until="networkidle")
    if looks_logged_out(page):
        raise RuntimeError("AUTH_EXPIRED")
    page.wait_for_timeout(int(cfg.get("polite_delay_seconds", 1.0) * 1000))
    extracted = page.evaluate(PAGE_JS)
    return store_page(con, cfg, book_id, url, extracted, series, capture_images=capture_images)


# --------------------------------------------------------------------------- #
# Re-scrape: purge a book's crawled data so it is fetched fresh
# --------------------------------------------------------------------------- #
def reset_book(con, book_id: int) -> None:
    """Delete a book's pages (and cascaded child rows) and clear its queue,
    so the next crawl re-harvests the TOC and re-fetches every page."""
    page_ids = [r["page_id"] for r in
                con.execute("SELECT page_id FROM pages WHERE book_id=?", (book_id,)).fetchall()]
    for pid in page_ids:
        for tbl in ("sections", "authors", "images", "page_links", '"references"'):
            con.execute(f"DELETE FROM {tbl} WHERE page_id=?", (pid,))
    con.execute("DELETE FROM pages WHERE book_id=?", (book_id,))
    con.execute("DELETE FROM crawl_queue WHERE book_id=?", (book_id,))
    con.commit()
    print(f"[reset] cleared {len(page_ids)} pages + queue for book {book_id}.")


# --------------------------------------------------------------------------- #
# Crawl a single book with an already-open page/context
# --------------------------------------------------------------------------- #
def crawl_one_book(page, cfg, con, book_id, toc_only=False, limit=0, capture_images=True) -> str:
    run = con.execute("INSERT INTO crawl_runs(started_at, book_id, status) VALUES(?,?, 'running')",
                      (now_iso(), book_id))
    run_id = run.lastrowid
    con.commit()

    series_row = con.execute("SELECT series FROM books WHERE book_id=?", (book_id,)).fetchone()
    series = series_row["series"] if series_row and series_row["series"] else ""

    info = harvest_toc(page, cfg, con, book_id)
    print(f"[toc] book {book_id} — {info['title']}: {info['leaves']} leaf links, {info['queued']} queued.")
    if toc_only:
        con.execute("UPDATE crawl_runs SET finished_at=?, status='toc_only' WHERE run_id=?",
                    (now_iso(), run_id))
        con.commit()
        return "toc_only"

    done = 0
    while True:
        row = con.execute(
            "SELECT * FROM crawl_queue WHERE book_id=? AND status IN('pending','error') "
            "ORDER BY queue_id LIMIT 1", (book_id,)).fetchone()
        if row is None:
            break
        url = row["url"]
        try:
            _, ptype = crawl_page(page, cfg, con, book_id, url, series, capture_images=capture_images)
            con.execute("UPDATE crawl_queue SET status='done', updated_at=? WHERE queue_id=?",
                        (now_iso(), row["queue_id"]))
            con.commit()
            done += 1
            print(f"  [{done}] done  {ptype:<24} {url}")
        except RuntimeError as e:
            if str(e) == "AUTH_EXPIRED":
                print("\n[!] Session expired. Re-run bluebooks_auth.py, then re-run to resume.")
                con.execute("UPDATE crawl_runs SET finished_at=?, status='auth_expired', pages_done=? WHERE run_id=?",
                            (now_iso(), done, run_id))
                con.commit()
                return "auth_expired"
            raise
        except (PWTimeout, Exception) as e:  # noqa
            con.execute("UPDATE crawl_queue SET status='error', attempts=attempts+1, last_error=?, updated_at=? WHERE queue_id=?",
                        (str(e)[:900], now_iso(), row["queue_id"]))
            con.execute("UPDATE pages SET crawl_status='error', error_note=? WHERE url=?",
                        (str(e)[:900], url))
            con.commit()
            print(f"  [err] {url} :: {str(e)[:120]}")

        if limit and done >= limit:
            print(f"  [limit] reached {limit} pages, stopping this book.")
            break
        time.sleep(cfg.get("polite_delay_seconds", 1.0))

    con.execute("UPDATE crawl_runs SET finished_at=?, status='done', pages_done=? WHERE run_id=?",
                (now_iso(), done, run_id))
    con.commit()
    print(f"[done] book {book_id}: crawled {done} pages.")
    return "done"


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Crawl one or more WHO Blue Books volumes into SQLite.")
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--book", type=int, nargs="+", required=True,
                    help="One or more book ids (the {id} in /chapters/{id}). e.g. --book 31 45 72")
    ap.add_argument("--toc-only", action="store_true", help="Only harvest the TOC into the queue.")
    ap.add_argument("--limit", type=int, default=0, help="Stop after N pages per book (0=all). Good for smoke tests.")
    ap.add_argument("--no-images", action="store_true",
                    help="Skip image capture (links are still recorded). Reduces DB size and time.")
    ap.add_argument("--rescrape", action="store_true",
                    help="Purge each selected book's existing data first, then crawl fresh.")
    args = ap.parse_args()
    cfg = load_config(args.config)

    # config default for images can be overridden by --no-images
    capture_images = cfg.get("capture_images", True) and not args.no_images

    con = db(cfg)
    init_db(con)

    if args.rescrape:
        for b in args.book:
            reset_book(con, b)

    print(f"[plan] books={args.book}  images={'on' if capture_images else 'OFF'}  "
          f"{'toc-only' if args.toc_only else ''}{f' limit={args.limit}' if args.limit else ''}")

    if sync_playwright is None:
        print("[!] Playwright is not installed. Run:  pip install -r requirements.txt "
              "&& python -m playwright install chromium")
        return 3

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=cfg.get("headless", True))
        ctx = browser.new_context(storage_state=cfg["auth_state_path"])
        page = ctx.new_page()
        page.set_default_navigation_timeout(cfg.get("nav_timeout_ms", 30000))
        rc = 0
        try:
            for b in args.book:
                status = crawl_one_book(page, cfg, con, b,
                                        toc_only=args.toc_only, limit=args.limit,
                                        capture_images=capture_images)
                if status == "auth_expired":
                    rc = 2
                    break
        finally:
            browser.close()
    return rc


if __name__ == "__main__":
    sys.exit(main())
