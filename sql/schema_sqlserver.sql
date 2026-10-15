-- Generated managed data schema; activity and collection history excluded.
-- For upgrades use bluebooks_local.ensure_server_schema.

IF OBJECT_ID('dbo.books','U') IS NULL
CREATE TABLE dbo.[books] (
  [book_id] INT NOT NULL,
  [title] NVARCHAR(MAX) NOT NULL,
  [edition] NVARCHAR(60) NULL,
  [series] NVARCHAR(MAX) NULL,
  [status] NVARCHAR(MAX) NULL,
  [url] NVARCHAR(1000) NOT NULL,
  [alias] NVARCHAR(250) NULL,
  PRIMARY KEY ([book_id])
);
GO
IF OBJECT_ID('dbo.chapters','U') IS NULL
CREATE TABLE dbo.[chapters] (
  [chapter_id] INT NOT NULL,
  [book_id] INT NOT NULL,
  [number] INT NULL,
  [title] NVARCHAR(MAX) NOT NULL,
  [ord] INT NULL,
  PRIMARY KEY ([chapter_id])
);
GO
IF OBJECT_ID('dbo.page_groups','U') IS NULL
CREATE TABLE dbo.[page_groups] (
  [group_id] INT NOT NULL,
  [chapter_id] INT NOT NULL,
  [parent_group] INT NULL,
  [label] NVARCHAR(MAX) NOT NULL,
  [level] INT NOT NULL,
  [ord] INT NULL,
  PRIMARY KEY ([group_id])
);
GO
IF OBJECT_ID('dbo.pages','U') IS NULL
CREATE TABLE dbo.[pages] (
  [page_id] INT NOT NULL,
  [book_id] INT NOT NULL,
  [chapter_id] INT NULL,
  [group_id] INT NULL,
  [site_page_id] INT NOT NULL,
  [url] NVARCHAR(1000) NOT NULL,
  [title] NVARCHAR(MAX) NULL,
  [subtitle] NVARCHAR(MAX) NULL,
  [breadcrumb] NVARCHAR(MAX) NULL,
  [page_type] NVARCHAR(MAX) NULL,
  [is_pointer] INT NULL DEFAULT 0,
  [raw_html] NVARCHAR(MAX) NULL,
  [markdown] NVARCHAR(MAX) NULL,
  [crawl_status] NVARCHAR(MAX) NULL DEFAULT 'pending',
  [error_note] NVARCHAR(MAX) NULL,
  [fetched_at] DATETIME2 NULL,
  [title_norm] NVARCHAR(600) NULL,
  [icdo_code_hint] NVARCHAR(40) NULL,
  PRIMARY KEY ([page_id])
);
GO
IF OBJECT_ID('dbo.sections','U') IS NULL
CREATE TABLE dbo.[sections] (
  [section_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [heading] NVARCHAR(MAX) NULL,
  [body_text] NVARCHAR(MAX) NULL,
  [ord] INT NULL,
  [source_anchor] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([section_id])
);
GO
IF OBJECT_ID('dbo.authors','U') IS NULL
CREATE TABLE dbo.[authors] (
  [author_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [role] NVARCHAR(MAX) NULL,
  [name] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([author_id])
);
GO
IF OBJECT_ID('dbo.images','U') IS NULL
CREATE TABLE dbo.[images] (
  [image_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [section_id] INT NULL,
  [site_image_no] NVARCHAR(MAX) NULL,
  [image_type] NVARCHAR(MAX) NULL,
  [caption] NVARCHAR(MAX) NULL,
  [thumb_url] NVARCHAR(MAX) NULL,
  [full_url] NVARCHAR(MAX) NULL,
  [local_path] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([image_id])
);
GO
IF OBJECT_ID('dbo.page_links','U') IS NULL
CREATE TABLE dbo.[page_links] (
  [link_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [link_text] NVARCHAR(MAX) NULL,
  [target_url] NVARCHAR(MAX) NULL,
  [link_kind] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([link_id])
);
GO
IF OBJECT_ID('dbo.references','U') IS NULL
CREATE TABLE dbo.[references] (
  [ref_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [section_id] INT NULL,
  [token] NVARCHAR(MAX) NULL,
  [token_format] NVARCHAR(MAX) NULL,
  [raw_text] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([ref_id])
);
GO
IF OBJECT_ID('dbo.entity_pages','U') IS NULL
CREATE TABLE dbo.[entity_pages] (
  [page_id] INT NOT NULL,
  [book_id] INT NOT NULL,
  [chapter] NVARCHAR(MAX) NULL,
  [category] NVARCHAR(MAX) NULL,
  [subcategory] NVARCHAR(MAX) NULL,
  [title] NVARCHAR(MAX) NULL,
  [definition] NVARCHAR(MAX) NULL,
  [extracted_at] DATETIME2 NULL DEFAULT SYSUTCDATETIME(),
  PRIMARY KEY ([page_id])
);
GO
IF OBJECT_ID('dbo.entity_codes','U') IS NULL
CREATE TABLE dbo.[entity_codes] (
  [entity_code_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [ordinal] INT NOT NULL,
  [term] NVARCHAR(600) NOT NULL,
  [code] NVARCHAR(40) NULL,
  [is_subtype] INT NOT NULL DEFAULT 0,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  [term_role] NVARCHAR(60) NULL,
  PRIMARY KEY ([entity_code_id])
);
GO
IF OBJECT_ID('dbo.entity_related_terms','U') IS NULL
CREATE TABLE dbo.[entity_related_terms] (
  [related_term_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [kind] NVARCHAR(60) NOT NULL,
  [term] NVARCHAR(600) NOT NULL,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  [term_role] NVARCHAR(60) NULL,
  PRIMARY KEY ([related_term_id])
);
GO
IF OBJECT_ID('dbo.entity_term_provenance','U') IS NULL
CREATE TABLE dbo.[entity_term_provenance] (
  [provenance_id] INT NOT NULL,
  [provenance_key] NVARCHAR(64) NOT NULL,
  [page_id] INT NOT NULL,
  [entity_code_id] INT NULL,
  [related_term_id] INT NULL,
  [source_kind] NVARCHAR(60) NOT NULL,
  [source_table] NVARCHAR(60) NOT NULL,
  [source_row_id] INT NOT NULL,
  [original_text] NVARCHAR(MAX) NOT NULL,
  [recovered_term] NVARCHAR(600) NOT NULL,
  [suggested_qualifier] NVARCHAR(60) NOT NULL,
  [terminology_status] NVARCHAR(60) NOT NULL,
  [review_status] NVARCHAR(60) NOT NULL DEFAULT 'proposed',
  [is_added_term] INT NOT NULL,
  [proposal_batch] NVARCHAR(60) NOT NULL,
  [note] NVARCHAR(MAX) NOT NULL,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  PRIMARY KEY ([provenance_id])
);
GO
IF OBJECT_ID('dbo.entity_term_code_matches','U') IS NULL
CREATE TABLE dbo.[entity_term_code_matches] (
  [match_id] INT NOT NULL,
  [match_key] NVARCHAR(64) NOT NULL,
  [provenance_id] INT NOT NULL,
  [edition] NVARCHAR(60) NOT NULL,
  [code] NVARCHAR(40) NOT NULL,
  [official_term] NVARCHAR(600) NOT NULL,
  [match_type] NVARCHAR(60) NOT NULL,
  [candidate_order] INT NOT NULL,
  [conditions] NVARCHAR(MAX) NOT NULL,
  [reference_file] NVARCHAR(MAX) NOT NULL,
  [reference_sheet] NVARCHAR(MAX) NOT NULL,
  [reference_row] INT NOT NULL,
  [reference_sha256] NVARCHAR(64) NOT NULL,
  [code_term_evidence] NVARCHAR(MAX) NOT NULL,
  [review_status] NVARCHAR(60) NOT NULL DEFAULT 'proposed',
  [official_termUS] NVARCHAR(600) NULL,
  [official_termNormUS] NVARCHAR(600) NULL,
  PRIMARY KEY ([match_id])
);
GO
IF OBJECT_ID('dbo.entity_identifiers','U') IS NULL
CREATE TABLE dbo.[entity_identifiers] (
  [identifier_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [system] NVARCHAR(40) NOT NULL,
  [identifier] NVARCHAR(40) NOT NULL,
  [term] NVARCHAR(600) NOT NULL,
  [source_kind] NVARCHAR(60) NOT NULL DEFAULT 'section_text',
  [source_heading] NVARCHAR(100) NOT NULL,
  [raw_text] NVARCHAR(MAX) NOT NULL,
  PRIMARY KEY ([identifier_id])
);
GO
IF OBJECT_ID('dbo.cpc_curation','U') IS NULL
CREATE TABLE dbo.[cpc_curation] (
  [curation_id] INT NOT NULL,
  [book_id] INT NULL,
  [icdo4_code] NVARCHAR(40) NULL,
  [chapter] NVARCHAR(MAX) NULL,
  [icdo32_code] NVARCHAR(40) NULL,
  [is_icdo41] INT NOT NULL DEFAULT 0,
  [cpc_site_group] NVARCHAR(MAX) NULL,
  [naaccr_note] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([curation_id])
);
GO
IF OBJECT_ID('dbo.icdo4_morphology','U') IS NULL
CREATE TABLE dbo.[icdo4_morphology] (
  [row_id] INT NOT NULL,
  [icdo4] NVARCHAR(40) NULL,
  [level] NVARCHAR(MAX) NULL,
  [term] NVARCHAR(600) NULL,
  [term_clean] NVARCHAR(600) NULL,
  [code_ref] NVARCHAR(MAX) NULL,
  [obs] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([row_id])
);
GO
IF OBJECT_ID('dbo.cpc_morph_codes','U') IS NULL
CREATE TABLE dbo.[cpc_morph_codes] (
  [row_id] INT NOT NULL,
  [morph_beh] NVARCHAR(40) NULL,
  [icdo4] NVARCHAR(40) NULL,
  [term] NVARCHAR(600) NULL,
  [term_norm] NVARCHAR(600) NULL,
  [term_clean] NVARCHAR(600) NULL,
  [level] NVARCHAR(MAX) NULL,
  [retired] INT NULL,
  [source_file] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([row_id])
);
GO
IF OBJECT_ID('dbo.icdo_site_specific_terms','U') IS NULL
CREATE TABLE dbo.[icdo_site_specific_terms] (
  [term_id] INT NOT NULL,
  [source_sheet] NVARCHAR(60) NOT NULL,
  [icdo_code] NVARCHAR(40) NOT NULL,
  [icdo_code_raw] NVARCHAR(40) NOT NULL,
  [icdo_term] NVARCHAR(MAX) NULL,
  [term_normalized] NVARCHAR(MAX) NULL,
  [term_clean] NVARCHAR(600) NULL,
  [preferred_term] NVARCHAR(MAX) NULL,
  [site_specific_flag] NVARCHAR(60) NULL,
  [subset_c_codes] NVARCHAR(MAX) NULL,
  [subset_labels] NVARCHAR(MAX) NULL,
  [subset_site_count] INT NULL,
  [smvl_site_count] INT NULL,
  [smvl_organ_summary] NVARCHAR(MAX) NULL,
  [smvl_all_c_codes] NVARCHAR(MAX) NULL,
  [rationale] NVARCHAR(MAX) NULL,
  [source_url] NVARCHAR(MAX) NULL,
  [source_reference] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([term_id])
);
GO
IF OBJECT_ID('dbo.icdo_site_specific_term_sites','U') IS NULL
CREATE TABLE dbo.[icdo_site_specific_term_sites] (
  [term_id] INT NOT NULL,
  [c_code] NVARCHAR(40) NOT NULL,
  [site_label] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([term_id],[c_code])
);
GO
IF OBJECT_ID('dbo.page_icdo_codes','U') IS NULL
CREATE TABLE dbo.[page_icdo_codes] (
  [code_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [icdo_code] NVARCHAR(40) NULL,
  [icdo_code_raw] NVARCHAR(40) NULL,
  [term_in_coding_section] NVARCHAR(MAX) NULL,
  [section_heading] NVARCHAR(MAX) NULL,
  [term_role] NVARCHAR(60) NULL,
  [term_source] NVARCHAR(60) NULL,
  [line_indent] INT NOT NULL DEFAULT 0,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  PRIMARY KEY ([code_id])
);
GO
IF OBJECT_ID('dbo.page_term_mentions','U') IS NULL
CREATE TABLE dbo.[page_term_mentions] (
  [mention_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [icdo_code] NVARCHAR(40) NULL,
  [term_original] NVARCHAR(MAX) NOT NULL,
  [term_original_norm] NVARCHAR(600) NOT NULL,
  [term_text] NVARCHAR(MAX) NOT NULL,
  [term_clean] NVARCHAR(600) NOT NULL,
  [matched_term_original] NVARCHAR(MAX) NULL,
  [matched_term_norm] NVARCHAR(MAX) NULL,
  [source_kind] NVARCHAR(60) NOT NULL,
  [source_heading] NVARCHAR(MAX) NULL,
  [section_flag] NVARCHAR(60) NOT NULL,
  [section_location] NVARCHAR(MAX) NULL,
  [evidence_policy] NVARCHAR(60) NOT NULL,
  [is_positive_evidence] INT NOT NULL,
  [confidence_score] DECIMAL(5,2) NOT NULL,
  [snippet] NVARCHAR(MAX) NULL,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  [url] NVARCHAR(1000) NULL,
  [term_source] NVARCHAR(60) NULL,
  [extraction_method] NVARCHAR(60) NULL,
  [term_role] NVARCHAR(60) NULL,
  [code_origin] NVARCHAR(60) NULL,
  [parent_mention_id] INT NULL,
  [review_status] NVARCHAR(60) NULL,
  [reviewed_by] NVARCHAR(60) NULL,
  [observation_key] NVARCHAR(64) NULL,
  [source_locator] NVARCHAR(MAX) NULL,
  [term_origin] NVARCHAR(60) NULL,
  [context_class] NVARCHAR(60) NULL,
  [evidence_hash] NVARCHAR(64) NULL,
  [extraction_tier] NVARCHAR(60) NULL,
  [is_current] INT NULL,
  PRIMARY KEY ([mention_id])
);
GO
IF OBJECT_ID('dbo.term_saved_sections','U') IS NULL
CREATE TABLE dbo.[term_saved_sections] (
  [page_id] INT NOT NULL,
  [source_sha256] NVARCHAR(MAX) NOT NULL,
  [parser_version] NVARCHAR(MAX) NOT NULL,
  [sections_json] NVARCHAR(MAX) NOT NULL,
  PRIMARY KEY ([page_id])
);
GO
IF OBJECT_ID('dbo.term_reference_rows','U') IS NULL
CREATE TABLE dbo.[term_reference_rows] (
  [reference_key] NVARCHAR(64) NOT NULL,
  [edition] NVARCHAR(60) NOT NULL,
  [reference_file] NVARCHAR(MAX) NOT NULL,
  [reference_sha256] NVARCHAR(64) NOT NULL,
  [reference_sheet] NVARCHAR(MAX) NOT NULL,
  [reference_row] INT NOT NULL,
  [code] NVARCHAR(40) NOT NULL,
  [official_term] NVARCHAR(MAX) NOT NULL,
  [official_termUS] NVARCHAR(MAX) NOT NULL,
  [official_termNormUS] NVARCHAR(600) NOT NULL,
  [level] NVARCHAR(MAX) NULL,
  [conditions] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([reference_key])
);
GO
IF OBJECT_ID('dbo.term_lookup_evaluations','U') IS NULL
CREATE TABLE dbo.[term_lookup_evaluations] (
  [evaluation_id] INT NOT NULL,
  [evaluation_key] NVARCHAR(64) NOT NULL,
  [mention_id] INT NOT NULL,
  [edition] NVARCHAR(60) NOT NULL,
  [reference_sha256] NVARCHAR(64) NOT NULL,
  [matcher_version] NVARCHAR(60) NOT NULL,
  [evidence_hash] NVARCHAR(64) NOT NULL,
  [outcome] NVARCHAR(60) NOT NULL,
  [detail] NVARCHAR(MAX) NOT NULL,
  [evaluated_at] DATETIME2 NOT NULL,
  [is_current] INT NOT NULL DEFAULT 1,
  PRIMARY KEY ([evaluation_id])
);
GO
IF OBJECT_ID('dbo.term_code_candidates','U') IS NULL
CREATE TABLE dbo.[term_code_candidates] (
  [candidate_id] INT NOT NULL,
  [candidate_key] NVARCHAR(64) NOT NULL,
  [evaluation_id] INT NOT NULL,
  [code] NVARCHAR(40) NOT NULL,
  [official_term] NVARCHAR(MAX) NOT NULL,
  [candidateTermUS] NVARCHAR(600) NOT NULL,
  [candidateTermNormUS] NVARCHAR(600) NOT NULL,
  [match_type] NVARCHAR(MAX) NOT NULL,
  [evidence_tier] NVARCHAR(60) NOT NULL,
  [candidate_order] INT NOT NULL,
  [conditions] NVARCHAR(MAX) NULL,
  [reference_evidence] NVARCHAR(MAX) NOT NULL,
  [review_status] NVARCHAR(60) NOT NULL,
  [legacy_match_key] NVARCHAR(64) NULL,
  PRIMARY KEY ([candidate_id])
);
GO
IF OBJECT_ID('dbo.term_review_decisions','U') IS NULL
CREATE TABLE dbo.[term_review_decisions] (
  [decision_id] INT NOT NULL,
  [decision_key] NVARCHAR(64) NOT NULL,
  [target_key] NVARCHAR(64) NOT NULL,
  [scope] NVARCHAR(60) NOT NULL,
  [outcome] NVARCHAR(60) NOT NULL,
  [reason] NVARCHAR(MAX) NOT NULL,
  [evidence_hash] NVARCHAR(64) NOT NULL,
  [reviewer] NVARCHAR(MAX) NULL,
  [decided_at] DATETIME2 NOT NULL,
  PRIMARY KEY ([decision_id])
);
GO
IF OBJECT_ID('dbo.term_pipeline_migrations','U') IS NULL
CREATE TABLE dbo.[term_pipeline_migrations] (
  [migration_key] NVARCHAR(100) NOT NULL,
  [applied_at] DATETIME2 NOT NULL,
  [imported_rows] INT NOT NULL,
  PRIMARY KEY ([migration_key])
);
GO
IF OBJECT_ID('dbo.page_site_hints','U') IS NULL
CREATE TABLE dbo.[page_site_hints] (
  [hint_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [c_code] NVARCHAR(40) NOT NULL,
  [provenance] NVARCHAR(60) NOT NULL,
  [confidence_score] DECIMAL(5,2) NOT NULL,
  PRIMARY KEY ([hint_id])
);
GO
IF OBJECT_ID('dbo.page_entity_evidence','U') IS NULL
CREATE TABLE dbo.[page_entity_evidence] (
  [evidence_id] INT NOT NULL,
  [page_id] INT NOT NULL,
  [icdo_code] NVARCHAR(40) NULL,
  [term_clean] NVARCHAR(600) NOT NULL,
  [positive_mentions] INT NOT NULL,
  [excluded_mentions] INT NOT NULL,
  [source_kinds] NVARCHAR(MAX) NULL,
  [has_code_on_page] INT NOT NULL,
  [site_hints] NVARCHAR(MAX) NULL,
  [confidence_score] DECIMAL(6,2) NOT NULL,
  [TermUS] NVARCHAR(600) NULL,
  [TermNormUS] NVARCHAR(600) NULL,
  PRIMARY KEY ([evidence_id])
);
GO
IF OBJECT_ID('dbo.page_search_documents','U') IS NULL
CREATE TABLE dbo.[page_search_documents] (
  [page_id] INT NOT NULL,
  [book_id] INT NOT NULL,
  [title] NVARCHAR(MAX) NULL,
  [full_text] NVARCHAR(MAX) NOT NULL,
  PRIMARY KEY ([page_id])
);
GO
IF OBJECT_ID('dbo.enum_values','U') IS NULL
CREATE TABLE dbo.[enum_values] (
  [enum_group] NVARCHAR(60) NOT NULL,
  [enum_value] NVARCHAR(60) NOT NULL,
  [description] NVARCHAR(MAX) NOT NULL,
  [legacy_values] NVARCHAR(MAX) NULL,
  PRIMARY KEY ([enum_group],[enum_value])
);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.chapters') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='book_id'))
CREATE INDEX [ix_chapters_book] ON dbo.[chapters] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.chapters') AND referenced_object_id=OBJECT_ID('dbo.books') AND COL_NAME(parent_object_id,parent_column_id)='book_id' AND COL_NAME(referenced_object_id,referenced_column_id)='book_id')
ALTER TABLE dbo.[chapters] WITH CHECK ADD CONSTRAINT [fk_local_chapters_book_id_books] FOREIGN KEY ([book_id]) REFERENCES dbo.[books] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_groups') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='parent_group'))
CREATE INDEX [ix_groups_parent] ON dbo.[page_groups] ([parent_group]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_groups') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='chapter_id'))
CREATE INDEX [ix_groups_chapter] ON dbo.[page_groups] ([chapter_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_groups') AND referenced_object_id=OBJECT_ID('dbo.page_groups') AND COL_NAME(parent_object_id,parent_column_id)='parent_group' AND COL_NAME(referenced_object_id,referenced_column_id)='group_id')
ALTER TABLE dbo.[page_groups] WITH CHECK ADD CONSTRAINT [fk_local_page_groups_parent_group_page_groups] FOREIGN KEY ([parent_group]) REFERENCES dbo.[page_groups] ([group_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_groups') AND referenced_object_id=OBJECT_ID('dbo.chapters') AND COL_NAME(parent_object_id,parent_column_id)='chapter_id' AND COL_NAME(referenced_object_id,referenced_column_id)='chapter_id')
ALTER TABLE dbo.[page_groups] WITH CHECK ADD CONSTRAINT [fk_local_page_groups_chapter_id_chapters] FOREIGN KEY ([chapter_id]) REFERENCES dbo.[chapters] ([chapter_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='title_norm'))
CREATE INDEX [ix_pages_title_norm] ON dbo.[pages] ([title_norm]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_type'))
CREATE INDEX [ix_pages_type] ON dbo.[pages] ([page_type]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='crawl_status'))
CREATE INDEX [ix_pages_status] ON dbo.[pages] ([crawl_status]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='book_id'))
CREATE INDEX [ix_pages_book] ON dbo.[pages] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='url'))
CREATE UNIQUE INDEX [ux_local_pages_url] ON dbo.[pages] ([url]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.pages') AND referenced_object_id=OBJECT_ID('dbo.page_groups') AND COL_NAME(parent_object_id,parent_column_id)='group_id' AND COL_NAME(referenced_object_id,referenced_column_id)='group_id')
ALTER TABLE dbo.[pages] WITH CHECK ADD CONSTRAINT [fk_local_pages_group_id_page_groups] FOREIGN KEY ([group_id]) REFERENCES dbo.[page_groups] ([group_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.pages') AND referenced_object_id=OBJECT_ID('dbo.chapters') AND COL_NAME(parent_object_id,parent_column_id)='chapter_id' AND COL_NAME(referenced_object_id,referenced_column_id)='chapter_id')
ALTER TABLE dbo.[pages] WITH CHECK ADD CONSTRAINT [fk_local_pages_chapter_id_chapters] FOREIGN KEY ([chapter_id]) REFERENCES dbo.[chapters] ([chapter_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.pages') AND referenced_object_id=OBJECT_ID('dbo.books') AND COL_NAME(parent_object_id,parent_column_id)='book_id' AND COL_NAME(referenced_object_id,referenced_column_id)='book_id')
ALTER TABLE dbo.[pages] WITH CHECK ADD CONSTRAINT [fk_local_pages_book_id_books] FOREIGN KEY ([book_id]) REFERENCES dbo.[books] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.sections') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_sections_pg] ON dbo.[sections] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.sections') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[sections] WITH CHECK ADD CONSTRAINT [fk_local_sections_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.authors') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_authors_pg] ON dbo.[authors] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.authors') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[authors] WITH CHECK ADD CONSTRAINT [fk_local_authors_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.images') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='section_id'))
CREATE INDEX [ix_images_section] ON dbo.[images] ([section_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.images') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_images_pg] ON dbo.[images] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.images') AND referenced_object_id=OBJECT_ID('dbo.sections') AND COL_NAME(parent_object_id,parent_column_id)='section_id' AND COL_NAME(referenced_object_id,referenced_column_id)='section_id')
ALTER TABLE dbo.[images] WITH CHECK ADD CONSTRAINT [fk_local_images_section_id_sections] FOREIGN KEY ([section_id]) REFERENCES dbo.[sections] ([section_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.images') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[images] WITH CHECK ADD CONSTRAINT [fk_local_images_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_links') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_links_pg] ON dbo.[page_links] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_links') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_links] WITH CHECK ADD CONSTRAINT [fk_local_page_links_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.references') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='section_id'))
CREATE INDEX [ix_refs_section] ON dbo.[references] ([section_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.references') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_refs_pg] ON dbo.[references] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.references') AND referenced_object_id=OBJECT_ID('dbo.sections') AND COL_NAME(parent_object_id,parent_column_id)='section_id' AND COL_NAME(referenced_object_id,referenced_column_id)='section_id')
ALTER TABLE dbo.[references] WITH CHECK ADD CONSTRAINT [fk_local_references_section_id_sections] FOREIGN KEY ([section_id]) REFERENCES dbo.[sections] ([section_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.references') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[references] WITH CHECK ADD CONSTRAINT [fk_local_references_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_pages') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='book_id'))
CREATE INDEX [ix_entity_pages_book] ON dbo.[entity_pages] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_pages') AND referenced_object_id=OBJECT_ID('dbo.books') AND COL_NAME(parent_object_id,parent_column_id)='book_id' AND COL_NAME(referenced_object_id,referenced_column_id)='book_id')
ALTER TABLE dbo.[entity_pages] WITH CHECK ADD CONSTRAINT [fk_local_entity_pages_book_id_books] FOREIGN KEY ([book_id]) REFERENCES dbo.[books] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_pages') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[entity_pages] WITH CHECK ADD CONSTRAINT [fk_local_entity_pages_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_entity_codes_TermNormUS] ON dbo.[entity_codes] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_entity_codes_TermNorm] ON dbo.[entity_codes] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_entity_codes_TermUS] ON dbo.[entity_codes] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='code'))
CREATE INDEX [ix_entity_codes_code] ON dbo.[entity_codes] ([code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_entity_codes_page] ON dbo.[entity_codes] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_codes') AND referenced_object_id=OBJECT_ID('dbo.entity_pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[entity_codes] WITH CHECK ADD CONSTRAINT [fk_local_entity_codes_page_id_entity_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[entity_pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_related_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_entity_related_terms_TermNormUS] ON dbo.[entity_related_terms] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_related_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_entity_related_terms_TermNorm] ON dbo.[entity_related_terms] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_related_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_entity_related_terms_TermUS] ON dbo.[entity_related_terms] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_related_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_entity_related_page] ON dbo.[entity_related_terms] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_related_terms') AND referenced_object_id=OBJECT_ID('dbo.entity_pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[entity_related_terms] WITH CHECK ADD CONSTRAINT [fk_local_entity_related_terms_page_id_entity_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[entity_pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_entity_term_provenance_TermNormUS] ON dbo.[entity_term_provenance] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_entity_term_provenance_TermUS] ON dbo.[entity_term_provenance] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='related_term_id'))
CREATE INDEX [ix_entity_term_provenance_related] ON dbo.[entity_term_provenance] ([related_term_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='entity_code_id'))
CREATE INDEX [ix_entity_term_provenance_code] ON dbo.[entity_term_provenance] ([entity_code_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_entity_term_provenance_page] ON dbo.[entity_term_provenance] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_provenance') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='provenance_key'))
CREATE UNIQUE INDEX [ux_local_entity_term_provenance_provenance_key] ON dbo.[entity_term_provenance] ([provenance_key]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND referenced_object_id=OBJECT_ID('dbo.entity_related_terms') AND COL_NAME(parent_object_id,parent_column_id)='related_term_id' AND COL_NAME(referenced_object_id,referenced_column_id)='related_term_id')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [fk_local_entity_term_provenance_related_term_id_entity_related_terms] FOREIGN KEY ([related_term_id]) REFERENCES dbo.[entity_related_terms] ([related_term_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND referenced_object_id=OBJECT_ID('dbo.entity_codes') AND COL_NAME(parent_object_id,parent_column_id)='entity_code_id' AND COL_NAME(referenced_object_id,referenced_column_id)='entity_code_id')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [fk_local_entity_term_provenance_entity_code_id_entity_codes] FOREIGN KEY ([entity_code_id]) REFERENCES dbo.[entity_codes] ([entity_code_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND referenced_object_id=OBJECT_ID('dbo.entity_pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [fk_local_entity_term_provenance_page_id_entity_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[entity_pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_code_matches') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='official_termNormUS'))
CREATE INDEX [ix_entity_term_code_matches_official_termNormUS] ON dbo.[entity_term_code_matches] ([official_termNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_code_matches') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='official_termUS'))
CREATE INDEX [ix_entity_term_code_matches_official_termUS] ON dbo.[entity_term_code_matches] ([official_termUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_code_matches') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='edition') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='code'))
CREATE INDEX [ix_entity_term_code_matches_edition_code] ON dbo.[entity_term_code_matches] ([edition],[code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_code_matches') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='provenance_id'))
CREATE INDEX [ix_entity_term_code_matches_provenance] ON dbo.[entity_term_code_matches] ([provenance_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_term_code_matches') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='match_key'))
CREATE UNIQUE INDEX [ux_local_entity_term_code_matches_match_key] ON dbo.[entity_term_code_matches] ([match_key]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND referenced_object_id=OBJECT_ID('dbo.entity_term_provenance') AND COL_NAME(parent_object_id,parent_column_id)='provenance_id' AND COL_NAME(referenced_object_id,referenced_column_id)='provenance_id')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [fk_local_entity_term_code_matches_provenance_id_entity_term_provenance] FOREIGN KEY ([provenance_id]) REFERENCES dbo.[entity_term_provenance] ([provenance_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_identifiers') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='system') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='identifier'))
CREATE INDEX [ix_entity_identifiers_lookup] ON dbo.[entity_identifiers] ([system],[identifier]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.entity_identifiers') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=5 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='system') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=3 AND ic.is_descending_key=0 AND c.name='identifier') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=4 AND ic.is_descending_key=0 AND c.name='source_heading') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=5 AND ic.is_descending_key=0 AND c.name='term'))
CREATE UNIQUE INDEX [ux_local_entity_identifiers_page_id_system_identifier_source_heading_term] ON dbo.[entity_identifiers] ([page_id],[system],[identifier],[source_heading],[term]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.entity_identifiers') AND referenced_object_id=OBJECT_ID('dbo.entity_pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[entity_identifiers] WITH CHECK ADD CONSTRAINT [fk_local_entity_identifiers_page_id_entity_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[entity_pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.cpc_curation') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='book_id') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='icdo4_code'))
CREATE INDEX [ix_cpc_curation_code] ON dbo.[cpc_curation] ([book_id],[icdo4_code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.cpc_curation') AND referenced_object_id=OBJECT_ID('dbo.books') AND COL_NAME(parent_object_id,parent_column_id)='book_id' AND COL_NAME(referenced_object_id,referenced_column_id)='book_id')
ALTER TABLE dbo.[cpc_curation] WITH CHECK ADD CONSTRAINT [fk_local_cpc_curation_book_id_books] FOREIGN KEY ([book_id]) REFERENCES dbo.[books] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.icdo4_morphology') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='icdo4'))
CREATE INDEX [ix_icdo4_morph_code] ON dbo.[icdo4_morphology] ([icdo4]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.icdo4_morphology') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='term_clean'))
CREATE INDEX [ix_icdo4_morph_clean] ON dbo.[icdo4_morphology] ([term_clean]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.cpc_morph_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='retired'))
CREATE INDEX [ix_cpc_morph_ret] ON dbo.[cpc_morph_codes] ([retired]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.cpc_morph_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='icdo4'))
CREATE INDEX [ix_cpc_morph_o4] ON dbo.[cpc_morph_codes] ([icdo4]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.cpc_morph_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='morph_beh'))
CREATE INDEX [ix_cpc_morph_code] ON dbo.[cpc_morph_codes] ([morph_beh]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.cpc_morph_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='term_clean'))
CREATE INDEX [ix_cpc_morph_clean] ON dbo.[cpc_morph_codes] ([term_clean]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.icdo_site_specific_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='term_clean'))
CREATE INDEX [ix_icdo_site_specific_terms_clean] ON dbo.[icdo_site_specific_terms] ([term_clean]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.icdo_site_specific_terms') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='icdo_code'))
CREATE INDEX [ix_icdo_site_specific_terms_code] ON dbo.[icdo_site_specific_terms] ([icdo_code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.icdo_site_specific_term_sites') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='c_code'))
CREATE INDEX [ix_icdo_term_sites_c_code] ON dbo.[icdo_site_specific_term_sites] ([c_code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.icdo_site_specific_term_sites') AND referenced_object_id=OBJECT_ID('dbo.icdo_site_specific_terms') AND COL_NAME(parent_object_id,parent_column_id)='term_id' AND COL_NAME(referenced_object_id,referenced_column_id)='term_id')
ALTER TABLE dbo.[icdo_site_specific_term_sites] WITH CHECK ADD CONSTRAINT [fk_local_icdo_site_specific_term_sites_term_id_icdo_site_specific_terms] FOREIGN KEY ([term_id]) REFERENCES dbo.[icdo_site_specific_terms] ([term_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_icdo_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_page_icdo_codes_TermNormUS] ON dbo.[page_icdo_codes] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_icdo_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_page_icdo_codes_TermUS] ON dbo.[page_icdo_codes] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_icdo_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_icdo_codes_page] ON dbo.[page_icdo_codes] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_icdo_codes') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='icdo_code') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_icdo_codes_code] ON dbo.[page_icdo_codes] ([icdo_code],[page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_icdo_codes') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_icdo_codes] WITH CHECK ADD CONSTRAINT [fk_local_page_icdo_codes_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_term_observation_page_norm] ON dbo.[page_term_mentions] ([page_id],[TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=1 AND i.filter_definition LIKE '%observation_key%IS NOT NULL%' AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='observation_key'))
CREATE UNIQUE INDEX [ux_term_observation] ON dbo.[page_term_mentions] ([observation_key]) WHERE [observation_key] IS NOT NULL;
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_page_term_mentions_TermNormUS] ON dbo.[page_term_mentions] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_page_term_mentions_TermNorm] ON dbo.[page_term_mentions] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_page_term_mentions_TermUS] ON dbo.[page_term_mentions] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_term_mentions_page] ON dbo.[page_term_mentions] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='evidence_policy') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='is_positive_evidence'))
CREATE INDEX [ix_page_term_mentions_policy] ON dbo.[page_term_mentions] ([evidence_policy],[is_positive_evidence]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='icdo_code') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_term_mentions_code] ON dbo.[page_term_mentions] ([icdo_code],[page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_term_mentions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='term_clean') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_term_mentions_clean] ON dbo.[page_term_mentions] ([term_clean],[page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_term_mentions') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_term_mentions] WITH CHECK ADD CONSTRAINT [fk_local_page_term_mentions_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.term_saved_sections') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[term_saved_sections] WITH CHECK ADD CONSTRAINT [fk_local_term_saved_sections_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_reference_rows') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='edition') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='code'))
CREATE INDEX [ix_term_reference_code] ON dbo.[term_reference_rows] ([edition],[code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_reference_rows') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='edition') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='official_termNormUS'))
CREATE INDEX [ix_term_reference_norm] ON dbo.[term_reference_rows] ([edition],[official_termNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=3 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='mention_id') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='edition') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=3 AND ic.is_descending_key=0 AND c.name='is_current'))
CREATE INDEX [ix_term_evaluation_observation] ON dbo.[term_lookup_evaluations] ([mention_id],[edition],[is_current]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='evaluation_key'))
CREATE UNIQUE INDEX [ux_local_term_lookup_evaluations_evaluation_key] ON dbo.[term_lookup_evaluations] ([evaluation_key]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND referenced_object_id=OBJECT_ID('dbo.page_term_mentions') AND COL_NAME(parent_object_id,parent_column_id)='mention_id' AND COL_NAME(referenced_object_id,referenced_column_id)='mention_id')
ALTER TABLE dbo.[term_lookup_evaluations] WITH CHECK ADD CONSTRAINT [fk_local_term_lookup_evaluations_mention_id_page_term_mentions] FOREIGN KEY ([mention_id]) REFERENCES dbo.[page_term_mentions] ([mention_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_code_candidates') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='review_status') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='evaluation_id'))
CREATE INDEX [ix_term_candidate_review] ON dbo.[term_code_candidates] ([review_status],[evaluation_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_code_candidates') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='evaluation_id'))
CREATE INDEX [ix_term_candidate_evaluation] ON dbo.[term_code_candidates] ([evaluation_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_code_candidates') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='candidate_key'))
CREATE UNIQUE INDEX [ux_local_term_code_candidates_candidate_key] ON dbo.[term_code_candidates] ([candidate_key]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.term_code_candidates') AND referenced_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND COL_NAME(parent_object_id,parent_column_id)='evaluation_id' AND COL_NAME(referenced_object_id,referenced_column_id)='evaluation_id')
ALTER TABLE dbo.[term_code_candidates] WITH CHECK ADD CONSTRAINT [fk_local_term_code_candidates_evaluation_id_term_lookup_evaluations] FOREIGN KEY ([evaluation_id]) REFERENCES dbo.[term_lookup_evaluations] ([evaluation_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_review_decisions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='target_key') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='decision_id'))
CREATE INDEX [ix_term_review_target] ON dbo.[term_review_decisions] ([target_key],[decision_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.term_review_decisions') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND i.is_unique=1 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='decision_key'))
CREATE UNIQUE INDEX [ux_local_term_review_decisions_decision_key] ON dbo.[term_review_decisions] ([decision_key]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_site_hints') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='c_code'))
CREATE INDEX [ix_page_site_hints_code] ON dbo.[page_site_hints] ([c_code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_site_hints') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_site_hints_page] ON dbo.[page_site_hints] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_site_hints') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_site_hints] WITH CHECK ADD CONSTRAINT [fk_local_page_site_hints_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_entity_evidence') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_page_entity_evidence_TermNormUS] ON dbo.[page_entity_evidence] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_entity_evidence') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermNormUS'))
CREATE INDEX [ix_page_entity_evidence_TermNorm] ON dbo.[page_entity_evidence] ([TermNormUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_entity_evidence') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='TermUS'))
CREATE INDEX [ix_page_entity_evidence_TermUS] ON dbo.[page_entity_evidence] ([TermUS]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_entity_evidence') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='page_id'))
CREATE INDEX [ix_page_entity_evidence_page] ON dbo.[page_entity_evidence] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID('dbo.page_entity_evidence') AND i.type IN (1,2) AND i.is_disabled=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND ic.is_descending_key=0 AND c.name='term_clean') AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND ic.is_descending_key=0 AND c.name='icdo_code'))
CREATE INDEX [ix_page_entity_evidence_term] ON dbo.[page_entity_evidence] ([term_clean],[icdo_code]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_entity_evidence') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_entity_evidence] WITH CHECK ADD CONSTRAINT [fk_local_page_entity_evidence_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_search_documents') AND referenced_object_id=OBJECT_ID('dbo.books') AND COL_NAME(parent_object_id,parent_column_id)='book_id' AND COL_NAME(referenced_object_id,referenced_column_id)='book_id')
ALTER TABLE dbo.[page_search_documents] WITH CHECK ADD CONSTRAINT [fk_local_page_search_documents_book_id_books] FOREIGN KEY ([book_id]) REFERENCES dbo.[books] ([book_id]);
GO
IF NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id=OBJECT_ID('dbo.page_search_documents') AND referenced_object_id=OBJECT_ID('dbo.pages') AND COL_NAME(parent_object_id,parent_column_id)='page_id' AND COL_NAME(referenced_object_id,referenced_column_id)='page_id')
ALTER TABLE dbo.[page_search_documents] WITH CHECK ADD CONSTRAINT [fk_local_page_search_documents_page_id_pages] FOREIGN KEY ([page_id]) REFERENCES dbo.[pages] ([page_id]);
GO
CREATE OR ALTER VIEW dbo.v_search AS
SELECT s.section_id,s.page_id,s.heading,s.body_text,p.title,p.page_type,p.url,p.book_id,
b.title AS book_title,b.edition FROM dbo.sections s JOIN dbo.pages p ON p.page_id=s.page_id
JOIN dbo.books b ON b.book_id=p.book_id;
GO
/* ===========================================================================
   00_dbo_Clean.sql

   The corrected dbo.Clean scalar UDF (regenerated 2026-07-09), included here so
   the SQL Server folder is self-contained. This is the AUTHORITATIVE source of
   truth for the normalization logic; python/clean_term.py mirrors it 1:1.

   Deploy this first, then 01_deploy_clean.sql (indexed key column), then use
   the recipes in 02_search_examples.sql.

   NOTE: paste of the maintainer's deployed function body. If you edit it,
   re-mirror the change in python/clean_term.py and re-run tests/test_parity.py.
   =========================================================================== */
CREATE OR ALTER FUNCTION [dbo].[Clean]
(
    @StringIn NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @StringIn IS NULL RETURN NULL;
    IF TRIM(@StringIn) = '' RETURN '';

    DECLARE @StringOut NVARCHAR(MAX) = @StringIn;

    SELECT @StringOut = REPLACE(@StringOut, NCHAR(160), ' ');
    SELECT @StringOut = REPLACE(@StringOut, '/', ' ');

    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x200B), '');   -- zero-width space
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x00AD), '');   -- soft hyphen
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0xFEFF), '');   -- zero-width no-break space

    SELECT @StringOut = REPLACE(@StringOut, ',', '');
    SELECT @StringOut = TRIM(LEADING '+' FROM @StringOut);
    SELECT @StringOut = TRIM(LEADING '?' FROM @StringOut);
    SELECT @StringOut = REPLACE(@StringOut, '#', '');

    -- FIX 1: dashes -> space BEFORE the NOS/type removals
    SELECT @StringOut = REPLACE(@StringOut, '-', ' ');
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x2013), ' ');  -- en dash
    SELECT @StringOut = REPLACE(@StringOut, NCHAR(0x2014), ' ');  -- em dash

    WHILE CHARINDEX('  ', @StringOut) > 0
        SELECT @StringOut = REPLACE(@StringOut, '  ', ' ');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' NOS', '');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' (NOS)', '');

    -- grade <roman> -> grade <digit>
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade III' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-3) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade II' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-2) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% grade I'  SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-1) + '1';

    -- FIX 2: type <roman> -> <digit> (drop word 'type')
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type III' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-8) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type II' SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-7) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '% type I'  SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-6) + '1';

    -- FIX 3: ACRONYM <roman> -> ACRONYM <digit>
    IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] III'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-3) + '3';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] II'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-2) + '2';
    ELSE IF @StringOut COLLATE Latin1_General_100_BIN2 LIKE '%[A-Z][A-Z] I'
        SELECT @StringOut = LEFT(@StringOut, LEN(@StringOut)-1) + '1';

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, ' type', '');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'non ', 'non');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Non ', 'Non');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Naev', 'Nev');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'naev', 'nev');

    -- FIX 4: British -> American, case-preserving
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Tumour', 'Tumor');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'tumour', 'tumor');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Colour', 'Color');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'colour', 'color');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Grey', 'Gray');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'grey', 'gray');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Mould', 'Mold');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'mould', 'mold');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, 'of the ', 'of ');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'aem', 'em');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Aem', 'Em');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'paed', 'ped');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Paed', 'Ped');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'paen', 'pen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Paen', 'Pen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'phaeo', 'pheo');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Phaeo', 'Pheo');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'melaen', 'melen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Melaen', 'Melen');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Goitre', 'Goiter');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'goitre', 'goiter');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Centre', 'Center');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'centre', 'center');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oedema', 'Edema');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oedema', 'edema');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oesophag', 'Esophag');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oesophag', 'esophag');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Coeli', 'Celi');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'coeli', 'celi');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'rhoea', 'rhea');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Oestr', 'Estr');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'oestr', 'estr');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'Foet', 'Fet');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_CS_AS, 'foet', 'fet');

    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, '''s', '');
    SELECT @StringOut = REPLACE(@StringOut COLLATE Latin1_General_100_BIN2, NCHAR(0x2019) + 's', '');

    SELECT @StringOut = SUBSTRING(@StringOut, 1, (CHARINDEX('(specify', @StringOut COLLATE Latin1_General_100_BIN2, 1) - 1))
        WHERE CHARINDEX('(specify', @StringOut COLLATE Latin1_General_100_BIN2, 1) > 0;

    WHILE CHARINDEX('  ', @StringOut) > 0
        SELECT @StringOut = REPLACE(@StringOut, '  ', ' ');
    SELECT @StringOut = TRIM(@StringOut);

    RETURN @StringOut;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF OBJECT_ID('dbo.CleanDisplayTerm','FN') IS NOT NULL
 EXEC(N'CREATE OR ALTER FUNCTION dbo.CleanDisplayTerm(@s NVARCHAR(4000)) RETURNS NVARCHAR(4000) AS BEGIN RETURN dbo.UpperInitial(dbo.CleanTermEnding(@s)); END');
GO
CREATE OR ALTER FUNCTION dbo.CleanBritishSpelling2(@StringIn NVARCHAR(4000))
RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS
BEGIN
 DECLARE @s NVARCHAR(4000)=@StringIn;
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8203),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8204),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8205),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8288),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(65279),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(173),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8206),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8207),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8234),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8235),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8236),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8237),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8238),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8294),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8295),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8296),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8297),N'');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(9),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(10),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(13),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(160),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8194),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8195),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8196),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8197),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8198),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8199),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8200),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8201),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8202),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8239),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8287),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(12288),N' ');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8208),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8209),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8210),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8211),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8212),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(8213),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(65112),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(65123),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(65293),N'-');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(223),NCHAR(946));
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(230),N'ae');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(198),N'Ae');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(339),N'oe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,NCHAR(338),N'Oe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'naev',N'nev');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Naev',N'Nev');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'NAEV',N'NEV');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'grey',N'gray');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Grey',N'Gray');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'GREY',N'GRAY');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'oesophag',N'esophag');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Oesophag',N'Esophag');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'OESOPHAG',N'ESOPHAG');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'oestr',N'estr');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Oestr',N'Estr');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'OESTR',N'ESTR');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'foet',N'fet');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Foet',N'Fet');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'FOET',N'FET');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'coeli',N'celi');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Coeli',N'Celi');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'COELI',N'CELI');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'oedema',N'edema');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Oedema',N'Edema');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'OEDEMA',N'EDEMA');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'apnoea',N'apnea');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Apnoea',N'Apnea');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'APNOEA',N'APNEA');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'dyspnoea',N'dyspnea');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Dyspnoea',N'Dyspnea');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'DYSPNOEA',N'DYSPNEA');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'rhoe',N'rhe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Rhoe',N'Rhe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'RHOE',N'RHE');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'gynaec',N'gynec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Gynaec',N'Gynec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'GYNAEC',N'GYNEC');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'caec',N'cec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Caec',N'Cec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'CAEC',N'CEC');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'faec',N'fec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Faec',N'Fec');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'FAEC',N'FEC');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'melaen',N'melen');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Melaen',N'Melen');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'MELAEN',N'MELEN');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'orthopaed',N'orthoped');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Orthopaed',N'Orthoped');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'ORTHOPAED',N'ORTHOPED');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'paed',N'ped');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Paed',N'Ped');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'PAED',N'PED');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'aem',N'em');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Aem',N'Em');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'AEM',N'EM');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'paen',N'pen');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Paen',N'Pen');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'PAEN',N'PEN');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'umour',N'umor');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Umour',N'Umor');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'UMOUR',N'UMOR');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'centre',N'center');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Centre',N'Center');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'CENTRE',N'CENTER');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'phaeo',N'pheo');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Phaeo',N'Pheo');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'PHAEO',N'PHEO');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'goitre',N'goiter');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Goitre',N'Goiter');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'GOITRE',N'GOITER');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'mould',N'mold');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Mould',N'Mold');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'MOULD',N'MOLD');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'fibre',N'fiber');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Fibre',N'Fiber');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'FIBRE',N'FIBER');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'sulph',N'sulf');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Sulph',N'Sulf');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'SULPH',N'SULF');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'ischaem',N'ischem');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Ischaem',N'Ischem');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'ISCHAEM',N'ISCHEM');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'anaesth',N'anesth');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Anaesth',N'Anesth');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'ANAESTH',N'ANESTH');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'catalogu',N'catalog');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Catalogu',N'Catalog');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'CATALOGU',N'CATALOG');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'morphoe',N'morphe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Morphoe',N'Morphe');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'MORPHOE',N'MORPHE');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'metre',N'meter');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Metre',N'Meter');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'METRE',N'METER');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'colour',N'color');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Colour',N'Color');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'COLOUR',N'COLOR');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'haviour',N'havior');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'Haviour',N'Havior');
 SET @s=REPLACE(@s COLLATE Latin1_General_100_BIN2,N'HAVIOUR',N'HAVIOR');
 SET @s=REPLACE(@s,NCHAR(7),N'');
 SET @s=REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2,N' ',N' '+NCHAR(7)),NCHAR(7)+N' ',N''),NCHAR(7),N'');
 RETURN TRIM(@s);
END
GO
CREATE OR ALTER FUNCTION dbo.CleanTermEnding(@value NVARCHAR(4000))
RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS
BEGIN
 DECLARE @s NVARCHAR(4000)=@value;
 WHILE DATALENGTH(@s)>0 AND UNICODE(RIGHT(@s,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,8224,8225,167,182,42,46,59,58)
  SET @s=LEFT(@s,DATALENGTH(@s)/2-1);
 IF CHARINDEX(N'[[',@s COLLATE Latin1_General_100_BIN2)>0
  SET @s=LEFT(@s,CHARINDEX(N'[[',@s COLLATE Latin1_General_100_BIN2)-1);
 DECLARE @pos INT=CHARINDEX(N'(',@s), @start INT;
 WHILE @pos>0
 BEGIN
  SET @start=@pos+1;
  WHILE UNICODE(SUBSTRING(@s,@start,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) SET @start=@start+1;
  IF LOWER(SUBSTRING(@s,@start,3)) COLLATE Latin1_General_100_BIN2=N'see'
   AND (SUBSTRING(@s,@start+3,1)=N'' OR UNICODE(SUBSTRING(@s,@start+3,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) OR SUBSTRING(@s,@start+3,1) IN (N'.',N':',N',',N';',N')'))
  BEGIN SET @s=LEFT(@s,@pos-1); BREAK; END;
  SET @pos=CHARINDEX(N'(',@s,@pos+1);
 END;
 DECLARE @tail INT=DATALENGTH(@s)/2;
 WHILE UNICODE(SUBSTRING(@s,@tail,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) SET @tail=@tail-1;
 IF SUBSTRING(@s,@tail-1,2)=N'>>'
 BEGIN
  SET @pos=CHARINDEX(N'<<',@s);
  WHILE @pos>0
  BEGIN
   SET @start=@pos+2;
   WHILE UNICODE(SUBSTRING(@s,@start,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) SET @start=@start+1;
   IF LOWER(SUBSTRING(@s,@start,3)) COLLATE Latin1_General_100_BIN2=N'see'
    AND (SUBSTRING(@s,@start+3,1)=N'' OR UNICODE(SUBSTRING(@s,@start+3,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) OR SUBSTRING(@s,@start+3,1) IN (N'.',N':',N',',N';',N'>'))
   BEGIN SET @s=LEFT(@s,@pos-1); BREAK; END;
   SET @pos=CHARINDEX(N'<<',@s,@pos+1);
  END;
 END;
 WHILE LEN(@s)>0 AND UNICODE(LEFT(@s,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288)
  SET @s=SUBSTRING(@s,2,4000);
 IF LEFT(@s,1)=N'*' AND UNICODE(SUBSTRING(@s,2,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) SET @s=SUBSTRING(@s,2,4000);
 IF UNICODE(LEFT(@s,1))=8226 SET @s=SUBSTRING(@s,2,4000);
 WHILE LEN(@s)>0 AND UNICODE(LEFT(@s,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288) SET @s=SUBSTRING(@s,2,4000);
 WHILE DATALENGTH(@s)>0 AND UNICODE(RIGHT(@s,1)) IN (9,10,11,12,13,28,29,30,31,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,8224,8225,167,182,42,46,59,58)
  SET @s=LEFT(@s,DATALENGTH(@s)/2-1);
 RETURN TRIM(@s);
END
GO
CREATE OR ALTER FUNCTION dbo.UpperInitial(@s NVARCHAR(4000))
RETURNS NVARCHAR(4000) WITH SCHEMABINDING AS
BEGIN
 RETURN CASE WHEN UNICODE(LEFT(@s,1)) BETWEEN 97 AND 122 THEN NCHAR(UNICODE(LEFT(@s,1))-32)+SUBSTRING(@s,2,4000) ELSE @s END;
END
GO
CREATE OR ALTER FUNCTION dbo.CleanDisplayTerm(@s NVARCHAR(4000))
RETURNS NVARCHAR(4000) AS
BEGIN
 RETURN dbo.UpperInitial(dbo.CleanTermEnding(@s));
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [dbo].[Clean2]
-- =============================================
-- Author:      Moldwin, Richard
-- Version:     3.0.2 (2026-10-08). Check with SELECT dbo.Clean2Version().
-- Create Date: 2026 Sep 28. Successor to dbo.Clean (2022 Aug 29 ... 2026-07-09).
--              GENERATED from clean2.py - edit the rules there and regenerate,
--              so SQL and Python stay identical.
-- Description: Comparison-key normalizer. Use as
--                  dbo.Clean2(dbo.CleanBritishSpelling2(Term))
--              Drops commas, NOS and the word 'type'; '/' and dashes become
--              spaces ('::' too); grade/type/acronym Roman numerals become
--              digits; 'non X' and bound prefixes (micro, pre, ...) join;
--              every minus sign is kept and written as U+2212 MINUS SIGN ('ALK-)', '5q-)');
--              karyotypes closed up ('del(5q)');
--              possessive 's dropped. Never changes letter case. Word rules
--              match whole words only. Not display text.
--   v3:        lowercase articles the/a/an removed (case-sensitive, guarded);
--              numerals before ';' ':'; no space before ';' ':'; trailing ';' ':'
--              dropped; 'pre-pre-B' -> 'prepreB'; Greek letters -> names;
--              '&' -> 'and'; double/special quotes -> straight single quote.
--
--   vs dbo.Clean:  no British spelling (it lives in CleanBritishSpelling2);
--   special characters from the same tables as CleanBritishSpelling2;
--   exact case-sensitive matching (BIN2) throughout; whole-word NOS/type/non,
--   so 'nose', 'types' and 'Canon' are safe; numerals also at the end of a
--   closing parenthetical, plus grade/type IV; apostrophe look-alikes; a
--   trailing period dropped. No loops, a single RETURN, every statement but
--   the first reads @s once, and consecutive replacements are nested into
--   few statements - so SQL Server actually inlines it.
-- =============================================
--
--   NVARCHAR(4000), not MAX: MAX strings are handled as large objects, and with
--   ~370 replacements per call that made Clean2 ~10x slower (3.7 s vs 0.4 s for
--   the 5,709 terms of CPC_MorphCodeList_2026Jul28). Terms are nvarchar(255).
--   An input longer than 4,000 characters would be truncated.
(
    @StringIn NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
WITH SCHEMABINDING
AS
BEGIN
    -- A variable does not keep a collation, so every comparison below names
    -- BIN2 explicitly: exact code points, case-sensitive, no linguistic
    -- expansions (under a linguistic collation 'ß' matches 'ss').
    -- NULL flows through every step as NULL; there is a single RETURN.
    DECLARE @s NVARCHAR(4000) = @StringIn;

    -- 0. Everything from '(specify' onward is dropped (as dbo.Clean). First, because it is the one step that must read the string twice - done here it costs nothing
    SET @s = REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(Specify', N'(specify')
        , N'(SPECIFY', N'(specify');
    SET @s = LEFT(@s, CHARINDEX(N'(specify', (@s + N'(specify') COLLATE Latin1_General_100_BIN2) - 1);

    -- 1. Special characters - the SAME tables as dbo.CleanBritishSpelling2
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8203), N'')  -- U+200B ZERO WIDTH SPACE
        , NCHAR(8204), N'')  -- U+200C ZERO WIDTH NON-JOINER
        , NCHAR(8205), N'')  -- U+200D ZERO WIDTH JOINER
        , NCHAR(8288), N'')  -- U+2060 WORD JOINER
        , NCHAR(65279), N'')  -- U+FEFF ZERO WIDTH NO-BREAK SPACE
        , NCHAR(173), N'')  -- U+00AD SOFT HYPHEN
        , NCHAR(8206), N'')  -- U+200E LEFT-TO-RIGHT MARK
        , NCHAR(8207), N'')  -- U+200F RIGHT-TO-LEFT MARK
        , NCHAR(8234), N'')  -- U+202A LEFT-TO-RIGHT EMBEDDING
        , NCHAR(8235), N'')  -- U+202B RIGHT-TO-LEFT EMBEDDING
        , NCHAR(8236), N'')  -- U+202C POP DIRECTIONAL FORMATTING
        , NCHAR(8237), N'')  -- U+202D LEFT-TO-RIGHT OVERRIDE
        , NCHAR(8238), N'')  -- U+202E RIGHT-TO-LEFT OVERRIDE
        , NCHAR(8294), N'')  -- U+2066 LEFT-TO-RIGHT ISOLATE
        , NCHAR(8295), N'')  -- U+2067 RIGHT-TO-LEFT ISOLATE
        , NCHAR(8296), N'')  -- U+2068 FIRST STRONG ISOLATE
        , NCHAR(8297), N'')  -- U+2069 POP DIRECTIONAL ISOLATE
        , NCHAR(9), N' ')  -- U+0009 CHARACTER TABULATION
        , NCHAR(10), N' ')  -- U+000A LINE FEED
        , NCHAR(13), N' ')  -- U+000D CARRIAGE RETURN
        , NCHAR(160), N' ')  -- U+00A0 NO-BREAK SPACE
        , NCHAR(8194), N' ')  -- U+2002 EN SPACE
        , NCHAR(8195), N' ')  -- U+2003 EM SPACE
        , NCHAR(8196), N' ')  -- U+2004 THREE-PER-EM SPACE
        , NCHAR(8197), N' ')  -- U+2005 FOUR-PER-EM SPACE
        , NCHAR(8198), N' ')  -- U+2006 SIX-PER-EM SPACE
        , NCHAR(8199), N' ')  -- U+2007 FIGURE SPACE
        , NCHAR(8200), N' ')  -- U+2008 PUNCTUATION SPACE
        , NCHAR(8201), N' ')  -- U+2009 THIN SPACE
        , NCHAR(8202), N' ');  -- U+200A HAIR SPACE
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8239), N' ')  -- U+202F NARROW NO-BREAK SPACE
        , NCHAR(8287), N' ')  -- U+205F MEDIUM MATHEMATICAL SPACE
        , NCHAR(12288), N' ')  -- U+3000 IDEOGRAPHIC SPACE
        , NCHAR(8208), N'-')  -- U+2010 HYPHEN
        , NCHAR(8209), N'-')  -- U+2011 NON-BREAKING HYPHEN
        , NCHAR(8210), N'-')  -- U+2012 FIGURE DASH
        , NCHAR(8211), N'-')  -- U+2013 EN DASH
        , NCHAR(8212), N'-')  -- U+2014 EM DASH
        , NCHAR(8213), N'-')  -- U+2015 HORIZONTAL BAR
        , NCHAR(65112), N'-')  -- U+FE58 SMALL EM DASH
        , NCHAR(65123), N'-')  -- U+FE63 SMALL HYPHEN-MINUS
        , NCHAR(65293), N'-')  -- U+FF0D FULLWIDTH HYPHEN-MINUS
        , NCHAR(223), NCHAR(946))  -- U+00DF LATIN SMALL LETTER SHARP S, U+03B2 GREEK SMALL LETTER BETA
        , NCHAR(230), N'ae')  -- U+00E6 LATIN SMALL LETTER AE
        , NCHAR(198), N'Ae')  -- U+00C6 LATIN CAPITAL LETTER AE
        , NCHAR(339), N'oe')  -- U+0153 LATIN SMALL LIGATURE OE
        , NCHAR(338), N'Oe');  -- U+0152 LATIN CAPITAL LIGATURE OE

    -- 2. Remaining control characters removed (so the sentinels and markers used in steps 6 and 9e cannot occur in the input)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(1), N'')  -- U+0001 control character
        , NCHAR(2), N'')  -- U+0002 start sentinel
        , NCHAR(3), N'')  -- U+0003 end sentinel
        , NCHAR(4), N'')  -- U+0004 control character
        , NCHAR(5), N'')  -- U+0005 control character
        , NCHAR(6), N'')  -- U+0006 control character
        , NCHAR(7), N'')  -- U+0007 BELL
        , NCHAR(8), N'')  -- U+0008 control character
        , NCHAR(11), N'')  -- U+000B control character
        , NCHAR(12), N'')  -- U+000C control character
        , NCHAR(14), N'')  -- U+000E control character
        , NCHAR(15), N'')  -- U+000F control character
        , NCHAR(16), N'')  -- U+0010 control character
        , NCHAR(17), N'')  -- U+0011 control character
        , NCHAR(18), N'')  -- U+0012 control character
        , NCHAR(19), N'')  -- U+0013 control character
        , NCHAR(20), N'')  -- U+0014 control character
        , NCHAR(21), N'')  -- U+0015 control character
        , NCHAR(22), N'')  -- U+0016 control character
        , NCHAR(23), N'')  -- U+0017 control character
        , NCHAR(24), N'')  -- U+0018 control character
        , NCHAR(25), N'')  -- U+0019 control character
        , NCHAR(26), N'')  -- U+001A control character
        , NCHAR(27), N'')  -- U+001B control character
        , NCHAR(28), N'')  -- U+001C control character
        , NCHAR(29), N'')  -- U+001D control character
        , NCHAR(30), N'')  -- U+001E control character
        , NCHAR(31), N'')  -- U+001F control character
        , NCHAR(127), N'');  -- U+007F control character

    -- 3. Apostrophe look-alikes, and (v3 R8) double and other special quotation marks, read as the ASCII apostrophe / straight single quote
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8217), N'''')  -- U+2019 RIGHT SINGLE QUOTATION MARK
        , NCHAR(8216), N'''')  -- U+2018 LEFT SINGLE QUOTATION MARK
        , NCHAR(8219), N'''')  -- U+201B SINGLE HIGH-REVERSED-9 QUOTATION MARK
        , NCHAR(700), N'''')  -- U+02BC MODIFIER LETTER APOSTROPHE
        , NCHAR(697), N'''')  -- U+02B9 MODIFIER LETTER PRIME
        , N'`', N'''')
        , NCHAR(180), N'''')  -- U+00B4 ACUTE ACCENT
        , NCHAR(8242), N'''')  -- U+2032 PRIME
        , NCHAR(65287), N'''')  -- U+FF07 FULLWIDTH APOSTROPHE
        , N'"', N'''')
        , NCHAR(8220), N'''')  -- U+201C LEFT DOUBLE QUOTATION MARK
        , NCHAR(8221), N'''')  -- U+201D RIGHT DOUBLE QUOTATION MARK
        , NCHAR(8222), N'''')  -- U+201E DOUBLE LOW-9 QUOTATION MARK
        , NCHAR(8223), N'''')  -- U+201F DOUBLE HIGH-REVERSED-9 QUOTATION MARK
        , NCHAR(8218), N'''')  -- U+201A SINGLE LOW-9 QUOTATION MARK
        , NCHAR(171), N'''')  -- U+00AB LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
        , NCHAR(187), N'''')  -- U+00BB RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
        , NCHAR(8249), N'''')  -- U+2039 SINGLE LEFT-POINTING ANGLE QUOTATION MARK
        , NCHAR(8250), N'''')  -- U+203A SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
        , NCHAR(12317), N'''')  -- U+301D REVERSED DOUBLE PRIME QUOTATION MARK
        , NCHAR(12318), N'''')  -- U+301E DOUBLE PRIME QUOTATION MARK
        , NCHAR(12319), N'''')  -- U+301F LOW DOUBLE PRIME QUOTATION MARK
        , NCHAR(65282), N'''');  -- U+FF02 FULLWIDTH QUOTATION MARK

    -- 3b. (v3 R6) Greek letters written as their names, a space on each side: 'β-catenin' = 'beta-catenin', 'γδ' = 'gamma-delta'. The extra spaces are collapsed in step 5
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(945), N' alpha ')  -- U+03B1 GREEK SMALL LETTER ALPHA
        , NCHAR(913), N' Alpha ')  -- U+0391 GREEK CAPITAL LETTER ALPHA
        , NCHAR(946), N' beta ')  -- U+03B2 GREEK SMALL LETTER BETA
        , NCHAR(914), N' Beta ')  -- U+0392 GREEK CAPITAL LETTER BETA
        , NCHAR(947), N' gamma ')  -- U+03B3 GREEK SMALL LETTER GAMMA
        , NCHAR(915), N' Gamma ')  -- U+0393 GREEK CAPITAL LETTER GAMMA
        , NCHAR(948), N' delta ')  -- U+03B4 GREEK SMALL LETTER DELTA
        , NCHAR(916), N' Delta ')  -- U+0394 GREEK CAPITAL LETTER DELTA
        , NCHAR(949), N' epsilon ')  -- U+03B5 GREEK SMALL LETTER EPSILON
        , NCHAR(917), N' Epsilon ')  -- U+0395 GREEK CAPITAL LETTER EPSILON
        , NCHAR(950), N' zeta ')  -- U+03B6 GREEK SMALL LETTER ZETA
        , NCHAR(918), N' Zeta ')  -- U+0396 GREEK CAPITAL LETTER ZETA
        , NCHAR(951), N' eta ')  -- U+03B7 GREEK SMALL LETTER ETA
        , NCHAR(919), N' Eta ')  -- U+0397 GREEK CAPITAL LETTER ETA
        , NCHAR(952), N' theta ')  -- U+03B8 GREEK SMALL LETTER THETA
        , NCHAR(920), N' Theta ')  -- U+0398 GREEK CAPITAL LETTER THETA
        , NCHAR(953), N' iota ')  -- U+03B9 GREEK SMALL LETTER IOTA
        , NCHAR(921), N' Iota ')  -- U+0399 GREEK CAPITAL LETTER IOTA
        , NCHAR(954), N' kappa ')  -- U+03BA GREEK SMALL LETTER KAPPA
        , NCHAR(922), N' Kappa ')  -- U+039A GREEK CAPITAL LETTER KAPPA
        , NCHAR(955), N' lambda ')  -- U+03BB GREEK SMALL LETTER LAMDA
        , NCHAR(923), N' Lambda ')  -- U+039B GREEK CAPITAL LETTER LAMDA
        , NCHAR(956), N' mu ')  -- U+03BC GREEK SMALL LETTER MU
        , NCHAR(924), N' Mu ')  -- U+039C GREEK CAPITAL LETTER MU
        , NCHAR(957), N' nu ')  -- U+03BD GREEK SMALL LETTER NU
        , NCHAR(925), N' Nu ')  -- U+039D GREEK CAPITAL LETTER NU
        , NCHAR(958), N' xi ')  -- U+03BE GREEK SMALL LETTER XI
        , NCHAR(926), N' Xi ')  -- U+039E GREEK CAPITAL LETTER XI
        , NCHAR(959), N' omicron ')  -- U+03BF GREEK SMALL LETTER OMICRON
        , NCHAR(927), N' Omicron ');  -- U+039F GREEK CAPITAL LETTER OMICRON
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(960), N' pi ')  -- U+03C0 GREEK SMALL LETTER PI
        , NCHAR(928), N' Pi ')  -- U+03A0 GREEK CAPITAL LETTER PI
        , NCHAR(961), N' rho ')  -- U+03C1 GREEK SMALL LETTER RHO
        , NCHAR(929), N' Rho ')  -- U+03A1 GREEK CAPITAL LETTER RHO
        , NCHAR(962), N' sigma ')  -- U+03C2 GREEK SMALL LETTER FINAL SIGMA
        , NCHAR(963), N' sigma ')  -- U+03C3 GREEK SMALL LETTER SIGMA
        , NCHAR(931), N' Sigma ')  -- U+03A3 GREEK CAPITAL LETTER SIGMA
        , NCHAR(964), N' tau ')  -- U+03C4 GREEK SMALL LETTER TAU
        , NCHAR(932), N' Tau ')  -- U+03A4 GREEK CAPITAL LETTER TAU
        , NCHAR(965), N' upsilon ')  -- U+03C5 GREEK SMALL LETTER UPSILON
        , NCHAR(933), N' Upsilon ')  -- U+03A5 GREEK CAPITAL LETTER UPSILON
        , NCHAR(966), N' phi ')  -- U+03C6 GREEK SMALL LETTER PHI
        , NCHAR(934), N' Phi ')  -- U+03A6 GREEK CAPITAL LETTER PHI
        , NCHAR(967), N' chi ')  -- U+03C7 GREEK SMALL LETTER CHI
        , NCHAR(935), N' Chi ')  -- U+03A7 GREEK CAPITAL LETTER CHI
        , NCHAR(968), N' psi ')  -- U+03C8 GREEK SMALL LETTER PSI
        , NCHAR(936), N' Psi ')  -- U+03A8 GREEK CAPITAL LETTER PSI
        , NCHAR(969), N' omega ')  -- U+03C9 GREEK SMALL LETTER OMEGA
        , NCHAR(937), N' Omega ');  -- U+03A9 GREEK CAPITAL LETTER OMEGA

    -- 3c. (v3 R7) '&' -> 'and'
    SET @s = REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'&', N' and ');

    -- 4. Punctuation: commas and '#' removed; '::' (gene fusion), '/' and '-' become spaces (every other dash is already '-'), except a minus sign - U+2212 anywhere, or '-' right before ')' - which is kept ('CD34− tumor', 'ALK-)', '5q-)'); a space is put before every '(' (karyotypes are closed up again in step 6b)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N',', N'')
        , N'#', N'')
        , N'::', N' ')
        , N'/', N' ')
        , NCHAR(8722), NCHAR(14))  -- U+2212 MINUS SIGN, U+000E control character
        , N'-)', NCHAR(14) + N')')  -- U+000E control character
        , N'-', N' ')
        , N'(', N' (');

    -- 5. Tidy the ends: collapse spaces, trim, leading '+'/'?' (as dbo.Clean), trailing '.'
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = LTRIM(@s, N'+? ');
    SET @s = RTRIM(@s, N'. ');

    -- 6. Mark the start and end with sentinels U+0002 / U+0003 so a word at either end has a boundary to match against
    SET @s = NCHAR(2) + @s + NCHAR(3);  -- U+0002 start sentinel, U+0003 end sentinel

    -- 6b. Karyotype notation closed up again: 't (9;22)' 'del (5q)' -> 't(9;22)' 'del(5q)'; and ') (p' / ') (q' -> ')(p' / ')(q': 'inv(16) (p13;q22)' -> 'inv(16)(p13;q22)'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' t (', N' t(')
        , N'(t (', N'(t(')
        , N'+t (', N'+t(')
        , N';t (', N';t(')
        , NCHAR(2) + N't (', NCHAR(2) + N't(')  -- U+0002 start sentinel
        , N' inv (', N' inv(')
        , N'(inv (', N'(inv(')
        , N'+inv (', N'+inv(')
        , N';inv (', N';inv(')
        , NCHAR(2) + N'inv (', NCHAR(2) + N'inv(')  -- U+0002 start sentinel
        , N' del (', N' del(')
        , N'(del (', N'(del(')
        , N'+del (', N'+del(')
        , N';del (', N';del(')
        , NCHAR(2) + N'del (', NCHAR(2) + N'del(')  -- U+0002 start sentinel
        , N' der (', N' der(')
        , N'(der (', N'(der(')
        , N'+der (', N'+der(')
        , N';der (', N';der(')
        , NCHAR(2) + N'der (', NCHAR(2) + N'der(')  -- U+0002 start sentinel
        , N' dup (', N' dup(')
        , N'(dup (', N'(dup(')
        , N'+dup (', N'+dup(')
        , N';dup (', N';dup(')
        , NCHAR(2) + N'dup (', NCHAR(2) + N'dup(')  -- U+0002 start sentinel
        , N' ins (', N' ins(')
        , N'(ins (', N'(ins(')
        , N'+ins (', N'+ins(')
        , N';ins (', N';ins(')
        , NCHAR(2) + N'ins (', NCHAR(2) + N'ins(');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' i (', N' i(')
        , N'(i (', N'(i(')
        , N'+i (', N'+i(')
        , N';i (', N';i(')
        , NCHAR(2) + N'i (', NCHAR(2) + N'i(')  -- U+0002 start sentinel
        , N' add (', N' add(')
        , N'(add (', N'(add(')
        , N'+add (', N'+add(')
        , N';add (', N';add(')
        , NCHAR(2) + N'add (', NCHAR(2) + N'add(')  -- U+0002 start sentinel
        , N' idic (', N' idic(')
        , N'(idic (', N'(idic(')
        , N'+idic (', N'+idic(')
        , N';idic (', N';idic(')
        , NCHAR(2) + N'idic (', NCHAR(2) + N'idic(')  -- U+0002 start sentinel
        , N') (p', N')(p')
        , N') (q', N')(q');

    -- 7. Possessive 's dropped at a word end: "Paget's disease" = "Paget disease"
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'''s ', N' ')
        , N'''s)', N')')
        , N'''s]', N']')
        , N'''s}', N'}')
        , N'''s:', N':')
        , N'''s;', N';')
        , N'''s' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'''s ', N' ')
        , N'''s)', N')')
        , N'''s]', N']')
        , N'''s}', N'}')
        , N'''s:', N':')
        , N'''s;', N';')
        , N'''s' + NCHAR(3), NCHAR(3));  -- U+0003 end sentinel

    -- 8. NOS removed - uppercase whole word only (never inside adenosquamous, nose ...). Before the numerals, so 'CIN III, NOS' ends in its numeral
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' NOS ', N' ')
        , N' NOS)', N')')
        , N' NOS]', N']')
        , N' NOS}', N'}')
        , N' NOS:', N':')
        , N' NOS;', N';')
        , N' NOS' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(NOS ', N'(')
        , N'(NOS)', N'')
        , N'(NOS]', N'(]')
        , N'(NOS}', N'(}')
        , N'(NOS:', N'(:')
        , N'(NOS;', N'(;')
        , N'(NOS' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[NOS ', N'[')
        , N'[NOS)', N'[)')
        , N'[NOS]', N'')
        , N'[NOS}', N'[}')
        , N'[NOS:', N'[:')
        , N'[NOS;', N'[;')
        , N'[NOS' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{NOS ', N'{')
        , N'{NOS)', N'{)')
        , N'{NOS]', N'{]')
        , N'{NOS}', N'')
        , N'{NOS:', N'{:')
        , N'{NOS;', N'{;')
        , N'{NOS' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':NOS ', N':')
        , N':NOS)', N':)');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':NOS]', N':]')
        , N':NOS}', N':}')
        , N':NOS:', N'::')
        , N':NOS;', N':;')
        , N':NOS' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';NOS ', N';')
        , N';NOS)', N';)')
        , N';NOS]', N';]')
        , N';NOS}', N';}')
        , N';NOS:', N';:')
        , N';NOS;', N';;')
        , N';NOS' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N'NOS ', NCHAR(2))  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS)', NCHAR(2) + N')')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS]', NCHAR(2) + N']')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS}', NCHAR(2) + N'}')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS:', NCHAR(2) + N':')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS;', NCHAR(2) + N';')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS' + NCHAR(3), NCHAR(2) + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , N' NOS ', N' ')
        , N' NOS)', N')')
        , N' NOS]', N']')
        , N' NOS}', N'}')
        , N' NOS:', N':')
        , N' NOS;', N';')
        , N' NOS' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(NOS ', N'(')
        , N'(NOS)', N'')
        , N'(NOS]', N'(]')
        , N'(NOS}', N'(}');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(NOS:', N'(:')
        , N'(NOS;', N'(;')
        , N'(NOS' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[NOS ', N'[')
        , N'[NOS)', N'[)')
        , N'[NOS]', N'')
        , N'[NOS}', N'[}')
        , N'[NOS:', N'[:')
        , N'[NOS;', N'[;')
        , N'[NOS' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{NOS ', N'{')
        , N'{NOS)', N'{)')
        , N'{NOS]', N'{]')
        , N'{NOS}', N'')
        , N'{NOS:', N'{:')
        , N'{NOS;', N'{;')
        , N'{NOS' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':NOS ', N':')
        , N':NOS)', N':)')
        , N':NOS]', N':]')
        , N':NOS}', N':}')
        , N':NOS:', N'::')
        , N':NOS;', N':;')
        , N':NOS' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';NOS ', N';')
        , N';NOS)', N';)')
        , N';NOS]', N';]')
        , N';NOS}', N';}')
        , N';NOS:', N';:')
        , N';NOS;', N';;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';NOS' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N'NOS ', NCHAR(2))  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS)', NCHAR(2) + N')')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS]', NCHAR(2) + N']')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS}', NCHAR(2) + N'}')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS:', NCHAR(2) + N':')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS;', NCHAR(2) + N';')  -- U+0002 start sentinel
        , NCHAR(2) + N'NOS' + NCHAR(3), NCHAR(2) + NCHAR(3));  -- U+0002 start sentinel, U+0003 end sentinel

    -- 8b. Close up the space a removal can leave next to the start/end sentinel, so a numeral exposed by it is still recognised as trailing
    SET @s = REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , NCHAR(2) + N' ', NCHAR(2));  -- U+0002 start sentinel
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 8c. (v3 R1) Articles: lowercase whole words 'the', 'a', 'an' removed - never the first or last word, and 'a'/'an' kept after a label word ('type a', 'hepatitis a'). Case-sensitive: 'A' (type A, group A) is never touched. Before step 9, so 'type a' is still recognisable
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'type a ', N'type ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'type a)', N'type ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'type a;', N'type ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'type a:', N'type ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'type a' + NCHAR(3), N'type ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'type an ', N'type ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'type an)', N'type ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'type an;', N'type ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'type an:', N'type ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'type an' + NCHAR(3), N'type ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Type a ', N'Type ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Type a)', N'Type ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Type a;', N'Type ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Type a:', N'Type ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Type a' + NCHAR(3), N'Type ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Type an ', N'Type ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Type an)', N'Type ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Type an;', N'Type ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Type an:', N'Type ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Type an' + NCHAR(3), N'Type ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'group a ', N'group ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'group a)', N'group ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'group a;', N'group ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'group a:', N'group ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'group a' + NCHAR(3), N'group ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'group an ', N'group ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'group an)', N'group ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'group an;', N'group ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'group an:', N'group ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'group an' + NCHAR(3), N'group ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Group a ', N'Group ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Group a)', N'Group ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Group a;', N'Group ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Group a:', N'Group ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Group a' + NCHAR(3), N'Group ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Group an ', N'Group ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Group an)', N'Group ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Group an;', N'Group ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Group an:', N'Group ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Group an' + NCHAR(3), N'Group ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'grade a ', N'grade ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'grade a)', N'grade ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'grade a;', N'grade ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'grade a:', N'grade ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'grade a' + NCHAR(3), N'grade ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'grade an ', N'grade ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'grade an)', N'grade ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'grade an;', N'grade ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'grade an:', N'grade ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'grade an' + NCHAR(3), N'grade ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Grade a ', N'Grade ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Grade a)', N'Grade ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Grade a;', N'Grade ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Grade a:', N'Grade ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Grade a' + NCHAR(3), N'Grade ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Grade an ', N'Grade ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Grade an)', N'Grade ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Grade an;', N'Grade ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Grade an:', N'Grade ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Grade an' + NCHAR(3), N'Grade ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'class a ', N'class ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'class a)', N'class ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'class a;', N'class ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'class a:', N'class ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'class a' + NCHAR(3), N'class ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'class an ', N'class ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'class an)', N'class ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'class an;', N'class ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'class an:', N'class ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'class an' + NCHAR(3), N'class ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Class a ', N'Class ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Class a)', N'Class ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Class a;', N'Class ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Class a:', N'Class ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Class a' + NCHAR(3), N'Class ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Class an ', N'Class ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Class an)', N'Class ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Class an;', N'Class ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Class an:', N'Class ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Class an' + NCHAR(3), N'Class ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'subtype a ', N'subtype ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'subtype a)', N'subtype ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'subtype a;', N'subtype ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'subtype a:', N'subtype ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'subtype a' + NCHAR(3), N'subtype ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'subtype an ', N'subtype ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'subtype an)', N'subtype ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'subtype an;', N'subtype ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'subtype an:', N'subtype ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'subtype an' + NCHAR(3), N'subtype ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Subtype a ', N'Subtype ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Subtype a)', N'Subtype ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Subtype a;', N'Subtype ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Subtype a:', N'Subtype ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Subtype a' + NCHAR(3), N'Subtype ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Subtype an ', N'Subtype ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Subtype an)', N'Subtype ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Subtype an;', N'Subtype ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Subtype an:', N'Subtype ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Subtype an' + NCHAR(3), N'Subtype ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'pattern a ', N'pattern ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'pattern a)', N'pattern ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'pattern a;', N'pattern ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'pattern a:', N'pattern ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'pattern a' + NCHAR(3), N'pattern ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'pattern an ', N'pattern ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'pattern an)', N'pattern ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'pattern an;', N'pattern ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'pattern an:', N'pattern ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'pattern an' + NCHAR(3), N'pattern ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Pattern a ', N'Pattern ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Pattern a)', N'Pattern ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Pattern a;', N'Pattern ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Pattern a:', N'Pattern ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Pattern a' + NCHAR(3), N'Pattern ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Pattern an ', N'Pattern ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Pattern an)', N'Pattern ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Pattern an;', N'Pattern ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Pattern an:', N'Pattern ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Pattern an' + NCHAR(3), N'Pattern ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'variant a ', N'variant ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'variant a)', N'variant ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'variant a;', N'variant ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'variant a:', N'variant ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'variant a' + NCHAR(3), N'variant ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'variant an ', N'variant ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'variant an)', N'variant ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'variant an;', N'variant ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'variant an:', N'variant ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'variant an' + NCHAR(3), N'variant ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Variant a ', N'Variant ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Variant a)', N'Variant ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Variant a;', N'Variant ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Variant a:', N'Variant ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Variant a' + NCHAR(3), N'Variant ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Variant an ', N'Variant ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Variant an)', N'Variant ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Variant an;', N'Variant ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Variant an:', N'Variant ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Variant an' + NCHAR(3), N'Variant ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'form a ', N'form ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'form a)', N'form ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'form a;', N'form ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'form a:', N'form ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'form a' + NCHAR(3), N'form ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'form an ', N'form ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'form an)', N'form ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'form an;', N'form ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'form an:', N'form ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'form an' + NCHAR(3), N'form ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Form a ', N'Form ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Form a)', N'Form ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Form a;', N'Form ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Form a:', N'Form ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Form a' + NCHAR(3), N'Form ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Form an ', N'Form ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Form an)', N'Form ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Form an;', N'Form ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Form an:', N'Form ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Form an' + NCHAR(3), N'Form ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'hepatitis a ', N'hepatitis ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'hepatitis a)', N'hepatitis ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'hepatitis a;', N'hepatitis ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'hepatitis a:', N'hepatitis ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'hepatitis a' + NCHAR(3), N'hepatitis ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'hepatitis an ', N'hepatitis ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'hepatitis an)', N'hepatitis ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'hepatitis an;', N'hepatitis ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'hepatitis an:', N'hepatitis ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'hepatitis an' + NCHAR(3), N'hepatitis ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Hepatitis a ', N'Hepatitis ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Hepatitis a)', N'Hepatitis ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Hepatitis a;', N'Hepatitis ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Hepatitis a:', N'Hepatitis ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Hepatitis a' + NCHAR(3), N'Hepatitis ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Hepatitis an ', N'Hepatitis ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Hepatitis an)', N'Hepatitis ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Hepatitis an;', N'Hepatitis ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Hepatitis an:', N'Hepatitis ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Hepatitis an' + NCHAR(3), N'Hepatitis ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'vitamin a ', N'vitamin ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'vitamin a)', N'vitamin ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'vitamin a;', N'vitamin ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'vitamin a:', N'vitamin ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'vitamin a' + NCHAR(3), N'vitamin ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'vitamin an ', N'vitamin ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'vitamin an)', N'vitamin ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'vitamin an;', N'vitamin ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'vitamin an:', N'vitamin ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'vitamin an' + NCHAR(3), N'vitamin ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Vitamin a ', N'Vitamin ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Vitamin a)', N'Vitamin ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Vitamin a;', N'Vitamin ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Vitamin a:', N'Vitamin ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Vitamin a' + NCHAR(3), N'Vitamin ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Vitamin an ', N'Vitamin ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Vitamin an)', N'Vitamin ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Vitamin an;', N'Vitamin ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Vitamin an:', N'Vitamin ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Vitamin an' + NCHAR(3), N'Vitamin ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'factor a ', N'factor ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'factor a)', N'factor ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'factor a;', N'factor ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'factor a:', N'factor ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'factor a' + NCHAR(3), N'factor ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'factor an ', N'factor ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'factor an)', N'factor ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'factor an;', N'factor ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'factor an:', N'factor ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'factor an' + NCHAR(3), N'factor ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'Factor a ', N'Factor ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Factor a)', N'Factor ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Factor a;', N'Factor ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Factor a:', N'Factor ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Factor a' + NCHAR(3), N'Factor ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Factor an ', N'Factor ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Factor an)', N'Factor ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Factor an;', N'Factor ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Factor an:', N'Factor ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Factor an' + NCHAR(3), N'Factor ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'protein a ', N'protein ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'protein a)', N'protein ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'protein a;', N'protein ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'protein a:', N'protein ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'protein a' + NCHAR(3), N'protein ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'protein an ', N'protein ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'protein an)', N'protein ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'protein an;', N'protein ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'protein an:', N'protein ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'protein an' + NCHAR(3), N'protein ' + NCHAR(15) + N'an' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Protein a ', N'Protein ' + NCHAR(15) + N'a ')  -- U+000F control character
        , N'Protein a)', N'Protein ' + NCHAR(15) + N'a)')  -- U+000F control character
        , N'Protein a;', N'Protein ' + NCHAR(15) + N'a;')  -- U+000F control character
        , N'Protein a:', N'Protein ' + NCHAR(15) + N'a:')  -- U+000F control character
        , N'Protein a' + NCHAR(3), N'Protein ' + NCHAR(15) + N'a' + NCHAR(3))  -- U+0003 end sentinel, U+000F control character
        , N'Protein an ', N'Protein ' + NCHAR(15) + N'an ')  -- U+000F control character
        , N'Protein an)', N'Protein ' + NCHAR(15) + N'an)')  -- U+000F control character
        , N'Protein an;', N'Protein ' + NCHAR(15) + N'an;')  -- U+000F control character
        , N'Protein an:', N'Protein ' + NCHAR(15) + N'an:')  -- U+000F control character
        , N'Protein an' + NCHAR(3), N'Protein ' + NCHAR(15) + N'an' + NCHAR(3));  -- U+0003 end sentinel, U+000F control character
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' the ', N' ')
        , N' the)', N')')
        , N' the]', N']')
        , N' the}', N'}')
        , N' the:', N':')
        , N' the;', N';')
        , N'(the ', N'(')
        , N'(the]', N'(]')
        , N'(the}', N'(}')
        , N'(the:', N'(:')
        , N'(the;', N'(;')
        , N'[the ', N'[')
        , N'[the)', N'[)')
        , N'[the}', N'[}')
        , N'[the:', N'[:')
        , N'[the;', N'[;')
        , N'{the ', N'{')
        , N'{the)', N'{)')
        , N'{the]', N'{]')
        , N'{the:', N'{:')
        , N'{the;', N'{;')
        , N':the ', N':')
        , N':the)', N':)')
        , N':the]', N':]')
        , N':the}', N':}')
        , N':the:', N'::')
        , N':the;', N':;')
        , N';the ', N';')
        , N';the)', N';)')
        , N';the]', N';]');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';the}', N';}')
        , N';the:', N';:')
        , N';the;', N';;')
        , N' a ', N' ')
        , N' a)', N')')
        , N' a]', N']')
        , N' a}', N'}')
        , N' a:', N':')
        , N' a;', N';')
        , N'(a ', N'(')
        , N'(a]', N'(]')
        , N'(a}', N'(}')
        , N'(a:', N'(:')
        , N'(a;', N'(;')
        , N'[a ', N'[')
        , N'[a)', N'[)')
        , N'[a}', N'[}')
        , N'[a:', N'[:')
        , N'[a;', N'[;')
        , N'{a ', N'{')
        , N'{a)', N'{)')
        , N'{a]', N'{]')
        , N'{a:', N'{:')
        , N'{a;', N'{;')
        , N':a ', N':')
        , N':a)', N':)')
        , N':a]', N':]')
        , N':a}', N':}')
        , N':a:', N'::')
        , N':a;', N':;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N';a ', N';')
        , N';a)', N';)')
        , N';a]', N';]')
        , N';a}', N';}')
        , N';a:', N';:')
        , N';a;', N';;')
        , N' an ', N' ')
        , N' an)', N')')
        , N' an]', N']')
        , N' an}', N'}')
        , N' an:', N':')
        , N' an;', N';')
        , N'(an ', N'(')
        , N'(an]', N'(]')
        , N'(an}', N'(}')
        , N'(an:', N'(:')
        , N'(an;', N'(;')
        , N'[an ', N'[')
        , N'[an)', N'[)')
        , N'[an}', N'[}')
        , N'[an:', N'[:')
        , N'[an;', N'[;')
        , N'{an ', N'{')
        , N'{an)', N'{)')
        , N'{an]', N'{]')
        , N'{an:', N'{:')
        , N'{an;', N'{;')
        , N':an ', N':')
        , N':an)', N':)')
        , N':an]', N':]');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':an}', N':}')
        , N':an:', N'::')
        , N':an;', N':;')
        , N';an ', N';')
        , N';an)', N';)')
        , N';an]', N';]')
        , N';an}', N';}')
        , N';an:', N';:')
        , N';an;', N';;')
        , N' the ', N' ')
        , N' a ', N' ')
        , N' an ', N' ')
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 9. Trailing Roman numerals. 'Trailing' = at the end of the string, or at the end of a closing parenthetical. Mid-string numerals are left alone. Order: 'type <roman>' first (it needs the word), then the word 'type' goes (9b), then grade and acronym numerals - so 'Grade III type' ends in its numeral when those rules look

    -- 9a. type <roman> -> <digit>: the word 'type' is dropped (maintainer decision)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' type IV)', N' 4)')
        , N' type IV' + NCHAR(3), N' 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' type IV ', N' 4 ')
        , N' type IV;', N' 4;')
        , N' type IV:', N' 4:')
        , N'(type IV)', N'(4)')
        , N'(type IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type IV ', N'(4 ')
        , N'(type IV;', N'(4;')
        , N'(type IV:', N'(4:')
        , NCHAR(2) + N'type IV ', NCHAR(2) + N'type 4 ')  -- U+0002 start sentinel
        , N' type III)', N' 3)')
        , N' type III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' type III ', N' 3 ')
        , N' type III;', N' 3;')
        , N' type III:', N' 3:')
        , N'(type III)', N'(3)')
        , N'(type III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type III ', N'(3 ')
        , N'(type III;', N'(3;')
        , N'(type III:', N'(3:')
        , NCHAR(2) + N'type III ', NCHAR(2) + N'type 3 ')  -- U+0002 start sentinel
        , N' type II)', N' 2)')
        , N' type II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' type II ', N' 2 ')
        , N' type II;', N' 2;')
        , N' type II:', N' 2:')
        , N'(type II)', N'(2)')
        , N'(type II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type II ', N'(2 ');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(type II;', N'(2;')
        , N'(type II:', N'(2:')
        , NCHAR(2) + N'type II ', NCHAR(2) + N'type 2 ')  -- U+0002 start sentinel
        , N' type I)', N' 1)')
        , N' type I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' type I ', N' 1 ')
        , N' type I;', N' 1;')
        , N' type I:', N' 1:')
        , N'(type I)', N'(1)')
        , N'(type I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(type I ', N'(1 ')
        , N'(type I;', N'(1;')
        , N'(type I:', N'(1:')
        , NCHAR(2) + N'type I ', NCHAR(2) + N'type 1 ')  -- U+0002 start sentinel
        , N' Type IV)', N' 4)')
        , N' Type IV' + NCHAR(3), N' 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type IV ', N' 4 ')
        , N' Type IV;', N' 4;')
        , N' Type IV:', N' 4:')
        , N'(Type IV)', N'(4)')
        , N'(Type IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type IV ', N'(4 ')
        , N'(Type IV;', N'(4;')
        , N'(Type IV:', N'(4:')
        , NCHAR(2) + N'Type IV ', NCHAR(2) + N'Type 4 ')  -- U+0002 start sentinel
        , N' Type III)', N' 3)')
        , N' Type III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type III ', N' 3 ')
        , N' Type III;', N' 3;')
        , N' Type III:', N' 3:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(Type III)', N'(3)')
        , N'(Type III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type III ', N'(3 ')
        , N'(Type III;', N'(3;')
        , N'(Type III:', N'(3:')
        , NCHAR(2) + N'Type III ', NCHAR(2) + N'Type 3 ')  -- U+0002 start sentinel
        , N' Type II)', N' 2)')
        , N' Type II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type II ', N' 2 ')
        , N' Type II;', N' 2;')
        , N' Type II:', N' 2:')
        , N'(Type II)', N'(2)')
        , N'(Type II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type II ', N'(2 ')
        , N'(Type II;', N'(2;')
        , N'(Type II:', N'(2:')
        , NCHAR(2) + N'Type II ', NCHAR(2) + N'Type 2 ')  -- U+0002 start sentinel
        , N' Type I)', N' 1)')
        , N' Type I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type I ', N' 1 ')
        , N' Type I;', N' 1;')
        , N' Type I:', N' 1:')
        , N'(Type I)', N'(1)')
        , N'(Type I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Type I ', N'(1 ')
        , N'(Type I;', N'(1;')
        , N'(Type I:', N'(1:')
        , NCHAR(2) + N'Type I ', NCHAR(2) + N'Type 1 ')  -- U+0002 start sentinel
        , N' TYPE IV)', N' 4)')
        , N' TYPE IV' + NCHAR(3), N' 4' + NCHAR(3));  -- U+0003 end sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' TYPE IV ', N' 4 ')
        , N' TYPE IV;', N' 4;')
        , N' TYPE IV:', N' 4:')
        , N'(TYPE IV)', N'(4)')
        , N'(TYPE IV' + NCHAR(3), N'(4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE IV ', N'(4 ')
        , N'(TYPE IV;', N'(4;')
        , N'(TYPE IV:', N'(4:')
        , NCHAR(2) + N'TYPE IV ', NCHAR(2) + N'TYPE 4 ')  -- U+0002 start sentinel
        , N' TYPE III)', N' 3)')
        , N' TYPE III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE III ', N' 3 ')
        , N' TYPE III;', N' 3;')
        , N' TYPE III:', N' 3:')
        , N'(TYPE III)', N'(3)')
        , N'(TYPE III' + NCHAR(3), N'(3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE III ', N'(3 ')
        , N'(TYPE III;', N'(3;')
        , N'(TYPE III:', N'(3:')
        , NCHAR(2) + N'TYPE III ', NCHAR(2) + N'TYPE 3 ')  -- U+0002 start sentinel
        , N' TYPE II)', N' 2)')
        , N' TYPE II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE II ', N' 2 ')
        , N' TYPE II;', N' 2;')
        , N' TYPE II:', N' 2:')
        , N'(TYPE II)', N'(2)')
        , N'(TYPE II' + NCHAR(3), N'(2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE II ', N'(2 ')
        , N'(TYPE II;', N'(2;')
        , N'(TYPE II:', N'(2:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2) + N'TYPE II ', NCHAR(2) + N'TYPE 2 ')  -- U+0002 start sentinel
        , N' TYPE I)', N' 1)')
        , N' TYPE I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE I ', N' 1 ')
        , N' TYPE I;', N' 1;')
        , N' TYPE I:', N' 1:')
        , N'(TYPE I)', N'(1)')
        , N'(TYPE I' + NCHAR(3), N'(1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE I ', N'(1 ')
        , N'(TYPE I;', N'(1;')
        , N'(TYPE I:', N'(1:')
        , NCHAR(2) + N'TYPE I ', NCHAR(2) + N'TYPE 1 ');  -- U+0002 start sentinel

    -- 9b. The word 'type' removed - whole word, any of type/Type/TYPE, never as the first word ('Type A thymoma' keeps it); 'types', 'subtype', 'typical' untouched
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'type ' + NCHAR(15), N'type' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N'Type ' + NCHAR(15), N'Type' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N'TYPE ' + NCHAR(15), N'TYPE' + NCHAR(17) + NCHAR(15))  -- U+000F control character, U+0011 control character
        , N' type ', N' ')
        , N' type)', N')')
        , N' type]', N']')
        , N' type}', N'}')
        , N' type:', N':')
        , N' type;', N';')
        , N' type' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(type ', N'(')
        , N'(type)', N'')
        , N'(type]', N'(]')
        , N'(type}', N'(}')
        , N'(type:', N'(:')
        , N'(type;', N'(;')
        , N'(type' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[type ', N'[')
        , N'[type)', N'[)')
        , N'[type]', N'')
        , N'[type}', N'[}')
        , N'[type:', N'[:')
        , N'[type;', N'[;')
        , N'[type' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{type ', N'{')
        , N'{type)', N'{)')
        , N'{type]', N'{]')
        , N'{type}', N'')
        , N'{type:', N'{:')
        , N'{type;', N'{;');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'{type' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':type ', N':')
        , N':type)', N':)')
        , N':type]', N':]')
        , N':type}', N':}')
        , N':type:', N'::')
        , N':type;', N':;')
        , N':type' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';type ', N';')
        , N';type)', N';)')
        , N';type]', N';]')
        , N';type}', N';}')
        , N';type:', N';:')
        , N';type;', N';;')
        , N';type' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' Type ', N' ')
        , N' Type)', N')')
        , N' Type]', N']')
        , N' Type}', N'}')
        , N' Type:', N':')
        , N' Type;', N';')
        , N' Type' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(Type ', N'(')
        , N'(Type)', N'')
        , N'(Type]', N'(]')
        , N'(Type}', N'(}')
        , N'(Type:', N'(:')
        , N'(Type;', N'(;')
        , N'(Type' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[Type ', N'[');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'[Type)', N'[)')
        , N'[Type]', N'')
        , N'[Type}', N'[}')
        , N'[Type:', N'[:')
        , N'[Type;', N'[;')
        , N'[Type' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{Type ', N'{')
        , N'{Type)', N'{)')
        , N'{Type]', N'{]')
        , N'{Type}', N'')
        , N'{Type:', N'{:')
        , N'{Type;', N'{;')
        , N'{Type' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':Type ', N':')
        , N':Type)', N':)')
        , N':Type]', N':]')
        , N':Type}', N':}')
        , N':Type:', N'::')
        , N':Type;', N':;')
        , N':Type' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';Type ', N';')
        , N';Type)', N';)')
        , N';Type]', N';]')
        , N';Type}', N';}')
        , N';Type:', N';:')
        , N';Type;', N';;')
        , N';Type' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' TYPE ', N' ')
        , N' TYPE)', N')')
        , N' TYPE]', N']');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' TYPE}', N'}')
        , N' TYPE:', N':')
        , N' TYPE;', N';')
        , N' TYPE' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N'(TYPE ', N'(')
        , N'(TYPE)', N'')
        , N'(TYPE]', N'(]')
        , N'(TYPE}', N'(}')
        , N'(TYPE:', N'(:')
        , N'(TYPE;', N'(;')
        , N'(TYPE' + NCHAR(3), N'(' + NCHAR(3))  -- U+0003 end sentinel
        , N'[TYPE ', N'[')
        , N'[TYPE)', N'[)')
        , N'[TYPE]', N'')
        , N'[TYPE}', N'[}')
        , N'[TYPE:', N'[:')
        , N'[TYPE;', N'[;')
        , N'[TYPE' + NCHAR(3), N'[' + NCHAR(3))  -- U+0003 end sentinel
        , N'{TYPE ', N'{')
        , N'{TYPE)', N'{)')
        , N'{TYPE]', N'{]')
        , N'{TYPE}', N'')
        , N'{TYPE:', N'{:')
        , N'{TYPE;', N'{;')
        , N'{TYPE' + NCHAR(3), N'{' + NCHAR(3))  -- U+0003 end sentinel
        , N':TYPE ', N':')
        , N':TYPE)', N':)')
        , N':TYPE]', N':]')
        , N':TYPE}', N':}')
        , N':TYPE:', N'::');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N':TYPE;', N':;')
        , N':TYPE' + NCHAR(3), N':' + NCHAR(3))  -- U+0003 end sentinel
        , N';TYPE ', N';')
        , N';TYPE)', N';)')
        , N';TYPE]', N';]')
        , N';TYPE}', N';}')
        , N';TYPE:', N';:')
        , N';TYPE;', N';;')
        , N';TYPE' + NCHAR(3), N';' + NCHAR(3))  -- U+0003 end sentinel
        , N' type ', N' ')
        , N' Type ', N' ')
        , N' TYPE ', N' ');

    -- 9c. Close up again after the 'type' removal
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' ' + NCHAR(3), NCHAR(3))  -- U+0003 end sentinel
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');

    -- 9d. grade <roman> -> grade <digit>: the word 'grade' is kept
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' grade IV)', N' grade 4)')
        , N' grade IV' + NCHAR(3), N' grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade IV ', N' grade 4 ')
        , N' grade IV;', N' grade 4;')
        , N' grade IV:', N' grade 4:')
        , N'(grade IV)', N'(grade 4)')
        , N'(grade IV' + NCHAR(3), N'(grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade IV ', N'(grade 4 ')
        , N'(grade IV;', N'(grade 4;')
        , N'(grade IV:', N'(grade 4:')
        , NCHAR(2) + N'grade IV)', NCHAR(2) + N'grade 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV' + NCHAR(3), NCHAR(2) + N'grade 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade IV ', NCHAR(2) + N'grade 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV;', NCHAR(2) + N'grade 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade IV:', NCHAR(2) + N'grade 4:')  -- U+0002 start sentinel
        , N' grade III)', N' grade 3)')
        , N' grade III' + NCHAR(3), N' grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade III ', N' grade 3 ')
        , N' grade III;', N' grade 3;')
        , N' grade III:', N' grade 3:')
        , N'(grade III)', N'(grade 3)')
        , N'(grade III' + NCHAR(3), N'(grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade III ', N'(grade 3 ')
        , N'(grade III;', N'(grade 3;')
        , N'(grade III:', N'(grade 3:')
        , NCHAR(2) + N'grade III)', NCHAR(2) + N'grade 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III' + NCHAR(3), NCHAR(2) + N'grade 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade III ', NCHAR(2) + N'grade 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III;', NCHAR(2) + N'grade 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade III:', NCHAR(2) + N'grade 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' grade II)', N' grade 2)')
        , N' grade II' + NCHAR(3), N' grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade II ', N' grade 2 ')
        , N' grade II;', N' grade 2;')
        , N' grade II:', N' grade 2:')
        , N'(grade II)', N'(grade 2)')
        , N'(grade II' + NCHAR(3), N'(grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade II ', N'(grade 2 ')
        , N'(grade II;', N'(grade 2;')
        , N'(grade II:', N'(grade 2:')
        , NCHAR(2) + N'grade II)', NCHAR(2) + N'grade 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II' + NCHAR(3), NCHAR(2) + N'grade 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade II ', NCHAR(2) + N'grade 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II;', NCHAR(2) + N'grade 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade II:', NCHAR(2) + N'grade 2:')  -- U+0002 start sentinel
        , N' grade I)', N' grade 1)')
        , N' grade I' + NCHAR(3), N' grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' grade I ', N' grade 1 ')
        , N' grade I;', N' grade 1;')
        , N' grade I:', N' grade 1:')
        , N'(grade I)', N'(grade 1)')
        , N'(grade I' + NCHAR(3), N'(grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(grade I ', N'(grade 1 ')
        , N'(grade I;', N'(grade 1;')
        , N'(grade I:', N'(grade 1:')
        , NCHAR(2) + N'grade I)', NCHAR(2) + N'grade 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I' + NCHAR(3), NCHAR(2) + N'grade 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'grade I ', NCHAR(2) + N'grade 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I;', NCHAR(2) + N'grade 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'grade I:', NCHAR(2) + N'grade 1:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' Grade IV)', N' Grade 4)')
        , N' Grade IV' + NCHAR(3), N' Grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade IV ', N' Grade 4 ')
        , N' Grade IV;', N' Grade 4;')
        , N' Grade IV:', N' Grade 4:')
        , N'(Grade IV)', N'(Grade 4)')
        , N'(Grade IV' + NCHAR(3), N'(Grade 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade IV ', N'(Grade 4 ')
        , N'(Grade IV;', N'(Grade 4;')
        , N'(Grade IV:', N'(Grade 4:')
        , NCHAR(2) + N'Grade IV)', NCHAR(2) + N'Grade 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV' + NCHAR(3), NCHAR(2) + N'Grade 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade IV ', NCHAR(2) + N'Grade 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV;', NCHAR(2) + N'Grade 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade IV:', NCHAR(2) + N'Grade 4:')  -- U+0002 start sentinel
        , N' Grade III)', N' Grade 3)')
        , N' Grade III' + NCHAR(3), N' Grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade III ', N' Grade 3 ')
        , N' Grade III;', N' Grade 3;')
        , N' Grade III:', N' Grade 3:')
        , N'(Grade III)', N'(Grade 3)')
        , N'(Grade III' + NCHAR(3), N'(Grade 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade III ', N'(Grade 3 ')
        , N'(Grade III;', N'(Grade 3;')
        , N'(Grade III:', N'(Grade 3:')
        , NCHAR(2) + N'Grade III)', NCHAR(2) + N'Grade 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III' + NCHAR(3), NCHAR(2) + N'Grade 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade III ', NCHAR(2) + N'Grade 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III;', NCHAR(2) + N'Grade 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade III:', NCHAR(2) + N'Grade 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' Grade II)', N' Grade 2)')
        , N' Grade II' + NCHAR(3), N' Grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade II ', N' Grade 2 ')
        , N' Grade II;', N' Grade 2;')
        , N' Grade II:', N' Grade 2:')
        , N'(Grade II)', N'(Grade 2)')
        , N'(Grade II' + NCHAR(3), N'(Grade 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade II ', N'(Grade 2 ')
        , N'(Grade II;', N'(Grade 2;')
        , N'(Grade II:', N'(Grade 2:')
        , NCHAR(2) + N'Grade II)', NCHAR(2) + N'Grade 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II' + NCHAR(3), NCHAR(2) + N'Grade 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade II ', NCHAR(2) + N'Grade 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II;', NCHAR(2) + N'Grade 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade II:', NCHAR(2) + N'Grade 2:')  -- U+0002 start sentinel
        , N' Grade I)', N' Grade 1)')
        , N' Grade I' + NCHAR(3), N' Grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' Grade I ', N' Grade 1 ')
        , N' Grade I;', N' Grade 1;')
        , N' Grade I:', N' Grade 1:')
        , N'(Grade I)', N'(Grade 1)')
        , N'(Grade I' + NCHAR(3), N'(Grade 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(Grade I ', N'(Grade 1 ')
        , N'(Grade I;', N'(Grade 1;')
        , N'(Grade I:', N'(Grade 1:')
        , NCHAR(2) + N'Grade I)', NCHAR(2) + N'Grade 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I' + NCHAR(3), NCHAR(2) + N'Grade 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'Grade I ', NCHAR(2) + N'Grade 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I;', NCHAR(2) + N'Grade 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'Grade I:', NCHAR(2) + N'Grade 1:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' GRADE IV)', N' GRADE 4)')
        , N' GRADE IV' + NCHAR(3), N' GRADE 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE IV ', N' GRADE 4 ')
        , N' GRADE IV;', N' GRADE 4;')
        , N' GRADE IV:', N' GRADE 4:')
        , N'(GRADE IV)', N'(GRADE 4)')
        , N'(GRADE IV' + NCHAR(3), N'(GRADE 4' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE IV ', N'(GRADE 4 ')
        , N'(GRADE IV;', N'(GRADE 4;')
        , N'(GRADE IV:', N'(GRADE 4:')
        , NCHAR(2) + N'GRADE IV)', NCHAR(2) + N'GRADE 4)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV' + NCHAR(3), NCHAR(2) + N'GRADE 4' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE IV ', NCHAR(2) + N'GRADE 4 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV;', NCHAR(2) + N'GRADE 4;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE IV:', NCHAR(2) + N'GRADE 4:')  -- U+0002 start sentinel
        , N' GRADE III)', N' GRADE 3)')
        , N' GRADE III' + NCHAR(3), N' GRADE 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE III ', N' GRADE 3 ')
        , N' GRADE III;', N' GRADE 3;')
        , N' GRADE III:', N' GRADE 3:')
        , N'(GRADE III)', N'(GRADE 3)')
        , N'(GRADE III' + NCHAR(3), N'(GRADE 3' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE III ', N'(GRADE 3 ')
        , N'(GRADE III;', N'(GRADE 3;')
        , N'(GRADE III:', N'(GRADE 3:')
        , NCHAR(2) + N'GRADE III)', NCHAR(2) + N'GRADE 3)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III' + NCHAR(3), NCHAR(2) + N'GRADE 3' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE III ', NCHAR(2) + N'GRADE 3 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III;', NCHAR(2) + N'GRADE 3;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE III:', NCHAR(2) + N'GRADE 3:');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' GRADE II)', N' GRADE 2)')
        , N' GRADE II' + NCHAR(3), N' GRADE 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE II ', N' GRADE 2 ')
        , N' GRADE II;', N' GRADE 2;')
        , N' GRADE II:', N' GRADE 2:')
        , N'(GRADE II)', N'(GRADE 2)')
        , N'(GRADE II' + NCHAR(3), N'(GRADE 2' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE II ', N'(GRADE 2 ')
        , N'(GRADE II;', N'(GRADE 2;')
        , N'(GRADE II:', N'(GRADE 2:')
        , NCHAR(2) + N'GRADE II)', NCHAR(2) + N'GRADE 2)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II' + NCHAR(3), NCHAR(2) + N'GRADE 2' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE II ', NCHAR(2) + N'GRADE 2 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II;', NCHAR(2) + N'GRADE 2;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE II:', NCHAR(2) + N'GRADE 2:')  -- U+0002 start sentinel
        , N' GRADE I)', N' GRADE 1)')
        , N' GRADE I' + NCHAR(3), N' GRADE 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' GRADE I ', N' GRADE 1 ')
        , N' GRADE I;', N' GRADE 1;')
        , N' GRADE I:', N' GRADE 1:')
        , N'(GRADE I)', N'(GRADE 1)')
        , N'(GRADE I' + NCHAR(3), N'(GRADE 1' + NCHAR(3))  -- U+0003 end sentinel
        , N'(GRADE I ', N'(GRADE 1 ')
        , N'(GRADE I;', N'(GRADE 1;')
        , N'(GRADE I:', N'(GRADE 1:')
        , NCHAR(2) + N'GRADE I)', NCHAR(2) + N'GRADE 1)')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I' + NCHAR(3), NCHAR(2) + N'GRADE 1' + NCHAR(3))  -- U+0002 start sentinel, U+0003 end sentinel
        , NCHAR(2) + N'GRADE I ', NCHAR(2) + N'GRADE 1 ')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I;', NCHAR(2) + N'GRADE 1;')  -- U+0002 start sentinel
        , NCHAR(2) + N'GRADE I:', NCHAR(2) + N'GRADE 1:');  -- U+0002 start sentinel

    -- 9d-ii. a numeral right after a converted one: 'grade II/III' -> 'grade 2 III' -> 'grade 2 3'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 1 IV)', N' 1 4)')
        , N' 1 IV' + NCHAR(3), N' 1 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 IV ', N' 1 4 ')
        , N' 1 IV;', N' 1 4;')
        , N' 1 IV:', N' 1 4:')
        , N' 1 III)', N' 1 3)')
        , N' 1 III' + NCHAR(3), N' 1 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 III ', N' 1 3 ')
        , N' 1 III;', N' 1 3;')
        , N' 1 III:', N' 1 3:')
        , N' 1 II)', N' 1 2)')
        , N' 1 II' + NCHAR(3), N' 1 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 II ', N' 1 2 ')
        , N' 1 II;', N' 1 2;')
        , N' 1 II:', N' 1 2:')
        , N' 1 I)', N' 1 1)')
        , N' 1 I' + NCHAR(3), N' 1 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 1 I ', N' 1 1 ')
        , N' 1 I;', N' 1 1;')
        , N' 1 I:', N' 1 1:')
        , N' 2 IV)', N' 2 4)')
        , N' 2 IV' + NCHAR(3), N' 2 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 IV ', N' 2 4 ')
        , N' 2 IV;', N' 2 4;')
        , N' 2 IV:', N' 2 4:')
        , N' 2 III)', N' 2 3)')
        , N' 2 III' + NCHAR(3), N' 2 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 III ', N' 2 3 ')
        , N' 2 III;', N' 2 3;')
        , N' 2 III:', N' 2 3:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 2 II)', N' 2 2)')
        , N' 2 II' + NCHAR(3), N' 2 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 II ', N' 2 2 ')
        , N' 2 II;', N' 2 2;')
        , N' 2 II:', N' 2 2:')
        , N' 2 I)', N' 2 1)')
        , N' 2 I' + NCHAR(3), N' 2 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 2 I ', N' 2 1 ')
        , N' 2 I;', N' 2 1;')
        , N' 2 I:', N' 2 1:')
        , N' 3 IV)', N' 3 4)')
        , N' 3 IV' + NCHAR(3), N' 3 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 IV ', N' 3 4 ')
        , N' 3 IV;', N' 3 4;')
        , N' 3 IV:', N' 3 4:')
        , N' 3 III)', N' 3 3)')
        , N' 3 III' + NCHAR(3), N' 3 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 III ', N' 3 3 ')
        , N' 3 III;', N' 3 3;')
        , N' 3 III:', N' 3 3:')
        , N' 3 II)', N' 3 2)')
        , N' 3 II' + NCHAR(3), N' 3 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 II ', N' 3 2 ')
        , N' 3 II;', N' 3 2;')
        , N' 3 II:', N' 3 2:')
        , N' 3 I)', N' 3 1)')
        , N' 3 I' + NCHAR(3), N' 3 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 3 I ', N' 3 1 ')
        , N' 3 I;', N' 3 1;')
        , N' 3 I:', N' 3 1:');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' 4 IV)', N' 4 4)')
        , N' 4 IV' + NCHAR(3), N' 4 4' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 IV ', N' 4 4 ')
        , N' 4 IV;', N' 4 4;')
        , N' 4 IV:', N' 4 4:')
        , N' 4 III)', N' 4 3)')
        , N' 4 III' + NCHAR(3), N' 4 3' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 III ', N' 4 3 ')
        , N' 4 III;', N' 4 3;')
        , N' 4 III:', N' 4 3:')
        , N' 4 II)', N' 4 2)')
        , N' 4 II' + NCHAR(3), N' 4 2' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 II ', N' 4 2 ')
        , N' 4 II;', N' 4 2;')
        , N' 4 II:', N' 4 2:')
        , N' 4 I)', N' 4 1)')
        , N' 4 I' + NCHAR(3), N' 4 1' + NCHAR(3))  -- U+0003 end sentinel
        , N' 4 I ', N' 4 1 ')
        , N' 4 I;', N' 4 1;')
        , N' 4 I:', N' 4 1:');

    -- 9e. ALL-CAPS acronym + roman -> acronym + digit (CIN III = CIN 3, RAEB II = RAEB 2). Rule: the two characters before the trailing numeral are both A-Z. Done with plain replacements and markers instead of a LIKE test, so SQL Server can inline it

    -- 9e-i. mark the space before a whole-word I/II/III (followed by a space, ')' or the end)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' III ', NCHAR(4) + N'III ')  -- U+0004 control character
        , N' III)', NCHAR(4) + N'III)')  -- U+0004 control character
        , N' III' + NCHAR(3), NCHAR(4) + N'III' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' III;', NCHAR(4) + N'III;')  -- U+0004 control character
        , N' III:', NCHAR(4) + N'III:')  -- U+0004 control character
        , N' II ', NCHAR(4) + N'II ')  -- U+0004 control character
        , N' II)', NCHAR(4) + N'II)')  -- U+0004 control character
        , N' II' + NCHAR(3), NCHAR(4) + N'II' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' II;', NCHAR(4) + N'II;')  -- U+0004 control character
        , N' II:', NCHAR(4) + N'II:')  -- U+0004 control character
        , N' I ', NCHAR(4) + N'I ')  -- U+0004 control character
        , N' I)', NCHAR(4) + N'I)')  -- U+0004 control character
        , N' I' + NCHAR(3), NCHAR(4) + N'I' + NCHAR(3))  -- U+0003 end sentinel, U+0004 control character
        , N' I;', NCHAR(4) + N'I;')  -- U+0004 control character
        , N' I:', NCHAR(4) + N'I:');  -- U+0004 control character

    -- 9e-ii. a capital right before the mark gets a marker in front of it ...
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'A' + NCHAR(4), NCHAR(5) + N'A' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'B' + NCHAR(4), NCHAR(5) + N'B' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'C' + NCHAR(4), NCHAR(5) + N'C' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'D' + NCHAR(4), NCHAR(5) + N'D' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'E' + NCHAR(4), NCHAR(5) + N'E' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'F' + NCHAR(4), NCHAR(5) + N'F' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'G' + NCHAR(4), NCHAR(5) + N'G' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'H' + NCHAR(4), NCHAR(5) + N'H' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'I' + NCHAR(4), NCHAR(5) + N'I' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'J' + NCHAR(4), NCHAR(5) + N'J' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'K' + NCHAR(4), NCHAR(5) + N'K' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'L' + NCHAR(4), NCHAR(5) + N'L' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'M' + NCHAR(4), NCHAR(5) + N'M' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'N' + NCHAR(4), NCHAR(5) + N'N' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'O' + NCHAR(4), NCHAR(5) + N'O' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'P' + NCHAR(4), NCHAR(5) + N'P' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Q' + NCHAR(4), NCHAR(5) + N'Q' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'R' + NCHAR(4), NCHAR(5) + N'R' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'S' + NCHAR(4), NCHAR(5) + N'S' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'T' + NCHAR(4), NCHAR(5) + N'T' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'U' + NCHAR(4), NCHAR(5) + N'U' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'V' + NCHAR(4), NCHAR(5) + N'V' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'W' + NCHAR(4), NCHAR(5) + N'W' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'X' + NCHAR(4), NCHAR(5) + N'X' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Y' + NCHAR(4), NCHAR(5) + N'Y' + NCHAR(4))  -- U+0004 control character, U+0005 control character
        , N'Z' + NCHAR(4), NCHAR(5) + N'Z' + NCHAR(4));  -- U+0004 control character, U+0005 control character

    -- 9e-iii. ... which is promoted if the character before THAT is also a capital
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'A' + NCHAR(5), N'A' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'B' + NCHAR(5), N'B' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'C' + NCHAR(5), N'C' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'D' + NCHAR(5), N'D' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'E' + NCHAR(5), N'E' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'F' + NCHAR(5), N'F' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'G' + NCHAR(5), N'G' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'H' + NCHAR(5), N'H' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'I' + NCHAR(5), N'I' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'J' + NCHAR(5), N'J' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'K' + NCHAR(5), N'K' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'L' + NCHAR(5), N'L' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'M' + NCHAR(5), N'M' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'N' + NCHAR(5), N'N' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'O' + NCHAR(5), N'O' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'P' + NCHAR(5), N'P' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Q' + NCHAR(5), N'Q' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'R' + NCHAR(5), N'R' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'S' + NCHAR(5), N'S' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'T' + NCHAR(5), N'T' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'U' + NCHAR(5), N'U' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'V' + NCHAR(5), N'V' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'W' + NCHAR(5), N'W' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'X' + NCHAR(5), N'X' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Y' + NCHAR(5), N'Y' + NCHAR(6))  -- U+0005 control character, U+0006 control character
        , N'Z' + NCHAR(5), N'Z' + NCHAR(6));  -- U+0005 control character, U+0006 control character

    -- 9e-iv. two capitals confirmed: the space mark becomes the convert mark
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(6) + N'A' + NCHAR(4), N'A' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'B' + NCHAR(4), N'B' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'C' + NCHAR(4), N'C' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'D' + NCHAR(4), N'D' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'E' + NCHAR(4), N'E' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'F' + NCHAR(4), N'F' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'G' + NCHAR(4), N'G' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'H' + NCHAR(4), N'H' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'I' + NCHAR(4), N'I' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'J' + NCHAR(4), N'J' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'K' + NCHAR(4), N'K' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'L' + NCHAR(4), N'L' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'M' + NCHAR(4), N'M' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'N' + NCHAR(4), N'N' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'O' + NCHAR(4), N'O' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'P' + NCHAR(4), N'P' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Q' + NCHAR(4), N'Q' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'R' + NCHAR(4), N'R' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'S' + NCHAR(4), N'S' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'T' + NCHAR(4), N'T' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'U' + NCHAR(4), N'U' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'V' + NCHAR(4), N'V' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'W' + NCHAR(4), N'W' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'X' + NCHAR(4), N'X' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Y' + NCHAR(4), N'Y' + NCHAR(8))  -- U+0006 control character, U+0004 control character, U+0008 control character
        , NCHAR(6) + N'Z' + NCHAR(4), N'Z' + NCHAR(8));  -- U+0006 control character, U+0004 control character, U+0008 control character

    -- 9e-v. convert the confirmed numeral, then remove all markers (restoring the space)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(8) + N'III ', N' 3 ')  -- U+0008 control character
        , NCHAR(8) + N'III)', N' 3)')  -- U+0008 control character
        , NCHAR(8) + N'III' + NCHAR(3), N' 3' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'III;', N' 3;')  -- U+0008 control character
        , NCHAR(8) + N'III:', N' 3:')  -- U+0008 control character
        , NCHAR(8) + N'II ', N' 2 ')  -- U+0008 control character
        , NCHAR(8) + N'II)', N' 2)')  -- U+0008 control character
        , NCHAR(8) + N'II' + NCHAR(3), N' 2' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'II;', N' 2;')  -- U+0008 control character
        , NCHAR(8) + N'II:', N' 2:')  -- U+0008 control character
        , NCHAR(8) + N'I ', N' 1 ')  -- U+0008 control character
        , NCHAR(8) + N'I)', N' 1)')  -- U+0008 control character
        , NCHAR(8) + N'I' + NCHAR(3), N' 1' + NCHAR(3))  -- U+0008 control character, U+0003 end sentinel
        , NCHAR(8) + N'I;', N' 1;')  -- U+0008 control character
        , NCHAR(8) + N'I:', N' 1:')  -- U+0008 control character
        , NCHAR(5), N'')  -- U+0005 control character
        , NCHAR(6), N'')  -- U+0006 control character
        , NCHAR(4), N' ')  -- U+0004 control character
        , NCHAR(8), N' ');  -- U+0008 control character

    -- 9f. (v3) The space before a karyotype ('pre t(9;22)', 'Non del(5q)') is protected, so steps 10/10b never glue a word onto it (a second pass would split it again)
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' t(', NCHAR(17) + N't(')  -- U+0011 control character
        , N' inv(', NCHAR(17) + N'inv(')  -- U+0011 control character
        , N' del(', NCHAR(17) + N'del(')  -- U+0011 control character
        , N' der(', NCHAR(17) + N'der(')  -- U+0011 control character
        , N' dup(', NCHAR(17) + N'dup(')  -- U+0011 control character
        , N' ins(', NCHAR(17) + N'ins(')  -- U+0011 control character
        , N' i(', NCHAR(17) + N'i(')  -- U+0011 control character
        , N' add(', NCHAR(17) + N'add(')  -- U+0011 control character
        , N' idic(', NCHAR(17) + N'idic(');  -- U+0011 control character

    -- 10. The whole word non/Non/NON joins the next word: 'Non small' = 'Nonsmall'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' non ', N' non')
        , N'(non ', N'(non')
        , N'[non ', N'[non')
        , N'{non ', N'{non')
        , N':non ', N':non')
        , N';non ', N';non')
        , NCHAR(2) + N'non ', NCHAR(2) + N'non')  -- U+0002 start sentinel
        , N' Non ', N' Non')
        , N'(Non ', N'(Non')
        , N'[Non ', N'[Non')
        , N'{Non ', N'{Non')
        , N':Non ', N':Non')
        , N';Non ', N';Non')
        , NCHAR(2) + N'Non ', NCHAR(2) + N'Non')  -- U+0002 start sentinel
        , N' NON ', N' NON')
        , N'(NON ', N'(NON')
        , N'[NON ', N'[NON')
        , N'{NON ', N'{NON')
        , N':NON ', N':NON')
        , N';NON ', N';NON')
        , NCHAR(2) + N'NON ', NCHAR(2) + N'NON')  -- U+0002 start sentinel
        , N' non ', N' non')
        , N'(non ', N'(non')
        , N'[non ', N'[non')
        , N'{non ', N'{non')
        , N':non ', N':non')
        , N';non ', N';non')
        , NCHAR(2) + N'non ', NCHAR(2) + N'non')  -- U+0002 start sentinel
        , N' Non ', N' Non')
        , N'(Non ', N'(Non');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'[Non ', N'[Non')
        , N'{Non ', N'{Non')
        , N':Non ', N':Non')
        , N';Non ', N';Non')
        , NCHAR(2) + N'Non ', NCHAR(2) + N'Non')  -- U+0002 start sentinel
        , N' NON ', N' NON')
        , N'(NON ', N'(NON')
        , N'[NON ', N'[NON')
        , N'{NON ', N'{NON')
        , N':NON ', N':NON')
        , N';NON ', N';NON')
        , NCHAR(2) + N'NON ', NCHAR(2) + N'NON');  -- U+0002 start sentinel

    -- 10b. Bound prefixes join the next word like 'non': 'micro invasive' = 'microinvasive'; (v3 R5) a repeated prefix first: 'pre pre B' -> 'prepreB'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N' micro micro ', N' micromicro')
        , N' micro ', N' micro')
        , N'(micro micro ', N'(micromicro')
        , N'(micro ', N'(micro')
        , NCHAR(2) + N'micro micro ', NCHAR(2) + N'micromicro')  -- U+0002 start sentinel
        , NCHAR(2) + N'micro ', NCHAR(2) + N'micro')  -- U+0002 start sentinel
        , N'micromicro ', N'micromicro')
        , N' Micro micro ', N' Micromicro')
        , N' Micro ', N' Micro')
        , N'(Micro micro ', N'(Micromicro')
        , N'(Micro ', N'(Micro')
        , NCHAR(2) + N'Micro micro ', NCHAR(2) + N'Micromicro')  -- U+0002 start sentinel
        , NCHAR(2) + N'Micro ', NCHAR(2) + N'Micro')  -- U+0002 start sentinel
        , N'Micromicro ', N'Micromicro')
        , N' pre pre ', N' prepre')
        , N' pre ', N' pre')
        , N'(pre pre ', N'(prepre')
        , N'(pre ', N'(pre')
        , NCHAR(2) + N'pre pre ', NCHAR(2) + N'prepre')  -- U+0002 start sentinel
        , NCHAR(2) + N'pre ', NCHAR(2) + N'pre')  -- U+0002 start sentinel
        , N'prepre ', N'prepre')
        , N' Pre pre ', N' Prepre')
        , N' Pre ', N' Pre')
        , N'(Pre pre ', N'(Prepre')
        , N'(Pre ', N'(Pre')
        , NCHAR(2) + N'Pre pre ', NCHAR(2) + N'Prepre')  -- U+0002 start sentinel
        , NCHAR(2) + N'Pre ', NCHAR(2) + N'Pre')  -- U+0002 start sentinel
        , N'Prepre ', N'Prepre')
        , N' post post ', N' postpost')
        , N' post ', N' post');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'(post post ', N'(postpost')
        , N'(post ', N'(post')
        , NCHAR(2) + N'post post ', NCHAR(2) + N'postpost')  -- U+0002 start sentinel
        , NCHAR(2) + N'post ', NCHAR(2) + N'post')  -- U+0002 start sentinel
        , N'postpost ', N'postpost')
        , N' Post post ', N' Postpost')
        , N' Post ', N' Post')
        , N'(Post post ', N'(Postpost')
        , N'(Post ', N'(Post')
        , NCHAR(2) + N'Post post ', NCHAR(2) + N'Postpost')  -- U+0002 start sentinel
        , NCHAR(2) + N'Post ', NCHAR(2) + N'Post')  -- U+0002 start sentinel
        , N'Postpost ', N'Postpost')
        , N' extra extra ', N' extraextra')
        , N' extra ', N' extra')
        , N'(extra extra ', N'(extraextra')
        , N'(extra ', N'(extra')
        , NCHAR(2) + N'extra extra ', NCHAR(2) + N'extraextra')  -- U+0002 start sentinel
        , NCHAR(2) + N'extra ', NCHAR(2) + N'extra')  -- U+0002 start sentinel
        , N'extraextra ', N'extraextra')
        , N' Extra extra ', N' Extraextra')
        , N' Extra ', N' Extra')
        , N'(Extra extra ', N'(Extraextra')
        , N'(Extra ', N'(Extra')
        , NCHAR(2) + N'Extra extra ', NCHAR(2) + N'Extraextra')  -- U+0002 start sentinel
        , NCHAR(2) + N'Extra ', NCHAR(2) + N'Extra')  -- U+0002 start sentinel
        , N'Extraextra ', N'Extraextra')
        , N' poly poly ', N' polypoly')
        , N' poly ', N' poly')
        , N'(poly poly ', N'(polypoly')
        , N'(poly ', N'(poly');
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2) + N'poly poly ', NCHAR(2) + N'polypoly')  -- U+0002 start sentinel
        , NCHAR(2) + N'poly ', NCHAR(2) + N'poly')  -- U+0002 start sentinel
        , N'polypoly ', N'polypoly')
        , N' Poly poly ', N' Polypoly')
        , N' Poly ', N' Poly')
        , N'(Poly poly ', N'(Polypoly')
        , N'(Poly ', N'(Poly')
        , NCHAR(2) + N'Poly poly ', NCHAR(2) + N'Polypoly')  -- U+0002 start sentinel
        , NCHAR(2) + N'Poly ', NCHAR(2) + N'Poly')  -- U+0002 start sentinel
        , N'Polypoly ', N'Polypoly')
        , N' atrio atrio ', N' atrioatrio')
        , N' atrio ', N' atrio')
        , N'(atrio atrio ', N'(atrioatrio')
        , N'(atrio ', N'(atrio')
        , NCHAR(2) + N'atrio atrio ', NCHAR(2) + N'atrioatrio')  -- U+0002 start sentinel
        , NCHAR(2) + N'atrio ', NCHAR(2) + N'atrio')  -- U+0002 start sentinel
        , N'atrioatrio ', N'atrioatrio')
        , N' Atrio atrio ', N' Atrioatrio')
        , N' Atrio ', N' Atrio')
        , N'(Atrio atrio ', N'(Atrioatrio')
        , N'(Atrio ', N'(Atrio')
        , NCHAR(2) + N'Atrio atrio ', NCHAR(2) + N'Atrioatrio')  -- U+0002 start sentinel
        , NCHAR(2) + N'Atrio ', NCHAR(2) + N'Atrio')  -- U+0002 start sentinel
        , N'Atrioatrio ', N'Atrioatrio')
        , N' tubulo tubulo ', N' tubulotubulo')
        , N' tubulo ', N' tubulo')
        , N'(tubulo tubulo ', N'(tubulotubulo')
        , N'(tubulo ', N'(tubulo')
        , NCHAR(2) + N'tubulo tubulo ', NCHAR(2) + N'tubulotubulo')  -- U+0002 start sentinel
        , NCHAR(2) + N'tubulo ', NCHAR(2) + N'tubulo');  -- U+0002 start sentinel
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'tubulotubulo ', N'tubulotubulo')
        , N' Tubulo tubulo ', N' Tubulotubulo')
        , N' Tubulo ', N' Tubulo')
        , N'(Tubulo tubulo ', N'(Tubulotubulo')
        , N'(Tubulo ', N'(Tubulo')
        , NCHAR(2) + N'Tubulo tubulo ', NCHAR(2) + N'Tubulotubulo')  -- U+0002 start sentinel
        , NCHAR(2) + N'Tubulo ', NCHAR(2) + N'Tubulo')  -- U+0002 start sentinel
        , N'Tubulotubulo ', N'Tubulotubulo')
        , N' bronchiolo bronchiolo ', N' bronchiolobronchiolo')
        , N' bronchiolo ', N' bronchiolo')
        , N'(bronchiolo bronchiolo ', N'(bronchiolobronchiolo')
        , N'(bronchiolo ', N'(bronchiolo')
        , NCHAR(2) + N'bronchiolo bronchiolo ', NCHAR(2) + N'bronchiolobronchiolo')  -- U+0002 start sentinel
        , NCHAR(2) + N'bronchiolo ', NCHAR(2) + N'bronchiolo')  -- U+0002 start sentinel
        , N'bronchiolobronchiolo ', N'bronchiolobronchiolo')
        , N' Bronchiolo bronchiolo ', N' Bronchiolobronchiolo')
        , N' Bronchiolo ', N' Bronchiolo')
        , N'(Bronchiolo bronchiolo ', N'(Bronchiolobronchiolo')
        , N'(Bronchiolo ', N'(Bronchiolo')
        , NCHAR(2) + N'Bronchiolo bronchiolo ', NCHAR(2) + N'Bronchiolobronchiolo')  -- U+0002 start sentinel
        , NCHAR(2) + N'Bronchiolo ', NCHAR(2) + N'Bronchiolo')  -- U+0002 start sentinel
        , N'Bronchiolobronchiolo ', N'Bronchiolobronchiolo');

    -- 12. Remove the sentinels; collapse spaces BEFORE tidying parentheses (a removal can leave two spaces after '('); tidy the ends again, since removals can expose a leading '+'/'?' or trailing '.'
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , NCHAR(2), N'')  -- U+0002 start sentinel
        , NCHAR(3), N'')  -- U+0003 end sentinel
        , NCHAR(14), NCHAR(8722))  -- U+000E control character, U+2212 MINUS SIGN
        , NCHAR(15), N'')  -- U+000F control character
        , NCHAR(17), N' ');  -- U+0011 control character
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2
        , N'( ', N'(')
        , N' )', N')')
        , N'()', N'')
        , N'{(', N'{ (')
        , N'[(', N'[ (')
        , N': :', N':')
        , N' ;', N';')
        , N' :', N':')
        , N'::', N':');
    -- collapse runs of spaces without a loop: BEL marks each space, 'BEL +
    -- space' pairs are dropped, then leftover marks. BEL cannot come from the
    -- input: step 2 removed every control character.
    SET @s = REPLACE(REPLACE(REPLACE(@s COLLATE Latin1_General_100_BIN2, N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'');  -- U+0007 BELL used as a marker
    SET @s = LTRIM(@s, N'+? ');
    SET @s = RTRIM(@s, N'. ;:');

    RETURN @s;
END


GO

CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_entity_codes] ON dbo.[entity_codes] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_entity_codes'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term])>8000 OR DATALENGTH(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))>1200 OR DATALENGTH(dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))))>1200)
  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;
 UPDATE t SET [term]=dbo.CleanDisplayTerm(i.[term]), [TermUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))), [TermNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))) FROM dbo.[entity_codes] t JOIN inserted i ON t.[entity_code_id]=i.[entity_code_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_entity_related_terms] ON dbo.[entity_related_terms] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_entity_related_terms'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term])>8000 OR DATALENGTH(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))>1200 OR DATALENGTH(dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))))>1200)
  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;
 UPDATE t SET [term]=dbo.CleanDisplayTerm(i.[term]), [TermUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))), [TermNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term]))))) FROM dbo.[entity_related_terms] t JOIN inserted i ON t.[related_term_id]=i.[related_term_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_page_icdo_codes] ON dbo.[page_icdo_codes] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_page_icdo_codes'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term_in_coding_section])>8000 OR DATALENGTH(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_in_coding_section]))))>1200 OR DATALENGTH(dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_in_coding_section]))))))>1200)
  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;
 UPDATE t SET [term_in_coding_section]=dbo.CleanDisplayTerm(i.[term_in_coding_section]), [TermUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_in_coding_section]))), [TermNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_in_coding_section]))))) FROM dbo.[page_icdo_codes] t JOIN inserted i ON t.[code_id]=i.[code_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_page_term_mentions] ON dbo.[page_term_mentions] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_page_term_mentions'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term_original])>8000 OR DATALENGTH(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_original]))))>1200 OR DATALENGTH(dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_original]))))))>1200)
  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;
 UPDATE t SET [term_original]=dbo.CleanDisplayTerm(i.[term_original]), [term_text]=dbo.CleanDisplayTerm(i.[term_text]), [matched_term_original]=dbo.CleanDisplayTerm(i.[matched_term_original]), [term_original_norm]=dbo.UpperInitial(dbo.Clean(dbo.CleanDisplayTerm(i.[term_original]))), [term_clean]=dbo.UpperInitial(dbo.Clean(dbo.CleanDisplayTerm(i.[term_text]))), [matched_term_norm]=dbo.UpperInitial(dbo.Clean(dbo.CleanDisplayTerm(i.[matched_term_original]))), [TermUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_original]))), [TermNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_original]))))) FROM dbo.[page_term_mentions] t JOIN inserted i ON t.[mention_id]=i.[mention_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_hygiene_page_entity_evidence] ON dbo.[page_entity_evidence] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_hygiene_page_entity_evidence'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term_clean])>8000 OR DATALENGTH(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_clean]))))>1200 OR DATALENGTH(dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_clean]))))))>1200)
  THROW 51000, 'Term exceeds the normalizer or indexed key length limit', 1;
 UPDATE t SET [term_clean]=dbo.CleanDisplayTerm(i.[term_clean]), [TermUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_clean]))), [TermNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(dbo.CleanDisplayTerm(i.[term_clean]))))) FROM dbo.[page_entity_evidence] t JOIN inserted i ON t.[evidence_id]=i.[evidence_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_entity_identifiers] ON dbo.[entity_identifiers] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_entity_identifiers'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [term]=dbo.UpperInitial(i.[term]) FROM dbo.[entity_identifiers] t JOIN inserted i ON t.[identifier_id]=i.[identifier_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_entity_term_provenance] ON dbo.[entity_term_provenance] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_entity_term_provenance'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[recovered_term])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [recovered_term]=dbo.UpperInitial(i.[recovered_term]) FROM dbo.[entity_term_provenance] t JOIN inserted i ON t.[provenance_id]=i.[provenance_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_entity_term_code_matches] ON dbo.[entity_term_code_matches] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_entity_term_code_matches'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[official_term])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [official_term]=dbo.UpperInitial(i.[official_term]), [official_termUS]=dbo.UpperInitial(dbo.CleanBritishSpelling2(i.[official_term])), [official_termNormUS]=dbo.UpperInitial(dbo.Clean2(dbo.UpperInitial(dbo.CleanBritishSpelling2(i.[official_term])))) FROM dbo.[entity_term_code_matches] t JOIN inserted i ON t.[match_id]=i.[match_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_icdo4_morphology] ON dbo.[icdo4_morphology] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_icdo4_morphology'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term])>8000 OR DATALENGTH(i.[term_clean])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [term]=dbo.UpperInitial(i.[term]), [term_clean]=dbo.UpperInitial(i.[term_clean]) FROM dbo.[icdo4_morphology] t JOIN inserted i ON t.[row_id]=i.[row_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_cpc_morph_codes] ON dbo.[cpc_morph_codes] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_cpc_morph_codes'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[term])>8000 OR DATALENGTH(i.[term_norm])>8000 OR DATALENGTH(i.[term_clean])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [term]=dbo.UpperInitial(i.[term]), [term_norm]=dbo.UpperInitial(i.[term_norm]), [term_clean]=dbo.UpperInitial(i.[term_clean]) FROM dbo.[cpc_morph_codes] t JOIN inserted i ON t.[row_id]=i.[row_id];
