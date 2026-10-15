# Page code-term view: performance findings and implementation plan

## Scope and output contract

The presentation query pairs `ICDO32` and `ICDO4` on exact, case-sensitive
`page_id` and `TermUS`; the public `code_edition` column is removed.
Edition-specific candidate labels, proposal flags, outcomes, match types,
conditions, and review states remain separately available with suffixes `32`
and `4`. Source assignments and evidence are not rewritten.

The row key is `(page_id, TermUS, ICDO32, ICDO4, candidateTermUS32,
candidateTermUS4)`. Multiple mappings retain all scalar combinations; these
are possibilities, not an asserted crosswalk. See the
[data guide](../data-guide.md) for the complete interpretation.

The query implementation is in [term_pipeline.py](../../../app/term_pipeline.py).
The paired deployment helper in
[bluebooks_local.py](../../../app/bluebooks_local.py) backs up both databases,
checks protected table hashes, and compares view values across engines.

## Measurements, 2026-10-15

Measured against the local SQLite corpus and local SQL Server `BlueBooks`,
not the unrelated configured Azure connection. No shared caches were flushed
and no server settings were changed. Warm timings exclude first compilation;
they are observations on this machine, not service-level guarantees.

### Data and storage

| Table | Rows | SQL Server base storage, approximately |
|---|---:|---:|
| `page_term_mentions` | 117,559 | 154 MiB |
| `term_lookup_evaluations` | 94,953 | 84 MiB |
| `term_code_candidates` | 69,670 | 77 MiB |
| `entity_codes` | 6,497 | 2.6 MiB |
| `page_icdo_codes` | 9,991 | 4.2 MiB |

Storage is the base heap/clustered allocation, excluding nonclustered indexes.
The corpus is not large enough to justify partitioning; expensive repeated
work and wide evidence rows are more important than row count.

### Timings and limitations

| Query | Original view | Relational paired view | Indexed temporary read-model trial |
|---|---:|---:|---:|
| SQL Server: all columns, `page_id=4941` | 8-9 ms warm; first measured execution 0.59 s | 49 ms warm; first execution 3.20 s | 0.55-0.75 ms warm |
| SQL Server: all columns, `TermNormUS=N'Gynandroblastoma'` | 20-27 s | 3.68 s warm; first execution 10.93 s | 0.95-1.21 ms warm |
| SQL Server: full `COUNT(*)` | 1.0-1.24 s warm | 4.89 s warm | 2.6-5.8 ms warm |
| SQLite: page 4941, all columns | 5.94 s | approximately 1.95 s on an in-memory corpus copy | Not yet measured |
| SQLite: full `COUNT(*)` | 2.97 s | approximately 2.77 s on the same copy | Not yet measured |

The old view returned 51,179 rows; the paired view returns 24,350.
Page 4941 returns two rows instead of four, including its separate unmapped
term. Combining editions must not be confused with deleting distinct terms.
The normalized-term lookup returns 12 paired rows instead of 24 edition rows.

**Important:** pairing is a correctness change, not a universal performance
fix. Normalized-term lookup improves, but the full-count query regresses.
The additional grouping/window/pairing work and larger projections are not
free. Do not describe the revised relational view as uniformly faster.

The read-model prototype used a connection-local SQL Server temporary table
populated with the complete new view, then indexes on `page_id` and
`(TermNormUS, page_id)`. Building all rows took 19.88 s; creating both indexes
took 0.185 s. Subsequent queries fully fetched their requested results.
This demonstrates the potential of computing once per publication instead
of on every read; durable-table costs, concurrency and refresh correctness
still need validation. It is not a production cache implementation.

## Diagnosed costs

1. **Repeated traversal of the same evidence.** The old actual page plan
   contains 43 nested-loop operators, 22 clustered seeks, 22 nonclustered
   seeks, and two RID lookups. It references mentions 14 times, evaluations
   12 times, and candidates six times. Summed operator logical reads for
   that small page execution are 438. This is a plan-wide operator total,
   not a distinct-page count.
