# Current issue backlog

This folder tracks local follow-up work for BBCrawler. It is not a GitHub issue
tracker mirror; no remote publication is implied. Check each item's current
status before starting work.

| Topic | Status | What remains |
|---|---|---|
| Hierarchy in coding pages | Deferred | Determine whether page layout should be represented as grouping structure without treating visual indentation as ICD-O hierarchy. |
| Cross-edition code discrepancies | Planned | Build neutral audits comparing Blue Books assignments with each other and official references. |
| ICD-O reference annexes | Partial | Base morphology reference loading is implemented; morphology annex and topography annex/site-restriction ingestion remain unresolved. |
| Subtitle capture | Open, deferred | Establish whether saved source pages contain useful subtitles and whether capture is correct before adding observations. |

## Scope of the remaining work

### Coding-page hierarchy

Inspect representative saved HTML structure (headings, containers, style, and
indentation) to distinguish visual category rubrics from diagnostic terms.
If useful, represent rubrics as grouping structure without dropping coded or
uncoded term observations. Indentation is not an official ICD-O hierarchy and
must not be treated as one.

### Cross-edition discrepancies

Build queries that compare TOC titles and code hints with the related
`page_icdo_codes` evidence, then compare Blue Books variants with the
edition-specific official morphology references. Preserve variants and their
provenance neutrally; do not pick a winner until supported by authoritative
errata or standard reference evidence. See the current
[data guide](../docs/technical/data-guide.md) and
[reference-matching contract](../docs/technical/reference-matching.md).

### ICD-O reference annexes

Loading the base ICD-O-4 morphology workbook and current compiled morphology
reference is implemented. The open work is to parse the local
`Morphology_annexes.xlsx` and `Topography_annexes.xlsx` updates, including new,
revised, and retired morphology entries plus topography changes and
site-specific restrictions. Preserve source file/sheet/row identity, edition,
and conditions; then re-evaluate affected candidates without rewriting printed
source assignments. Inputs are local under the neighboring
`BBNotebook\Library\CPC_ICDO4\Updates_2026_09` reference directory.

## Issue notes

- [Audit subtitle capture](subtitle-capture-audit.md) — preserve this
  investigation as deferred until the current observation/matching workflow is
  stable.