END
GO
CREATE OR ALTER TRIGGER dbo.[tr_term_display_icdo_site_specific_terms] ON dbo.[icdo_site_specific_terms] AFTER INSERT, UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.tr_term_display_icdo_site_specific_terms'))>1 RETURN;
 IF EXISTS(SELECT 1 FROM inserted i WHERE DATALENGTH(i.[icdo_term])>8000 OR DATALENGTH(i.[term_normalized])>8000 OR DATALENGTH(i.[term_clean])>8000 OR DATALENGTH(i.[preferred_term])>8000)
  THROW 51000, 'Display term exceeds the 4000 UTF-16-unit limit', 1;
 UPDATE t SET [icdo_term]=dbo.UpperInitial(i.[icdo_term]), [term_normalized]=dbo.UpperInitial(i.[term_normalized]), [term_clean]=dbo.UpperInitial(i.[term_clean]), [preferred_term]=dbo.UpperInitial(i.[preferred_term]) FROM dbo.[icdo_site_specific_terms] t JOIN inserted i ON t.[term_id]=i.[term_id];
END
GO
CREATE OR ALTER VIEW dbo.v_entity_terms AS
SELECT 'entity_codes' AS term_table,entity_code_id AS term_id,page_id,term,TermUS,TermNormUS,
       code AS source_code,is_subtype,
       COALESCE(term_role, CASE WHEN is_subtype=1 THEN 'subtype' ELSE 'preferred' END) AS term_role,
       'coding' AS terminology_kind