2. **Filter-dependent plans.** Page lookup can be very fast on SQL Server,
   while a selective normalized-term lookup is much slower. SQLite's old
   page plan scans source branches and builds temporary grouping structures
   before filtering the final aggregate.
3. **Exact matching does not match physical key collation.** `TermUS` and
   `TermNormUS` are `nvarchar(600)` with
   `SQL_Latin1_General_CP1_CI_AS` collation. The query deliberately compares
   display labels with `Latin1_General_100_BIN2`. The actual plan reports
   seek-affecting conversions on those comparisons. Do not remove exact
   comparison semantics just to obtain a seek.
4. **Mixed code types.** Live `page_icdo_codes.icdo_code_raw` and mention
   codes are `varchar(10)`, while other code columns are Unicode with
   different lengths. `COALESCE`/UNION introduce conversions. Any type
   alignment must retain the original strings, including letter variants.
5. **Current-state reads share wide historical/evidence tables.** Existing
   indexes cover page, normalized term, `(mention_id, edition, is_current)`,
   and candidate `evaluation_id`, but do not cover the whole presentation
   projection. Repeated evidence lookups, sorts and grouping remain.
6. **Pairing expands work as well as reducing visible rows.** The two
   edition branches reuse grouped results, but SQL Server can expand CTEs
   rather than persist them. A CTE is not a materialization guarantee.

The revised relational query replaces correlated outcome/source-presence
checks with grouped outcome, candidate-key and source-key relations, keeps
page/term keys direct, and includes the normalized key in grouping/window
partitions so filters have a path toward the sources.

### Experiments that were rejected

- Coalescing page keys across a full outer join blocked useful predicate
  pushdown. A SQLite corpus-copy execution exceeded its time budget. The
  implementation instead uses two left-join branches with direct page keys.
- A one-pass JSON packing/expansion prototype improved SQL Server term
  lookup to about 162 ms warm, but full count took 11-14 s. Its complexity
  and full-scan regression did not justify adopting it.
- A query-local `MAXDOP 1` trial made full count about 12 s and did not solve
  term lookup. No instance-wide parallelism setting was changed.
- Transactional trials added five source-table covering indexes:
  mention `(TermNormUS,page_id)`, current evaluation `(mention_id,edition)`
  including outcome, candidate `(evaluation_id,code)` including presentation
  fields, and page/term source-code indexes. Page lookup became about 13 ms
  warm, but term lookup remained about 3.2 s and full count about 4.9 s.
  These indexes were rolled back. Installing all of them is not the main fix.

## Recommended implementation sequence

### 1. Freeze correctness and representative workloads

- Preserve paired backups, protected-data hashes, exact column order, both
  edition code/label relationship sets, and cross-engine view parity.
- Keep tests for both editions mapped, either edition absent, neither
  mapped, ambiguity on both sides, repeated evidence, differing official
  labels, rejected/stale candidates, source/proposed flags and NULL codes.
- Benchmark real consumers: page lookup, normalized-term lookup, book/chapter
  browsing with explicit ordering, full projection/export, and full count.
  Record compilation separately, median/p95, CPU, elapsed time, logical reads,
  actual/estimated rows, memory grants, spills, and rows/bytes transferred.
  A count alone does not measure rendering or export performance.

### 2. Build an indexed presentation read model (highest payoff)

Use an ordinary derived table in each database, **not an indexed SQL Server
view**. This query's UNION, outer joins and window functions are incompatible
with indexed-view restrictions. Keep all original evidence and relationship
tables authoritative.

- Compute the complete paired projection into a staging table once after a
  successful refresh/mirror or affected-page update.
- Store a surrogate row ID. Validate the full nullable logical key with exact
  comparisons before publication. Do not force the entire wide label/code key
  into a SQL Server index: two `nvarchar(600)` labels already exceed ordinary
  nonclustered key limits. If using a hash for validation, check collisions
  against the actual key; a hash alone is not identity.
