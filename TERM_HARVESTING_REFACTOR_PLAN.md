# Term harvesting and ICD-O proposal refactor

Updated: 2026-10-14

Status: planning only; implementation not authorized.

This is the maintained plan for the crawler and companion notebook repository,
and for both SQLite and SQL Server databases. Update it as implementation
decisions, validation results, or scope change. No migration or cleanup has been
performed as part of writing this plan.

## Change summary

- Revised: legacy recovery replay is a temporary migration input, not a permanent
  step in the new processing pipeline.
- Added: explicit evidence sources and limits on external searches.
- Added: contextual extraction, explainable rating, and scoped review feedback.
- Added: query-driven indexes and query-plan validation.
- Added: notebook and Markdown support as acceptance requirements.
- Added: pre-implementation commit and annotated milestone-tag gate.
- Added: a [repository-local subtitle issue](issues/subtitle-capture-audit.md);
  GitHub filing is blocked by the absence of a configured remote or confirmed
  target repository.

## 1. Scope and baseline

The audit found 1,542 recognized entity-page title instances absent from the same
page's canonical vocabulary, representing 1,246 distinct normalized titles.
Of these pages, 168 have no harvested vocabulary. These are vocabulary omissions,
not evidence that all titles are distinct codeable tumor diagnoses.

Review the separate 655-page extraction-exclusion inventory selectively.
Previously confirmed blank pages require no recovery. Preserve administrative
and frontmatter exclusions.

The initial implementation covers:

- Eligible entity titles.
- Coding-section labels, subtypes, and related terminology.
- Embedded known-reference terminology in saved BB prose.
- Independent ICD-O-3.2 and ICD-O-4 proposals.
- Explicit evaluation outcomes, evidence, and review workflows.
- Consistent database, view, spreadsheet, and notebook output.

Subtitle harvesting is deferred to the issue draft below.

## 2. Pre-implementation gate

Before extensive implementation:

1. Inspect both worktrees and separate relevant existing changes from unrelated
   work. Do not stage unrelated changes automatically.
2. Validate the current view corrections with focused checks.
3. Inspect staged content for sensitive information and verify ignore rules for
   Archive, local_backups, databases, database sidecars, caches, and local Library
   reference material.
4. Commit the relevant existing state and this plan in each affected repository.
5. Apply an annotated milestone tag, proposed name
   `pre-term-harvesting-refactor-2026-10-14`, to each baseline commit. Do not
   overwrite an existing tag; record commit IDs and actual tags here.
6. Back up both databases before any writes and verify that the backups are
   readable/restorable using the repository's established backup checks.
7. Capture baseline source assignments, normalization values, review decisions,
   curated recovered terms, and view counts.

Git tags and database backups serve different purposes; neither replaces the
other. Do not push or redistribute local reference files as part of this gate.

Current gate status: not executed; this turn performs planning only.

## 3. One shared pipeline

Capture -> Extract -> Normalize -> Match -> Persist -> Present

These are responsibilities, not a requirement for six new modules.

- Capture: save HTML and page metadata, without terminology matching.
- Extract: retain observations before considering code availability.
- Normalize: use one canonical cleaning, US-spelling, and normalization policy
  for BB labels and reference labels; retain original text.
- Match: independently evaluate each applicable ICD-O edition.
- Persist: write observations, outcomes, candidates, and evidence idempotently,
  preserving review history and stable identities.
- Present: drive both databases' views, notebooks, and spreadsheet output from
  the shared results rather than duplicated parsing rules.

Do not overwrite printed source assignments with proposals.

## 4. Title harvesting and entity eligibility

- Preserve eligible page titles even when coding sections contain beta
  placeholders or no codes.
- Distinguish entity names, groupers, syndromes, non-neoplastic lesions, and
  editorial text. A title is not automatically a tumor-code assignment.
- Keep title observations separate from differently worded coding labels.
- Align spreadsheet and database title handling.
- Repair the nested-definition/related-content eligibility problem, including
  page 5029, without admitting blank pages indiscriminately.