FROM dbo.entity_codes
UNION ALL
SELECT 'entity_related_terms',related_term_id,page_id,term,TermUS,TermNormUS,
       NULL,0,
       COALESCE(term_role, CASE kind WHEN 'acceptable' THEN 'related_acceptable' WHEN 'not_recommended' THEN 'related_not_recommended' ELSE 'related_unlabeled' END),
       kind FROM dbo.entity_related_terms
GO
CREATE OR ALTER VIEW dbo.v_entity_term_provenance AS
SELECT t.*,p.provenance_id,p.source_kind,p.source_table,p.source_row_id,
       p.original_text,p.recovered_term,p.suggested_qualifier,p.terminology_status,
       p.review_status,p.is_added_term,p.proposal_batch,p.note
FROM dbo.v_entity_terms t LEFT JOIN dbo.entity_term_provenance p
ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))
GO
CREATE OR ALTER VIEW dbo.v_entity_term_code_matches AS
SELECT t.*,p.source_kind,p.suggested_qualifier,p.is_added_term,p.proposal_batch,
       m.match_id,m.edition,m.code AS suggested_code,m.official_termUS AS official_term,
       m.official_termUS AS candidateTermUS,m.official_termNormUS AS candidateTermNormUS,m.official_term AS official_term_source,m.match_type,
       m.candidate_order,m.conditions,m.review_status,m.reference_file,
       m.reference_sheet,m.reference_row,m.reference_sha256,m.code_term_evidence
