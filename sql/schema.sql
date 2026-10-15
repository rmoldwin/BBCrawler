-- ============================================================================
-- WHO Blue Books corpus — SQLite schema (v1)
-- Grounded in cross-edition live discovery:
--   URL model: book TOC = /chapters/{bookId}; leaf = /chaptercontent/{bookId}/{pageId}
--   Non-contiguous, reused page IDs -> harvest links, never guess ranges.
--   Multi-level page groups (>=3), cross-reference/pointer entries,
--   expanded page_type enum, image_type (figure/wsi/tables_boxes),
--   link_kind, normalized author roles, {PMID} and [[...]] reference formats.
-- ============================================================================
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- ---------------------------------------------------------------------------
-- Books  (one row per site "chapters/{id}" volume)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS books (
  book_id      INTEGER PRIMARY KEY,        -- the {id} in /chapters/{id}
  title        TEXT NOT NULL,
  alias        TEXT,                       -- editable short book/version label used in views
  edition      TEXT,                       -- '5th' | '6th' | 'cytopathology'
  series       TEXT,                       -- e.g. 'WHO Classification of Tumours' | 'IAC-IARC-WHO Reporting Systems'
  status       TEXT,                       -- 'Print' | 'Beta'
  url          TEXT NOT NULL
);

-- ---------------------------------------------------------------------------
-- Chapters (top-level accordion sections within a book TOC)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chapters (
  chapter_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id      INTEGER NOT NULL REFERENCES books(book_id),
  number       INTEGER,                    -- chapter number if present
  title        TEXT NOT NULL,
  ord          INTEGER                     -- display order within the book
);

-- ---------------------------------------------------------------------------
-- Page groups (>= 3 levels: group header -> subgroup header -> deeper,
--   plus page-under-page nesting). parent_group gives the tree.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS page_groups (
  group_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  chapter_id   INTEGER NOT NULL REFERENCES chapters(chapter_id),
  parent_group INTEGER REFERENCES page_groups(group_id),
  label        TEXT NOT NULL,
  level        INTEGER NOT NULL,           -- 1=group, 2=subgroup, 3+=deeper
  ord          INTEGER
);

-- ---------------------------------------------------------------------------
-- Pages (leaf content pages). site_page_id is the {pageId}; it is NOT unique
--   across books (reused), so uniqueness is on the full url.
--   page_type enum:
--     editorial_board, how_to_cite, foreword, icdo_coding, tnm_staging,
--     iccr_datasets, chapter_intro, classification_overview, tumour_entity,
--     reporting_system_section, subcommittee, front_matter, other
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pages (
  page_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id       INTEGER NOT NULL REFERENCES books(book_id),
  chapter_id    INTEGER REFERENCES chapters(chapter_id),
  group_id      INTEGER REFERENCES page_groups(group_id),
  site_page_id  INTEGER NOT NULL,          -- {pageId} in chaptercontent/{book}/{pageId}
  url           TEXT NOT NULL UNIQUE,
  title         TEXT,
  subtitle      TEXT,
  title_norm    TEXT,                      -- materialized by local enrichment
  icdo_code_hint TEXT,                     -- optional subtitle-only code hint
  breadcrumb    TEXT,
  page_type     TEXT,
  is_pointer    INTEGER DEFAULT 0,         -- "(See chapter N)" cross-ref stub
  raw_html      TEXT,                      -- full server-rendered content HTML
  markdown      TEXT,                      -- converted markdown (optional)
  crawl_status  TEXT DEFAULT 'pending',    -- pending | done | error
  error_note    TEXT,
  fetched_at    TEXT
);

-- ---------------------------------------------------------------------------
-- Sections (the ~15 fixed headings on 5th-ed entity pages; single Definition
--   section on cytopathology pages; free prose sections elsewhere)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sections (
  section_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id      INTEGER NOT NULL REFERENCES pages(page_id),
  heading      TEXT,
  body_text    TEXT,
  ord          INTEGER,
  source_anchor TEXT                     -- saved HTML heading/block id, local backfill
);

-- ---------------------------------------------------------------------------
-- Authors (roles normalized across singular/plural label variants)
--   role enum: responsible_editor, co_editor, responsible_author,
--              co_author, editorial_office, other
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS authors (
  author_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id      INTEGER NOT NULL REFERENCES pages(page_id),
  role         TEXT,
  name         TEXT
);