- Record title observations as titles, not fictitious related terminology.

## 5. Legacy recovery transition

The curated manifest contains preselected terms and mappings; its loader is not
an automatic prose discovery engine.

Reuse stable-key helpers, reference validation, evidence handling, review
preservation, and useful persistence logic in the new shared pipeline.

During migration:

1. Import existing curated terms, provenance, candidate evidence, and reviewed
   decisions into the general representation.
2. Compare the new extractor's discoveries against the curated baseline.
3. Preserve reviewed or historically recovered observations that cannot be
   reproduced from current saved HTML as explicit legacy-import observations.
   Do not falsely describe them as newly scraped source text.
4. Verify a full refresh preserves these records without replaying the manifest.
5. Remove legacy recovery replay from the steady-state refresh path.
6. Archive superseded scripts or manifests only after identifying dependencies,
   preserving necessary audit evidence, and verifying refresh parity.

The old batch is a migration input and regression fixture, not an ongoing
recovery stage. Do not force ordinary observations into recovery-specific table
constraints. Existing legacy tables can remain read-only for compatibility
until consumers and review history have been migrated; dropping them is not a
prerequisite and requires a separately verified migration decision.

## 6. Evidence sources

Primary sources:

- Saved BB HTML, sections, titles, page metadata, and page URLs.
- Printed coding assignments and terminology labels, including acceptable and
  not-recommended status.
- Official ICD-O-3.2 reference workbooks already available locally.
- Official September ICD-O-4 reference workbook:
  `..\BBNotebook\Library\CPC_ICDO4\Updates_2026_09\ICD-O-4.xlsx`.
- Preserved curated recovery evidence and prior review decisions.

Inventory the exact ICD-O-3.2 file/sheet and all active reference revisions before
matching. Store file/sheet/row identity and hashes. Do not silently mix the older
general ICD-O-4 import with the September reference.

BB context establishes what the page says. An official reference establishes a
term/code relationship. Neither alone proves that every contextual mention is
the page's diagnosis.

External research:

- No automatic broad Internet search in the initial deterministic pipeline.
- Live official BB pages may be consulted, within access permissions, when
  saved content is missing or its revision is disputed.
- Official IARC/WHO publications or other authoritative sources may support
  targeted review of unresolved candidates.
- Search snippets, informal websites, and unsupported inferred synonyms are
  not authoritative evidence for a code assignment.
- Record URL, access date, source revision where available, and the supported
  claim for externally reviewed evidence.
- Do not upload private corpus text or local reference files to third parties.
- Do not commit copyrighted reference contents or credentials.

A future automated external-research facility requires separate approval and
design; it is not implied by this plan.

## 7. Extraction and evaluation techniques

Start with deterministic, auditable methods:

1. DOM/section-aware structured parsing for titles and terminology lists.
2. Central standalone-placeholder filtering, preserving legitimate qualifiers.
3. Boundary-aware reference-phrase matching within prose, with source spans and
   surrounding sentences. Handle longest overlapping matches explicitly and
   retain provenance rather than emitting arbitrary fragments.
4. Canonical-normalized matching, while recording transformations that remove
   meaningful qualifiers.
5. Official synonym lookup; keep edition and reference evidence separate.
6. Context classification for affirmative, negated, differential, historical,
   incidental, grouper, and subtype mentions.
7. Review-only broader or approximate suggestions when exact/reference-synonym
   matching fails. Approximate similarity alone must not assign a code.

No model-based extractor or external AI service is assumed in the initial scope.
Discovery of unknown terms beyond reference phrases needs additional reviewed
rules and an explicit coverage statement.

Rate extraction and code mapping separately:

- Extraction: structured observation, supported prose span, or interpretation
  requiring review.
- Mapping: exact official label, official synonym, normalized match,
  conditional/broader suggestion, ambiguous, or unmatched.
