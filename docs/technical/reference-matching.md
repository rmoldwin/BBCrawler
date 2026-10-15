# Reference matching

This guide defines how BBCrawler connects wording found in saved Blue Books
pages to official morphology reference data. Matching is evidence for review;
it does not change what a source page printed and does not establish a
diagnosis. For storage and field meanings, see the
[data guide](data-guide.md) and the generated
[table and column reference](table-columns.md).

## Keep observation, source code, and proposal separate

The pipeline follows this sequence:

**Capture → observe → normalize → evaluate each edition → retain candidates and evidence → review**

- **Observation:** wording and context located on a page. Eligible titles are
  retained even when they have no source code or official match.
- **Source assignment:** a code actually printed in a Blue Books coding
  section. Keep its spelling, edition, page, and source provenance.
- **Candidate:** an official-reference code proposed for an observation by
  matching. Keep its edition, reference revision, evidence, conditions, match
  type, and review status separately from source assignments.
- **Decision:** a review event about a candidate or observation. A decision is
  scoped to its target and evidence; it does not silently apply to a different
  page, edition, or reference revision.

Do not infer a code from a neighboring row, parent page, broad heading, or
another edition. A page-term pair with no defensible code remains present and
unmapped rather than receiving a guessed value.

## Observation sources and their limits

Observations can come from eligible entity titles, structured coding and
related-terminology sections, supported phrases in saved page prose, or
explicitly preserved legacy evidence. The source location and extraction route
are recorded. A recovered alternate term keeps its original text and recovery
provenance; it is not presented as newly captured source wording.

Prose extraction is conservative: it matches known official phrases at word
boundaries, prefers complete longer phrases where spans overlap, and retains
surrounding context. It is not an open-ended discovery system for every unknown
term in the prose. Raw saved HTML remains authoritative over a parsed section
cache; the cache is invalidated by source hash and parser version.

Structured coding/subtype terms, related terms (`acceptable`,
`not_recommended`, `other`), contextual code mentions, and observations from
page text are distinct sources. `terminology_kind` describes source origin,
not clinical validity, preferred-term status, or synonym status. Deprecated
`is_subtype` must not be used for new behavior; use `term_role` and explicit
source provenance.

Standalone placeholders such as “Not applicable” are filtered centrally.
Meaningful qualifiers and terms containing balanced parentheses are retained.
MIM/OMIM identifiers have their own evidence table and are not morphology
codes.

## Normalization is for comparison

The pipeline preserves source spelling and text, and derives US-display and
normalized keys for lookup. The current indexed fields are:

- `TermUS`: display-cleaned term with British spelling normalized to US
  spelling, then only an initial ASCII lowercase letter uppercased.
- `TermNormUS`: the normalized matching key derived from `TermUS` using the
  maintained `Clean2` behavior.

Trailing footnotes, bullets, list punctuation, and unambiguous citation or
“see” tails can be removed from term displays. Meaningful qualifiers,
balanced parentheses, numeric superscripts/subscripts, scientific signs, and
noninitial characters are preserved. `Clean2` itself preserves case and NULL;
the initial-letter display rule is separate. Keys are not silently truncated.

Cleaning or normalization is not an editorial replacement for the original
term. Do not normalize the stored source text in place or use a normalized-key
collision to discard distinct source terms. See the [data guide](data-guide.md)
for the indexed source tables and derived fields.

## Match editions independently

The local reference rows retain the edition, input filename, file hash, sheet,
actual workbook row, code, original official label, canonical label, and any
level or conditions. Current official morphology inputs are the local
ICD-O-3.2 reference workbook and the September ICD-O-4
`ICD-O-4.xlsx` `Morphology` sheet under the neighboring
`BBNotebook\Library\CPC_ICDO4\Updates_2026_09` reference directory. The
repository also uses auxiliary compiled and site-specific references; they do
not replace the edition-specific official morphology sources.