FROM dbo.v_entity_terms t
LEFT JOIN dbo.entity_term_provenance p ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))
 AND p.provenance_id=(SELECT MIN(p2.provenance_id) FROM dbo.entity_term_provenance p2
 WHERE p2.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND p2.entity_code_id=t.term_id) OR
  (t.term_table='entity_related_terms' AND p2.related_term_id=t.term_id)))
LEFT JOIN dbo.entity_term_code_matches m ON m.provenance_id=p.provenance_id
GO
CREATE OR ALTER VIEW dbo.v_page_code_terms AS
WITH raw_rows AS (
 SELECT c.page_id,CASE LEN(NULLIF(TRIM(c.code),'')) WHEN 6 THEN 'ICD-O-3.2' WHEN 7 THEN 'ICD-O-4' ELSE NULL END AS edition,NULLIF(TRIM(c.code),'') AS code,c.TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,
        c.TermNormUS COLLATE Latin1_General_100_BIN2 AS TermNormUS,CAST(NULL AS VARCHAR(600)) AS candidateTermUS,CAST(c.is_subtype AS INT) AS is_subtype,
        'source_assignment' AS code_kind,'parsed_entity' AS source_kind,
        CAST(NULL AS VARCHAR(60)) AS suggested_qualifier,CAST(NULL AS VARCHAR(60)) AS match_type,
        'coding' AS terminology_kind,CAST(NULL AS VARCHAR(4000)) AS conditions,
        CAST(NULL AS VARCHAR(60)) AS review_status,'entity_codes' AS term_table,
        COALESCE(c.term_role, CASE WHEN c.is_subtype=1 THEN 'subtype' ELSE 'preferred' END) AS term_role,
        'entity_coding_section' AS term_source,
        CASE WHEN c.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END AS section_heading
 FROM dbo.entity_codes c WHERE NULLIF(TRIM(c.code),'') IS NOT NULL
 UNION ALL
 SELECT c.page_id,CASE LEN(NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),'')) WHEN 6 THEN 'ICD-O-3.2' WHEN 7 THEN 'ICD-O-4' ELSE NULL END,NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),''),c.TermUS COLLATE Latin1_General_100_BIN2,c.TermNormUS COLLATE Latin1_General_100_BIN2,NULL,
        COALESCE(e.is_subtype,0),'contextual_code','section_text',NULL,NULL,'contextual',
        NULL,NULL,'page_icdo_codes',
        COALESCE(c.term_role, CASE WHEN c.section_heading LIKE '%subtype%' THEN 'subtype_section' ELSE 'preferred' END),
        COALESCE(c.term_source, 'icdo_coding_page'),
        c.section_heading
 FROM dbo.page_icdo_codes c
 LEFT JOIN (SELECT page_id,code,TermUS,MAX(CAST(is_subtype AS INT)) AS is_subtype
            FROM dbo.entity_codes GROUP BY page_id,code,TermUS) e
 ON e.page_id=c.page_id AND e.code=NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),'') AND e.TermUS COLLATE Latin1_General_100_BIN2=c.TermUS COLLATE Latin1_General_100_BIN2
 WHERE c.TermUS IS NOT NULL AND NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),'') IS NOT NULL
 UNION ALL
 SELECT c.page_id,NULL,NULL,c.TermUS COLLATE Latin1_General_100_BIN2,c.TermNormUS COLLATE Latin1_General_100_BIN2,NULL,
        0,'uncoded_term',COALESCE(c.term_source,'icdo_coding_page'),NULL,NULL,
        'icdo_coding_page',NULL,NULL,'page_icdo_codes',
        COALESCE(c.term_role, 'uncoded_preferred'),
        COALESCE(c.term_source, 'icdo_coding_page'),
        c.section_heading
 FROM dbo.page_icdo_codes c
 WHERE c.TermUS IS NOT NULL AND NULLIF(TRIM(COALESCE(c.icdo_code_raw,c.icdo_code)),'') IS NULL
 UNION ALL
 SELECT m.page_id,m.edition,m.suggested_code,m.TermUS COLLATE Latin1_General_100_BIN2,m.TermNormUS COLLATE Latin1_General_100_BIN2,m.candidateTermUS,m.is_subtype,
        'candidate',m.source_kind,m.suggested_qualifier,m.match_type,m.terminology_kind,
        m.conditions,m.review_status,m.term_table,
        m.term_role,COALESCE(m.source_kind, 'parsed_entity'),
        CASE WHEN m.term_table='entity_related_terms' THEN 'Related terminology'
             WHEN m.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END
 FROM dbo.v_entity_term_code_matches m
 WHERE m.match_id IS NOT NULL
 UNION ALL
 SELECT t.page_id,NULL,NULL,t.TermUS COLLATE Latin1_General_100_BIN2,t.TermNormUS COLLATE Latin1_General_100_BIN2,NULL,t.is_subtype,'uncoded_term',
        COALESCE(p.source_kind,'parsed_entity'),p.suggested_qualifier,NULL,t.terminology_kind,
        NULL,p.review_status,t.term_table,
        t.term_role,COALESCE(p.source_kind, 'parsed_entity'),
        CASE WHEN t.term_table='entity_related_terms' THEN 'Related terminology'
             WHEN t.is_subtype=1 THEN 'Subtype(s)' ELSE 'ICD-O coding' END
 FROM dbo.v_entity_terms t LEFT JOIN dbo.entity_term_provenance p
 ON p.provenance_id=(SELECT MIN(p2.provenance_id) FROM dbo.entity_term_provenance p2
 WHERE p2.page_id=t.page_id AND
 ((t.term_table='entity_codes' AND p2.entity_code_id=t.term_id) OR
  (t.term_table='entity_related_terms' AND p2.related_term_id=t.term_id)))
 WHERE t.source_code IS NULL OR TRIM(t.source_code)=''
),
key_rows AS (
 SELECT page_id,edition,code,TermUS,MAX(TermNormUS) AS TermNormUS,
        MAX(is_subtype) AS is_subtype,
        MAX(term_role) AS term_role FROM raw_rows
 WHERE NOT (code IS NULL AND EXISTS(
   SELECT 1 FROM raw_rows coded WHERE coded.page_id=raw_rows.page_id
   AND coded.TermUS=raw_rows.TermUS AND coded.code IS NOT NULL))
 GROUP BY page_id,edition,code,TermUS
),
candidate_labels AS (
 SELECT DISTINCT page_id,edition,code,TermUS,candidateTermUS FROM raw_rows
 WHERE candidateTermUS IS NOT NULL
),
tags AS (SELECT page_id,edition,code,TermUS,v.field,v.value FROM raw_rows CROSS APPLY (VALUES ('code_kind',CAST(code_kind AS NVARCHAR(MAX))),('source_kind',CAST(source_kind AS NVARCHAR(MAX))),('suggested_qualifier',CAST(suggested_qualifier AS NVARCHAR(MAX))),('match_type',CAST(match_type AS NVARCHAR(MAX))),('terminology_kind',CAST(terminology_kind AS NVARCHAR(MAX))),('conditions',CAST(conditions AS NVARCHAR(MAX))),('review_status',CAST(review_status AS NVARCHAR(MAX))),('term_table',CAST(term_table AS NVARCHAR(MAX))),('term_role',CAST(term_role AS NVARCHAR(MAX))),('term_source',CAST(term_source AS NVARCHAR(MAX)))) v(field,value) WHERE v.value IS NOT NULL AND v.value<>''),
distinct_tags AS (
 SELECT DISTINCT page_id,edition,code,TermUS,field,value FROM tags
),
tag_text AS (
 SELECT page_id,edition,code,TermUS,field,STRING_AGG(CAST(value AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY value) AS values_text
 FROM distinct_tags GROUP BY page_id,edition,code,TermUS,field
),
metadata AS (
 SELECT page_id,edition,code,TermUS,MAX(CASE WHEN field='code_kind' THEN values_text END) AS code_kind,
       MAX(CASE WHEN field='source_kind' THEN values_text END) AS source_kind,
       MAX(CASE WHEN field='suggested_qualifier' THEN values_text END) AS suggested_qualifier,
       MAX(CASE WHEN field='match_type' THEN values_text END) AS match_type,
       MAX(CASE WHEN field='terminology_kind' THEN values_text END) AS terminology_kind,
       MAX(CASE WHEN field='conditions' THEN values_text END) AS conditions,
       MAX(CASE WHEN field='review_status' THEN values_text END) AS review_status,
       MAX(CASE WHEN field='term_table' THEN values_text END) AS term_table,
       MAX(CASE WHEN field='term_role' THEN values_text END) AS term_role,
       MAX(CASE WHEN field='term_source' THEN values_text END) AS term_source
 FROM tag_text GROUP BY page_id,edition,code,TermUS
),
section_rows AS (
 SELECT DISTINCT page_id,edition,code,TermUS,section_heading FROM raw_rows
 WHERE section_heading IS NOT NULL AND TRIM(section_heading)<>''
),
section_text AS (
 SELECT page_id,edition,code,TermUS,STRING_AGG(CAST(section_heading AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY section_heading) AS page_sections
 FROM section_rows GROUP BY page_id,edition,code,TermUS
),
site_rows AS (
 SELECT page_id,c_code,MAX(confidence_score) AS confidence_score
 FROM dbo.page_site_hints WHERE confidence_score>=0.9 GROUP BY page_id,c_code
),
site_text AS (
 SELECT page_id,STRING_AGG(CAST(c_code AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY c_code) AS candidate_topography_codes,
        MIN(confidence_score) AS site_confidence_min,MAX(confidence_score) AS site_confidence_max
 FROM site_rows GROUP BY page_id
)
SELECT b.alias AS alias,b.title AS book_name,b.book_id,b.edition,k.page_id,
       COALESCE(ch.title,ep.chapter) AS chapter,ch.ord AS ch_order,
       pg.title AS page_title,pg.url AS page_url,
       s.page_sections,k.TermUS,k.TermNormUS,candidate.candidateTermUS,k.edition AS code_edition,
       CASE WHEN k.edition='ICD-O-3.2' THEN k.code END AS ICDO32,
       CASE WHEN k.edition='ICD-O-4' THEN k.code END AS ICDO4,
       k.code AS morphology_code,
       CASE WHEN k.term_role IN ('subtype','uncoded_subtype','icdo_indent_subtype','subtype_section') OR k.is_subtype=1 THEN 1 ELSE 0 END AS is_subtype,
       k.term_role,m.term_source,m.code_kind,m.source_kind,
       m.suggested_qualifier,m.match_type,m.terminology_kind,m.conditions,m.review_status,
       m.term_table AS source_tables,sites.candidate_topography_codes,
       sites.site_confidence_min,sites.site_confidence_max
FROM key_rows k JOIN dbo.pages pg ON pg.page_id=k.page_id
JOIN dbo.books b ON b.book_id=pg.book_id
LEFT JOIN dbo.chapters ch ON ch.chapter_id=pg.chapter_id
LEFT JOIN dbo.entity_pages ep ON ep.page_id=k.page_id
LEFT JOIN candidate_labels candidate ON candidate.page_id=k.page_id
 AND candidate.edition=k.edition AND candidate.code=k.code AND candidate.TermUS=k.TermUS
LEFT JOIN metadata m ON m.page_id=k.page_id AND m.TermUS=k.TermUS
 AND (m.edition=k.edition OR (m.edition IS NULL AND k.edition IS NULL))
 AND (m.code=k.code OR (m.code IS NULL AND k.code IS NULL))
LEFT JOIN section_text s ON s.page_id=k.page_id AND s.TermUS=k.TermUS
 AND (s.edition=k.edition OR (s.edition IS NULL AND k.edition IS NULL))
 AND (s.code=k.code OR (s.code IS NULL AND k.code IS NULL))
LEFT JOIN site_text sites ON sites.page_id=k.page_id
GO

CREATE OR ALTER VIEW dbo.v_legacy_entity_terms AS
SELECT 'entity_codes' AS term_table,entity_code_id AS term_id,page_id,term,TermUS,TermNormUS,
       code AS source_code,is_subtype,
       COALESCE(term_role, CASE WHEN is_subtype=1 THEN 'subtype' ELSE 'preferred' END) AS term_role,
       'coding' AS terminology_kind
FROM dbo.entity_codes
UNION ALL
SELECT 'entity_related_terms',related_term_id,page_id,term,TermUS,TermNormUS,
       NULL,0,
       COALESCE(term_role, CASE kind WHEN 'acceptable' THEN 'related_acceptable' WHEN 'not_recommended' THEN 'related_not_recommended' ELSE 'related_unlabeled' END),
       kind FROM dbo.entity_related_terms
GO
CREATE OR ALTER VIEW dbo.v_legacy_entity_term_provenance AS
SELECT t.*,p.provenance_id,p.source_kind,p.source_table,p.source_row_id,
       p.original_text,p.recovered_term,p.suggested_qualifier,p.terminology_status,
       p.review_status,p.is_added_term,p.proposal_batch,p.note
FROM dbo.v_legacy_entity_terms t LEFT JOIN dbo.entity_term_provenance p
ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))
GO
CREATE OR ALTER VIEW dbo.v_legacy_entity_term_code_matches AS
SELECT t.*,p.source_kind,p.suggested_qualifier,p.is_added_term,p.proposal_batch,
       m.match_id,m.edition,m.code AS suggested_code,m.official_termUS AS official_term,
       m.official_termUS AS candidateTermUS,m.official_termNormUS AS candidateTermNormUS,m.official_term AS official_term_source,m.match_type,
       m.candidate_order,m.conditions,m.review_status,m.reference_file,
       m.reference_sheet,m.reference_row,m.reference_sha256,m.code_term_evidence
FROM dbo.v_legacy_entity_terms t
LEFT JOIN dbo.entity_term_provenance p ON t.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND t.term_id=p.entity_code_id) OR
  (t.term_table='entity_related_terms' AND t.term_id=p.related_term_id))
 AND p.provenance_id=(SELECT MIN(p2.provenance_id) FROM dbo.entity_term_provenance p2
 WHERE p2.page_id=p.page_id AND
 ((t.term_table='entity_codes' AND p2.entity_code_id=t.term_id) OR
  (t.term_table='entity_related_terms' AND p2.related_term_id=t.term_id)))