- Record reason codes, contextual restrictions, and supporting evidence.
- Use ordinal evidence tiers initially, not uncalibrated probability percentages.
- If numeric ranking is later useful, validate its weights and thresholds against
  a reviewed test set and retain the component reasons.

Negation or differential context does not invalidate the reference term/code
relationship; it limits whether the mention is positive evidence for this page.
Do not inherit parent or neighboring codes onto split components.

### Previous accepted and rejected candidates

Preserve prior extracted candidates and decisions, including rejections.
Use stable identities and scoped reasons to inform reevaluation:

- Global extraction rejection, such as a standalone placeholder.
- Page/source-context rejection, such as an incidental differential mention.
- Term/edition/code rejection, including reference revision and conditions.
- Changed source or reference evidence that warrants reopening review.

A page-specific rejection must not suppress that term globally. A rejected
ICD-O-3.2 mapping must not automatically reject an ICD-O-4 mapping.

Unchanged reviewed decisions survive refresh. Materially changed evidence is
flagged for review rather than silently reusing or erasing the decision.
Preserve decision history, scope, reason, reviewer where available, and timestamp;
do not rely solely on the current status.

## 8. General storage model

Observation -> edition/reference evaluation -> candidate mappings

Proposed schema:

| Table | Change |
|---|---|
| `page_term_mentions` | General observations, including unmatched titles/structured/prose terms. Add stable `observation_key`, `source_locator`, and `term_origin`; reuse existing original text, normalized values, role, context, and extraction-method fields. |
| New `term_lookup_evaluations` | Non-null observation link; stable evaluation identity; edition, reference identity/hash, matcher version, outcome, time, and detail. |
| New `term_code_candidates` | Non-null evaluation link; code, original/normalized official label, match type/order, conditions, supporting reference rows, and review status; legacy mapping linkage where applicable. |
| New `term_review_decisions` | Append-only scoped decisions for observations or candidate mappings, with outcome, reason, evidence identity, reviewer where available, and timestamp. Current status is a projection of valid decisions. |
| Existing recovery tables | Preserve existing constraints during transition; migrate/adapt evidence without creating synthetic AI-recovery provenance for ordinary source observations. |

Final field types, foreign keys, uniqueness constraints, and reference-evidence
representation must be specified before migration code is written. Every
evaluation has an observation; no nullable alternate evaluation anchor is needed.

Candidate evidence must cite actual supporting rows, including multiple rows
when needed. Never fabricate a row number to satisfy a constraint.

## 9. Views and dependent consumers

- Proposed codes appear in existing `ICDO32` and `ICDO4` output columns.
- `TermUS` preserves BB wording; `candidateTermUS` displays reference wording.
- Independently flag proposed code and proposed alternative term.
- Preserve both origins when printed and proposed evidence agree.
- Show conditions, match type, and current review status.
- Keep rejected candidates in review/audit surfaces, not active proposal output.
- Expose matched, ambiguous, no_match, not_applicable, needs_review, and
  not_evaluated outcomes by edition.
- A code in one edition must not hide the other edition's outcome.
- Consolidate display rows by page/term/edition/code/candidate-label grain;
  aggregate evidence separately to avoid source-link multiplication.

Update all relevant entity/provenance/candidate/page-code views consistently.
Include `page_site_hints` and other consumers of single-valued legacy mention
codes in the migration. Multiple candidates must not be reduced to an arbitrary
first code; positive-context and site-confidence requirements remain enforced.

## 10. Indexes

Add indexes where measured query plans and representative queries show benefit.
Inventory existing indexes first and avoid redundant indexes.

Initial candidates:

- Unique `page_term_mentions(observation_key)`.
- Observation retrieval by `(page_id, TermNormUS)`, with spelling-preserving
  `TermUS` access where actual joins require it.
- Reference-term lookup by canonical normalized term, plus edition where the
  reference table stores multiple editions.
- Unique evaluation identity and retrieval by
  `(mention_id, edition, reference identity, matcher_version)`.
