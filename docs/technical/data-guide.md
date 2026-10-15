# Data guide

This hand-maintained guide explains how to interpret the local SQLite data
model and its important fields. For generated schema details—including column
types, nullability, defaults, keys, and indexes—see the
[table and column reference](table-columns.md). The documentation generator
for that reference is `app\build_local_docs.py`.

Some useful database words:

| Word | Meaning here |
|---|---|
| Schema | The arrangement of tables, columns and their rules |
| NULL / nullable | A value is missing / the column allows a missing value |
| Primary key | The value or values that identify one stored row |
| Index | A lookup structure that helps the database find rows quickly |
| View | A named query that presents stored values in a useful shape |
| Provenance | Where a value came from and the evidence supporting it |
| Transaction | A group of database changes that succeeds or rolls back together |
| Mirror / parity | A copy to the other database / a check that values agree |

The local refresh entry point is `app\bluebooks_local.py`. It reads the saved
crawler database and required local references, enriches them, rebuilds search
documents and SQLite full-text search, and can optionally mirror the result to
SQL Server. It does not log in, discover books, or crawl pages. Reference
inputs are validated before replacement; the refresh and mirror use
transactional and backup safeguards. See [Maintaining the project](maintaining-the-project.md)
before changing schemas or refresh behavior.

## Read the data carefully

- A **source assignment** is a code printed in the Blue Books material. A
  **candidate** is a separate proposal found by comparing an observed term
  with an official reference. Never substitute a candidate for a printed
  assignment.
- An observed term or code mention is evidence that text occurs on a page; it
  is not automatically a diagnosis for that page or a patient.
- ICD-O-3.2 and ICD-O-4 are evaluated independently. A missing code in one
  edition does not authorize copying a code from the other edition.
- `TermUS` is a cleaned display value used for matching; `TermNormUS` is its
  normalized match key. Neither replaces the original source text.
- `confidence_score` and roll-up scores are application-specific evidence
  values, not calibrated probabilities.
- SQLite is the local canonical producer. SQL Server stores mirrored data;
  SQL Server maps SQLite integers, text, decimal values, and timestamps to
  compatible server types. Backend-specific search ranking and stemming can
  differ.

## Population and ownership

The crawler stores the captured books, pages, sections, links, authors,
references, and image metadata. The local enrichment process parses entity
pages and code/term evidence, imports local official references, constructs
edition-aware candidate evaluations, creates site hints and evidence rollups,
and builds one whole-page search document per page.

Manual curation is not cleared by enrichment. Review decisions are append-only.
The local build sidecar records input identity and build information; it is
build provenance, not a table of user or agent activity. Crawl queues and run
logs are outside the mirrored managed data contract.

## Crawler and page content

### `books`

Volume inventory and local discovery snapshot. `alias` is an editable short
display label; `title` remains the full title.

Columns: `book_id` INTEGER (primary key), `title` TEXT, `edition` TEXT,
`series` TEXT, `status` TEXT, `url` TEXT, `alias` TEXT.

### `chapters`

Stored table-of-contents chapters.

Columns: `chapter_id` INTEGER (primary key), `book_id` INTEGER, `number`
INTEGER, `title` TEXT, `ord` INTEGER.

### `page_groups`

Nested table-of-contents groups. `parent_group` links to another group.

Columns: `group_id` INTEGER (primary key), `chapter_id` INTEGER,
`parent_group` INTEGER, `label` TEXT, `level` INTEGER, `ord` INTEGER.

### `pages`

Captured page metadata and source content. `raw_html` is the saved source;
`markdown` is a stored text representation. `title_norm` is derived locally.
`icdo_code_hint` is a subtitle-derived hint and may be NULL; it is not a
verified assignment.

Columns: `page_id` INTEGER (primary key), `book_id` INTEGER, `chapter_id`
INTEGER, `group_id` INTEGER, `site_page_id` INTEGER, `url` TEXT, `title` TEXT,
`subtitle` TEXT, `breadcrumb` TEXT, `page_type` TEXT, `is_pointer` INTEGER,
`raw_html` TEXT, `markdown` TEXT, `crawl_status` TEXT, `error_note` TEXT,
`fetched_at` TEXT, `title_norm` TEXT, `icdo_code_hint` TEXT.

### `sections`

Page sections, including headings, extracted body, and the source HTML anchor.
Saved-HTML recovery appends missing sections and fills only safe empty matches;
it retains nonempty sections and prunes an empty entity-page section only when
no image/reference row links to it.