- Start with a narrow `page_id` index and `(TermNormUS,page_id)` lookup index.
  Benchmark a covering version with `ICDO32`, `ICDO4`, and proposal flags in
  INCLUDE columns. Avoid putting conditions, prose, JSON evidence, or every
  display column into every index. SQLite has no INCLUDE syntax.
- Add a book/chapter/page ordering index only after measuring that access
  pattern. Keep original page and term strings in the projection.
- Record projection schema version, completed generation, row count and source
  generation. Check code/label relationship coverage and row-value parity
  before publishing. Do not copy rejected or obsolete evidence into active
  mappings merely to simplify refresh.
- Publish transactionally so readers see one complete generation, never an
  emptied or half-built table. Do not introduce dirty reads/`NOLOCK`.

**Freshness is a release gate.** The public view must not silently serve a stale
projection. Wire every relevant writer before redirecting it: source
assignments, observations/current flags, candidates/evaluations, review-state
changes, page/site hints, book aliases and chapter/page metadata. Restrict
unmanaged writes or provide transactional affected-page maintenance at the
database boundary. Changing a book alias must update all affected pages.
An asynchronous invalidation queue or TTL alone does not preserve this view's
current semantics. Keep the relational view until synchronous maintenance and
failure/rollback paths are verified.

The prototype suggests orders-of-magnitude faster normalized-term reads and
much cheaper counts. Initial acceptance targets on the same corpus are warm
page/term median under 20 ms, p95 under 100 ms, and full count under 50 ms.
Measure full export independently, and bound refresh overhead before rollout.

### 3. Tune the refresh/source path selectively

After the read model is in place, profile its build rather than optimizing
every historical evidence read.

- Trial persisted binary/exact matching keys and page/exact-term indexes
  if actual plans still show seek-affecting collation conversions. Preserve
  existing user-visible collation behavior elsewhere.
- Align code types/lengths only through a checked migration; prove no
  truncation or spelling/code changes before applying it.
- Compare a filtered current-evaluation covering index with the existing
  `(mention_id,edition,is_current)` index. Trial candidate covering indexes
  only if build reads justify their storage/write cost.
- Inspect statistics sampling, modification counters and actual estimates
  after bulk refresh. Update the affected statistics when justified; do not
  prescribe blanket FULLSCANs, rebuilds, or dropping overlapping indexes
  without usage evidence from the other query workloads.

### 4. Validate, roll out, and monitor

- Re-run regression tests, original-data hashes, code/label coverage, duplicate
  checks, and full SQLite/SQL Server row-value parity.
- Prove rollback on failed generation and readers concurrent with refresh;
  test review changes, alias edits and partial refreshes.
- Compare the same workloads over multiple warm runs without clearing shared
  caches. Track projection build duration, publication generation, row count,
  source-generation agreement, read latency and write overhead.
- Keep the relational definition and paired backups as the rollback path.
  Roll back the public interface if freshness or correctness cannot be proved.

## Status

Implemented: paired edition columns, independent edition metadata, suppression
of same-edition uncoded duplicates, updated deployment duplicate checks, and
regression tests. The paired view is deployed in both SQLite and SQL Server,
with 24,350 identical rows and identical 47-column order. Paired backups were
created before deployment. Protected-data hashes and all 32 managed-table
cross-engine hashes passed. Comparison against the pre-deployment backup
confirmed that all 32,936 non-NULL edition/code/official-label relationships
and all 23,784 page/term identities survive the reshape. In both databases,
page 4941's `Gynandroblastoma` row contains `8632/1` and `86320/1` together.

Query/index/read-model experiments used database transactions
or private copies; trial indexes and temporary projections were not retained.
The materialized read model, physical type/collation migrations and new
production indexes are **planned, not deployed**.

References: Microsoft
[indexed-view requirements](https://learn.microsoft.com/sql/relational-databases/views/create-indexed-views)
and [index design guidance](https://learn.microsoft.com/sql/relational-databases/sql-server-index-design-guide).