Each applicable edition receives an independent evaluation. Outcomes include
`matched`, `ambiguous`, `no_match`, `not_applicable`, `needs_review`, and
`not_evaluated`. Evaluation identity includes the observation, edition,
reference revision, matcher version, and evidence hash. Historical evaluations
remain available; a new reference revision does not silently rewrite them.

Candidate types distinguish official labels/synonyms from normalized or
broader suggestions. Exact and official synonym evidence is different from
lossy normalization. A contained broader label, conditional match, or
approximate wording is review-only; similarity alone never assigns a code.
Candidates are ordered with ordinal evidence tiers and explicit reasons, not
treated as calibrated probability scores. Preserve conditions and supporting
reference rows so reviewers can see why the proposal exists.

The reference matcher does not perform broad automatic Internet searches and
does not upload private page text or local reference files. If authorized
external evidence is used in a targeted review, record the source, access date,
revision where available, and the claim it supports. Informal search snippets
are not an authoritative code assignment.

## Context controls page-level meaning

A valid term/code relationship does not prove that the page asserts that code
as its own diagnosis. Context can be affirmative, negated, differential,
historical, incidental, a grouper, or a subtype. Negation and differential
context do not invalidate the reference relationship, but they limit whether
the mention is positive evidence for the page.

The evidence roll-up is deterministic and must not be described as a
probability. Review or exclude contextual evidence when appropriate; do not
inherit a code from a parent or neighboring entity. A site hint is even more
constrained: it requires a unique positive, unconditioned ICD-O-3.2 relationship
and qualifying local site-reference evidence. Hints with confidence at or
above the configured `0.90` threshold are page-level hints, not verified
term-specific sites or patient-level facts.

## Review and change behavior

`term_lookup_evaluations` records edition- and revision-specific outcomes.
`term_code_candidates` stores proposed official labels and codes with their
evidence. `term_review_decisions` is append-only and records scope, outcome,
reason, evidence identity, reviewer when available, and time.

Decision scope matters:

- A page-context rejection does not reject the term globally.
- A rejection for one edition does not automatically reject another edition.
- A candidate decision is distinct from a source observation decision.
- Materially changed source or reference evidence requires reevaluation and
  can reopen review; prior decisions remain in history.
- Candidate presence, ordering, or a high internal score is not reviewer
  approval.

The recovered-term manifest was a one-time migration input. Normal refresh
uses persisted observations and candidates; it must not replay the manifest.
Migration markers in `term_pipeline_migrations` prevent that replay.

## Main query surfaces

| Surface | Intended use |
|---|---|
| `page_term_mentions` | Observe text, source locator, context, extraction tier, and current/history state |
| `term_lookup_evaluations` | Compare the same observation across editions and reference revisions |
| `term_code_candidates` | Inspect proposed official codes, match evidence, conditions, and review status |
| `term_review_decisions` | Read append-only scoped review history |
| `v_term_candidate_evidence` | Audit candidates and evidence, including rejected or historical records |
| `v_page_code_terms` | Present source and proposed codes separately in page-oriented output |
| `v_entity_terms`, `v_entity_term_provenance`, `v_entity_term_code_matches` | Inspect entity labels, source links, and recovered-term proposals |
| `page_site_hints`, `page_entity_evidence` | Inspect constrained page hints and deterministic evidence roll-ups |

`v_page_code_terms` is a page-oriented presentation surface. Its exact
projection and row grain are defined by the active view implementation; do not
infer a source assignment from the presence, absence, or co-occurrence of
projected fields. Read the source-evidence and candidate tables when a
distinction matters. Views are unordered unless the query specifies an order.

## Deferred subtitle question

Subtitle capture is an open, deferred audit—not a promised feature. First
determine whether subtitles exist in a representative sample of saved HTML and
whether the current capture is correct. Add subtitle observations only if the
source provides useful content, using this same observation and matching
contract rather than a parallel parser. See the
[subtitle capture audit](../../issues/subtitle-capture-audit.md).