Columns: `section_id` INTEGER (primary key), `page_id` INTEGER, `heading` TEXT,
`body_text` TEXT, `ord` INTEGER, `source_anchor` TEXT.

### `authors`

Page author names and roles.

Columns: `author_id` INTEGER (primary key), `page_id` INTEGER, `role` TEXT,
`name` TEXT.

### `images`

Figure metadata and captions. `local_path` records a local image path when
present; refreshing metadata does not mean new image files are downloaded.

Columns: `image_id` INTEGER (primary key), `page_id` INTEGER, `section_id`
INTEGER, `site_image_no` TEXT, `image_type` TEXT, `caption` TEXT, `thumb_url`
TEXT, `full_url` TEXT, `local_path` TEXT.

### `page_links`

Captured page-link labels, target URLs, and link kinds.

Columns: `link_id` INTEGER (primary key), `page_id` INTEGER, `link_text` TEXT,
`target_url` TEXT, `link_kind` TEXT.

### `references`

Captured citation tokens and their source text. The table name is a SQL
keyword; quote it when a query dialect requires quoting.

Columns: `ref_id` INTEGER (primary key), `page_id` INTEGER, `section_id`
INTEGER, `token` TEXT, `token_format` TEXT, `raw_text` TEXT.

## Entity terminology and evidence

### `entity_pages`

Entity-page extraction from saved page HTML. The edition is obtained from the
associated book. `definition` is extracted page content, not an official
reference definition.

Columns: `page_id` INTEGER (primary key), `book_id` INTEGER, `chapter` TEXT,
`category` TEXT, `subcategory` TEXT, `title` TEXT, `definition` TEXT,
`extracted_at` TEXT.

### `entity_codes`

Structured coding-section terms, including rows with no code. `code` preserves
the source assignment; `term_role` and source provenance carry current
distinctions. `is_subtype` is a deprecated compatibility field: do not use it
for new logic. A blank code does not make the term row invalid.

Columns: `entity_code_id` INTEGER (primary key), `page_id` INTEGER, `ordinal`
INTEGER, `term` TEXT, `code` TEXT, `is_subtype` INTEGER (deprecated), `TermUS`
TEXT, `TermNormUS` TEXT, `term_role` TEXT.

### `entity_related_terms`

Related terminology labeled by source status or left as `other`. The allowed
`kind` values are `acceptable`, `not_recommended`, and `other`. Semicolon
separation respects balanced parentheses. Recovered alternate terms use
`other` and have separate provenance; they are not source-code assignments.

Columns: `related_term_id` INTEGER (primary key), `page_id` INTEGER, `kind`
TEXT, `term` TEXT, `TermUS` TEXT, `TermNormUS` TEXT, `term_role` TEXT.

### `entity_term_provenance`

Links an alternate/recovered term to its original evidence and target
terminology row. The original text and source locator are preserved; the
proposed qualifier is not a biological classification.

Columns: `provenance_id` INTEGER (primary key), `provenance_key` TEXT,
`page_id` INTEGER, `entity_code_id` INTEGER, `related_term_id` INTEGER,
`source_kind` TEXT, `source_table` TEXT, `source_row_id` INTEGER,
`original_text` TEXT, `recovered_term` TEXT, `suggested_qualifier` TEXT,
`terminology_status` TEXT, `review_status` TEXT, `is_added_term` INTEGER,
`proposal_batch` TEXT, `note` TEXT, `TermUS` TEXT, `TermNormUS` TEXT.

### `entity_term_code_matches`

Edition-specific proposed matches for recovered terms. `official_term` and
`code` come from reference evidence; `match_type`, `conditions`, and the
reference file/sheet/row/hash explain the proposal. These values do not replace
`entity_codes.code` or page-level source evidence.

Columns: `match_id` INTEGER (primary key), `match_key` TEXT, `provenance_id`
INTEGER, `edition` TEXT, `code` TEXT, `official_term` TEXT, `match_type` TEXT,
`candidate_order` INTEGER, `conditions` TEXT, `reference_file` TEXT,
`reference_sheet` TEXT, `reference_row` INTEGER, `reference_sha256` TEXT,
`code_term_evidence` TEXT, `review_status` TEXT, `official_termUS` TEXT,
`official_termNormUS` TEXT.

### `entity_identifiers`

