# Local database parity implementation report

**Initial parity date:** 2026-10-06. Saved-body follow-up: 2026-10-07.
**Status:** completed and verified locally, including the final independent
saved-prose acceptance run.

**Follow-up status (2026-10-12):** references below to the former derived key
name `TermNorm` describe the schema at the time of this historical report; the
current column name is `TermNormUS`. The legacy `is_subtype` flag is deprecated
and retained only for compatibility; new logic should use `term_role` and
explicit provenance/relationship metadata.

**Coverage correction:** the initial parity and all-edition builds below verified
matching data and populated indexes, but indexed only definitions/terms plus
the previously stored sections. They did **not** establish full saved-page body
coverage. The saved-body recovery follow-up documents the additional correction;
historical counts below must not be interpreted as current body-completeness
evidence.

**Current managed scope:** **25 tables**, including `entity_identifiers`,
`entity_term_provenance` and `entity_term_code_matches`.
Final saved-body acceptance and alternate-term recovery results are recorded
in the follow-ups below.

**Historical parity diff:** normalized row-value hashes matched for all **22
managed tables**, not just row counts. Remaining differences are the agreed
inventory/bookkeeping/activity exclusions and engine-specific search/schema
machinery. The corpus and enrichment values are essentially identical.

## Implemented

SQLite is now the canonical producer for 22 managed data tables. A single
local-only pipeline imports the reference files, normalizes page titles, parses
saved fifth- and sixth-edition HTML, populates code/term/site evidence and rollups, and builds
whole-page search documents. SQL Server receives the same keys, values and
extraction timestamps instead of independently recomputing enrichment.

The original missing tables were not crawler-owned: separate SQL Server-only
scripts had populated them, and the Runner copied only its original core tables.
Both notebook workflows and compatibility CLIs now call the shared producer.
See the [data dictionary](DATA_DICTIONARY.md) for all tables, columns, sources,
refresh ownership and exclusions.

### Historical managed table counts before saved-body recovery

| Table | Rows |
|---|---:|
| books | 23 in SQLite; book 70 excluded from the 22-book mirror |
| chapters | 222 |
| page_groups | 1,104 |
| pages | 3,634 |
| sections | 28,709 |
| authors | 8,600 |
| images | 17,205 |
| page_links | 1,087,874 |
| references | 39,105 |
| entity_pages | 2,973 |
| entity_codes | 6,910 (4,413 nonblank codes; 2,497 uncoded term rows) |
| entity_related_terms | 5,273 |
| cpc_curation | 0 |
| icdo4_morphology | 4,720 |
| cpc_morph_codes | 5,642 |
| icdo_site_specific_terms | 3,715 |
| icdo_site_specific_term_sites | 12,250 |
| page_icdo_codes | 5,911 |
| page_term_mentions | 62,419 |
| page_site_hints | 351,006 |
| page_entity_evidence | 61,446 |
| page_search_documents | 3,634 |

## Saved-body recovery workflow (build version 4; version 5 follow-up below)

The shared parser now recovers section prose from locally saved HTML, using
anchored description blocks, embedded headings and nested structured sections.
It preserves meaningful cross-reference link text, consolidates repeated
content and excludes navigation/citation chrome. Code-only ICD-O rows receive
the entity title as their fallback term. Substantive coding subsections replace
Beta placeholders; `None` remains uncoded.

SQLite section backfill preserves every original section ID, page association,
heading, ordinal and nonempty body. It fills unambiguous empty matches and
appends canonical saved sections when no safe match exists. Existing conflicting
rows and image/reference links remain intact. `sections.source_anchor` records
the source HTML anchor; detailed recovery exceptions are kept in the private
build sidecar rather than silently discarded.

External OMIM identifiers now have their own `entity_identifiers` table with
page relationship, unique key and `(system, identifier)` lookup index. Their
source text remains searchable, but they are not morphology assignments.

The corpus audit also caught paragraph endings after nested labels and decoded
comparison operators being mistaken for HTML markup. Focused regressions now
preserve that prose. The microinvasive carcinoma page explicitly says it
"does not have an ICD-O code"; its examples `8500/3` and `8520/3` describe
possible tumour-type coding, not assigned codes for that entity. They remain
searchable body/code evidence without inventing entity assignments.

The complete refresh order is saved-section recovery, entities/identifiers,
references and code/term/site evidence, rollups, whole-page documents, SQLite
FTS rebuild, then transactional SQL Server mirror and full-text readiness
checks. Run Runner Step 5/7 or Explorer Step 7 without login/discovery/crawl
cells. The compatibility full-text entry point also recovers saved bodies;
after section changes, use the complete shared refresh before SQL mirroring so
enrichment cannot lag behind the new bodies.

### Affected files and notebooks

- Crawler: [shared pipeline](bluebooks_local.py), [full-text compatibility entry point](bluebooks_fts.py),
  [schemas](schema.sql), [enrichment schema](schema_enrichment.sql),
  [generated SQL Server schema](schema_sqlserver.sql), [data dictionary](DATA_DICTIONARY.md),
  [documentation generator](build_local_docs.py), [notebook integrator](notebook_local.py),
  [Runner](Crawler_Runner.ipynb), [README](README.md),
  [validator](validate_local.py), [pipeline tests](tests/test_local_pipeline.py) and
  [parser tests](tests/test_saved_html_parser.py).
- Companion: [HTML parser](../BBNotebook/bb_entity_extract.py),
  [pipeline bridge](../BBNotebook/local_pipeline.py),
  [compatibility entity store](../BBNotebook/bb_entity_store.py),
  [schema](../BBNotebook/schema.sql), [README](../BBNotebook/README.md),
  [query guide](../BBNotebook/AI_AGENT_QUERY_GUIDE.md),
  [Explorer 2](../BBNotebook/BlueBooks_Explorer_2.ipynb),
  [Explorer 3](../BBNotebook/BlueBooks_Explorer_3.ipynb) and
  [site-query notebook](../BBNotebook/Querying_Site_Specific_Terms.ipynb).

