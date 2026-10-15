# Table and column reference

This is the detailed map of stored data, generated from the local database.
Start with [the data guide](data-guide.md) if you are choosing what to query.
Required means a value must be present. Key identifies a row; lookup indexes
make searches faster. PK means primary key. References connect related rows.

The generator reads metadata only. It does not refresh or modify data.

## `books`

Saved volume inventory. alias is an editable short label; title and edition are retained independently.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `book_id` | INTEGER | yes | Primary key |  |
| `title` | TEXT | yes |  |  |
| `edition` | TEXT | no |  |  |
| `series` | TEXT | no |  |  |
| `status` | TEXT | no |  |  |
| `url` | TEXT | yes |  |  |
| `alias` | TEXT | no |  |  |


Lookup indexes:


## `chapters`

Saved table-of-contents chapters.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `chapter_id` | INTEGER | yes | Primary key |  |
| `book_id` | INTEGER | yes |  |  |
| `number` | INTEGER | no |  |  |
| `title` | TEXT | yes |  |  |
| `ord` | INTEGER | no |  |  |

- `book_id` refers to `books.book_id`.

Lookup indexes:

- `ix_chapters_book`: `book_id`

## `page_groups`

Saved nested table-of-contents groups.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `group_id` | INTEGER | yes | Primary key |  |
| `chapter_id` | INTEGER | yes |  |  |
| `parent_group` | INTEGER | no |  |  |
| `label` | TEXT | yes |  |  |
| `level` | INTEGER | yes |  |  |
| `ord` | INTEGER | no |  |  |

- `parent_group` refers to `page_groups.group_id`.
- `chapter_id` refers to `chapters.chapter_id`.

Lookup indexes:

- `ix_groups_parent`: `parent_group`
- `ix_groups_chapter`: `chapter_id`

## `pages`

Saved page HTML, titles, subtitles, URLs and collection state. title_norm is a matching key; icdo_code_hint is subtitle-only.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `page_id` | INTEGER | yes | Primary key |  |
| `book_id` | INTEGER | yes |  |  |
| `chapter_id` | INTEGER | no |  |  |
| `group_id` | INTEGER | no |  |  |
| `site_page_id` | INTEGER | yes |  |  |
| `url` | TEXT | yes |  |  |
| `title` | TEXT | no |  |  |
| `subtitle` | TEXT | no |  |  |
| `breadcrumb` | TEXT | no |  |  |
| `page_type` | TEXT | no |  |  |
| `is_pointer` | INTEGER | no |  | 0 |
| `raw_html` | TEXT | no |  |  |
| `markdown` | TEXT | no |  |  |
| `crawl_status` | TEXT | no |  | 'pending' |
| `error_note` | TEXT | no |  |  |
| `fetched_at` | TEXT | no |  |  |
| `title_norm` | TEXT | no |  |  |
| `icdo_code_hint` | TEXT | no |  |  |

- `group_id` refers to `page_groups.group_id`.
- `chapter_id` refers to `chapters.chapter_id`.
- `book_id` refers to `books.book_id`.

Lookup indexes:

- `ix_pages_title_norm`: `title_norm`
- `ix_pages_type`: `page_type`
- `ix_pages_status`: `crawl_status`
- `ix_pages_book`: `book_id`
- Unique `sqlite_autoindex_pages_1`: `url`

## `sections`

Saved sections and recovered section bodies. IDs and image/reference associations are preserved. Exceptions are recorded in private build information.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `section_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `heading` | TEXT | no |  |  |
| `body_text` | TEXT | no |  |  |
| `ord` | INTEGER | no |  |  |
| `source_anchor` | TEXT | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_sections_pg`: `page_id`

## `authors`

Saved page authors and roles.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `author_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `role` | TEXT | no |  |  |
| `name` | TEXT | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_authors_pg`: `page_id`

## `images`

Saved figure metadata, captions and local paths; local refresh does not download images.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `image_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `section_id` | INTEGER | no |  |  |
| `site_image_no` | TEXT | no |  |  |
| `image_type` | TEXT | no |  |  |
| `caption` | TEXT | no |  |  |
| `thumb_url` | TEXT | no |  |  |
| `full_url` | TEXT | no |  |  |
| `local_path` | TEXT | no |  |  |

- `section_id` refers to `sections.section_id`.
- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_images_section`: `section_id`
- `ix_images_pg`: `page_id`

## `page_links`

