# Audit BB subtitle capture and add harvesting only if useful

Status: open, deferred

Dependency: complete the [main term-harvesting refactor](../TERM_HARVESTING_REFACTOR_PLAN.md)
before starting this work.

Tracking: repository-local issue. GitHub publication is pending a confirmed
target repository; no remote issue has been created.

## Background

All 3,634 audited stored pages have empty subtitles. This does not establish
whether source pages lack subtitles or current selectors fail to capture them.
Subtitle hints currently use a four-digit code expression.

## Tasks

- [ ] Inspect a bounded representative sample of saved HTML across editions and
  page types; consult authorized live pages only if necessary.
- [ ] Establish whether subtitle elements exist and capture is correct.
- [ ] Determine whether subtitle text contains useful terminology or code
  metadata.
- [ ] If no useful content exists, document the evidence and close this issue
  without adding a harvesting feature.
- [ ] If useful content exists, route it through the shared observation pipeline
  with subtitle provenance and edition-aware code recognition.
- [ ] Update both database workflows, affected notebooks, documentation, and
  focused tests for any confirmed behavior changes.

## Acceptance criteria

- Source absence and capture failure are distinguished with recorded evidence.
- No invented terms, duplicate observations, or separate parsing pipeline.
- Source assignments and proposals remain distinguishable.
- Refresh remains idempotent.
- No subtitle work begins before the main refactor is complete.