No Blue Books requests, login or crawling are involved. Repository documents
are updated locally; nothing has been remotely published or committed. Agent
activity, crawl bookkeeping and manual curation are outside the rebuild.

### Persisted saved-body build results

The corrected build completed at **2026-10-07 02:09 UTC**. All 23 managed
table row-value hashes matched after the SQL Server copy; the optional book 70
inventory exception remains excluded from that comparison.

| Table/measurement | Before body recovery | Corrected build |
|---|---:|---:|
| sections | 28,709 | 88,640 |
| nonempty section bodies | 1,115 | 60,531 |
| entity_pages | 2,973 | 2,979 |
| entity_codes | 6,910 | 6,579 |
| nonblank entity codes | 4,413 | 4,425 |
| blank-code term rows | 2,497 | 2,154 |
| entity_related_terms | 5,273 | 5,294 |
| entity_identifiers | absent | 182 |
| page_icdo_codes | 5,911 | 9,692 |
| page_term_mentions | 62,419 | 66,384 |
| page_site_hints | 351,006 | 351,318 |
| page_entity_evidence | 61,446 | 64,149 |
| page_search_documents | 3,634 | 3,634 |
| mean whole-page document length | roughly 500 characters | 6,385.7 characters |

Recovered section bodies total 21,995,019 characters; whole-page documents
total 23,205,650. Average length includes short/non-entity pages, so it should
not be compared directly with the estimated length of one long entity page.
Entity totals are 2,386 fifth-edition and 593 sixth-edition pages.

Lower total coding-row counts do not mean assigned codes were removed: OMIM
rows and spurious heading/placeholder rows no longer masquerade as morphology
terms. Baseline comparison checks preservation of all 3,556 distinct
previously assigned page/code pairs. Related-term exact-string changes include
cross-reference rendering differences (for example, dropping the word
"section" while retaining the destination); meaningful linked names remain.

The first recovery filled 180 original empty sections and appended 59,927
saved sections; follow-up corrections filled one more and appended four.
Ambiguous/conflicting original rows were retained, not overwritten.
Recovery is repeatable: a rollback-only live rerun must add/fill zero sections.
The 44 pages without qualifying saved description prose are explicitly reported
in provenance; the workflow cannot reconstruct content absent from local HTML.

Verified pre-task backups are timestamped `20261006T225416378592Z`; a fresh
SQLite backup and SQL Server COPY_ONLY backup preceded each subsequent refresh.
The final corrected refresh backups are timestamped `20261007T020913817353Z`.
SQLite backups remain in `local_backups`; SQL backups remain in the instance
backup directory. Detailed paths are in private logs. An intermediate parser
attempt was rejected by SQL length preflight before data replacement; only its
new, unlinked SQLite sections were cleaned up, preserving all original rows.

### Acceptance results

- All **23 managed row-value hashes match**. SQLite integrity and foreign-key
  checks pass. Fresh/repeated schema provisioning has 23 tables and 26 managed
  relationships.
- All **60,774 parsed sections** from 3,590 pages have their bodies stored and
  included in whole-page documents, with zero missing extracted bodies.
- `"teratoma of the lung"` finds the lung page 44/444 in both whole-page and
  section full-text search on both backends.
- All six reported missing codes are in both `entity_codes` and
  `page_icdo_codes`: 8503/2, 8890/3, 9570/0, 9132/0, 9120/0 and 8823/1.
- The salivary page retains all five 8500/2 rows; both specified salivary pages
  retain the not-recommended term. GLPD remains uncoded. Lynch identifier
  609310 is separately stored and searchable.
- All 28,709 original section IDs/associations and all 3,556 baseline distinct
  assigned page/code pairs are preserved. Eleven protected corpus, association,
  curation and crawl tables have unchanged baseline hashes.
- SQL Server's three full-text indexes are enabled, AUTO-tracked, idle and have
  zero pending changes: 3,634 pages, 3,634 documents and 88,640 sections.
- All four notebook files validate/compile. Explorer search works on both
  backends; all 20 site-query code cells execute on each backend.
- A live rollback-only repeat adds/fills zero sections. The parser/pipeline
  regression suite passes **47 tests**, including an independent audit
  regression that detects deliberately omitted substantive paragraphs.

The independent validator collects saved description paragraphs directly from
HTML, not from parser output, and checks their ordered word tokens against the
actual persisted search document. It deduplicates exact repeats and excludes
structural headings, navigation, citation links and four exact non-prose
residuals: `None`, `Classification in progress, Data not available in this Beta`,
`TM Categories` and `FIGO Stagesa`. Inline bold labels do not discard following
prose, and ordinary linked text is retained. Its persisted coverage result must
have zero unmatched paragraphs; this avoids hiding concentrated extraction
losses behind a high aggregate token percentage.
The independent read-only corpus audit checked **80,687 unique source
paragraphs with zero unmatched paragraphs**. It splits HTML line breaks and
allows adjacent-token joining differences caused by inline markup serialization;
it retains footnote markers and still fails on deliberately omitted substantive
prose. This checks recoverable saved description text, not an assertion that
every online page or image/table asset has been captured locally.

Bare-word search is still engine-specific: SQLite `carcinoma` returns 1,566
pages versus SQL Server's 1,485; `carcinoma OR hepatoblastoma` returns
1,572 versus 1,491. This is not an index-population gap: both prefix searches
return 1,599 pages, with identical stored documents and fully populated indexes.
Use explicit prefix/inflectional expressions when comparing engines; do not
assume their default token/stemming/phrase rules are identical.

## Distinct page code-term views (version 10, 2026-10-11)

Both live databases now contain `v_page_code_terms` (SQL Server:
`dbo.v_page_code_terms`), with **15,339 rows** and identical values.
Each row is one page/edition/code/TermUS pair, retaining different terms that
share a code. It includes short book/version, chapter, page title/URL,
sections, scalar TermUS/candidateTermUS, ICDO32/ICDO4 and source/candidate,
subtype, qualifier, match, condition and review metadata. Unmapped terms keep
NULL codes. Morphology codes and terms are never concatenated.