MIM/OMIM identifiers from labeled numbering rows, qualified coding rows, and
inline citations. `source_kind` separates coding-section from section-text
evidence; `raw_text` preserves the source wording. These identifiers are not
morphology assignments.

Columns: `identifier_id` INTEGER (primary key), `page_id` INTEGER, `system`
TEXT, `identifier` TEXT, `term` TEXT, `source_kind` TEXT, `source_heading`
TEXT, `raw_text` TEXT.

### `page_icdo_codes`

Code evidence found in section text and saved-HTML entity coding. `icdo_code_raw`
preserves the source form; `icdo_code` is the compatibility representation
used by current helpers. `section_heading`, `term_role`, `term_source`, and
`line_indent` retain context. A contextual code is not necessarily assigned to
the page's entity.

Columns: `code_id` INTEGER (primary key), `page_id` INTEGER, `icdo_code` TEXT,
`icdo_code_raw` TEXT, `term_in_coding_section` TEXT, `section_heading` TEXT,
`term_role` TEXT, `term_source` TEXT, `line_indent` INTEGER, `TermUS` TEXT,
`TermNormUS` TEXT.

### `page_term_mentions`

Observation-first term records. A page title, structured label, or supported
known-reference phrase can be observed even if it has no code. `observation_key`
and `source_locator` identify the evidence; `context_class`, `evidence_policy`,
and `is_positive_evidence` distinguish context from positive page evidence.
`icdo_code` is printed evidence only. Original text, normalized values, source
location, extraction tier, source hash, and current/history status are kept
separate so a match does not overwrite the observation.

Columns: `mention_id` INTEGER (primary key), `page_id` INTEGER, `icdo_code`
TEXT, `term_original` TEXT, `term_original_norm` TEXT, `term_text` TEXT,
`term_clean` TEXT, `matched_term_original` TEXT, `matched_term_norm` TEXT,
`source_kind` TEXT, `source_heading` TEXT, `section_flag` TEXT,
`section_location` TEXT, `evidence_policy` TEXT, `is_positive_evidence`
INTEGER, `confidence_score` DECIMAL(5,2), `snippet` TEXT, `TermUS` TEXT,
`TermNormUS` TEXT, `url` TEXT, `term_source` TEXT, `extraction_method` TEXT,
`term_role` TEXT, `code_origin` TEXT, `parent_mention_id` INTEGER,
`review_status` TEXT, `reviewed_by` TEXT, `observation_key` TEXT,
`source_locator` TEXT, `term_origin` TEXT, `context_class` TEXT,
`evidence_hash` TEXT, `extraction_tier` TEXT, `is_current` INTEGER.

### `term_saved_sections`

Cached DOM sections shared by refresh and spreadsheet extraction. The source
hash and parser version invalidate stale cached data; saved `pages.raw_html`
remains authoritative.

Columns: `page_id` INTEGER (primary key), `source_sha256` TEXT,
`parser_version` TEXT, `sections_json` TEXT.

### `page_entity_evidence`

Deterministic roll-up of mention evidence by page, term, and code. The score is
`positive_mentions - 0.5 * excluded_mentions + 0.5 * has_code_on_page`; this is
not a probability.

Columns: `evidence_id` INTEGER (primary key), `page_id` INTEGER, `icdo_code`
TEXT, `term_clean` TEXT, `positive_mentions` INTEGER, `excluded_mentions`
INTEGER, `source_kinds` TEXT, `has_code_on_page` INTEGER, `site_hints` TEXT,
`confidence_score` DECIMAL(6,2), `TermUS` TEXT, `TermNormUS` TEXT.

### `page_site_hints`

Page-level topography/site hints from a unique positive, unconditioned
ICD-O-3.2 relationship matched to local site-reference evidence. Ambiguous,
historical, incidental, differential, or negated mentions do not establish a
term-specific site.

Columns: `hint_id` INTEGER (primary key), `page_id` INTEGER, `c_code` TEXT,
`provenance` TEXT, `confidence_score` DECIMAL(5,2).

### `page_search_documents`

One whole-page search document per page, built from recovered section bodies
and stored page text, with nonduplicated entity definitions, terms, and
identifier text.

Columns: `page_id` INTEGER (primary key), `book_id` INTEGER, `title` TEXT,
`full_text` TEXT.

## Official references, matching, and review

### `term_reference_rows`

Edition- and revision-specific official reference rows. The file hash, sheet,
and actual row identity are retained; older revisions remain distinguishable
instead of being silently combined.

