-- Local post-crawl data. Populated by bluebooks_local.refresh_local().
-- Agent activity and crawl bookkeeping are deliberately not mirrored.
CREATE TABLE IF NOT EXISTS entity_pages (
 page_id INTEGER PRIMARY KEY REFERENCES pages(page_id),
 book_id INTEGER NOT NULL REFERENCES books(book_id),
 chapter TEXT, category TEXT, subcategory TEXT, title TEXT, definition TEXT,
 extracted_at TEXT
);
CREATE TABLE IF NOT EXISTS entity_codes (
 entity_code_id INTEGER PRIMARY KEY,
 page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),
 ordinal INTEGER NOT NULL, term TEXT NOT NULL, code TEXT,
 is_subtype INTEGER NOT NULL DEFAULT 0 CHECK(is_subtype IN (0,1)),
 term_role TEXT,
 TermUS TEXT, TermNormUS TEXT
);
CREATE TABLE IF NOT EXISTS entity_related_terms (
 related_term_id INTEGER PRIMARY KEY,
 page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),
 kind TEXT NOT NULL CHECK(kind IN ('acceptable','not_recommended','other')),
 term TEXT NOT NULL, term_role TEXT, TermUS TEXT, TermNormUS TEXT
);
CREATE TABLE IF NOT EXISTS entity_term_provenance (
 provenance_id INTEGER PRIMARY KEY,
 provenance_key TEXT NOT NULL UNIQUE,
 page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),
 entity_code_id INTEGER REFERENCES entity_codes(entity_code_id),
 related_term_id INTEGER REFERENCES entity_related_terms(related_term_id),
 source_kind TEXT NOT NULL CHECK(source_kind='AI_recovered_prose'),
 source_table TEXT NOT NULL CHECK(source_table IN ('entity_codes','entity_related_terms')),
 source_row_id INTEGER NOT NULL,
 original_text TEXT NOT NULL,
 recovered_term TEXT NOT NULL,
 suggested_qualifier TEXT NOT NULL CHECK(suggested_qualifier IN ('synonym','related','subtype','grouper','other')),
 terminology_status TEXT NOT NULL CHECK(terminology_status IN ('historical','unspecified')),
 review_status TEXT NOT NULL DEFAULT 'proposed' CHECK(review_status IN ('proposed','approved','rejected','needs_review')),
 is_added_term INTEGER NOT NULL CHECK(is_added_term IN (0,1)),
 proposal_batch TEXT NOT NULL,
 note TEXT NOT NULL,
 CHECK((entity_code_id IS NOT NULL AND related_term_id IS NULL) OR
       (entity_code_id IS NULL AND related_term_id IS NOT NULL))
);
CREATE TABLE IF NOT EXISTS entity_term_code_matches (
 match_id INTEGER PRIMARY KEY,
 match_key TEXT NOT NULL UNIQUE,
 provenance_id INTEGER NOT NULL REFERENCES entity_term_provenance(provenance_id),
 edition TEXT NOT NULL CHECK(edition IN ('ICD-O-3.2','ICD-O-4')),
 code TEXT NOT NULL,
 official_term TEXT NOT NULL,
 official_termUS TEXT,
 official_termNormUS TEXT,
 match_type TEXT NOT NULL CHECK(match_type IN ('exact','synonym','broader','narrower','conditional')),
 candidate_order INTEGER NOT NULL CHECK(candidate_order>0),
 conditions TEXT NOT NULL,
 reference_file TEXT NOT NULL,
 reference_sheet TEXT NOT NULL,
 reference_row INTEGER NOT NULL CHECK(reference_row>0),
 reference_sha256 TEXT NOT NULL,
 code_term_evidence TEXT NOT NULL,
 review_status TEXT NOT NULL DEFAULT 'proposed' CHECK(review_status IN ('proposed','approved','rejected','needs_review'))
);
CREATE INDEX IF NOT EXISTS ix_entity_term_provenance_page ON entity_term_provenance(page_id);
CREATE INDEX IF NOT EXISTS ix_entity_term_provenance_code ON entity_term_provenance(entity_code_id);
CREATE INDEX IF NOT EXISTS ix_entity_term_provenance_related ON entity_term_provenance(related_term_id);
CREATE INDEX IF NOT EXISTS ix_entity_term_code_matches_provenance ON entity_term_code_matches(provenance_id);
CREATE INDEX IF NOT EXISTS ix_entity_term_code_matches_edition_code ON entity_term_code_matches(edition,code);
CREATE TABLE IF NOT EXISTS entity_identifiers (
 identifier_id INTEGER PRIMARY KEY,
 page_id INTEGER NOT NULL REFERENCES entity_pages(page_id),
 system TEXT NOT NULL CHECK(system IN ('OMIM')),
 identifier TEXT NOT NULL,
 term TEXT NOT NULL,
 source_kind TEXT NOT NULL DEFAULT 'section_text',
 source_heading TEXT NOT NULL, raw_text TEXT NOT NULL,
 UNIQUE(page_id,system,identifier,source_heading,term)
);
CREATE TABLE IF NOT EXISTS cpc_curation (
 curation_id INTEGER PRIMARY KEY, book_id INTEGER REFERENCES books(book_id),
 icdo4_code TEXT, chapter TEXT, icdo32_code TEXT,
 is_icdo41 INTEGER NOT NULL DEFAULT 0 CHECK(is_icdo41 IN (0,1)),
 cpc_site_group TEXT, naaccr_note TEXT
);
CREATE TABLE IF NOT EXISTS icdo4_morphology (
 row_id INTEGER PRIMARY KEY, icdo4 TEXT, level TEXT, term TEXT,
 term_clean TEXT, code_ref TEXT, obs TEXT
);
CREATE TABLE IF NOT EXISTS cpc_morph_codes (
 row_id INTEGER PRIMARY KEY, morph_beh TEXT, icdo4 TEXT, term TEXT,
 term_norm TEXT, term_clean TEXT, level TEXT, retired INTEGER, source_file TEXT
);
CREATE TABLE IF NOT EXISTS icdo_site_specific_terms (
 term_id INTEGER PRIMARY KEY,
 source_sheet TEXT NOT NULL, icdo_code TEXT NOT NULL, icdo_code_raw TEXT NOT NULL,
 icdo_term TEXT, term_normalized TEXT, term_clean TEXT, preferred_term TEXT,
 site_specific_flag TEXT, subset_c_codes TEXT, subset_labels TEXT,
 subset_site_count INTEGER, smvl_site_count INTEGER, smvl_organ_summary TEXT,
 smvl_all_c_codes TEXT, rationale TEXT, source_url TEXT, source_reference TEXT
);
CREATE TABLE IF NOT EXISTS icdo_site_specific_term_sites (
 term_id INTEGER NOT NULL REFERENCES icdo_site_specific_terms(term_id),
 c_code TEXT NOT NULL, site_label TEXT, PRIMARY KEY(term_id,c_code)
);
CREATE TABLE IF NOT EXISTS page_icdo_codes (
 code_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES pages(page_id),
 icdo_code TEXT, icdo_code_raw TEXT, term_in_coding_section TEXT,
 section_heading TEXT, term_role TEXT, term_source TEXT, line_indent INTEGER NOT NULL DEFAULT 0,
 TermUS TEXT, TermNormUS TEXT
);
CREATE TABLE IF NOT EXISTS page_term_mentions (
 mention_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES pages(page_id),
 url TEXT,
 icdo_code TEXT, term_original TEXT NOT NULL, term_original_norm TEXT NOT NULL,
 term_text TEXT NOT NULL, term_clean TEXT NOT NULL,
 matched_term_original TEXT, matched_term_norm TEXT,
 term_source TEXT, extraction_method TEXT, term_role TEXT, code_origin TEXT,
 parent_mention_id INTEGER REFERENCES page_term_mentions(mention_id),
 source_kind TEXT NOT NULL,
 source_heading TEXT, section_flag TEXT, section_location TEXT,
 evidence_policy TEXT NOT NULL,
 is_positive_evidence INTEGER NOT NULL CHECK(is_positive_evidence IN (0,1)),
 confidence_score DECIMAL(5,2) NOT NULL, snippet TEXT,
 review_status TEXT NOT NULL DEFAULT 'accepted',
 reviewed_by TEXT NOT NULL DEFAULT 'rule',
 TermUS TEXT, TermNormUS TEXT,
 observation_key TEXT, source_locator TEXT, term_origin TEXT,
 context_class TEXT, evidence_hash TEXT, extraction_tier TEXT, is_current INTEGER
);
CREATE TABLE IF NOT EXISTS page_site_hints (
 hint_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES pages(page_id),
 c_code TEXT NOT NULL, provenance TEXT NOT NULL,
 confidence_score DECIMAL(5,2) NOT NULL
);
CREATE TABLE IF NOT EXISTS page_entity_evidence (
 evidence_id INTEGER PRIMARY KEY, page_id INTEGER NOT NULL REFERENCES pages(page_id),
 icdo_code TEXT, term_clean TEXT NOT NULL, positive_mentions INTEGER NOT NULL,
 excluded_mentions INTEGER NOT NULL, source_kinds TEXT,
 has_code_on_page INTEGER NOT NULL CHECK(has_code_on_page IN (0,1)),
 site_hints TEXT, confidence_score DECIMAL(6,2) NOT NULL, TermUS TEXT, TermNormUS TEXT
);
CREATE TABLE IF NOT EXISTS page_search_documents (
 page_id INTEGER PRIMARY KEY REFERENCES pages(page_id),
 book_id INTEGER NOT NULL REFERENCES books(book_id),
 title TEXT, full_text TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_pages_title_norm ON pages(title_norm);
CREATE INDEX IF NOT EXISTS ix_entity_pages_book ON entity_pages(book_id);
CREATE INDEX IF NOT EXISTS ix_entity_codes_page ON entity_codes(page_id);
CREATE INDEX IF NOT EXISTS ix_entity_codes_code ON entity_codes(code);
CREATE INDEX IF NOT EXISTS ix_entity_related_page ON entity_related_terms(page_id);
CREATE INDEX IF NOT EXISTS ix_entity_identifiers_lookup ON entity_identifiers(system,identifier);
CREATE INDEX IF NOT EXISTS ix_cpc_curation_code ON cpc_curation(book_id,icdo4_code);
CREATE INDEX IF NOT EXISTS ix_icdo4_morph_clean ON icdo4_morphology(term_clean);
CREATE INDEX IF NOT EXISTS ix_icdo4_morph_code ON icdo4_morphology(icdo4);
CREATE INDEX IF NOT EXISTS ix_cpc_morph_clean ON cpc_morph_codes(term_clean);
CREATE INDEX IF NOT EXISTS ix_cpc_morph_code ON cpc_morph_codes(morph_beh);
CREATE INDEX IF NOT EXISTS ix_cpc_morph_o4 ON cpc_morph_codes(icdo4);
CREATE INDEX IF NOT EXISTS ix_cpc_morph_ret ON cpc_morph_codes(retired);
CREATE INDEX IF NOT EXISTS ix_icdo_site_specific_terms_code ON icdo_site_specific_terms(icdo_code);
CREATE INDEX IF NOT EXISTS ix_icdo_site_specific_terms_clean ON icdo_site_specific_terms(term_clean);
CREATE INDEX IF NOT EXISTS ix_icdo_term_sites_c_code ON icdo_site_specific_term_sites(c_code);
CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_code ON page_icdo_codes(icdo_code,page_id);
CREATE INDEX IF NOT EXISTS ix_page_icdo_codes_page ON page_icdo_codes(page_id);
CREATE INDEX IF NOT EXISTS ix_page_term_mentions_page ON page_term_mentions(page_id);
CREATE INDEX IF NOT EXISTS ix_page_term_mentions_clean ON page_term_mentions(term_clean,page_id);
CREATE INDEX IF NOT EXISTS ix_page_term_mentions_code ON page_term_mentions(icdo_code,page_id);
CREATE INDEX IF NOT EXISTS ix_page_term_mentions_policy ON page_term_mentions(evidence_policy,is_positive_evidence);
CREATE INDEX IF NOT EXISTS ix_page_site_hints_page ON page_site_hints(page_id);
CREATE INDEX IF NOT EXISTS ix_page_site_hints_code ON page_site_hints(c_code);
CREATE INDEX IF NOT EXISTS ix_page_entity_evidence_term ON page_entity_evidence(term_clean,icdo_code);
CREATE INDEX IF NOT EXISTS ix_page_entity_evidence_page ON page_entity_evidence(page_id);

CREATE TABLE IF NOT EXISTS enum_values (
  enum_group TEXT NOT NULL,
  enum_value TEXT NOT NULL,
  description TEXT,
  legacy_values TEXT,
  PRIMARY KEY (enum_group, enum_value)
);

INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_match', 'broader', 'Assigned or proposed code represents a broader category than BB term', 'broader');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_match', 'conditional', 'Match applies only under specific site or behaviour constraints', 'conditional');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_match', 'exact', 'Official term concept matches Blue Book term identically', 'exact');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_match', 'narrower', 'Assigned or proposed code represents a narrower category than BB term', 'narrower');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_match', 'synonym', 'Blue Book term is an official synonym of the coded concept', 'synonym');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_origin', 'none', 'No code assigned or identified', 'uncoded_term');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_origin', 'printed_on_coding_page', 'Code is printed next to term on book-level ICD-O coding page', 'contextual_code');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_origin', 'printed_with_term', 'Code is printed on the same line as the term in entity coding section', 'source_assignment');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('code_origin', 'proposed_match', 'Code was proposed by vocabulary matching and not printed with term', 'candidate');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('extraction_method', 'ai_recovery', 'Recovered from prose by AI reading and inspection', 'AI_recovered_prose');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('extraction_method', 'html_parse', 'Read deterministically from page structure or TOC hierarchy', 'parsed_entity,section_text');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('extraction_method', 'lexicon_match', 'Found by matching text against the known-term lexicon', 'term_site_match');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('extraction_method', 'manual', 'Entered or verified by a human curator', 'manual');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'chapter_intro', 'The introduction to a chapter', 'chapter_intro');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'editorial_board', 'An editorial board roster page', 'editorial_board');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'entity', 'A page describing an individual tumour entity', 'tumour_entity, other');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'foreword', 'A foreword page', 'foreword');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'front_matter', 'General book front matter or introduction', 'front_matter');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'how_to_cite', 'Citation instructions page', 'how_to_cite');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'iccr_dataset', 'An ICCR dataset page', 'iccr_datasets');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'icdo_coding', 'A book-level ICD-O coding list page', 'icdo_coding');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'other', 'Other administrative or unclassified page', 'other');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'subcommittee', 'A consensus or advisory subcommittee page', 'subcommittee');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('page_type', 'tnm_staging', 'A TNM staging reference page', 'tnm_staging');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('review_status', 'accepted', 'Accepted as valid evidence / term entry', 'included, 1');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('review_status', 'proposed', 'Produced by machine extraction and pending review', 'proposed');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('review_status', 'rejected', 'Excluded from active lexicon but retained for audit', 'excluded, 0');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('reviewed_by', 'human', 'Decided by a human domain expert or curator', 'curator');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('reviewed_by', 'rule', 'Decided automatically by a deterministic code/hygiene rule', 'evidence_policy');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_currency', 'current', 'The Blue Book presents the term as in active standard use', 'unspecified');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_currency', 'historical', 'The Blue Book marks the term as former or obsolete', 'historical');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_currency', 'unspecified', 'The Blue Book text makes no explicit statement about currency', 'unspecified');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'ai_suggested_grouper', 'Role suggested as grouper by AI recovery model', 'suggested_qualifier=grouper');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'ai_suggested_other', 'Role suggested as other by AI recovery model', 'suggested_qualifier=other');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'ai_suggested_related', 'Role suggested as related term by AI recovery model', 'suggested_qualifier=related');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'ai_suggested_subtype', 'Role suggested as subtype by AI recovery model', 'suggested_qualifier=subtype');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'ai_suggested_synonym', 'Role suggested as synonym by AI recovery model', 'suggested_qualifier=synonym');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'component', 'One term split out of a multi-term entry, linked to parent_mention_id', 'sub-term');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'entity_name', 'The official name of the entity as given by page title or TOC entry', 'page_title');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'grouper', 'A label that names a class or family of entities (e.g. plural TOC node)', 'grouper');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'icdo_indent_subtype', 'Indented line on a coding page with an assigned code', 'is_subtype=1');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'mention', 'The term appears in prose or link text without a defined formal role', 'section_body,link_text');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'preferred', 'Non-indented line on a coding page or coding section with an assigned code', 'is_subtype=0');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'related_acceptable', 'Listed under Acceptable in Related terminology', 'acceptable');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'related_not_recommended', 'Listed under Not recommended in Related terminology', 'not_recommended');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'related_unlabeled', 'Listed in Related terminology without an explicit label', 'other');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'subtype_section', 'Term harvested from the Subtype(s) section of an entity page', 'subtype');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'uncoded_preferred', 'Non-indented line on a coding page or coding section without a code', 'uncoded_term');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_role', 'uncoded_subtype', 'Indented line on a coding page without a code (ambiguous status)', 'uncoded_term');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'entity_coding_section', 'A line in the ICD-O coding section of an entity page', 'coding_section');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'icdo_coding_page', 'A line on a book-level ICD-O coding page (page_type = icdo_coding)', 'coding_section');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'image_caption', 'The caption text of a figure or table image', 'image_caption');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'link_text', 'The visible text of a hyperlink to another page', 'link_text');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'page_title', 'The title (H1) shown on the page itself', 'page_title');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'related_terminology_section', 'A line in the Related terminology section of an entity page', 'entity_related_term');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'section_body', 'Running prose inside a section body', 'section_body');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'section_heading', 'A section or subsection heading on an entity or introductory page', 'section_heading');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'subtype_section', 'A line in the Subtype(s) section of an entity page', 'section_heading,section_body');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'toc_group_label', 'Text of a TOC node that groups pages without direct link', 'page_groups.label');
INSERT OR IGNORE INTO enum_values (enum_group, enum_value, description, legacy_values) VALUES ('term_source', 'toc_page_title', 'Text of a table-of-contents entry that links to a page', 'page_title');