Distinct page-level topography hints with confidence >= 0.9 are listed on
each row; these are not verified term-specific or patient sites.
Section headings, metadata and site lists alone may be combined.
The original raw morphology code is retained, including ICD-O-4 letter variants;
no cross-edition mappings are fabricated.

`terminology_kind` has five atomic values (`coding`, `contextual`,
`acceptable`, `not_recommended`, `other`), combined alphabetically with `; `
when one row has multiple origins. The observed distribution matches across engines:
`coding; contextual` 4,415, `contextual` 4,068, `not_recommended` 3,092,
`acceptable` 1,931, `coding` 1,284, `other` 517, `acceptable; coding` 17,
`coding; other` 10, `acceptable; not_recommended` 4, `contextual; other` 1.
Definitions: [TERMINOLOGY_KIND_VALUES.md](TERMINOLOGY_KIND_VALUES.md).

`entity_term_code_matches.official_termUS` is a stored, indexed,
trigger-maintained US display column. The existing match view exposes it as
`official_term` and `candidateTermUS`, and retains original reference spelling
as `official_term_source`. All 398 original matches, reference evidence,
provenance, source assignments and original table fields were preserved.
The match view has 12,173 rows. Plain SQLite connections can read both views
without normalization UDFs.

Verified paired backups taken before deployment:

- SQLite: `local_backups/bluebooks-20261011T215835556738Z.db`.
- SQL Server:
  `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\BlueBooks-local-parity-20261011T215835556738Z.bak`.

Verification: all **25 managed tables** have matching cross-engine row-value
hashes; all original pre-upgrade fields match their respective baseline;
no repeated page/edition/code/TermUS pairs and no empty/artifact/unknown-edition
coded rows were found. All 11 term validators pass and **80 regression tests**
pass, including shared codes, merged source/candidate metadata, raw letter
codes, multiple sections, site confidence thresholds, unassigned names and
candidate spelling-trigger updates.

Full-view SQL query tuning reduced retrieval from 71.4 seconds to 10.8 seconds
(SQLite: approximately 1.3 seconds). SQL Server page-filtered retrieval measured
0.55 seconds; full-view count measured 0.64 seconds. Prefer page/book predicates
and bounded projections for interactive browsing, especially because page site
lists repeat on each distinct term row.

The canonical migration/refresh/mirror and generated schemas retain the view
definitions. Both READMEs, query guide, dictionary and four active notebooks
were updated; each notebook was backed up and only its two managed recovery
cells changed. No original code assignments or Clean2 logic changed.

## Historical all-edition implementation details

The fourteen fifth-edition and four sixth-edition books are processed from saved HTML as
well as stored sections. All 750 previously missing normalized page titles were
included in the initial refresh. Enrichment counts increased because these books'
structured codes and related terms are now included. Raw codes, including
five-digit morphology codes, remain available alongside compatibility keys.
Evidence policy remains explicit: acceptable/not-recommended terminology is
excluded from positive evidence; broad site prefixes are hints, not exact sites.
Rollup scores are heuristic, not probabilities.

The following sixth-edition evidence counts describe the initial parity build;
current all-edition totals are above.

| Sixth-edition book ID | Stored pages | Parsed entities | Code evidence | Term mentions |
|---|---:|---:|---:|---:|
| 72 | 199 | 161 | 1,052 | 2,894 |
| 84 | 112 | 69 | 0 | 356 |
| 85 | 220 | 183 | 8 | 3,339 |
| 87 | 219 | 180 | 150 | 1,920 |

Book 84's saved records yield no morphology codes; no codes were fabricated or
fetched online. Its entity/term data is processed, not skipped. Non-entity pages
explain why parsed-entity counts are lower than total stored pages.

## Search

- SQLite FTS5 section and whole-page indexes are rebuilt and integrity-checked.
- SQL Server retains section/title indexes and adds
  `page_search_documents(title,full_text)` with English indexing and AUTO change
  tracking. Provisioning waits for completed population with a bounded timeout.
- Both engines use identical ordered whole-page documents, including
  fifth- and sixth-edition entity definitions/terms. Phrase, Boolean, prefix and book-filter
  queries are supported using each engine's native syntax.
- Native stemming, tokenization and ranking are intentionally engine-specific;
  identical search counts are not a parity requirement.
- Normalization validation exposed collation-dependent differences in
  `dbo.Clean` (case handling and Roman numeral character ranges). Explicit binary
  comparisons now match Python's case-preserving rules. Python also correctly
  handles a `(specify...)` suffix starting at position zero.

Current live whole-page results after fifth-edition entity supplementation:

| Query | SQLite | SQL Server |
|---|---:|---:|
| `carcinoma` | 606 | 596 |
| `"hepatocellular carcinoma"` | 12 | 12 |
| `carcinoma AND liver` | 19 | 18 |
| `carcinoma OR hepatoblastoma` | 610 | 600 |
| Prefix (`carc*` / `"carc*"`) | 631 | 631 |
| `carcinoma`, book 72 only | 53 | 52 |

All three SQL Server indexes report completed population, idle status and zero
pending changes. SQLite integrity/FK checks pass. Normalization fixtures
including case, Roman numerals, NULL and Unicode produce zero backend mismatches.

SQL Server `FORMSOF(INFLECTIONAL, carcinoma)` matches the same **606 page IDs**
as SQLite; `FORMSOF(INFLECTIONAL, carcinoma) OR hepatoblastoma` matches the same
**610 page IDs**. The remaining native singular-query differences are stemming,
not missing data or stale indexes. More hits than the initial 453/457 SQLite
results come from newly included fifth-edition structured entity fields, not
newly crawled pages.

## Notebook and ancillary integration

- [Crawler_Runner.ipynb](Crawler_Runner.ipynb): Step 5 builds the complete local
  dataset; Step 7 provisions/mirrors all managed tables and verifies search.