Columns: `reference_key` TEXT (primary key), `edition` TEXT, `reference_file`
TEXT, `reference_sha256` TEXT, `reference_sheet` TEXT, `reference_row` INTEGER,
`code` TEXT, `official_term` TEXT, `official_termUS` TEXT,
`official_termNormUS` TEXT, `level` TEXT, `conditions` TEXT.

### `term_lookup_evaluations`

One result for an observation, edition, reference revision, matcher version,
and evidence identity. Outcomes are retained as history; only the applicable
current evaluation is marked current.

Columns: `evaluation_id` INTEGER (primary key), `evaluation_key` TEXT,
`mention_id` INTEGER, `edition` TEXT, `reference_sha256` TEXT,
`matcher_version` TEXT, `evidence_hash` TEXT, `outcome` TEXT, `detail` TEXT,
`evaluated_at` TEXT, `is_current` INTEGER.

### `term_code_candidates`

Edition-specific candidate mappings linked to an evaluation. `official_term`
is the source reference wording; `candidateTermUS` is its display form.
`evidence_tier`, `match_type`, `conditions`, ordering, and supporting reference
rows explain why it was proposed. Candidates never become source assignments
by virtue of being present.

Columns: `candidate_id` INTEGER (primary key), `candidate_key` TEXT,
`evaluation_id` INTEGER, `code` TEXT, `official_term` TEXT,
`candidateTermUS` TEXT, `candidateTermNormUS` TEXT, `match_type` TEXT,
`evidence_tier` TEXT, `candidate_order` INTEGER, `conditions` TEXT,
`reference_evidence` TEXT, `review_status` TEXT, `legacy_match_key` TEXT.

### `term_review_decisions`

Append-only review history. `scope` and `target_key` specify the decision
target; `evidence_hash` binds the decision to the evidence reviewed. Changed
evidence can require a new decision rather than erasing the old one.

Columns: `decision_id` INTEGER (primary key), `decision_key` TEXT,
`target_key` TEXT, `scope` TEXT, `outcome` TEXT, `reason` TEXT,
`evidence_hash` TEXT, `reviewer` TEXT, `decided_at` TEXT.

### `term_pipeline_migrations`

One-time migration markers and imported-row counts. These prevent migration
adapters from replaying curated historical input on each normal refresh.

Columns: `migration_key` TEXT (primary key), `applied_at` TEXT,
`imported_rows` INTEGER.

## Reference workbooks and curation

### `cpc_curation`

Manual working-group decisions. Enrichment does not clear them; conflicting
mirror state requires explicit reconciliation.

Columns: `curation_id` INTEGER (primary key), `book_id` INTEGER,
`icdo4_code` TEXT, `chapter` TEXT, `icdo32_code` TEXT, `is_icdo41` INTEGER,
`cpc_site_group` TEXT, `naaccr_note` TEXT.

### `icdo4_morphology`

Official local ICD-O-4 morphology reference rows from the `Morphology` sheet
of the supplied ICD-O-4 workbook. The table retains the source's labels and
observations.

Columns: `row_id` INTEGER (primary key), `icdo4` TEXT, `level` TEXT,
`term` TEXT, `term_clean` TEXT, `code_ref` TEXT, `obs` TEXT.

### `cpc_morph_codes`

Auxiliary compiled morphology rows, including the source file and retired
status. This compilation is not a replacement for the edition-specific
official reference rows.

Columns: `row_id` INTEGER (primary key), `morph_beh` TEXT, `icdo4` TEXT,
`term` TEXT, `term_norm` TEXT, `term_clean` TEXT, `level` TEXT,
`retired` INTEGER, `source_file` TEXT.

### `icdo_site_specific_terms`

Site-specific reference-workbook terms and their preserved workbook fields.
`source_sheet` and `source_reference` identify the reference evidence;
`subset_c_codes` and related summaries preserve the supplied site detail.

Columns: `term_id` INTEGER (primary key), `source_sheet` TEXT, `icdo_code`
TEXT, `icdo_code_raw` TEXT, `icdo_term` TEXT, `term_normalized` TEXT,
`term_clean` TEXT, `preferred_term` TEXT, `site_specific_flag` TEXT,
`subset_c_codes` TEXT, `subset_labels` TEXT, `subset_site_count` INTEGER,
`smvl_site_count` INTEGER, `smvl_organ_summary` TEXT, `smvl_all_c_codes`
TEXT, `rationale` TEXT, `source_url` TEXT, `source_reference` TEXT.

