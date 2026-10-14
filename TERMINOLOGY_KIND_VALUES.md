# `v_page_code_terms.terminology_kind` values

`terminology_kind` records **where in the source page each term came from**.
It describes provenance only. It does **not** decide whether a code is valid,
whether a term is preferred, whether two terms are synonyms or a registry status.
Recovered-term relationships are stored separately in `suggested_qualifier`.

## Atomic values

There are five possible atomic values:

| Value | Definition | Origin |
|---|---|---|
| `coding` | Term from the page's ICD-O coding or Subtype(s) section | `entity_codes` rows; candidate and uncoded rows from `entity_codes` |
| `contextual` | Term-code pair found in section text and stored as a page-level code mention | `page_icdo_codes` rows |
| `acceptable` | Related terminology explicitly labeled "Acceptable" by the source | `entity_related_terms.kind='acceptable'` |
| `not_recommended` | Related terminology explicitly labeled "Not recommended" by the source | `entity_related_terms.kind='not_recommended'` |
| `other` | Related terminology without an Acceptable/Not recommended label, including recovered alternate terms | `entity_related_terms.kind='other'` |

`entity_related_terms.kind` is constrained to `acceptable`, `not_recommended` or
`other` in both databases. `coding` and `contextual` are assigned by the views.

## Combined values

`v_page_code_terms` has one row per page, edition, code and `TermUS`. When the same
code-term pair has more than one origin, distinct atomic values are combined in
alphabetical order with `; ` separators. For example, `coding; contextual` means the
same code-term pair appears in both the coding section and page section text.

Current values (same in SQLite and SQL Server; 15,339 rows):

| Value | Rows |
|---|---:|
| `coding; contextual` | 4,415 |
| `contextual` | 4,068 |
| `not_recommended` | 3,092 |
| `acceptable` | 1,931 |
| `coding` | 1,284 |
| `other` | 517 |
| `acceptable; coding` | 17 |
| `coding; other` | 10 |
| `acceptable; not_recommended` | 4 |
| `contextual; other` | 1 |

Other combinations of the five atomic values may occur after future refreshes.
Use `LIKE '%not_recommended%'` (or split on `; `) for value-based filtering, not
equality alone.

## Related fields

| Field | Meaning |
|---|---|
| `terminology_kind` | Source location/type of terminology |
| `code_kind` | How the code was attached: `source_assignment`, `contextual_code`, `candidate` or `uncoded_term` (combined with `; ` the same way) |
| `source_kind` | Extraction or recovery pathway: `parsed_entity`, `section_text` or `AI_recovered_prose` (combined with `; ` the same way) |
| `suggested_qualifier` | Proposed relationship for recovered terms: `synonym`, `related`, `subtype`, `grouper` or `other` |
| deprecated `is_subtype` | Legacy source subtype-section flag, retained for compatibility only; do not use for new logic. See [IS_SUBTYPE_ASSIGNMENT.md](IS_SUBTYPE_ASSIGNMENT.md). Prefer `term_role` and explicit provenance/relationship metadata. |
