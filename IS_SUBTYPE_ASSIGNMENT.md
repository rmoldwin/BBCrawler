# Deprecated legacy field: `is_subtype`

**Status: deprecated.** Do not use this field in new queries, extraction logic,
or schema design. It remains temporarily available for legacy compatibility;
prefer `term_role` and explicit source provenance/relationship metadata.
This note documents the historical assignment behavior only.

`is_subtype` was a **source-section flag**, not an inferred biological classification.

## In `entity_codes`

- **Deprecated `1`**: the term was extracted from a Blue Books **"Subtype(s)"** section, including nested subtype sections.
- **Deprecated `0`**: the term came from the ordinary **"ICD-O coding"** section.

A subtype could have deprecated `is_subtype=1` **even without an assigned code**. Historically, parsing set the flag in `_parse_subtype_block` in [bb_entity_extract.py](../BBNotebook/bb_entity_extract.py), and the pipeline stored it as `0` or `1` in [bluebooks_local.py](./bluebooks_local.py).

## In `v_page_code_terms`

For backward compatibility, the view still exposes the deprecated field:

- Carries the flag from `entity_codes`.
- For contextual `page_icdo_codes` rows, looks for a matching **page + raw code + TermUS** in `entity_codes`; otherwise it uses `0`.
- When repeated occurrences collapse into one code-term row, historically used **`MAX(is_subtype)`**: any matching subtype occurrence made the result `1`.

See the view definition in [term_recovery.py](./term_recovery.py).

## Recovered alternate terms

Terms stored in `entity_related_terms` appear with deprecated **`is_subtype=0`**, even if their recovery metadata has **`suggested_qualifier='subtype'`**. These deliberately express different things:

| Field | Meaning |
|---|---|
| Deprecated `is_subtype=1` | Legacy flag for extraction from a source subtype section |
| `suggested_qualifier='subtype'` | Proposed relationship for a recovered term |

Consequently, **deprecated `is_subtype=0` does not mean "this diagnosis is not biologically a subtype."** It means the legacy source-subtype flag was not established by this extraction pathway.

See also [terminology_kind values](TERMINOLOGY_KIND_VALUES.md) for the provenance values shown in `v_page_code_terms`.
