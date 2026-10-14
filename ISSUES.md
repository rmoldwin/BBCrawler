# Deferred Issues & Enhancement Backlog

This document tracks deferred architectural, analytical, and data ingestion tasks identified during terminology standardization and parity implementation.

---

## Issue #1: Hierarchical Rubric Extraction from ICD-O Coding Pages

- **Status**: Backlog / Deferred
- **Context**: On book-level ICD-O coding pages (such as page 474 for Eye and Orbit Tumours), indentation levels and header formatting represent page-level visual hierarchy rather than official ICD-O hierarchical semantics.
- **Problem**:
  - Indents alone do not reliably distinguish between preferred terms, synonyms, related terms, and formal subtypes as used in published ICD-O manuals.
  - Intermediate headers (e.g., larger fonts, italics, section division headings) organize diagnostic categories but do not themselves qualify as valid diagnostic terms.
  - Visual layout rubrics vary across books (e.g., Digestive System v5 vs. Eye and Orbit v5) and between editions/beta releases.
- **Planned Approach**:
  1. Inspect raw HTML DOM structure (`<h1>`-`<h6>`, `<div class="...">`, inline CSS font-size/font-weight/italic styles) alongside indentation levels.
  2. Differentiate informational category rubrics from diagnostic entities so categories are recorded as grouping nodes rather than flat term entries.
  3. Map the extracted rubric to a structured hierarchy without dropping uncoded diagnostic entities.
- **Priority**: Medium (all coded and uncoded diagnostic terms are currently extracted safely into `page_icdo_codes` and `page_term_mentions` with layout indentation metadata).

---

## Issue #2: Cross-Edition and Book-to-Official ICD-O Discrepancy Auditing Queries

- **Status**: Backlog / Planned
- **Context**: In beta and transitional editions of WHO Blue Books, discrepancies exist between Table of Contents (TOC) names/codes and ICD-O coding page names/codes.
- **Problem**:
  - A TOC title may cite an updated morphology code while the coding page retains an earlier code, or vice versa.
  - Differences in wording, punctuation, and qualifier terminology occur between the narrative entity page and the summary ICD-O coding table.
  - Discrepancies also occur between Blue Book summary tables and official IARC / WHO ICD-O releases (ICD-O-3.2 and ICD-O-4).
- **Planned Approach**:
  1. Build automated audit queries comparing:
     - `pages.title` / `pages.icdo_code_hint` vs. `page_icdo_codes.term_in_coding_section` / `page_icdo_codes.icdo_code` for the same entity.
     - Book-assigned codes vs. `cpc_morph_codes` (ICD-O-3.2) and `icdo4_morphology` (ICD-O-4).
     - Cross-book differences where identical tumor entities appear with divergent codes across different organ systems.
  2. Record both variants neutrally with full provenance (avoid prematurely "picking a winner") until official IARC errata or standard tables adjudicate.
- **Priority**: High (scheduled for analytical query development).

---

## Issue #3: Ingestion of September 2026 IARC Official ICD-O-4 Update Files

- **Status**: Backlog / Planned
- **Location**: `BBNotebook/Library/CPC_ICDO4/Updates_2026_09` (local reference files; excluded from Git)
- **Source Files**:
  - `ICD-O-4.xlsx` (Full ICD-O-4 release specifications)
  - `Morphology_annexes.xlsx` (New, revised, and retired morphology codes and synonyms)
  - `Topography_annexes.xlsx` (Topography updates and site-specific restrictions)
- **Planned Approach**:
  1. Create automated loaders in `bb_icdo_lookup.py` to parse the September 2026 Excel update packages.
  2. Update or supplement reference tables (`icdo4_morphology`, `cpc_morph_codes`, and topography references) in both SQLite and SQL Server databases.
  3. Re-evaluate `entity_term_code_matches` against the updated lexicon, checking candidate conditions, synonyms, and narrower/broader matches.
- **Priority**: Medium (current system operates on the verified `CPC_MorphCodeList_2026Sep08.csv` and `1-s2.0-S1877782126000044-mmc1.xlsx` baselines).