- Candidate joins by `evaluation_id`; code lookup by `(edition, code)` if edition
  is stored on the candidate, otherwise index the corresponding evaluation join.
- Candidate review queues using status and evaluation linkage where selective.
- Review-history retrieval by target identity and decision sequence/time.
- Existing canonical term-table page/key indexes used by rebuilt views.

Choose key order and included/filtered columns from actual query shapes. Use
SQLite EXPLAIN QUERY PLAN and SQL Server execution plans/timings. Ordinary views
benefit from base-table indexes; do not assume they require indexed views.
Account for write overhead and SQL Server key-length limits.

## 11. Cleanup, notebooks, and documentation

Every behavior and schema enhancement must be supported by:

- Shared crawler/notebook helpers, without duplicated extraction rules.
- Crawler runner and relevant companion explorer/query notebooks.
- Notebook examples for title coverage, unmatched terms, both-edition proposals,
  evidence/context inspection, and accepted/rejected review.
- README files, data dictionaries, query guides, schema snapshots, and generated
  documentation where affected.
- This plan, updated with actual decisions and validation outcomes.

Inventory consumers before declaring a file deprecated. Move superseded files
to each repository's ignored Archive folder after updating imports, notebook
cells, links, and build/documentation dependencies. Do not archive shared code
that still has active responsibilities.

Do not track Archive, local_backups, databases, database sidecars, or local
copyrighted reference material.

## 12. Validation and staged deployment

- Focused parser tests: Gynandroblastoma title with beta placeholder, empty
  coding, nested definitions, related-only substantive content.
- Placeholder tests: four confirmed erroneous rows and legitimate qualifier.
- Matching tests: exact, normalized/lossy, synonym, ambiguity, context,
  conditional suggestions, and both-edition unmatched outcomes.
- Review tests: scoped rejection, decision history, refresh preservation,
  changed reference/source evidence, and legacy migration parity.
- Output tests: independent proposed-code/term flags, mixed origins, multiple
  observations without display multiplication, and site-hint behavior.
- Persistence tests: stable observation keys, idempotence, regenerated-ID
  relinking, no loss of historical observations.
- Database tests: unchanged printed assignments, SQLite/SQL Server parity,
  normalization/index coverage, representative query performance.
- Notebook/helper execution and documentation consistency checks.

Stage extraction/matching tests before production writes. Apply backed-up
migrations and verify both databases before finalizing deployment commits.
Retire the old recovery execution path only after full-refresh parity succeeds.

## Deferred issue: subtitle capture and usefulness

Tracking issue: [subtitle capture audit](issues/subtitle-capture-audit.md), open
and deferred until the main refactor is complete.

GitHub issue status: not filed. Neither a configured Git remote nor a confirmed
target repository is available. Publish the local issue once the repository is
supplied.

Title: Audit BB subtitle capture and add harvesting only if useful

Dependency: begin after the main term-harvesting refactor is complete.

Background:

All 3,634 audited stored pages have empty subtitles. This does not establish
whether the source pages have no subtitles or the current selectors fail to
capture them. Subtitle hints currently use a four-digit code expression.

Tasks:

1. Inspect a bounded representative sample of saved HTML across editions and
   page types; consult authorized live pages only if necessary.
2. Determine whether subtitle elements exist, whether capture is correct, and
   whether their text contains usable terminology or code metadata.
3. If no useful subtitle content exists, document the evidence and close the
   issue without adding a harvesting feature.
4. If useful content exists, route it through the shared observation pipeline,
   with subtitle provenance and edition-aware code recognition.
5. Update both database workflows, relevant notebooks, documentation, and
   focused tests only for the confirmed useful behavior.

Acceptance:

- Distinguish source absence from capture failure with recorded evidence.
- No invented terms, duplicate observations, or parallel parsing pipeline.
- Preserve source/proposal distinctions and refresh idempotence.
- Main refactor completion is a prerequisite, not this issue's scope.
