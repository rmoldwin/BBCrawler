# Audit subtitle capture and usefulness

**Status:** open, deferred

Do not add subtitle extraction before the current observation and reference
matching workflow is stable. For that active contract, see
[Reference matching](../docs/technical/reference-matching.md).

## Question

Determine whether subtitles are present in saved Blue Books pages, whether the
crawler currently captures them correctly, and whether the captured text adds
useful terminology or code evidence.

An empty stored subtitle field alone does not establish that the source has no
subtitle or that the current page selector is failing.

## Work

- [ ] Select a bounded, representative sample of saved HTML across editions and
  page types.
- [ ] Check the source markup and stored page metadata to distinguish source
  absence from a capture failure.
- [ ] Decide whether subtitle text contains useful terminology or code
  metadata, rather than repeating existing title or section evidence.
- [ ] If the sample shows no useful content, document the evidence and close
  this issue without adding harvesting behavior.
- [ ] If useful content exists, add it as an observation in the shared pipeline
  with subtitle provenance and edition-aware matching.
- [ ] Add focused tests and update both affected database workflows, notebooks,
  and documentation only for confirmed behavior changes.

## Acceptance criteria

- Source absence and capture failure are distinguished with recorded evidence.
- No terms, duplicate observations, or code assignments are invented.
- Subtitle observations use the existing observation, context, and matching
  contracts; no separate parser or matcher is added.
- Printed source assignments and proposed reference codes remain distinct.
- Refresh is idempotent and preserves existing review decisions.
- The audit does not begin until the shared pipeline contract is ready.