-- ---------------------------------------------------------------------------
-- Images (figures, whole-slide images, tables/boxes captures)
--   image_type enum: figure | whole_slide_image | tables_boxes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS images (
  image_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id        INTEGER NOT NULL REFERENCES pages(page_id),
  section_id     INTEGER REFERENCES sections(section_id),
  site_image_no  TEXT,                     -- e.g. '#167'
  image_type     TEXT,
  caption        TEXT,
  thumb_url      TEXT,
  full_url       TEXT,
  local_path     TEXT                      -- relative path once downloaded
);

-- ---------------------------------------------------------------------------
-- Page links (internal cross-links, external, mailto, cross-reference stubs,
--   reference tokens rendered as links, image links)
--   link_kind enum: internal | external | mailto | cross_reference | reference | image
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS page_links (
  link_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id      INTEGER NOT NULL REFERENCES pages(page_id),
  link_text    TEXT,
  target_url   TEXT,
  link_kind    TEXT
);

-- ---------------------------------------------------------------------------
-- References (two token formats: {PMID} inline, [[full citation]] on intros)
--   token_format enum: pmid_curly | bracket
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "references" (
  ref_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  page_id      INTEGER NOT NULL REFERENCES pages(page_id),
  section_id   INTEGER REFERENCES sections(section_id),
  token        TEXT,                       -- PMID digits or citation key
  token_format TEXT,
  raw_text     TEXT
);

-- ---------------------------------------------------------------------------
-- Crawl bookkeeping
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS crawl_queue (
  queue_id     INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id      INTEGER NOT NULL REFERENCES books(book_id),
  site_page_id INTEGER NOT NULL,
  url          TEXT NOT NULL UNIQUE,
  status       TEXT DEFAULT 'pending',     -- pending | done | error
  attempts     INTEGER DEFAULT 0,
  last_error   TEXT,
  updated_at   TEXT
);

CREATE TABLE IF NOT EXISTS crawl_runs (
  run_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at   TEXT,
  finished_at  TEXT,
  book_id      INTEGER,
  pages_done   INTEGER DEFAULT 0,
  status       TEXT,
  notes        TEXT
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_pages_book    ON pages(book_id);
CREATE INDEX IF NOT EXISTS ix_chapters_book ON chapters(book_id);
CREATE INDEX IF NOT EXISTS ix_groups_chapter ON page_groups(chapter_id);
CREATE INDEX IF NOT EXISTS ix_groups_parent ON page_groups(parent_group);
CREATE INDEX IF NOT EXISTS ix_authors_pg ON authors(page_id);
CREATE INDEX IF NOT EXISTS ix_pages_status  ON pages(crawl_status);
CREATE INDEX IF NOT EXISTS ix_pages_type    ON pages(page_type);
CREATE INDEX IF NOT EXISTS ix_sections_pg   ON sections(page_id);
CREATE INDEX IF NOT EXISTS ix_images_pg     ON images(page_id);
CREATE INDEX IF NOT EXISTS ix_images_section ON images(section_id);
CREATE INDEX IF NOT EXISTS ix_links_pg      ON page_links(page_id);
CREATE INDEX IF NOT EXISTS ix_refs_pg       ON "references"(page_id);
CREATE INDEX IF NOT EXISTS ix_refs_section  ON "references"(section_id);
CREATE INDEX IF NOT EXISTS ix_queue_status  ON crawl_queue(status);

-- ---------------------------------------------------------------------------
-- FTS5 full-text index over section text.
-- content-less external-content table linked to sections by rowid=section_id.
-- Explicit local rebuilds keep it in sync; no automatic triggers are installed.
-- ---------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS sections_fts USING fts5(
  heading,
  body_text,
  title UNINDEXED,       -- denormalized page title for display
  book_id UNINDEXED,
  page_id UNINDEXED,
  content='',            -- contentless: we insert explicitly
  tokenize = 'porter unicode61'
);

-- Page-level FTS: whole-page text so multi-term AND queries match across
-- sections (e.g. 'neuroendocrine AND oesophagus' where the words are in
-- different sections). rowid = page_id.
CREATE VIRTUAL TABLE IF NOT EXISTS pages_fts USING fts5(
  title,
  full_text,
  book_id UNINDEXED,
  page_id UNINDEXED,
  content='',
  tokenize = 'porter unicode61'
);

-- Convenience view joining page metadata for search results
CREATE VIEW IF NOT EXISTS v_search AS
SELECT s.section_id, s.page_id, s.heading, s.body_text,
       p.title, p.page_type, p.url, p.book_id, b.title AS book_title, b.edition
FROM sections s
JOIN pages p ON p.page_id = s.page_id
JOIN books b ON b.book_id = p.book_id;