Saved page link labels and targets.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `link_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `link_text` | TEXT | no |  |  |
| `target_url` | TEXT | no |  |  |
| `link_kind` | TEXT | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_links_pg`: `page_id`

## `references`

Saved citation text and PMID tokens.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `ref_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `section_id` | INTEGER | no |  |  |
| `token` | TEXT | no |  |  |
| `token_format` | TEXT | no |  |  |
| `raw_text` | TEXT | no |  |  |

- `section_id` refers to `sections.section_id`.
- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_refs_section`: `section_id`
- `ix_refs_pg`: `page_id`

## `entity_pages`

Eligible entity pages parsed from saved HTML. Edition comes from the linked book; front matter is excluded.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `page_id` | INTEGER | yes | Primary key |  |
| `book_id` | INTEGER | yes |  |  |
| `chapter` | TEXT | no |  |  |
| `category` | TEXT | no |  |  |
| `subcategory` | TEXT | no |  |  |
| `title` | TEXT | no |  |  |
| `definition` | TEXT | no |  |  |
| `extracted_at` | TEXT | no |  | datetime('now') |

- `book_id` refers to `books.book_id`.
- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_entity_pages_book`: `book_id`

## `entity_codes`

Terms and codes printed in coding/subtype sections. Code formats are retained without conversion between editions. is_subtype is deprecated.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `entity_code_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `ordinal` | INTEGER | yes |  |  |
| `term` | TEXT | yes |  |  |
| `code` | TEXT | no |  |  |
| `is_subtype` | INTEGER | yes | Deprecated; use explicit source/relationship fields | 0 |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |
| `term_role` | TEXT | no |  |  |

- `page_id` refers to `entity_pages.page_id`.

Lookup indexes:

- `ix_entity_codes_TermNormUS`: `TermNormUS`
- `ix_entity_codes_TermNorm`: `TermNormUS`
- `ix_entity_codes_TermUS`: `TermUS`
- `ix_entity_codes_code`: `code`
- `ix_entity_codes_page`: `page_id`

## `entity_related_terms`

Acceptable, not recommended and other related terms, including explicitly attributed recovered names. Balanced scientific parentheses are preserved.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `related_term_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `kind` | TEXT | yes |  |  |
| `term` | TEXT | yes |  |  |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |
| `term_role` | TEXT | no |  |  |

- `page_id` refers to `entity_pages.page_id`.

Lookup indexes:

- `ix_entity_related_terms_TermNormUS`: `TermNormUS`
- `ix_entity_related_terms_TermNorm`: `TermNormUS`
- `ix_entity_related_terms_TermUS`: `TermUS`
- `ix_entity_related_page`: `page_id`

## `entity_term_provenance`

Source links for recovered names, including original text and row identifiers. Saved manual review details survive rebuilds.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `provenance_id` | INTEGER | yes | Primary key |  |
| `provenance_key` | TEXT | yes |  |  |
| `page_id` | INTEGER | yes |  |  |
| `entity_code_id` | INTEGER | no |  |  |
| `related_term_id` | INTEGER | no |  |  |
| `source_kind` | TEXT | yes |  |  |
| `source_table` | TEXT | yes |  |  |
| `source_row_id` | INTEGER | yes |  |  |
| `original_text` | TEXT | yes |  |  |
| `recovered_term` | TEXT | yes |  |  |
| `suggested_qualifier` | TEXT | yes |  |  |
| `terminology_status` | TEXT | yes |  |  |
| `review_status` | TEXT | yes |  | 'proposed' |
| `is_added_term` | INTEGER | yes |  |  |
| `proposal_batch` | TEXT | yes |  |  |
| `note` | TEXT | yes |  |  |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |

- `related_term_id` refers to `entity_related_terms.related_term_id`.
- `entity_code_id` refers to `entity_codes.entity_code_id`.
- `page_id` refers to `entity_pages.page_id`.

Lookup indexes:

- `ix_entity_term_provenance_TermNormUS`: `TermNormUS`
- `ix_entity_term_provenance_TermUS`: `TermUS`
- `ix_entity_term_provenance_related`: `related_term_id`
- `ix_entity_term_provenance_code`: `entity_code_id`
- `ix_entity_term_provenance_page`: `page_id`
- Unique `sqlite_autoindex_entity_term_provenance_1`: `provenance_key`

## `entity_term_code_matches`

Legacy edition-specific proposals with official wording, workbook evidence and conditions; never source assignments.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `match_id` | INTEGER | yes | Primary key |  |
| `match_key` | TEXT | yes |  |  |
| `provenance_id` | INTEGER | yes |  |  |
| `edition` | TEXT | yes |  |  |
| `code` | TEXT | yes |  |  |
| `official_term` | TEXT | yes |  |  |
| `match_type` | TEXT | yes |  |  |
| `candidate_order` | INTEGER | yes |  |  |
| `conditions` | TEXT | yes |  |  |
| `reference_file` | TEXT | yes |  |  |
| `reference_sheet` | TEXT | yes |  |  |
| `reference_row` | INTEGER | yes |  |  |
| `reference_sha256` | TEXT | yes |  |  |
| `code_term_evidence` | TEXT | yes |  |  |
| `review_status` | TEXT | yes |  | 'proposed' |
| `official_termUS` | TEXT | no |  |  |
| `official_termNormUS` | TEXT | no |  |  |

- `provenance_id` refers to `entity_term_provenance.provenance_id`.

Lookup indexes:

- `ix_entity_term_code_matches_official_termNormUS`: `official_termNormUS`
- `ix_entity_term_code_matches_official_termUS`: `official_termUS`
- `ix_entity_term_code_matches_edition_code`: `edition`, `code`
- `ix_entity_term_code_matches_provenance`: `provenance_id`
- Unique `sqlite_autoindex_entity_term_code_matches_1`: `match_key`

## `entity_identifiers`

OMIM/MIM identifiers and their section context; these are not morphology codes.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `identifier_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `system` | TEXT | yes |  |  |
| `identifier` | TEXT | yes |  |  |
| `term` | TEXT | yes |  |  |
| `source_kind` | TEXT | yes |  | 'section_text' |
| `source_heading` | TEXT | yes |  |  |
| `raw_text` | TEXT | yes |  |  |

