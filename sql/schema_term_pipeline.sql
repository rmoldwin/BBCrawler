CREATE TABLE IF NOT EXISTS term_saved_sections (
 page_id INTEGER PRIMARY KEY REFERENCES pages(page_id),
 source_sha256 TEXT NOT NULL, parser_version TEXT NOT NULL,
 sections_json TEXT NOT NULL,
 CHECK(length(source_sha256)=64), CHECK(length(parser_version)>0)
);
CREATE TABLE IF NOT EXISTS term_reference_rows (
 reference_key TEXT PRIMARY KEY,
 edition TEXT NOT NULL CHECK(edition IN ('ICD-O-3.2','ICD-O-4')),
 reference_file TEXT NOT NULL, reference_sha256 TEXT NOT NULL,
 reference_sheet TEXT NOT NULL, reference_row INTEGER NOT NULL CHECK(reference_row>0),
 code TEXT NOT NULL, official_term TEXT NOT NULL,
 official_termUS TEXT NOT NULL, official_termNormUS TEXT NOT NULL,
 level TEXT, conditions TEXT, CHECK(length(reference_sha256)=64)
);
CREATE INDEX IF NOT EXISTS ix_term_reference_norm ON term_reference_rows(edition,official_termNormUS);
CREATE INDEX IF NOT EXISTS ix_term_reference_code ON term_reference_rows(edition,code);
CREATE TABLE IF NOT EXISTS term_lookup_evaluations (
 evaluation_id INTEGER PRIMARY KEY, evaluation_key TEXT NOT NULL UNIQUE,
 mention_id INTEGER NOT NULL REFERENCES page_term_mentions(mention_id),
 edition TEXT NOT NULL CHECK(edition IN ('ICD-O-3.2','ICD-O-4')),
 reference_sha256 TEXT NOT NULL CHECK(length(reference_sha256)=64),
 matcher_version TEXT NOT NULL, evidence_hash TEXT NOT NULL,
 outcome TEXT NOT NULL CHECK(outcome IN
  ('matched','ambiguous','no_match','not_applicable','needs_review','not_evaluated')),
 detail TEXT NOT NULL, evaluated_at TEXT NOT NULL,
 is_current INTEGER NOT NULL DEFAULT 1 CHECK(is_current IN (0,1)),
 CHECK(length(evidence_hash)=64)
);
CREATE INDEX IF NOT EXISTS ix_term_evaluation_observation ON term_lookup_evaluations(mention_id,edition,is_current);
CREATE TABLE IF NOT EXISTS term_code_candidates (
 candidate_id INTEGER PRIMARY KEY, candidate_key TEXT NOT NULL UNIQUE,
 evaluation_id INTEGER NOT NULL REFERENCES term_lookup_evaluations(evaluation_id),
 code TEXT NOT NULL, official_term TEXT NOT NULL,
 candidateTermUS TEXT NOT NULL, candidateTermNormUS TEXT NOT NULL,
 match_type TEXT NOT NULL CHECK(match_type IN
  ('exact','synonym','normalized','broader','narrower','conditional','legacy_curated')),
 evidence_tier TEXT NOT NULL CHECK(evidence_tier IN
  ('structured','supported_span','interpretation','curated_review')),
 candidate_order INTEGER NOT NULL CHECK(candidate_order>0), conditions TEXT,
 reference_evidence TEXT NOT NULL, review_status TEXT NOT NULL,
 legacy_match_key TEXT,
 CHECK(review_status IN ('proposed','approved','rejected','needs_review'))
);
CREATE INDEX IF NOT EXISTS ix_term_candidate_evaluation ON term_code_candidates(evaluation_id);
CREATE INDEX IF NOT EXISTS ix_term_candidate_review ON term_code_candidates(review_status,evaluation_id);
CREATE TABLE IF NOT EXISTS term_review_decisions (
 decision_id INTEGER PRIMARY KEY, decision_key TEXT NOT NULL UNIQUE,
 target_key TEXT NOT NULL, scope TEXT NOT NULL CHECK(scope IN
  ('observation','page_context','candidate','term_edition_code','global_extraction')),
 outcome TEXT NOT NULL CHECK(outcome IN ('approved','rejected','needs_review','proposed')),
 reason TEXT NOT NULL, evidence_hash TEXT NOT NULL,
 reviewer TEXT, decided_at TEXT NOT NULL, CHECK(length(evidence_hash)=64)
);
CREATE INDEX IF NOT EXISTS ix_term_review_target ON term_review_decisions(target_key,decision_id);
CREATE TRIGGER IF NOT EXISTS term_review_no_update BEFORE UPDATE ON term_review_decisions
BEGIN SELECT RAISE(ABORT,'Review decisions are append-only'); END;
CREATE TRIGGER IF NOT EXISTS term_review_no_delete BEFORE DELETE ON term_review_decisions
BEGIN SELECT RAISE(ABORT,'Review decisions are append-only'); END;
CREATE TABLE IF NOT EXISTS term_pipeline_migrations (
 migration_key TEXT PRIMARY KEY, applied_at TEXT NOT NULL,
 imported_rows INTEGER NOT NULL CHECK(imported_rows>=0)
);
INSERT OR IGNORE INTO enum_values(enum_group,enum_value,description,legacy_values) VALUES
 ('lookup_outcome','matched','One supported official code relationship',''),
 ('lookup_outcome','ambiguous','Multiple official codes require adjudication',''),
 ('lookup_outcome','no_match','No official relationship found in this edition',''),
 ('lookup_outcome','not_applicable','Non-codeable syndrome without morphology relationship',''),
 ('lookup_outcome','needs_review','Context, qualifiers or broader relationship require review',''),
 ('lookup_outcome','not_evaluated','No current edition evaluation available',''),
 ('context_class','affirmative','Positive sentence-local mention',''),
 ('context_class','negated','Sentence-local explicit exclusion',''),
 ('context_class','differential','Differential or distinguishing context',''),
 ('context_class','historical','Former or obsolete terminology context',''),
 ('context_class','incidental','Incidental mention, not page diagnosis',''),
 ('context_class','legacy','Historical code-first lexicon evidence, inactive',''),
 ('extraction_tier','structured','Title or explicit structured label',''),
 ('extraction_tier','supported_span','Boundary-aware saved-prose span',''),
 ('extraction_tier','interpretation','Preserved curated interpretation requiring review',''),
 ('term_origin','source','Current saved source observation',''),
 ('term_origin','legacy_import','Persisted curated evidence adapted without manifest replay',''),
 ('term_origin','prior_lexicon','Inactive pre-pipeline code-first lexicon evidence',''),
 ('extraction_method','legacy_import','Historical extraction, not newly parsed source text',''),
 ('review_status','approved','Explicitly reviewed mapping/observation approval',''),
 ('review_status','needs_review','Context or materially changed evidence needs adjudication',''),
 ('code_match','normalized','Canonical matching removed meaningful qualifiers; review required',''),
 ('code_match','conditional','Relationship applies only under explicit conditions',''),
 ('code_match','broader','Broader official phrase; no automatic assignment','');