- [Explorer 3](../BBNotebook/BlueBooks_Explorer_3.ipynb) and
  [Explorer 2](../BBNotebook/BlueBooks_Explorer_2.ipynb): shared Step 7 enrichment
  and whole-page search. SQL mirroring is opt-in; local settings are respected.
- [Site-specific queries](../BBNotebook/Querying_Site_Specific_Terms.ipynb):
  reads either backend through a bounded, read-only dialect adapter.
- Notebook generators upgrade managed cells without duplicating Step 7 or
  discarding unrelated user cells.
- Evidence-building scripts and entity sync/push entry points route through the
  shared pipeline. The compatibility entity-sync methods now intentionally
  synchronize the complete dependent dataset, not an incomplete book-only subset.
- Schemas, dependency declarations, both READMEs and the agent-query guide were
  updated. [build_local_docs.py](build_local_docs.py) regenerates the dictionary,
  SQL Server bootstrap schema and companion SQLite schema.

## Safety and accepted differences

- **No Blue Books online access, login, discovery, crawling or downloads occurred.**
  Scraping behavior was left unchanged. Only stored data and local reference
  files were used.
- Book **70** is **WHO Reporting System for Breast Cytopathology**,
  `cytopathology`, `Beta`, with no stored pages/sections. Its inventory row remains
  SQLite-only by default. `--include-book70` optionally copies that existing row;
  it does not fetch content.
- `crawl_queue` and `crawl_runs` are excluded from reconciliation.
  Their unchanged counts are 3,642/2,892 and 37/35 (SQLite/SQL Server).
- Agent activity tables/schema are excluded from all migration/copy manifests.
  Manual curation is never cleared; conflicts/target-only differences fail
  validation instead of overwriting decisions.
  `agent_jobs` remains empty with its original ten columns; no SQLite activity
  table was introduced.
- Missing references fail before data replacement. Local refresh and SQL data
  replacement are transactional. The mirror verifies normalized row-value
  hashes before committing, not merely row counts.
- Build provenance stores corpus/reference hashes and rejects stale inputs
  before mirroring. It is a private sidecar, not agent-activity metadata.
- SQL Server administration objects, SQLite FTS internals, physical types and
  defaults remain documented engine-specific differences.

## Backups

Pre-migration SQLite backup:
`local_backups/bluebooks-20261006T203513525706Z.db`.
Pre-migration SQL Server COPY_ONLY/CHECKSUM backup:
`BlueBooks-local-parity-20261006T203513525706Z.bak` in the instance backup folder.
SQL Server RESTORE VERIFYONLY succeeded.

An additional verified pair was taken before the final refresh:
`bluebooks-20261006T205959477348Z.db` and
`BlueBooks-local-parity-20261006T205959477348Z.bak`.
Keep backups, licensed data and private validation/provenance files local and
out of version control.

## Verification

- 17 focused regression tests pass: both-edition saved-HTML extraction and
  front-matter exclusion, idempotent migration, freshness rejection,
  missing-input safety, rollback, curation exclusion, deterministic documents,
  structured-code supplementation, evidence policy, portable queries,
  normalization boundaries and notebook regeneration without duplication.
- A fresh companion SQLite schema creates all 22 managed tables.
- Affected Python modules compile; checked editor diagnostics are clear.
- The Explorer's real connection and whole-page search succeed on both engines
  (25 displayed results each).
- All 20 site-query code cells execute successfully on each backend.
- All 22 managed table hashes match after the committed mirror. The private,
  ignored `local-validation.json` records counts/hashes and live checks.
- Notebook regeneration and affected Python entry points were exercised;
  `git diff --check` passes for task changes in both folders.

## Future use

### All-edition extraction follow-up (2026-10-06)

The sixth-only result came from an explicit `edition='6th'` producer filter,
not absent fifth-edition HTML. The shared producer now selects both `5th` and
`6th`; build version 3 invalidates old sixth-only provenance so a fresh full
local build is required before mirroring.

The rebuild adds **2,380 fifth-edition entities**, **5,900 coding/subtype term
rows** and **4,286 related terms**. All 14 fifth-edition books have entities:
31, 32, 33, 34, 35, 36, 44, 45, 52, 53, 63, 64, 65 and 67.
TOC category, non-entity page exclusions and structured-content checks retain
entity pages even where the crawler classified them as `other`. Original
ICD-O-3.2 and ICD-O-4 codes are preserved; no cross-edition editorial mapping or
missing codes are invented. Blank code rows remain useful term/subtype rows.
Provisional letter-suffixed codes remain in `entity_codes`; numeric compatibility
evidence does not invent an ICD-O-3.2 equivalent for them.

| Edition | Entity pages | Coding/subtype rows | Rows with codes | Related terms |
|---|---:|---:|---:|---:|
| 5th | 2,380 | 5,900 | 3,699 | 4,286 |
| 6th | 593 | 1,010 | 714 | 987 |
| Both | 2,973 | 6,910 | 4,413 | 5,273 |

Book 67 has 83 parsed entities and 313 uncoded term rows; book 84 has 69 entities
and 51 uncoded term rows. These books are included, not skipped; their locally
saved structured fields do not supply morphology codes.

Existing sixth-edition entity content was compared against the pre-build SQLite
backup and is unchanged: 593 entities, 1,010 coding/subtype entries and 987
related terms. Generated child-row IDs can change on a full refresh; page IDs and
term/code/TOC values remain unchanged, and SQL Server receives the same rebuilt
IDs. Extraction timestamps correctly reflect the new build.

All dependent evidence/mentions/site hints/rollups and whole-page documents
were rebuilt together. **2,380 page documents changed**; the corpus still has
3,634 pages/documents and 28,709 sections. The Runner, both active Explorer
notebooks, site-query notebook, shared generators, dictionary and both repos'
README/agent documentation now describe the all-edition workflow. Sixth-edition
spreadsheet examples remain edition-specific without restricting the refresh.

Pre-build verified backups:
`bluebooks-20261006T221248260632Z.db` and
`BlueBooks-local-parity-20261006T221248260632Z.bak`.
SQLite crawl queue/history and manual curation values are unchanged.
No BB online access or remote document publishing was performed.