- `page_id` refers to `entity_pages.page_id`.

Lookup indexes:

- `ix_entity_identifiers_lookup`: `system`, `identifier`
- Unique `sqlite_autoindex_entity_identifiers_1`: `page_id`, `system`, `identifier`, `source_heading`, `term`

## `cpc_curation`

Manual decisions. Refresh does not clear them; conflicting mirror changes require reconciliation.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `curation_id` | INTEGER | yes | Primary key |  |
| `book_id` | INTEGER | no |  |  |
| `icdo4_code` | TEXT | no |  |  |
| `chapter` | TEXT | no |  |  |
| `icdo32_code` | TEXT | no |  |  |
| `is_icdo41` | INTEGER | yes |  | 0 |
| `cpc_site_group` | TEXT | no |  |  |
| `naaccr_note` | TEXT | no |  |  |

- `book_id` refers to `books.book_id`.

Lookup indexes:

- `ix_cpc_curation_code`: `book_id`, `icdo4_code`

## `icdo4_morphology`

Morphology rows from the current local ICD-O-4 reference workbook. Annex loading is separate work.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `row_id` | INTEGER | yes | Primary key |  |
| `icdo4` | TEXT | no |  |  |
| `level` | TEXT | no |  |  |
| `term` | TEXT | no |  |  |
| `term_clean` | TEXT | no |  |  |
| `code_ref` | TEXT | no |  |  |
| `obs` | TEXT | no |  |  |


Lookup indexes:

- `ix_icdo4_morph_code`: `icdo4`
- `ix_icdo4_morph_clean`: `term_clean`

## `cpc_morph_codes`

Newest dated local CPC morphology-code CSV, with original labels and retirement information.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `row_id` | INTEGER | yes | Primary key |  |
| `morph_beh` | TEXT | no |  |  |
| `icdo4` | TEXT | no |  |  |
| `term` | TEXT | no |  |  |
| `term_norm` | TEXT | no |  |  |
| `term_clean` | TEXT | no |  |  |
| `level` | TEXT | no |  |  |
| `retired` | INTEGER | no |  |  |
| `source_file` | TEXT | no |  |  |


Lookup indexes:

- `ix_cpc_morph_ret`: `retired`
- `ix_cpc_morph_o4`: `icdo4`
- `ix_cpc_morph_code`: `morph_beh`
- `ix_cpc_morph_clean`: `term_clean`

## `icdo_site_specific_terms`