LEFT JOIN dbo.entity_term_code_matches m ON m.provenance_id=p.provenance_id
GO
CREATE OR ALTER VIEW dbo.v_entity_terms AS
SELECT * FROM dbo.v_legacy_entity_terms
UNION ALL
SELECT 'page_term_mentions',m.mention_id,m.page_id,m.term_original,m.TermUS,m.TermNormUS,
 m.icdo_code,CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 m.term_role,m.term_source FROM dbo.page_term_mentions m WHERE m.is_current=1
 AND NOT EXISTS(SELECT 1 FROM dbo.v_legacy_entity_terms t WHERE t.page_id=m.page_id AND t.TermUS COLLATE Latin1_General_100_BIN2=m.TermUS COLLATE Latin1_General_100_BIN2)

GO

CREATE OR ALTER VIEW dbo.v_entity_term_provenance AS
SELECT m.page_id,m.mention_id AS term_id,m.term_original AS term,m.TermUS,m.TermNormUS,
 m.icdo_code AS source_code,m.observation_key,m.source_locator,m.term_origin AS source_kind,
 m.term_source,m.source_heading,m.snippet AS original_text,m.context_class,
 m.extraction_tier,m.review_status,m.is_current
FROM dbo.page_term_mentions m

GO

CREATE OR ALTER VIEW dbo.v_entity_term_code_matches AS
SELECT 'page_term_mentions' AS term_table,m.mention_id AS term_id,m.page_id,
 m.term_original AS term,m.TermUS,m.TermNormUS,m.icdo_code AS source_code,
 CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END AS is_subtype,
 m.term_role,m.term_source AS terminology_kind,m.term_origin AS source_kind,
 m.term_role AS suggested_qualifier,CASE WHEN m.term_origin='legacy_import' THEN 1 ELSE 0 END AS is_added_term,
 CAST(NULL AS VARCHAR(60)) AS proposal_batch,c.candidate_id AS match_id,
 e.edition,c.code AS suggested_code,c.candidateTermUS AS official_term,
 c.candidateTermUS,c.candidateTermNormUS,c.official_term AS official_term_source,
 c.match_type,c.candidate_order,c.conditions,c.review_status,
 COALESCE(JSON_VALUE(c.reference_evidence,'$[0].file'),JSON_VALUE(c.reference_evidence,'$.file'),JSON_VALUE(c.reference_evidence,'$.support[0].file')) AS reference_file,COALESCE(JSON_VALUE(c.reference_evidence,'$[0].sheet'),JSON_VALUE(c.reference_evidence,'$.sheet'),JSON_VALUE(c.reference_evidence,'$.support[0].sheet')) AS reference_sheet,
 TRY_CONVERT(INT,COALESCE(JSON_VALUE(c.reference_evidence,'$[0].row'),JSON_VALUE(c.reference_evidence,'$.row'),JSON_VALUE(c.reference_evidence,'$.support[0].row'))) AS reference_row,e.reference_sha256,c.reference_evidence AS code_term_evidence,
 e.outcome,e.is_current,m.observation_key,c.candidate_key