Final live verification confirms:

- All **22 managed normalized row-value hashes match** between SQLite and SQL
  Server, with the agreed book-70 exception.
- No invalid entity classifications or nonblank raw code formats were found.
  Both editions and all 18 locally stored tumour-classification books have
  parsed entities.
- All three SQL Server FT indexes are enabled with AUTO tracking, idle,
  completed and at zero pending changes: 3,634 page titles, 3,634 whole-page
  documents and 28,709 sections. SQLite integrity/FK checks pass.
- All four active notebooks validate/compile, real Explorer connections/search
  work on both engines, and all 20 site-query cells execute on each backend.
- Agent jobs remain empty with the original ten columns; the 17-test regression
  suite, affected Python compilation and both repos' whitespace checks pass.

### Follow-up index tuning (2026-10-06)

Six indexes were added to **both live databases** and shared schemas:

| Table | Leading indexed column | Index |
|---|---|---|
| page_term_mentions | page_id | ix_page_term_mentions_page |
| page_icdo_codes | page_id | ix_page_icdo_codes_page |
| authors | page_id | ix_authors_pg |
| chapters | book_id | ix_chapters_book |
| page_groups | chapter_id | ix_groups_chapter |
| page_groups | parent_group | ix_groups_parent |

All six SQLite lookup plans now report indexed **SEARCH**, not table scans.
SQL Server catalog checks confirm the corresponding indexes. All existing
primary keys and 25 managed FK relationships were retained; no additional
relationship or FT index was needed. Lower-priority conditional index candidates
were deliberately not added without workload evidence.

SQL provisioning now recognizes equivalent ordered keys under different names,
including a supporting unique constraint or clustered index. Name collisions
with incompatible definitions fail explicitly.

Two reviewed redundant **ordinary nonclustered indexes** were removed:

- `pages.ux_local_pages_url`: the existing URL UNIQUE constraint/index remains.
- `page_icdo_codes.ix_page_icdo_codes_code`: the existing `ix_pic_code` is
  **clustered**, not an identical nonclustered index. Its `(icdo_code,page_id)`
  access path and storage role were retained; the redundant nonclustered copy
  was removed.

Cleanup checks ordered keys, uniqueness, filters, included columns, storage
options/compression, and FK/full-text dependencies. It never drops primary-key
or UNIQUE constraints or clustered indexes. Repeating provisioning does not
recreate the removed copies.

Verified pre-tuning backups:
`bluebooks-20261006T214336037076Z.db` and
`BlueBooks-local-parity-20261006T214336037076Z.bak`.
After applying changes twice, all 22 managed row-value hashes still match,
FK checks remain clean and SQL full-text population/search checks pass.
The regression suite now contains **16 passing tests**.
Generated SQL schema batches also execute twice without changing the live index
inventory (validation transaction rolled back). Fresh companion SQLite schema
creation includes all six indexes. Generated SQL defaults translate legacy
SQLite UTC timestamp expressions to SQL Server's `SYSUTCDATETIME()`.

Run Runner Step 5 then optional Step 7, or:

```powershell
python bluebooks_local.py --sqlite bluebooks.db --mirror --server localhost --database BlueBooks
```

From Explorer, use the managed local Step 7 cells; set `MIRROR_SQLSERVER = True`
once if SQL Server should also be refreshed. Skip browser/package-download
cells when using the existing local corpus. Rebuild after corpus/reference
changes; a stale sidecar intentionally prevents a partial mirror.

## Version 5 follow-up: empty sections and OMIM cleanup (2026-10-07)

The shared local-only refresh now removes empty entity-page sections only when
neither `images` nor `references` points to the section. It adds
`ix_images_section` and `ix_refs_section` to both database schemas so foreign
key checks and the bulk cleanup do not repeatedly scan the child tables.
The backfill also skips empty saved entity sections, preventing transient
add-then-delete churn on later refreshes.

The baseline-checked build reduced `sections` from **88,640 to 64,964** by
pruning **23,676 empty, unlinked entity sections**. All 64,964 surviving
original section IDs/associations were preserved; linked rows were protected.
The source HTML contains 577 additional empty shells that were added and then
pruned during that build; the follow-up backfill guard now avoids re-adding
those shells. The final persisted section table has zero empty entity rows.

OMIM extraction now handles labeled numbering blocks, hash-prefixed IDs,
qualified unprefixed IDs and inline subtype citations. Unlabeled inline
citations retain their full source in `raw_text` without misusing an entire
prose paragraph as the display term. The final tables contain **249
identifiers** (up from 182), **6,568 entity-code rows**, and no residual MIM
numbers/labels in blank-code terms. “MIMS” remains correctly as an abbreviation.
The six previously missing morphology codes are present; the GLPD page remains
uncoded as its source specifies. The lung-teratoma body phrase and salivary
terminology spot searches succeed on both backends.

The successful version-5 refresh completed at **2026-10-07 14:27:45 UTC**.
All **23 managed table row-value hashes match** after the SQL Server mirror.
Baseline validation preserved all **3,568 previously assigned page/code pairs**,
checked 59,716 nonempty saved sections, and audited 80,687 source paragraphs
with zero missing prose. All three SQL Server full-text indexes are enabled,
complete, idle and on AUTO tracking: 64,964 sections, 3,634 pages and 3,634
whole-page documents. Both Explorer backends returned results, and all 20
site-query notebook cells executed on each backend. The 51-test regression
suite passes.

The remaining inventory/activity differences are intentional: SQLite has 23
book rows while SQL Server has 22 because book 70 is excluded by default;
SQLite has 37 crawl runs while SQL Server has 35 because crawl history is not
mirrored. Related-term strings match exactly. The 10-character aggregate
difference from `LEN()` is the ten trailing spaces that SQL Server `LEN`
ignores; `DATALENGTH` and SQLite string lengths agree.