Terms from the local site-specific workbook, including screened and uncertain items.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `term_id` | INTEGER | yes | Primary key |  |
| `source_sheet` | TEXT | yes |  |  |
| `icdo_code` | TEXT | yes |  |  |
| `icdo_code_raw` | TEXT | yes |  |  |
| `icdo_term` | TEXT | no |  |  |
| `term_normalized` | TEXT | no |  |  |
| `term_clean` | TEXT | no |  |  |
| `preferred_term` | TEXT | no |  |  |
| `site_specific_flag` | TEXT | no |  |  |
| `subset_c_codes` | TEXT | no |  |  |
| `subset_labels` | TEXT | no |  |  |
| `subset_site_count` | INTEGER | no |  |  |
| `smvl_site_count` | INTEGER | no |  |  |
| `smvl_organ_summary` | TEXT | no |  |  |
| `smvl_all_c_codes` | TEXT | no |  |  |
| `rationale` | TEXT | no |  |  |
| `source_url` | TEXT | no |  |  |
| `source_reference` | TEXT | no |  |  |


Lookup indexes:

- `ix_icdo_site_specific_terms_clean`: `term_clean`
- `ix_icdo_site_specific_terms_code`: `icdo_code`

## `icdo_site_specific_term_sites`

One workbook term/site-code relationship per row.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `term_id` | INTEGER | yes | Primary key |  |
| `c_code` | TEXT | yes | Primary key |  |
| `site_label` | TEXT | no |  |  |

- `term_id` refers to `icdo_site_specific_terms.term_id`.

Lookup indexes:

- `ix_icdo_term_sites_c_code`: `c_code`

## `page_icdo_codes`

Codes found in saved section text, with any explicitly supported term and section context.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `code_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `icdo_code` | TEXT | no |  |  |
| `icdo_code_raw` | TEXT | no |  |  |
| `term_in_coding_section` | TEXT | no |  |  |
| `section_heading` | TEXT | no |  |  |
| `term_role` | TEXT | no |  |  |
| `term_source` | TEXT | no |  |  |
| `line_indent` | INTEGER | yes |  | 0 |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_page_icdo_codes_TermNormUS`: `TermNormUS`
- `ix_page_icdo_codes_TermUS`: `TermUS`
- `ix_page_icdo_codes_page`: `page_id`
- `ix_page_icdo_codes_code`: `icdo_code`, `page_id`

## `page_term_mentions`

Observed titles, coding/related labels and known reference phrases, independent of whether a code was found. Context, origin and evidence identity are retained.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `mention_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `icdo_code` | TEXT | no |  |  |
| `term_original` | TEXT | yes |  |  |
| `term_original_norm` | TEXT | yes |  |  |
| `term_text` | TEXT | yes |  |  |
| `term_clean` | TEXT | yes |  |  |
| `matched_term_original` | TEXT | no |  |  |
| `matched_term_norm` | TEXT | no |  |  |
| `source_kind` | TEXT | yes |  |  |
| `source_heading` | TEXT | no |  |  |
| `section_flag` | TEXT | yes |  |  |
| `section_location` | TEXT | no |  |  |
| `evidence_policy` | TEXT | yes |  |  |
| `is_positive_evidence` | INTEGER | yes |  |  |
| `confidence_score` | DECIMAL(5,2) | yes |  |  |
| `snippet` | TEXT | no |  |  |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |
| `url` | TEXT | no |  |  |
| `term_source` | TEXT | no |  |  |
| `extraction_method` | TEXT | no |  |  |
| `term_role` | TEXT | no |  |  |
| `code_origin` | TEXT | no |  |  |
| `parent_mention_id` | INTEGER | no |  |  |
| `review_status` | TEXT | no |  |  |
| `reviewed_by` | TEXT | no |  |  |
| `observation_key` | TEXT | no |  |  |
| `source_locator` | TEXT | no |  |  |
| `term_origin` | TEXT | no |  |  |
| `context_class` | TEXT | no |  |  |
| `evidence_hash` | TEXT | no |  |  |
| `extraction_tier` | TEXT | no |  |  |
| `is_current` | INTEGER | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_term_observation_page_norm`: `page_id`, `TermNormUS`
- Unique `ux_term_observation`: `observation_key`
- `ix_page_term_mentions_TermNormUS`: `TermNormUS`
- `ix_page_term_mentions_TermNorm`: `TermNormUS`
- `ix_page_term_mentions_TermUS`: `TermUS`
- `ix_page_term_mentions_page`: `page_id`
- `ix_page_term_mentions_policy`: `evidence_policy`, `is_positive_evidence`
- `ix_page_term_mentions_code`: `icdo_code`, `page_id`
- `ix_page_term_mentions_clean`: `term_clean`, `page_id`