### `icdo_site_specific_term_sites`

Child rows linking a reference term to each supplied topography C-code and
label.

Columns: `term_id` INTEGER, `c_code` TEXT, `site_label` TEXT.

### `enum_values`

Definitions for centralized source, status, role, match, and evidence values.
Legacy labels are recorded where a migration mapping applies.

Columns: `enum_group` TEXT, `enum_value` TEXT, `description` TEXT,
`legacy_values` TEXT.

## Important derived views

Views are query interfaces, not additional stored source rows. Their order is
not guaranteed; queries that need a stable display order must use `ORDER BY`.

| View | Contract |
|---|---|
| `v_page_code_terms` | Pairs scalar `ICDO32` and `ICDO4` columns on the exact, case-sensitive page/`TermUS`. No public `code_edition` column. Multiple codes retain every distinct combination, not an asserted crosswalk. Edition-specific candidate labels, proposal flags, outcomes and review metadata have suffixes `32` and `4`. Unmapped editions retain NULL codes. |
| `v_entity_terms` | Returns each entity coding or related term once, separating source code from suggested code. |
| `v_entity_term_provenance` | Links terms to source evidence; multiple rows can represent multiple source links. |
| `v_entity_term_code_matches` | Shows proposed candidates without multiplying them by provenance links and retains unmapped terms. |
| `v_term_candidate_evidence` | Provides candidate evidence, including rejected and historical evidence for review/audit use. |
| `v_search` | Search-oriented interface over stored page and section material. |

### `v_page_code_terms` provenance fields

The full row identity is `page_id`, `TermUS`, `ICDO32`, `ICDO4`,
`candidateTermUS32`, `candidateTermUS4`. Repeated observations collapse;
different terms sharing a code remain separate. An uncoded observation does
not add another row when the same term already has a code in that edition.
Two codes in each edition produce four combinations, not an arbitrary pairing
or a delimited code list. Pairing does not establish a relationship between
the editions.

Use `candidateTermUS32/4`, `is_proposed_code32/4`,
`is_proposed_term32/4`, `lookup_outcome32/4`, `match_type32/4`,
`conditions32/4`, and `review_status32/4` for edition-specific interpretation.
For compatibility, shared `candidateTermUS` and `morphology_code` prefer
ICD-O-4 and otherwise use ICD-O-3.2. Shared proposal flags mean either edition;
shared textual metadata combines differing values with `; `. A combined
outcome or review field is therefore not necessarily a single enum value.
Use the suffixed columns when filtering one edition's state.

The original book `edition` remains unchanged; it is not the removed code
edition. Source assignments and reference evidence remain in their original
tables. See the [performance plan](plans/page-code-terms-performance.md)
for measured costs, indexing findings, and the proposed indexed read model.

Where exposed, `terminology_kind` describes five atomic origins: `coding`
(coding or Subtype(s) section), `contextual` (a code-term pair in page text),
`acceptable`, `not_recommended`, and `other` (unlabeled related terms,
including recovered alternates). Combined origins may be joined
alphabetically with `; `.

The source and candidate tables separately describe code association and
extraction/recovery route; `suggested_qualifier` describes a proposed
relationship for a recovered term. These concepts are not interchangeable.
`is_subtype` is deprecated; use `term_role` and explicit provenance instead.
For field meanings see [Reference matching](reference-matching.md).

## Normalized term fields

The five indexed term-source tables are `entity_codes`, `entity_related_terms`,
`page_icdo_codes`, `page_term_mentions`, and `page_entity_evidence`.
`TermUS` is derived from the source's authoritative term using display cleanup,
British-to-US spelling, and an initial-ASCII-letter casing rule.
`TermNormUS` is the normalized `Clean2(TermUS)` key. Display, key, and source
text are distinct values: original prose is not rewritten by normalization.

Cleaning removes unambiguous trailing footnote/citation/list punctuation and
keeps meaningful words, balanced parentheses, numeric superscripts/subscripts,
and scientific signs. It does not truncate overlength keys. The approved
`dbo.Clean2` definition and its local equivalent are kept synchronized; use
the project connection helpers for database writes so required SQLite
functions and triggers are registered.

The [table and column reference](table-columns.md) documents the complete
primary-key, nullability, default, foreign-key, and index metadata for the
current schema. This guide describes the interpretation and safe use of those
fields.