The original pre-cleanup validation baseline is
`local_backups/bluebooks-20261007T141952363658Z.db`; the final refresh had
fresh SQLite and SQL Server backups timestamped `20261007T142734845819Z`.
No Blue Books online access, login, crawl or remote document publishing was
used.

## Version 6 follow-up: identifier provenance and fragment cleanup (2026-10-07)

The saved-HTML parser now discards list-introduction fragments such as
“Molecular subtypes include:” from both coding and subtype term lists. Inline
identifier display terms strip a leading conjunction when it leaves a clean
name (for example, `and BDNF` becomes `BDNF`) and suppress clause fragments
such as “mutations in this gene are the underlying cause …”. The unaltered
source context remains available in `raw_text`.

`entity_identifiers.source_kind` now explicitly identifies `coding_section`
versus `section_text`, alongside the existing exact `source_heading`.
Code-only body mentions stay blank-term mentions instead of being mistaken
for coding entries. The provenance-aware unique key now includes
`source_heading`; this keeps same-page, same-identifier mentions in separate
sections instead of collapsing their provenance. SQLite and SQL Server
migrations preserve existing rows and add the new column/key. SQL Server uses
`NVARCHAR(100)` for the indexed heading after verifying that the source
headings fit; its five-column unique key is 1,564 bytes, within the index-key
limit.

The refreshed databases contain **249 identifier rows**: 189 from coding
sections and 60 from section text. On page 704, MIM 113505 now has term
`BDNF`. On page 3148, MIM 145001 has two blank-term mentions, retained
separately under `Genetic factors` and `Pathogenesis`. The three blank-term
175100 Clinical features mentions on pages 320, 699 and 2867 are explicitly
marked `section_text`, while their ICD-O coding rows are marked
`coding_section`. No `and BDNF` term, flagged mutation-clause term, or
“Molecular subtypes include” entity-code row remains.

The 53-test regression suite passes. The final refresh completed at
**2026-10-07 16:08:08 UTC** and the SQL Server mirror reports matching hashes
for **all 23 managed tables**. The build schema and data dictionary are
regenerated at version 6. Both backends were checked for each reported
example; no online Blue Books access or crawling was used.

## Version 7 follow-up: term hygiene and indexed US/comparison keys (2026-10-11)

Both `bluebooks.db` and SQL Server `localhost.BlueBooks` were repaired in place,
without a crawl or full rebuild. The maintainer approved the additional affected
`page_term_mentions` and `page_entity_evidence` tables before changes, and approved
removing saved-HTML-confirmed misplaced explanatory prose.

### Results per database

| Table | Final rows | Existing source values changed | Confirmed non-term rows removed |
|---|---:|---:|---:|
| entity_codes | 6,523 | 32 | 44 |
| entity_related_terms | 5,253 | 14 | 41 |
| page_icdo_codes | 9,692 | 1,279 | 0 |
| page_term_mentions | 66,154 | 814 | 0 |
| page_entity_evidence | 64,149 | 672 | 0 |

All retained rows have stored `TermUS` and `TermNorm` columns, with separate
nonunique indexes: **10 new indexes per engine**.

- `TermUS = CleanBritishSpelling2(CleanTermEnding(source))`.
- `TermNorm = Clean2(TermUS)`.
- The source is respectively `term`, `term`, `term_in_coding_section`,
  `term_original` and `term_clean`.
- Stored fields with INSERT/UPDATE maintenance were preferred over computed
  fields for ordinary cross-engine reads. SQLite writers must register the UDFs
  through `connect_sqlite` or `migrate_sqlite`; bare reads remain supported.
- Full SQL index keys are `NVARCHAR(600)` (1,200 bytes), within the 1,700-byte
  nonclustered limit. Overlength inputs/keys fail explicitly, never truncate.

The initial suffix audit found 674 contextual-code, 673 mention and 558 evidence
rows with footnote artifacts per database. The source-change counts above also
include punctuation, whitespace and citation/cross-reference tails. Mention
text and legacy normalized/matched fields are repaired together; existing legacy
`Clean` semantics are retained separately from the new `Clean2` keys.

The parser's related-section boundary bug no longer consumes Histopathology,
Etiology and subsequent explanatory sections as related terms. Prose detection
ignores balanced scientific qualifiers, preserving the full Carney triad name
and genuine names with citations. Only uncoded entity rows and confirmed
non-term related rows were removed. Exact removal IDs are recorded in
`bluebooks.db.local-build.json`, including its repair history.

There were also **465 contextual-code terms** containing punctuation or prose
after a code embedded in text. **407** received an unambiguous structured
coding/subtype name; **58** have NULL term/derived values rather than fabricated
names. All 9,692 contextual code rows and all their code fields remain intact.

Numeric scientific superscripts/subscripts, positive/negative signs, genuine
qualifiers, policies, scores, identifiers, snippets, raw HTML and section bodies
were preserved. No additional reference table required the audited trailing
footnote repair. Original leading source notation such as `//` in 252 mention
rows was retained; it is outside the trailing-artifact repair and is removed by
the authoritative comparison rules, not silently rewritten in display data.

### Normalizer authority and verification

The maintainer explicitly selected the existing deployed SQL Server `Clean2` v3,
not the older repository implementation. Its exported SQL is now the single rule
source for the restricted Python replacement-program executor. The earlier file
was backed up; historical before/after examples are marked as obsolete for v3.

- **68 regression tests passed**; edited modules have no editor diagnostics.
- Initial spelling/Clean2 comparison: **10,065 distinct real inputs**, zero
  discrepancies after aligning with deployed v3.
- Full hygiene/composition preflight: **9,998 retained inputs/edge cases**, zero
  Python/SQL discrepancies. Final refined whitespace/cross-reference check:
  **8,998 distinct repaired inputs/edge cases**, zero discrepancies.
- Zero source/derived-value mismatches or empty source/derived strings in all
  five tables. The 58 intentional NULL contextual names are not fabricated keys.