## `term_saved_sections`

Saved section cache keyed by source hash and parser definition; raw HTML remains the source.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `page_id` | INTEGER | yes | Primary key |  |
| `source_sha256` | TEXT | yes |  |  |
| `parser_version` | TEXT | yes |  |  |
| `sections_json` | TEXT | yes |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:


## `term_reference_rows`

Edition, file hash, sheet, physical row and original/canonical reference labels. Earlier reference revisions remain identifiable.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `reference_key` | TEXT | yes | Primary key |  |
| `edition` | TEXT | yes |  |  |
| `reference_file` | TEXT | yes |  |  |
| `reference_sha256` | TEXT | yes |  |  |
| `reference_sheet` | TEXT | yes |  |  |
| `reference_row` | INTEGER | yes |  |  |
| `code` | TEXT | yes |  |  |
| `official_term` | TEXT | yes |  |  |
| `official_termUS` | TEXT | yes |  |  |
| `official_termNormUS` | TEXT | yes |  |  |
| `level` | TEXT | no |  |  |
| `conditions` | TEXT | no |  |  |


Lookup indexes:

- `ix_term_reference_code`: `edition`, `code`
- `ix_term_reference_norm`: `edition`, `official_termNormUS`

## `term_lookup_evaluations`

Edition-specific matching outcomes, linked to observations and reference/evidence revisions.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `evaluation_id` | INTEGER | yes | Primary key |  |
| `evaluation_key` | TEXT | yes |  |  |
| `mention_id` | INTEGER | yes |  |  |
| `edition` | TEXT | yes |  |  |
| `reference_sha256` | TEXT | yes |  |  |
| `matcher_version` | TEXT | yes |  |  |
| `evidence_hash` | TEXT | yes |  |  |
| `outcome` | TEXT | yes |  |  |
| `detail` | TEXT | yes |  |  |
| `evaluated_at` | TEXT | yes |  |  |
| `is_current` | INTEGER | yes |  | 1 |

- `mention_id` refers to `page_term_mentions.mention_id`.

Lookup indexes:

- `ix_term_evaluation_observation`: `mention_id`, `edition`, `is_current`
- Unique `sqlite_autoindex_term_lookup_evaluations_1`: `evaluation_key`

## `term_code_candidates`

Proposed official mappings, wording, evidence tiers, conditions and supporting workbook rows.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `candidate_id` | INTEGER | yes | Primary key |  |
| `candidate_key` | TEXT | yes |  |  |
| `evaluation_id` | INTEGER | yes |  |  |
| `code` | TEXT | yes |  |  |
| `official_term` | TEXT | yes |  |  |
| `candidateTermUS` | TEXT | yes |  |  |
| `candidateTermNormUS` | TEXT | yes |  |  |
| `match_type` | TEXT | yes |  |  |
| `evidence_tier` | TEXT | yes |  |  |
| `candidate_order` | INTEGER | yes |  |  |
| `conditions` | TEXT | no |  |  |
| `reference_evidence` | TEXT | yes |  |  |
| `review_status` | TEXT | yes |  |  |
| `legacy_match_key` | TEXT | no |  |  |

- `evaluation_id` refers to `term_lookup_evaluations.evaluation_id`.

Lookup indexes:

- `ix_term_candidate_review`: `review_status`, `evaluation_id`
- `ix_term_candidate_evaluation`: `evaluation_id`
- Unique `sqlite_autoindex_term_code_candidates_1`: `candidate_key`

## `term_review_decisions`

Append-only scoped review decisions. Changed evidence can reopen review; previous decisions are not overwritten.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `decision_id` | INTEGER | yes | Primary key |  |
| `decision_key` | TEXT | yes |  |  |
| `target_key` | TEXT | yes |  |  |
| `scope` | TEXT | yes |  |  |
| `outcome` | TEXT | yes |  |  |
| `reason` | TEXT | yes |  |  |
| `evidence_hash` | TEXT | yes |  |  |
| `reviewer` | TEXT | no |  |  |
| `decided_at` | TEXT | yes |  |  |


Lookup indexes:

- `ix_term_review_target`: `target_key`, `decision_id`
- Unique `sqlite_autoindex_term_review_decisions_1`: `decision_key`

## `term_pipeline_migrations`