FROM dbo.page_term_mentions m
JOIN dbo.term_lookup_evaluations e ON e.mention_id=m.mention_id
LEFT JOIN dbo.term_code_candidates c ON c.evaluation_id=e.evaluation_id

GO

CREATE OR ALTER VIEW dbo.v_term_candidate_evidence AS
SELECT m.page_id,m.observation_key,m.source_locator,m.term_origin,m.term_source,
 m.context_class,m.extraction_tier,m.snippet,m.TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,m.TermNormUS,
 e.edition,e.outcome,e.reference_sha256,e.matcher_version,e.is_current,e.evidence_hash,e.detail,
 c.candidate_key,c.code,c.candidateTermUS,c.match_type,c.evidence_tier,
 c.conditions,c.reference_evidence,c.review_status
FROM dbo.page_term_mentions m
JOIN dbo.term_lookup_evaluations e ON e.mention_id=m.mention_id
LEFT JOIN dbo.term_code_candidates c ON c.evaluation_id=e.evaluation_id

GO

CREATE OR ALTER VIEW dbo.v_page_code_terms AS
WITH evaluation_outcomes AS (
 SELECT m.page_id,m.TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,e.edition,
 MAX(e.outcome COLLATE Latin1_General_100_BIN2) AS outcome
 FROM dbo.page_term_mentions m
 JOIN dbo.term_lookup_evaluations e ON e.mention_id=m.mention_id AND e.is_current=1
 GROUP BY m.page_id,m.TermUS COLLATE Latin1_General_100_BIN2,e.edition
),
candidate_keys AS (
 SELECT DISTINCT m.page_id,m.TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,c.code
 FROM dbo.page_term_mentions m
 JOIN dbo.term_lookup_evaluations e ON e.mention_id=m.mention_id AND e.is_current=1
 JOIN dbo.term_code_candidates c ON c.evaluation_id=e.evaluation_id
 WHERE c.review_status<>'rejected'
),
source_keys AS (
 SELECT page_id,TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,code FROM dbo.entity_codes
 UNION
 SELECT page_id,TermUS COLLATE Latin1_General_100_BIN2,COALESCE(icdo_code_raw,icdo_code) FROM dbo.page_icdo_codes
),
raw AS (
 SELECT c.page_id,c.TermUS COLLATE Latin1_General_100_BIN2 AS TermUS,c.TermNormUS,
 CASE WHEN LEN(c.code)=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END AS code_edition,
 c.code,NULL AS candidateTermUS,0 AS is_proposed_code,0 AS is_proposed_term,
 'source_assignment' AS code_kind,'source' AS source_kind,
 c.term_role,CAST(c.is_subtype AS INT) AS is_subtype,
 'coding_section' AS term_source,'entity_codes' AS source_tables,
 'ICD-O coding' AS page_sections,'coding' AS terminology_kind,
 COALESCE(o.outcome,'not_evaluated') AS lookup_outcome,
 NULL AS match_type,NULL AS conditions,NULL AS review_status
 FROM dbo.entity_codes c
 LEFT JOIN evaluation_outcomes o ON o.page_id=c.page_id AND o.TermUS=c.TermUS COLLATE Latin1_General_100_BIN2
 AND o.edition=CASE WHEN LEN(c.code)=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END
 LEFT JOIN candidate_keys k ON k.page_id=c.page_id AND k.TermUS=c.TermUS COLLATE Latin1_General_100_BIN2 AND k.code=c.code
 WHERE c.code IS NOT NULL AND TRIM(c.code)<>'' AND k.code IS NULL
 UNION ALL
 SELECT p.page_id,p.TermUS,p.TermNormUS,
 CASE WHEN LEN(COALESCE(p.icdo_code_raw,p.icdo_code))=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END,
 COALESCE(p.icdo_code_raw,p.icdo_code),NULL,0,0,'contextual_code','source',
 p.term_role,CASE WHEN p.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 p.term_source,'page_icdo_codes',p.section_heading,'coding',
 COALESCE(o.outcome,'not_evaluated'),NULL,NULL,NULL
 FROM dbo.page_icdo_codes p
 LEFT JOIN evaluation_outcomes o ON o.page_id=p.page_id AND o.TermUS=p.TermUS COLLATE Latin1_General_100_BIN2
 AND o.edition=CASE WHEN LEN(COALESCE(p.icdo_code_raw,p.icdo_code))=6 THEN 'ICD-O-3.2' ELSE 'ICD-O-4' END
 LEFT JOIN candidate_keys k ON k.page_id=p.page_id AND k.TermUS=p.TermUS COLLATE Latin1_General_100_BIN2
 AND k.code=COALESCE(p.icdo_code_raw,p.icdo_code)
 WHERE COALESCE(p.icdo_code_raw,p.icdo_code) IS NOT NULL
 AND p.TermUS IS NOT NULL
 AND k.code IS NULL
 UNION ALL
 SELECT m.page_id,m.TermUS,m.TermNormUS,e.edition,c.code,c.candidateTermUS COLLATE Latin1_General_100_BIN2,
 CASE WHEN c.code IS NOT NULL AND s.code IS NULL THEN 1 ELSE 0 END,
 CASE WHEN c.candidateTermUS IS NOT NULL AND c.candidateTermUS COLLATE Latin1_General_100_BIN2<>m.TermUS COLLATE Latin1_General_100_BIN2 THEN 1 ELSE 0 END,
 CASE WHEN c.code IS NULL THEN 'uncoded_term' ELSE 'candidate' END,m.term_origin,
 m.term_role,CASE WHEN m.term_role LIKE '%subtype%' THEN 1 ELSE 0 END,
 m.term_source,'page_term_mentions',m.source_heading,
 CASE WHEN m.term_source='related_terminology' THEN
 CASE m.term_role WHEN 'synonym' THEN 'acceptable' WHEN 'not_recommended' THEN 'not_recommended' ELSE 'other' END
 WHEN m.term_source IN ('coding_section','coding_page') THEN 'coding'
 WHEN m.term_source='page_title' THEN 'title' ELSE 'contextual' END,
 e.outcome,c.match_type,c.conditions,c.review_status
 FROM dbo.page_term_mentions m JOIN dbo.term_lookup_evaluations e
 ON e.mention_id=m.mention_id AND e.is_current=1
 LEFT JOIN dbo.term_code_candidates c ON c.evaluation_id=e.evaluation_id AND c.review_status<>'rejected'
 LEFT JOIN source_keys s ON s.page_id=m.page_id AND s.TermUS=m.TermUS COLLATE Latin1_General_100_BIN2 AND s.code=c.code
 WHERE m.is_current=1 AND m.review_status<>'rejected'
),
grain AS (
 SELECT page_id,TermUS,TermNormUS,code_edition,code,candidateTermUS,
 MAX(is_proposed_code) AS is_proposed_code,MAX(is_proposed_term) AS is_proposed_term,
 MAX(term_role COLLATE Latin1_General_100_BIN2) AS term_role,MAX(is_subtype) AS is_subtype,
 MAX(term_source COLLATE Latin1_General_100_BIN2) AS term_source,MAX(source_tables COLLATE Latin1_General_100_BIN2) AS source_tables,
 MAX(page_sections COLLATE Latin1_General_100_BIN2) AS page_sections,MAX(terminology_kind COLLATE Latin1_General_100_BIN2) AS terminology_kind,
 MAX(lookup_outcome COLLATE Latin1_General_100_BIN2) AS lookup_outcome,MAX(match_type COLLATE Latin1_General_100_BIN2) AS match_type,
 MAX(conditions COLLATE Latin1_General_100_BIN2) AS conditions,MAX(review_status COLLATE Latin1_General_100_BIN2) AS review_status,
 MAX(CASE WHEN code_kind IN ('source_assignment','contextual_code')
 OR (code IS NOT NULL AND is_proposed_code=0) THEN 1 ELSE 0 END) AS has_source,
 MAX(CASE WHEN code_kind='candidate' THEN 1 ELSE 0 END) AS has_candidate,
 MAX(source_kind COLLATE Latin1_General_100_BIN2) AS source_kind,
 MAX(CASE WHEN source_kind='source' THEN 1 ELSE 0 END) AS has_source_observation,
 MAX(CASE WHEN source_kind='legacy_import' THEN 1 ELSE 0 END) AS has_legacy_observation
 FROM raw GROUP BY page_id,TermUS,TermNormUS,code_edition,code,candidateTermUS
),
ranked AS (
 SELECT grain.*,MAX(CASE WHEN code IS NOT NULL THEN 1 ELSE 0 END)
 OVER (PARTITION BY page_id,TermUS,TermNormUS,code_edition) AS has_code
 FROM grain
),
edition32 AS (
 SELECT * FROM ranked WHERE code_edition='ICD-O-3.2' AND (code IS NOT NULL OR has_code=0)
),
edition4 AS (
 SELECT * FROM ranked WHERE code_edition='ICD-O-4' AND (code IS NOT NULL OR has_code=0)
),
paired AS (
 SELECT a.page_id,a.TermUS,a.TermNormUS,
 a.code AS ICDO32,z.code AS ICDO4,
 COALESCE(z.candidateTermUS,a.candidateTermUS) AS candidateTermUS,
 CASE WHEN a.term_role IS NULL THEN z.term_role WHEN z.term_role IS NULL OR a.term_role COLLATE Latin1_General_100_BIN2=z.term_role COLLATE Latin1_General_100_BIN2 THEN a.term_role WHEN a.term_role COLLATE Latin1_General_100_BIN2<z.term_role COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.term_role,N'; ',z.term_role) ELSE CONCAT(z.term_role,N'; ',a.term_role) END AS term_role,
 CASE WHEN a.term_source IS NULL THEN z.term_source WHEN z.term_source IS NULL OR a.term_source COLLATE Latin1_General_100_BIN2=z.term_source COLLATE Latin1_General_100_BIN2 THEN a.term_source WHEN a.term_source COLLATE Latin1_General_100_BIN2<z.term_source COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.term_source,N'; ',z.term_source) ELSE CONCAT(z.term_source,N'; ',a.term_source) END AS term_source,
 CASE WHEN a.source_tables IS NULL THEN z.source_tables WHEN z.source_tables IS NULL OR a.source_tables COLLATE Latin1_General_100_BIN2=z.source_tables COLLATE Latin1_General_100_BIN2 THEN a.source_tables WHEN a.source_tables COLLATE Latin1_General_100_BIN2<z.source_tables COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.source_tables,N'; ',z.source_tables) ELSE CONCAT(z.source_tables,N'; ',a.source_tables) END AS source_tables,
 CASE WHEN a.page_sections IS NULL THEN z.page_sections WHEN z.page_sections IS NULL OR a.page_sections COLLATE Latin1_General_100_BIN2=z.page_sections COLLATE Latin1_General_100_BIN2 THEN a.page_sections WHEN a.page_sections COLLATE Latin1_General_100_BIN2<z.page_sections COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.page_sections,N'; ',z.page_sections) ELSE CONCAT(z.page_sections,N'; ',a.page_sections) END AS page_sections,
 CASE WHEN a.terminology_kind IS NULL THEN z.terminology_kind WHEN z.terminology_kind IS NULL OR a.terminology_kind COLLATE Latin1_General_100_BIN2=z.terminology_kind COLLATE Latin1_General_100_BIN2 THEN a.terminology_kind WHEN a.terminology_kind COLLATE Latin1_General_100_BIN2<z.terminology_kind COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.terminology_kind,N'; ',z.terminology_kind) ELSE CONCAT(z.terminology_kind,N'; ',a.terminology_kind) END AS terminology_kind,
 CASE WHEN a.lookup_outcome IS NULL THEN z.lookup_outcome WHEN z.lookup_outcome IS NULL OR a.lookup_outcome COLLATE Latin1_General_100_BIN2=z.lookup_outcome COLLATE Latin1_General_100_BIN2 THEN a.lookup_outcome WHEN a.lookup_outcome COLLATE Latin1_General_100_BIN2<z.lookup_outcome COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.lookup_outcome,N'; ',z.lookup_outcome) ELSE CONCAT(z.lookup_outcome,N'; ',a.lookup_outcome) END AS lookup_outcome,
 CASE WHEN a.match_type IS NULL THEN z.match_type WHEN z.match_type IS NULL OR a.match_type COLLATE Latin1_General_100_BIN2=z.match_type COLLATE Latin1_General_100_BIN2 THEN a.match_type WHEN a.match_type COLLATE Latin1_General_100_BIN2<z.match_type COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.match_type,N'; ',z.match_type) ELSE CONCAT(z.match_type,N'; ',a.match_type) END AS match_type,
 CASE WHEN a.conditions IS NULL THEN z.conditions WHEN z.conditions IS NULL OR a.conditions COLLATE Latin1_General_100_BIN2=z.conditions COLLATE Latin1_General_100_BIN2 THEN a.conditions WHEN a.conditions COLLATE Latin1_General_100_BIN2<z.conditions COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.conditions,N'; ',z.conditions) ELSE CONCAT(z.conditions,N'; ',a.conditions) END AS conditions,
 CASE WHEN a.review_status IS NULL THEN z.review_status WHEN z.review_status IS NULL OR a.review_status COLLATE Latin1_General_100_BIN2=z.review_status COLLATE Latin1_General_100_BIN2 THEN a.review_status WHEN a.review_status COLLATE Latin1_General_100_BIN2<z.review_status COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.review_status,N'; ',z.review_status) ELSE CONCAT(z.review_status,N'; ',a.review_status) END AS review_status,
 CASE WHEN a.source_kind IS NULL THEN z.source_kind WHEN z.source_kind IS NULL OR a.source_kind COLLATE Latin1_General_100_BIN2=z.source_kind COLLATE Latin1_General_100_BIN2 THEN a.source_kind WHEN a.source_kind COLLATE Latin1_General_100_BIN2<z.source_kind COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.source_kind,N'; ',z.source_kind) ELSE CONCAT(z.source_kind,N'; ',a.source_kind) END AS source_kind,
 CASE WHEN COALESCE(a.is_proposed_code,0)>COALESCE(z.is_proposed_code,0) THEN COALESCE(a.is_proposed_code,0) ELSE COALESCE(z.is_proposed_code,0) END AS is_proposed_code,
 CASE WHEN COALESCE(a.is_proposed_term,0)>COALESCE(z.is_proposed_term,0) THEN COALESCE(a.is_proposed_term,0) ELSE COALESCE(z.is_proposed_term,0) END AS is_proposed_term,
 CASE WHEN COALESCE(a.is_subtype,0)>COALESCE(z.is_subtype,0) THEN COALESCE(a.is_subtype,0) ELSE COALESCE(z.is_subtype,0) END AS is_subtype,
 CASE WHEN COALESCE(a.has_source,0)>COALESCE(z.has_source,0) THEN COALESCE(a.has_source,0) ELSE COALESCE(z.has_source,0) END AS has_source,
 CASE WHEN COALESCE(a.has_candidate,0)>COALESCE(z.has_candidate,0) THEN COALESCE(a.has_candidate,0) ELSE COALESCE(z.has_candidate,0) END AS has_candidate,
 CASE WHEN COALESCE(a.has_source_observation,0)>COALESCE(z.has_source_observation,0) THEN COALESCE(a.has_source_observation,0) ELSE COALESCE(z.has_source_observation,0) END AS has_source_observation,
 CASE WHEN COALESCE(a.has_legacy_observation,0)>COALESCE(z.has_legacy_observation,0) THEN COALESCE(a.has_legacy_observation,0) ELSE COALESCE(z.has_legacy_observation,0) END AS has_legacy_observation,
 a.candidateTermUS AS candidateTermUS32,
 a.is_proposed_code AS is_proposed_code32,
 a.is_proposed_term AS is_proposed_term32,
 a.lookup_outcome AS lookup_outcome32,
 a.match_type AS match_type32,
 a.conditions AS conditions32,
 a.review_status AS review_status32,
 z.candidateTermUS AS candidateTermUS4,
 z.is_proposed_code AS is_proposed_code4,
 z.is_proposed_term AS is_proposed_term4,
 z.lookup_outcome AS lookup_outcome4,
 z.match_type AS match_type4,
 z.conditions AS conditions4,
 z.review_status AS review_status4
 FROM edition32 a LEFT JOIN edition4 z
 ON z.page_id=a.page_id AND z.TermUS=a.TermUS
 UNION ALL
 SELECT z.page_id,z.TermUS,z.TermNormUS,
 a.code AS ICDO32,z.code AS ICDO4,
 COALESCE(z.candidateTermUS,a.candidateTermUS) AS candidateTermUS,
 CASE WHEN a.term_role IS NULL THEN z.term_role WHEN z.term_role IS NULL OR a.term_role COLLATE Latin1_General_100_BIN2=z.term_role COLLATE Latin1_General_100_BIN2 THEN a.term_role WHEN a.term_role COLLATE Latin1_General_100_BIN2<z.term_role COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.term_role,N'; ',z.term_role) ELSE CONCAT(z.term_role,N'; ',a.term_role) END AS term_role,
 CASE WHEN a.term_source IS NULL THEN z.term_source WHEN z.term_source IS NULL OR a.term_source COLLATE Latin1_General_100_BIN2=z.term_source COLLATE Latin1_General_100_BIN2 THEN a.term_source WHEN a.term_source COLLATE Latin1_General_100_BIN2<z.term_source COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.term_source,N'; ',z.term_source) ELSE CONCAT(z.term_source,N'; ',a.term_source) END AS term_source,
 CASE WHEN a.source_tables IS NULL THEN z.source_tables WHEN z.source_tables IS NULL OR a.source_tables COLLATE Latin1_General_100_BIN2=z.source_tables COLLATE Latin1_General_100_BIN2 THEN a.source_tables WHEN a.source_tables COLLATE Latin1_General_100_BIN2<z.source_tables COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.source_tables,N'; ',z.source_tables) ELSE CONCAT(z.source_tables,N'; ',a.source_tables) END AS source_tables,
 CASE WHEN a.page_sections IS NULL THEN z.page_sections WHEN z.page_sections IS NULL OR a.page_sections COLLATE Latin1_General_100_BIN2=z.page_sections COLLATE Latin1_General_100_BIN2 THEN a.page_sections WHEN a.page_sections COLLATE Latin1_General_100_BIN2<z.page_sections COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.page_sections,N'; ',z.page_sections) ELSE CONCAT(z.page_sections,N'; ',a.page_sections) END AS page_sections,
 CASE WHEN a.terminology_kind IS NULL THEN z.terminology_kind WHEN z.terminology_kind IS NULL OR a.terminology_kind COLLATE Latin1_General_100_BIN2=z.terminology_kind COLLATE Latin1_General_100_BIN2 THEN a.terminology_kind WHEN a.terminology_kind COLLATE Latin1_General_100_BIN2<z.terminology_kind COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.terminology_kind,N'; ',z.terminology_kind) ELSE CONCAT(z.terminology_kind,N'; ',a.terminology_kind) END AS terminology_kind,
 CASE WHEN a.lookup_outcome IS NULL THEN z.lookup_outcome WHEN z.lookup_outcome IS NULL OR a.lookup_outcome COLLATE Latin1_General_100_BIN2=z.lookup_outcome COLLATE Latin1_General_100_BIN2 THEN a.lookup_outcome WHEN a.lookup_outcome COLLATE Latin1_General_100_BIN2<z.lookup_outcome COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.lookup_outcome,N'; ',z.lookup_outcome) ELSE CONCAT(z.lookup_outcome,N'; ',a.lookup_outcome) END AS lookup_outcome,
 CASE WHEN a.match_type IS NULL THEN z.match_type WHEN z.match_type IS NULL OR a.match_type COLLATE Latin1_General_100_BIN2=z.match_type COLLATE Latin1_General_100_BIN2 THEN a.match_type WHEN a.match_type COLLATE Latin1_General_100_BIN2<z.match_type COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.match_type,N'; ',z.match_type) ELSE CONCAT(z.match_type,N'; ',a.match_type) END AS match_type,
 CASE WHEN a.conditions IS NULL THEN z.conditions WHEN z.conditions IS NULL OR a.conditions COLLATE Latin1_General_100_BIN2=z.conditions COLLATE Latin1_General_100_BIN2 THEN a.conditions WHEN a.conditions COLLATE Latin1_General_100_BIN2<z.conditions COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.conditions,N'; ',z.conditions) ELSE CONCAT(z.conditions,N'; ',a.conditions) END AS conditions,
 CASE WHEN a.review_status IS NULL THEN z.review_status WHEN z.review_status IS NULL OR a.review_status COLLATE Latin1_General_100_BIN2=z.review_status COLLATE Latin1_General_100_BIN2 THEN a.review_status WHEN a.review_status COLLATE Latin1_General_100_BIN2<z.review_status COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.review_status,N'; ',z.review_status) ELSE CONCAT(z.review_status,N'; ',a.review_status) END AS review_status,
 CASE WHEN a.source_kind IS NULL THEN z.source_kind WHEN z.source_kind IS NULL OR a.source_kind COLLATE Latin1_General_100_BIN2=z.source_kind COLLATE Latin1_General_100_BIN2 THEN a.source_kind WHEN a.source_kind COLLATE Latin1_General_100_BIN2<z.source_kind COLLATE Latin1_General_100_BIN2 THEN CONCAT(a.source_kind,N'; ',z.source_kind) ELSE CONCAT(z.source_kind,N'; ',a.source_kind) END AS source_kind,
 CASE WHEN COALESCE(a.is_proposed_code,0)>COALESCE(z.is_proposed_code,0) THEN COALESCE(a.is_proposed_code,0) ELSE COALESCE(z.is_proposed_code,0) END AS is_proposed_code,
 CASE WHEN COALESCE(a.is_proposed_term,0)>COALESCE(z.is_proposed_term,0) THEN COALESCE(a.is_proposed_term,0) ELSE COALESCE(z.is_proposed_term,0) END AS is_proposed_term,
 CASE WHEN COALESCE(a.is_subtype,0)>COALESCE(z.is_subtype,0) THEN COALESCE(a.is_subtype,0) ELSE COALESCE(z.is_subtype,0) END AS is_subtype,
 CASE WHEN COALESCE(a.has_source,0)>COALESCE(z.has_source,0) THEN COALESCE(a.has_source,0) ELSE COALESCE(z.has_source,0) END AS has_source,
 CASE WHEN COALESCE(a.has_candidate,0)>COALESCE(z.has_candidate,0) THEN COALESCE(a.has_candidate,0) ELSE COALESCE(z.has_candidate,0) END AS has_candidate,
 CASE WHEN COALESCE(a.has_source_observation,0)>COALESCE(z.has_source_observation,0) THEN COALESCE(a.has_source_observation,0) ELSE COALESCE(z.has_source_observation,0) END AS has_source_observation,
 CASE WHEN COALESCE(a.has_legacy_observation,0)>COALESCE(z.has_legacy_observation,0) THEN COALESCE(a.has_legacy_observation,0) ELSE COALESCE(z.has_legacy_observation,0) END AS has_legacy_observation,
 a.candidateTermUS AS candidateTermUS32,
 a.is_proposed_code AS is_proposed_code32,
 a.is_proposed_term AS is_proposed_term32,
 a.lookup_outcome AS lookup_outcome32,
 a.match_type AS match_type32,
 a.conditions AS conditions32,
 a.review_status AS review_status32,
 z.candidateTermUS AS candidateTermUS4,
 z.is_proposed_code AS is_proposed_code4,
 z.is_proposed_term AS is_proposed_term4,
 z.lookup_outcome AS lookup_outcome4,
 z.match_type AS match_type4,
 z.conditions AS conditions4,
 z.review_status AS review_status4
 FROM edition4 z LEFT JOIN edition32 a
 ON z.page_id=a.page_id AND z.TermUS=a.TermUS
 WHERE a.page_id IS NULL
),
site_rows AS (
 SELECT page_id,c_code,MAX(confidence_score) AS confidence_score
 FROM dbo.page_site_hints WHERE confidence_score>=0.9 GROUP BY page_id,c_code
),
site_text AS (
 SELECT page_id,STRING_AGG(CAST(c_code AS NVARCHAR(MAX)),N'; ') WITHIN GROUP (ORDER BY c_code) AS candidate_topography_codes,
 MIN(confidence_score) AS site_confidence_min,MAX(confidence_score) AS site_confidence_max
 FROM site_rows GROUP BY page_id
)
SELECT b.alias,b.title AS book_name,b.book_id,b.edition,g.page_id,
 COALESCE(ch.title,ep.chapter) AS chapter,ch.ord AS ch_order,p.title AS page_title,p.url AS page_url,
 CASE
 WHEN g.term_source IN ('coding_section','coding_page') THEN 'ICD-O coding'
 WHEN g.term_role LIKE '%subtype%' THEN 'Subtype(s)'
 WHEN g.term_source='related_terminology' THEN 'Related terminology'
 WHEN g.term_source='page_title' THEN 'Page title'
 ELSE g.page_sections
 END AS page_sections,
 g.TermUS,g.TermNormUS,g.candidateTermUS,g.ICDO32,g.ICDO4,
 COALESCE(g.ICDO4,g.ICDO32) AS morphology_code,g.is_subtype,g.term_role,g.term_source,
 CASE WHEN g.has_source=1 AND g.has_candidate=1 THEN 'source_assignment; candidate'
 WHEN g.has_source=1 THEN 'source_assignment' WHEN g.has_candidate=1 THEN 'candidate'
 ELSE 'uncoded_term' END AS code_kind,
 CASE WHEN g.has_source_observation=1 AND g.has_legacy_observation=1 THEN 'source; legacy_import'
 ELSE g.source_kind END AS source_kind,
 NULL AS suggested_qualifier,g.match_type,g.terminology_kind,g.conditions,g.review_status,
 g.source_tables,g.is_proposed_code,g.is_proposed_term,g.lookup_outcome,
 sites.candidate_topography_codes,
 CAST(sites.site_confidence_min AS FLOAT) AS site_confidence_min,
 CAST(sites.site_confidence_max AS FLOAT) AS site_confidence_max,
 g.candidateTermUS32,g.is_proposed_code32,g.is_proposed_term32,g.lookup_outcome32,g.match_type32,g.conditions32,g.review_status32,g.candidateTermUS4,g.is_proposed_code4,g.is_proposed_term4,g.lookup_outcome4,g.match_type4,g.conditions4,g.review_status4