- Largest US key: 399 characters; largest normalized key: 386 characters.
- Verified SQLite lookup plans use all 10 indexes. SQL index and trigger
  metadata were checked; rollback-only multirow INSERT/UPDATE and attempted
  derived-key overwrites passed on all five SQL tables.
- Compared the pre-repair backup to the final database: all unaffected fields
  match for every retained row, and raw corpus hashes remain unchanged.
- All **23 managed table row-value hashes match** between both engines.
- A complete backed-up rerun made **zero source/key changes, zero deletions and
  zero contextual repairs**, and again passed 23-table parity.
- Expected normalization collision groups (162 / 26 / 251 / 326 / 4 by table)
  were reviewed through representative values: punctuation, NOS, spelling and
  deployed article-removal rules are many-to-one by design. These keys are not
  unique entity identifiers or inferred synonym/code crosswalks.

Evidence `TermUS` is based on its existing legacy grouping key; it cannot
recover British spelling already lost before this repair.

### Backups and notebook/documentation integration

Verified pre-task snapshots:

- SQLite: `local_backups/bluebooks-20261011T022724777852Z.db`.
- SQL Server COPY_ONLY/CHECKSUM backup, checked with RESTORE VERIFYONLY:
  `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\BlueBooks-local-parity-20261011T022724777852Z.bak`.
- Four original notebook backups, hash-verified before edits:
  `local_backups/notebooks-20261011T023500Z/`.

Fresh paired database snapshots were also made before each repair run:
`20261011T025633229883Z` (main repair), `20261011T031355667041Z` (four remaining
saved-section fragments), and the final idempotence run recorded in the sidecar.
No backup was overwritten.

Runner, Explorer 2, Explorer 3 and the site-query notebook now document the
rules, completed counts and read-only checks. All four pass notebook-format
validation and retain their final user/scratch cell unchanged. Every active
notebook generator now makes and verifies a byte-identical backup before writes.
The shared/companion schemas, data dictionary, READMEs and agent query guide were
updated. A moved reference-workbook path blocked the first repair attempt;
the documented Library relocation is now accepted only after verifying identical
file bytes, and provenance records the current path.

Schema provisioning and cross-engine data commits are not a distributed
transaction. Repair failures are raised explicitly, with rollback where possible
and verified backups retained; completion is only reported after parity succeeds.

## Recovered alternate diagnostic vocabulary (build version 8; 2026-10-11)

The maintainer approved the initial separate-table proposal. Explanatory prose
was not restored as terminology. Instead, recognizable diagnostic names were
extracted and retained as alternate/non-official vocabulary, with the original
deleted text kept as explicit evidence. Recovery covers names from 57 of the
85 removed source rows; the remaining rows do not provide additional defensible
diagnostic-name extractions.

### Persisted results in both databases

| Measurement | Rows |
|---|---:|
| New `entity_related_terms` rows, `kind='other'` | 171 |
| Existing page-linked terms reused | 17 |
| Recovered/reused page-linked targets | 188 |
| `entity_term_provenance` source links | 215 |
| `entity_term_code_matches` proposed edition/code matches | 398 |
| Page-linked targets with no defensible code match | 16 |
| Total `entity_related_terms` after recovery | 5,424 |

All provenance links carry `source_kind='AI_recovered_prose'`, a suggested
qualifier (`synonym`, `related`, `subtype`, `grouper` or `other`), historical
status where applicable, and `review_status='proposed'`. The `is_added_term`
flag distinguishes genuinely new vocabulary from reused source terms.
Historical source table/row IDs and full original text remain available;
these IDs refer to removed rows, not live foreign-key targets.

The 398 matches distinguish ICD-O-3.2 from ICD-O-4 and exact, synonym, broader
and conditional relationships. They preserve official workbook terms, row
numbers, file hashes, associated synonyms and coding conditions. Original
ICD-O-3.2 is not conflated with later registry/CPC additions. Alternative codes
are candidates, not probabilities or automatic patient coding decisions.
Unmapped names remain searchable vocabulary.

No proposed code was written into `entity_codes.code` or `page_icdo_codes`.
Source code assignments, raw corpus and existing evidence rollups were
preserved. New AI-added vocabulary is excluded from the structured positive
mention input, so a proposal cannot become affirmative source-code evidence.
Whole-page documents and native indexes were rebuilt to include recovered names.

### Query and rebuild integration

- `v_entity_terms` exposes every coding/related term once.
- `v_entity_term_provenance` exposes all original source links.
- `v_entity_term_code_matches` exposes candidates without multiplying them by
  source citations, and retains terms with no match through left joins.
- Source codes and suggested codes remain separate columns.
- New terms use the existing indexed, automatically maintained `TermUS` and
  `TermNorm` columns; lossy normalized keys are not used to deduplicate labels.

The persistent [recovery manifest](Library/recovered_terms.json) and
[recovery implementation](term_recovery.py) are integrated into local refresh,
mirror, search, all four active notebooks and their generators. Refresh
re-links regenerated target IDs and preserves provenance review status,
suggested qualifiers, notes and match review status by stable keys.
The schema scripts, dictionary, READMEs and companion query guide document
the storage and review contract; the companion SQLite schema includes the views.

### Backups and acceptance

Fresh, verified backups preceded version-8 writes:

- SQLite: `local_backups/bluebooks-20261011T153252881708Z.db`.
- SQL Server COPY_ONLY/CHECKSUM backup, verified with RESTORE VERIFYONLY:
  `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\BlueBooks-local-parity-20261011T153252881708Z.bak`.
- Each active notebook received a new byte-verified backup under
  `local_backups/notebooks-20261011T15315...Z/` before its update.

All **25 managed table row-value hashes match** after the completed mirror;
the optional book-70 inventory exception is unchanged. The application verified
that unaffected table hashes stayed identical, normalization checks passed, and
all expected terms, source links and candidate matches were present.
**75 regression tests passed** before application; the seven recovery tests
were rerun successfully after schema/document regeneration. The generated
standalone companion schema also created queryable recovery views successfully.