One-time migration records; historical recovery is not replayed on every refresh.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `migration_key` | TEXT | yes | Primary key |  |
| `applied_at` | TEXT | yes |  |  |
| `imported_rows` | INTEGER | yes |  |  |


Lookup indexes:


## `page_site_hints`

Supporting page-level site hints, not verified term-specific sites or patient assertions.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `hint_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `c_code` | TEXT | yes |  |  |
| `provenance` | TEXT | yes |  |  |
| `confidence_score` | DECIMAL(5,2) | yes |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_page_site_hints_code`: `c_code`
- `ix_page_site_hints_page`: `page_id`

## `page_entity_evidence`

Mention summary with positive/excluded counts and code evidence. Scores are not probabilities.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `evidence_id` | INTEGER | yes | Primary key |  |
| `page_id` | INTEGER | yes |  |  |
| `icdo_code` | TEXT | no |  |  |
| `term_clean` | TEXT | yes |  |  |
| `positive_mentions` | INTEGER | yes |  |  |
| `excluded_mentions` | INTEGER | yes |  |  |
| `source_kinds` | TEXT | no |  |  |
| `has_code_on_page` | INTEGER | yes |  |  |
| `site_hints` | TEXT | no |  |  |
| `confidence_score` | DECIMAL(6,2) | yes |  |  |
| `TermUS` | TEXT | no |  |  |
| `TermNormUS` | TEXT | no |  |  |

- `page_id` refers to `pages.page_id`.

Lookup indexes:

- `ix_page_entity_evidence_TermNormUS`: `TermNormUS`
- `ix_page_entity_evidence_TermNorm`: `TermNormUS`
- `ix_page_entity_evidence_TermUS`: `TermUS`
- `ix_page_entity_evidence_page`: `page_id`
- `ix_page_entity_evidence_term`: `term_clean`, `icdo_code`

## `page_search_documents`

One search document per page, combining saved/recovered prose without duplicated additions.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `page_id` | INTEGER | yes | Primary key |  |
| `book_id` | INTEGER | yes |  |  |
| `title` | TEXT | no |  |  |
| `full_text` | TEXT | yes |  |  |

- `book_id` refers to `books.book_id`.
- `page_id` refers to `pages.page_id`.

Lookup indexes:


## `enum_values`

Allowed values for controlled status, origin, role and review fields.

| Column | SQLite type | Required | Key / notes | Default |
|---|---|---|---|---|
| `enum_group` | TEXT | yes | Primary key |  |
| `enum_value` | TEXT | yes | Primary key |  |
| `description` | TEXT | yes |  |  |
| `legacy_values` | TEXT | no |  |  |


Lookup indexes:



## Terms and code suggestions

`v_page_code_terms` pairs ICDO32 and ICDO4 on the exact, case-sensitive
`page_id` and `TermUS`. There is no public `code_edition` column.
The row identity is `page_id`, `TermUS`, `ICDO32`, `ICDO4`,
`candidateTermUS32`, `candidateTermUS4`. When either edition has several
possibilities, every scalar combination is shown. This is not a code crosswalk.
Within an edition, a blank-code row is suppressed when a populated code exists.

Use the independent `32` and `4` fields for edition-specific interpretation:
`candidateTermUS32/4`, `is_proposed_code32/4`, `is_proposed_term32/4`,
`lookup_outcome32/4`, `match_type32/4`, `conditions32/4`, `review_status32/4`.
Shared `candidateTermUS` and `morphology_code` prefer ICD-O-4, falling back to
ICD-O-3.2. Shared proposal flags mean either edition; shared textual metadata
combines differing values. Neither field pairing nor reference matching proves
a diagnosis or approves an assignment.

`alias`, `book_name` (the full book title) and original `edition` are separate.
`terminology_kind` describes where a term came from: `coding`, `contextual`,
`acceptable`, `not_recommended`, or `other`. Multiple origins are joined with
`; `. This is not a statement of code validity or preferred wording.

`TermUS` provides US spelling. `TermNormUS` simplifies that display value for
matching through Clean2. Both are stored and indexed; neither is a unique term
identifier. Read-only connections need no custom normalization function.
Writes must use the shared connection helper so automatic maintenance works.

See [the data guide](data-guide.md) for interpretation and
[text matching](reference-matching.md) for matching rules and evidence limits.

## Database-specific storage

SQL Server uses Unicode text, UTC timestamps and compatible numeric types.
The mirror compares normalized values rather than database-specific representations.
Search indexes and activity/collection logs are not mirrored as managed data.