FROM paired g JOIN dbo.pages p ON p.page_id=g.page_id
JOIN dbo.books b ON b.book_id=p.book_id
LEFT JOIN dbo.chapters ch ON ch.chapter_id=p.chapter_id
LEFT JOIN dbo.entity_pages ep ON ep.page_id=g.page_id
LEFT JOIN site_text sites ON sites.page_id=g.page_id

CREATE OR ALTER TRIGGER dbo.tr_term_review_append_only ON dbo.term_review_decisions INSTEAD OF UPDATE, DELETE AS BEGIN THROW 51000, 'Review decisions are append-only', 1; END
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_target')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_target] CHECK ((entity_code_id IS NOT NULL AND related_term_id IS NULL) OR (entity_code_id IS NULL AND related_term_id IS NOT NULL));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_source_kind')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_source_kind] CHECK (source_kind='AI_recovered_prose');
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_source_table')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_source_table] CHECK (source_table IN ('entity_codes','entity_related_terms'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_qualifier')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_qualifier] CHECK (suggested_qualifier IN ('synonym','related','subtype','grouper','other'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_terminology_status')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_terminology_status] CHECK (terminology_status IN ('historical','unspecified'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_review')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_review] CHECK (review_status IN ('proposed','approved','rejected','needs_review'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_provenance') AND name='ck_local_entity_term_provenance_added')
ALTER TABLE dbo.[entity_term_provenance] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_provenance_added] CHECK (is_added_term IN (0,1));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND name='ck_local_entity_term_code_matches_edition')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_code_matches_edition] CHECK (edition IN ('ICD-O-3.2','ICD-O-4'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND name='ck_local_entity_term_code_matches_match_type')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_code_matches_match_type] CHECK (match_type IN ('exact','synonym','broader','narrower','conditional'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND name='ck_local_entity_term_code_matches_order')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_code_matches_order] CHECK (candidate_order>0);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND name='ck_local_entity_term_code_matches_reference_row')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_code_matches_reference_row] CHECK (reference_row>0);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.entity_term_code_matches') AND name='ck_local_entity_term_code_matches_review')
ALTER TABLE dbo.[entity_term_code_matches] WITH CHECK ADD CONSTRAINT [ck_local_entity_term_code_matches_review] CHECK (review_status IN ('proposed','approved','rejected','needs_review'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_reference_rows') AND name='ck_local_term_reference_rows_edition')
ALTER TABLE dbo.[term_reference_rows] WITH CHECK ADD CONSTRAINT [ck_local_term_reference_rows_edition] CHECK ([edition] IN ('ICD-O-3.2','ICD-O-4'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_reference_rows') AND name='ck_local_term_reference_rows_reference_row')
ALTER TABLE dbo.[term_reference_rows] WITH CHECK ADD CONSTRAINT [ck_local_term_reference_rows_reference_row] CHECK ([reference_row]>0);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_reference_rows') AND name='ck_local_term_reference_rows_reference_sha256')
ALTER TABLE dbo.[term_reference_rows] WITH CHECK ADD CONSTRAINT [ck_local_term_reference_rows_reference_sha256] CHECK (LEN([reference_sha256])=64);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND name='ck_local_term_lookup_evaluations_edition')
ALTER TABLE dbo.[term_lookup_evaluations] WITH CHECK ADD CONSTRAINT [ck_local_term_lookup_evaluations_edition] CHECK ([edition] IN ('ICD-O-3.2','ICD-O-4'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND name='ck_local_term_lookup_evaluations_outcome')
ALTER TABLE dbo.[term_lookup_evaluations] WITH CHECK ADD CONSTRAINT [ck_local_term_lookup_evaluations_outcome] CHECK ([outcome] IN ('matched','ambiguous','no_match','not_applicable','needs_review','not_evaluated'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND name='ck_local_term_lookup_evaluations_current')
ALTER TABLE dbo.[term_lookup_evaluations] WITH CHECK ADD CONSTRAINT [ck_local_term_lookup_evaluations_current] CHECK ([is_current] IN (0,1));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_lookup_evaluations') AND name='ck_local_term_lookup_evaluations_hashes')
ALTER TABLE dbo.[term_lookup_evaluations] WITH CHECK ADD CONSTRAINT [ck_local_term_lookup_evaluations_hashes] CHECK (LEN([reference_sha256])=64 AND LEN([evidence_hash])=64);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_code_candidates') AND name='ck_local_term_code_candidates_match_type')
ALTER TABLE dbo.[term_code_candidates] WITH CHECK ADD CONSTRAINT [ck_local_term_code_candidates_match_type] CHECK ([match_type] IN ('exact','synonym','normalized','broader','narrower','conditional','legacy_curated'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_code_candidates') AND name='ck_local_term_code_candidates_evidence_tier')
ALTER TABLE dbo.[term_code_candidates] WITH CHECK ADD CONSTRAINT [ck_local_term_code_candidates_evidence_tier] CHECK ([evidence_tier] IN ('structured','supported_span','interpretation','curated_review'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_code_candidates') AND name='ck_local_term_code_candidates_candidate_order')
ALTER TABLE dbo.[term_code_candidates] WITH CHECK ADD CONSTRAINT [ck_local_term_code_candidates_candidate_order] CHECK ([candidate_order]>0);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_code_candidates') AND name='ck_local_term_code_candidates_review_status')
ALTER TABLE dbo.[term_code_candidates] WITH CHECK ADD CONSTRAINT [ck_local_term_code_candidates_review_status] CHECK ([review_status] IN ('proposed','approved','rejected','needs_review'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_review_decisions') AND name='ck_local_term_review_decisions_scope')
ALTER TABLE dbo.[term_review_decisions] WITH CHECK ADD CONSTRAINT [ck_local_term_review_decisions_scope] CHECK ([scope] IN ('observation','page_context','candidate','term_edition_code','global_extraction'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_review_decisions') AND name='ck_local_term_review_decisions_outcome')
ALTER TABLE dbo.[term_review_decisions] WITH CHECK ADD CONSTRAINT [ck_local_term_review_decisions_outcome] CHECK ([outcome] IN ('approved','rejected','needs_review','proposed'));
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_review_decisions') AND name='ck_local_term_review_decisions_evidence_hash')
ALTER TABLE dbo.[term_review_decisions] WITH CHECK ADD CONSTRAINT [ck_local_term_review_decisions_evidence_hash] CHECK (LEN([evidence_hash])=64);
GO
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.term_pipeline_migrations') AND name='ck_local_term_pipeline_migrations_imported_rows')
ALTER TABLE dbo.[term_pipeline_migrations] WITH CHECK ADD CONSTRAINT [ck_local_term_pipeline_migrations_imported_rows] CHECK ([imported_rows]>=0);
GO