Post-application acceptance compared every retained original row against the
fresh SQLite backup and found no changes outside rebuilt search documents.
All 143 distinct recovered/reused display strings have identical US/normalized
keys in Python and SQL Server; all five term tables passed rule validation.
The comprehensive term/provenance/match views contain 11,947 / 11,974 / 12,173
rows respectively, identically in both engines, and retain all 16 unmapped
recovery targets. All 12 new SQL Server checks are enabled and trusted.
A rollback-only repeat population added zero terms, source links or matches
and preserved review metadata. Whole-page search returned results in both
engines, and SQLite quick-check passed.

Cross-engine completion is verified, not distributed-transaction atomicity.
The paired backups and full application report remain recorded in the build
sidecar. No remote publication or Git commit was performed.

## Explicit coding-name recovery and ASCII display case (version 9; 2026-10-11)

The live audit found **zero isolated ')'** values in term-named text columns in
either engine. The earlier conservative repair had already removed those
fragments, leaving 58 NULL `page_icdo_codes.term_in_coding_section` values and
58 NULL values in each associated `TermUS`/`TermNorm` column.
The only other term-column NULLs were 232 optional
`icdo_site_specific_terms.preferred_term` values absent from the workbook;
these remain NULL rather than inventing preferred terminology.

All 58 contextual coding names were recovered from explicit name/code pairs
in the same saved section. Multiple names sharing a code were preserved,
nested subtype headings were supported, and code-before-parenthetical-name
examples retained their own names rather than the parent-page diagnosis.
Two missing alternatives were added as code rows 9693 and 9694; all 9,692
original coding-row IDs, codes, page links and headings remain intact.
No original row was deleted. Saved-source replacement characters were resolved
only against a unique matching structured term, never guessed.

The confirmed capitalization policy changes only a leading ASCII `a-z`,
leaving later characters, numeric/Greek starts and punctuation-led values
unchanged. This is a display rule in `UpperInitial`/`CleanDisplayTerm`, not
a change to `Clean2`'s case-sensitive comparison program. Existing stored
`TermUS`/`TermNorm` and legacy term keys are maintained with the same initial-case
policy; raw evidence text and workbook evidence JSON remain verbatim.

| Table | Existing rows updated |
|---|---:|
| entity_codes | 1,445 |
| entity_related_terms | 4,478 |
| page_icdo_codes | 728 (including 58 recovered NULL names) |
| page_term_mentions | 370 |
| page_entity_evidence | 370 |
| entity_identifiers | 14 |
| icdo4_morphology | 3 |
| cpc_morph_codes | 20 |
| icdo_site_specific_terms | 18 |

The provenance/match tables already had capitalized display values and required
no data changes. All 11 managed term-bearing tables now have write-time
maintenance. Full refresh code/evidence extraction uses consistent display/key
handling; shared-code alternatives are not lost on rebuild. Existing mention,
hint, evidence scores/counts, source corpus, code assignments and review metadata
were preserved. Search documents and both engines' native search were refreshed.

Fresh verified paired backups immediately before the successful application:

- SQLite: `local_backups/bluebooks-20261011T183935312667Z.db`.
- SQL Server COPY_ONLY/CHECKSUM, verified with RESTORE VERIFYONLY:
  `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\BlueBooks-local-parity-20261011T183935312667Z.bak`.

Earlier attempts encountered SQL identity-insert and schema-bound function
dependency errors. Both raised explicit failures and rolled back data changes;
the corrected application completed at 18:44 UTC, verified all 25 managed
row-value hashes and passed all 11 term-rule validators. Additional backups
preceded each attempt. Schema provisioning is not distributed-transaction atomic.

Final acceptance: **78 regression tests passed**. All **32 actual term text/key
columns** contain no isolated ')' or initial lowercase ASCII letter. Metadata
enums and exact code-term evidence JSON are deliberately outside display casing.
Direct SQL/Python edge comparisons passed for ASCII, NULL/empty, Greek, numeric,
punctuation-led and scientific-sign inputs. All original display values equal
their backup values with only the permitted initial ASCII uppercase change,
except the 58 explicitly recovered NULL coding names. A rollback-only repeat
case repair updated zero rows; all 11 SQL term/display triggers are enabled.
Whole-page search responded in both engines; SQLite quick-check passed.
The 215 recovery source links and 398 proposed matches remain complete.
All four active notebooks were backed up, upgraded and format-validated with
their final user cells unchanged; generated schemas and the companion query
guide/READMEs were updated. The generated SQLite recovery views were tested.

## Related-term parser repair (2026-10-13)

The saved-HTML related-term parser now splits semicolon lists only outside
balanced parentheses, preserving cytogenetic terms such as `t(15;19)
carcinoma`. It also separates qualified Acceptable/Not recommended labels and
rejects editorial cross-references and explanatory prose. The canonical refresh
replaced 90 malformed or prose `entity_related_terms` rows with 58 complete
source-backed terms (net change: -32), and removed 12 uncoded instruction,
cross-reference or explanatory-prose rows from `entity_codes`. No assigned
coding terms were removed. All 398 proposed ICD-O code-match records were
unchanged.

Fresh verified backups were made before the live refresh:

- SQLite: `local_backups/bluebooks-20261013T224237351111Z.db`.
- SQL Server COPY_ONLY/CHECKSUM, verified with RESTORE VERIFYONLY:
  `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\BlueBooks-local-parity-20261013T224237351111Z.bak`.

SQLite and SQL Server now match by row count and SHA-256 value for all 26
managed tables. `entity_codes` contains 6,500 rows; `entity_related_terms`
contains 5,386 rows. The parser and mirror regression suites passed (14 term
hygiene tests and 22 local pipeline tests).

The full read-only `validate_local.py` run passed: SQLite integrity was `ok`,
all managed-table hashes matched, term normalization mismatches were zero,
whole-page searches returned results from both backends, and both Explorer
and site-term notebooks executed their tested cells on SQLite and SQL Server.
All saved sections/documents were present; the coverage report lists 44 saved
pages without parsed sections, an existing parse-coverage gap not changed by
this repair.
