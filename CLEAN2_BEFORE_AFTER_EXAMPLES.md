# Clean2: side-by-side database examples

**Historical report:** the examples below describe the 2026-10-07 repository
version, not the deployed Clean2 v3 selected by the maintainer on 2026-10-10.
They are retained as historical examples and are not authoritative for today's
schema names or normalization results.
The current SQL snapshot and Python executor now share the deployed rules.
10,065 real inputs were checked against SQL Server with zero composition
discrepancies after alignment. Current indexed `TermUS` / `TermNormUS` columns use
`CleanBritishSpelling2` followed by `Clean2`; refer to
[DATA_DICTIONARY.md](DATA_DICTIONARY.md) and the active notebooks for current
rules and validation. These historical values are not regenerated or represented
as current results.

Generated: 2026-10-07T13:38:32-05:00.

## Scope and interpretation

- Exactly 25 examples for each of four categories (100 examples total). Each category uses distinct raw inputs and retains its database primary-key ID.
- **Before** is the actual stored normalized key; **after** is the computed Python `clean2()` output from the same raw input. The database was opened read-only; no normalized keys or ICD-O codes were changed.
- Rows are selected deterministically by primary-key order, rotating among detected rule combinations for variety. These are illustrative examples, not a random sample or frequency estimate.
- This is direct Clean2, **without** `CleanBritishSpelling2`. Retained British spelling is a missing composition stage, not evidence that British spelling is better for matching.
- The existing five Clean2 tests passed when this report was generated. The test column names the relevant test family, **not** a claim that the exact database row is a fixture or that every rule has direct test coverage.
- SQL Server behavior and SQL/Python parity were not tested here.
- Source: [bluebooks.db](bluebooks.db); implementation: [clean_term2.py](clean_term2.py); archived baseline retained locally under the ignored `Archive/` folder; tests: [tests/test_clean_term2.py](tests/test_clean_term2.py).

## Classification and test-coverage legend

| ID | Observed difference / Clean2 rule | Relevant existing test | Coverage qualification |
| --- | --- | --- | --- |
| S | British spelling is retained by direct Clean2 rather than Americanized | `test_case_and_spelling_behavior` | Direct fixture for `Tumour`; other spelling families are analogous, not individually tested. |
| P | Double-colon fusion delimiter `::` becomes a space | `test_punctuation_and_invisible_spacing` | Direct fixture: `a::b` becomes `a b`. |
| M | Minus before a closing parenthesis is preserved as Unicode minus, instead of lost to spacing | `test_punctuation_and_invisible_spacing` | Direct fixture: `ALK-)` becomes `ALK` followed by U+2212 and `)`. |
| I | Unicode spacing/invisible characters become spaces or are removed | `test_punctuation_and_invisible_spacing` | Direct fixtures for NBSP and zero-width space; the narrow no-break space U+202F example is not an exact fixture. |
| O | A space is inserted before an ordinary opening parenthesis | No direct existing fixture | **Coverage gap**: karyotype fixtures test compaction, not this ordinary-parenthesis spacing rule. |
| C | Letter case from the raw term is retained; stored before key has different case | `test_case_and_spelling_behavior` (family only) | Pre-existing stored/baseline discrepancy, not a proved new algorithm improvement; no direct exact case-preservation fixture. |
| B | Bound-prefix space is removed: micro, pre, post, extra, poly, atrio, tubulo, bronchiolo | No direct existing fixture | **Coverage gap**: the `Non small cell` fixture tests a different prefix rule and does not cover these prefixes. |
| R | Roman numeral becomes a digit in a grade/type/acronym context | `test_roman_numerals_and_karyotypes` | Direct fixtures for CIN III, Grade IV and type IV; other contexts are analogous. |
| N | Whole-word non/Non/NON prefix joins to the following word | `test_case_and_spelling_behavior` | Direct fixture for `Non small cell`; other cases/boundaries are not individually tested. |
| W | Whole-word matching preserves text that the old substring removal damaged | `test_whole_word_rules` | Direct fixture preserves `nose types`; individual database inputs may not be fixtures. |
| K | Karyotype parentheses are compacted | `test_roman_numerals_and_karyotypes` | Direct fixtures for del(5q) and inv(16)(p13;q22). |
| T | Trailing period is removed | No direct existing fixture | **Coverage gap**. |

Multiple IDs indicate observable contributions in the same row. Classification checks differing stored/output substrings; it is not an exhaustive execution trace. `Baseline? = Yes` means the archived `clean_old(raw)` reproduces the stored before key; `No` flags a pre-existing stored/baseline discrepancy.

## Changed-row totals

| Category | Non-null input rows | Rows with a different key | Examples below |
| --- | ---: | ---: | ---: |
| Page titles | 3,634 | 964 | 25 |
| CPC terms | 5,642 | 159 | 25 |
| ICD-O morphology terms | 4,720 | 1,153 | 25 |
| Site-specific terms | 3,715 | 107 | 25 |

## Page titles

Before is `pages.title_norm`; after is direct `clean2(pages.title)`. The code column is an existing page-level hint, not a newly assigned code.

Location: `pages`, primary key `page_id`. Test names below omit the `test_` prefix for readability.

| # | Record ID | Raw input | Before: stored key | After: direct Clean2 | Existing code | Rule IDs | Relevant test / gap | Baseline? |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 4124 | Myeloid neoplasm post cytotoxic therapy | Myeloid neoplasm post cytotoxic therapy | Myeloid neoplasm postcytotoxic therapy | (NULL) | B | No direct test (gap) | Yes |
| 2 | 712 | ELP1-related medulloblastoma predisposition syndrome(ELP1) | ELP1 related medulloblastoma predisposition syndrome(ELP1) | ELP1 related medulloblastoma predisposition syndrome (ELP1) | (NULL) | O | No direct test (gap) | Yes |
| 3 | 2721 | Round cell sarcoma with EWSR1::non-ETS fusions | Round cell sarcoma with EWSR1::nonETS fusions | Round cell sarcoma with EWSR1 nonETS fusions | (NULL) | P | punctuation_and_invisible_spacing | Yes |
| 4 | 166 | WHO Classification of Tumours: Editorial Board | WHO Classification of Tumors: Editorial Board | WHO Classification of Tumours: Editorial Board | (NULL) | S | case_and_spelling_behavior | Yes |
| 5 | 396 | Adrenal medulla and extra-adrenal paraganglia tumours: Introduction | Adrenal medulla and extra adrenal paraganglia tumors: Introduction | Adrenal medulla and extraadrenal paraganglia tumours: Introduction | (NULL) | S + B | case_and_spelling_behavior; No direct test (gap) | Yes |
| 6 | 2665 | EWSR1::SMAD3-rearranged fibroblastic tumour | EWSR1::SMAD3 rearranged fibroblastic tumor | EWSR1 SMAD3 rearranged fibroblastic tumour | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 7 | 4141 | Mixed-phenotype acute leukaemia, rare types | Mixed phenotype acute leukemia rares | Mixed phenotype acute leukaemia rare types | (NULL) | S + W | case_and_spelling_behavior; whole_word_rules | Yes |
| 8 | 4133 | Myeloid/lymphoid neoplasm with ETV6::ABL1 fusion | Myeloid lymphoid neoplasm with ETV6::ABL1 fusion | Myeloid lymphoid neoplasm with ETV6 ABL1 fusion | (NULL) | P | punctuation_and_invisible_spacing | Yes |
| 9 | 169 | ICD-O coding of digestive system tumours | ICD O coding of digestive system tumors | ICD O coding of digestive system tumours | (NULL) | S | case_and_spelling_behavior | Yes |
| 10 | 2961 | Intracranial mesenchymal tumour, FET::CREB fusion-positive | Intracranial mesenchymal tumor FET::CREB fusion positive | Intracranial mesenchymal tumour FET CREB fusion positive | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 11 | 170 | TNM staging of digestive system tumours | TNM staging of digestive system tumors | TNM staging of digestive system tumours | (NULL) | S | case_and_spelling_behavior | Yes |
| 12 | 4101 | Acute promyelocytic leukaemia with PML::RARA fusion | Acute promyelocytic leukemia with PML::RARA fusion | Acute promyelocytic leukaemia with PML RARA fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 13 | 172 | Introduction to tumours of the digestive system | Introduction to tumors of digestive system | Introduction to tumours of digestive system | (NULL) | S | case_and_spelling_behavior | Yes |
| 14 | 4102 | Acute myeloid leukaemia with RUNX1::RUNX1T1 fusion | Acute myeloid leukemia with RUNX1::RUNX1T1 fusion | Acute myeloid leukaemia with RUNX1 RUNX1T1 fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 15 | 174 | Tumours of the oesophagus: Introduction | Tumors of esophagus: Introduction | Tumours of oesophagus: Introduction | (NULL) | S | case_and_spelling_behavior | Yes |
| 16 | 4103 | Acute myeloid leukaemia with CBFB::MYH11 fusion | Acute myeloid leukemia with CBFB::MYH11 fusion | Acute myeloid leukaemia with CBFB MYH11 fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 17 | 175 | Oesophageal squamous papilloma | Esophageal squamous papilloma | Oesophageal squamous papilloma | (NULL) | S | case_and_spelling_behavior | Yes |
| 18 | 4104 | Acute myeloid leukaemia with DEK::NUP214 fusion | Acute myeloid leukemia with DEK::NUP214 fusion | Acute myeloid leukaemia with DEK NUP214 fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 19 | 177 | Oesophageal squamous dysplasia | Esophageal squamous dysplasia | Oesophageal squamous dysplasia | (NULL) | S | case_and_spelling_behavior | Yes |
| 20 | 4105 | Acute myeloid leukaemia with RBM15::MRTFA fusion | Acute myeloid leukemia with RBM15::MRTFA fusion | Acute myeloid leukaemia with RBM15 MRTFA fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 21 | 178 | Adenocarcinoma of the oesophagus and oesophagogastric junction NOS | Adenocarcinoma of esophagus and esophagogastric junction | Adenocarcinoma of oesophagus and oesophagogastric junction | (NULL) | S | case_and_spelling_behavior | Yes |
| 22 | 4106 | Acute myeloid leukaemia with BCR::ABL1 fusion | Acute myeloid leukemia with BCR::ABL1 fusion | Acute myeloid leukaemia with BCR ABL1 fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 23 | 179 | Oesophageal adenoid cystic carcinoma | Esophageal adenoid cystic carcinoma | Oesophageal adenoid cystic carcinoma | (NULL) | S | case_and_spelling_behavior | Yes |
| 24 | 4136 | Mixed-phenotype acute leukaemia with BCR::ABL1 fusion | Mixed phenotype acute leukemia with BCR::ABL1 fusion | Mixed phenotype acute leukaemia with BCR ABL1 fusion | (NULL) | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 25 | 180 | Oesophageal adenosquamous and mucoepidermoid carcinomas | Esophageal adenosquamous and mucoepidermoid carcinomas | Oesophageal adenosquamous and mucoepidermoid carcinomas | (NULL) | S | case_and_spelling_behavior | Yes |

**Table annotation:** Rule occurrences among these 25 selected examples: B=2, O=1, P=11, S=21, W=1. Mixed-rule rows count under each rule; these counts describe the sample only.

## CPC terms

Before is `cpc_morph_codes.term_clean`; after is direct `clean2(term)`. Codes are the existing CPC `icdo4` strings, displayed without conversion; an empty code is explicitly shown.

Location: `cpc_morph_codes`, primary key `row_id`. Test names below omit the `test_` prefix for readability.

| # | Record ID | Raw input | Before: stored key | After: direct Clean2 | Existing code | Rule IDs | Relevant test / gap | Baseline? |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1084 | Bronchiolo-alveolar adenocarcinoma, NOS | Bronchiolo alveolar adenocarcinoma | Bronchioloalveolar adenocarcinoma | 82500/3 | B | No direct test (gap) | Yes |
| 2 | 1093 | Bronchiolo-alveolar carcinoma, type II pneumocyte | Bronchiolo alveolar carcinoma II pneumocyte | Bronchioloalveolar carcinoma 2 pneumocyte | 82520/3 | B + R | No direct test (gap); roman_numerals_and_karyotypes | Yes |
| 3 | 4733 | Classic Follicular Lymphoma | Classic follicular lymphoma | Classic Follicular Lymphoma | (empty) | C | case_and_spelling_behavior (family; pre-existing) | No |
| 4 | 4955 | Agranular CD4+ CD56+ hematodermic neoplasm/​tumor | Agranular CD4+ CD56+ hematodermic neoplasm tumor | Agranular CD4+ CD56+ hematodermic neoplasm tumor | (empty) | I | punctuation_and_invisible_spacing | Yes |
| 5 | 5635 | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del(5q) | 99860/3 | K | roman_numerals_and_karyotypes | Yes |
| 6 | 4881 | Anaplastic large cell lymphoma (ALK+/ALK-) | Anaplastic large cell lymphoma (ALK+ ALK ) | Anaplastic large cell lymphoma (ALK+ ALK−) | (empty) | M | punctuation_and_invisible_spacing | Yes |
| 7 | 5452 | Acute myeloid leukemia, AML1(CBF-alpha)/ETO | Acute myeloid leukemia AML1(CBF alpha) ETO | Acute myeloid leukemia AML1 (CBF alpha) ETO | 98960/3 | O | No direct test (gap) | Yes |
| 8 | 253 | DEK::AFF2 squamous carcinoma | DEK::AFF2 squamous carcinoma | DEK AFF2 squamous carcinoma | 80722/3 | P | punctuation_and_invisible_spacing | Yes |
| 9 | 315 | CIN III with severe dysplasia | CIN III with severe dysplasia | CIN 3 with severe dysplasia | (empty) | R | roman_numerals_and_karyotypes | Yes |
| 10 | 1211 | Pituitary adenoma / pituitary neuroendocrine tumour (PitNET) | Pituitary adenoma pituitary neuroendocrine tumor (PitNET) | Pituitary adenoma pituitary neuroendocrine tumour (PitNET) | 82720/3 | S | case_and_spelling_behavior | Yes |
| 11 | 3204 | Carcinoma ex benign mixed tumor. | Carcinoma ex benign mixed tumor. | Carcinoma ex benign mixed tumor | 89410/3 | T | No direct test (gap) | Yes |
| 12 | 1107 | Adenocarcinoma combined with other types of carcinoma | Adenocarcinoma combined with others of carcinoma | Adenocarcinoma combined with other types of carcinoma | (empty) | W | whole_word_rules | Yes |
| 13 | 1085 | Bronchiolo-alveolar carcinoma, NOS | Bronchiolo alveolar carcinoma | Bronchioloalveolar carcinoma | 82500/3 | B | No direct test (gap) | Yes |
| 14 | 1105 | Bronchiolo-alveolar carcinoma, type II pneumocyte and goblet cell type | Bronchiolo alveolar carcinoma II pneumocyte and goblet cell | Bronchioloalveolar carcinoma 2 pneumocyte and goblet cell | 82540/3 | B + R | No direct test (gap); roman_numerals_and_karyotypes | Yes |
| 15 | 4956 | Agranular CD4+ NK leukemia | Agranular CD4+ NK leukemia | Agranular CD4+ NK leukemia | (empty) | I | punctuation_and_invisible_spacing | Yes |
| 16 | 5633 | Myelodysplastic syndrome with 5q deletion (5q-) syndrome | Myelodysplastic syndrome with 5q deletion (5q ) syndrome | Myelodysplastic syndrome with 5q deletion (5q−) syndrome | 99860/3 | M | punctuation_and_invisible_spacing | Yes |
| 17 | 5457 | FAB M2, AML1(CBF-alpha)/ETO | FAB M2 AML1(CBF alpha) ETO | FAB M2 AML1 (CBF alpha) ETO | 98960/3 | O | No direct test (gap) | Yes |
| 18 | 254 | DEK::AFF2 squamous cell carcinoma | DEK::AFF2 squamous cell carcinoma | DEK AFF2 squamous cell carcinoma | 80722/3 | P | punctuation_and_invisible_spacing | Yes |
| 19 | 3270 | Pleuropulmonary blastoma, type I | Pleuropulmonary blastoma I | Pleuropulmonary blastoma 1 | 89731/3 | R | roman_numerals_and_karyotypes | No |
| 20 | 1311 | Müllerian-type tumour, clear cell type | Müllerian tumor clear cell | Müllerian tumour clear cell | (empty) | S | case_and_spelling_behavior | Yes |
| 21 | 2032 | Infiltrating duct mixed with other types of carcinoma | Infiltrating duct mixed with others of carcinoma | Infiltrating duct mixed with other types of carcinoma | 85230/3 | W | whole_word_rules | Yes |
| 22 | 1091 | Bronchiolo-alveolar carcinoma, Clara cell | Bronchiolo alveolar carcinoma Clara cell | Bronchioloalveolar carcinoma Clara cell | 82520/3 | B | No direct test (gap) | Yes |
| 23 | 2455 | Clear Cell tumor with Melanocytic Differentiation and ACTIN::MITF Translocation | Clear Cell tumor with Melanocytic Differentiation and ACTIN::MITF Translocation | Clear Cell tumor with Melanocytic Differentiation and ACTIN MITF Translocation | 87272/0 | P | punctuation_and_invisible_spacing | Yes |
| 24 | 3271 | Pleuropulmonary blastoma, type II | Pleuropulmonary blastoma II | Pleuropulmonary blastoma 2 | 89733/3 | R | roman_numerals_and_karyotypes | No |
| 25 | 2284 | Cauda equina neuroendocrine tumour | Cauda equina neuroendocrine tumor | Cauda equina neuroendocrine tumour | 86934/3 | S | case_and_spelling_behavior | Yes |

**Table annotation:** Rule occurrences among these 25 selected examples: B=5, C=1, I=2, K=1, M=2, O=2, P=3, R=5, S=3, T=1, W=2. Mixed-rule rows count under each rule; these counts describe the sample only.

## ICD-O morphology terms

Before is `icdo4_morphology.term_clean`; after is direct `clean2(term)`. Codes are the existing ICD-O-4 `icdo4` strings, displayed without conversion.

Location: `icdo4_morphology`, primary key `row_id`. Test names below omit the `test_` prefix for readability.

| # | Record ID | Raw input | Before: stored key | After: direct Clean2 | Existing code | Rule IDs | Relevant test / gap | Baseline? |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 865 | Bronchiolo-alveolar adenocarcinoma, NOS | Bronchiolo alveolar adenocarcinoma | Bronchioloalveolar adenocarcinoma | 82500/3 | B | No direct test (gap) | Yes |
| 2 | 876 | Bronchiolo-alveolar carcinoma, type II pneumocyte, NOS | Bronchiolo alveolar carcinoma II pneumocyte | Bronchioloalveolar carcinoma 2 pneumocyte | 82520/3 | B + R | No direct test (gap); roman_numerals_and_karyotypes | Yes |
| 3 | 4708 | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del(5q) | 99860/3 | K | roman_numerals_and_karyotypes | Yes |
| 4 | 4709 | Myelodysplastic syndrome with 5q deletion (5q-) syndrome | Myelodysplastic syndrome with 5q deletion (5q ) syndrome | Myelodysplastic syndrome with 5q deletion (5q−) syndrome | 99860/3 | M | punctuation_and_invisible_spacing | Yes |
| 5 | 215 | DEK::AFF2 squamous cell carcinoma | DEK::AFF2 squamous cell carcinoma | DEK AFF2 squamous cell carcinoma | 80722/3 | P | punctuation_and_invisible_spacing | Yes |
| 6 | 2684 | Pleuropulmonary blastoma, type Ir (type I regressed) | Pleuropulmonary blastoma Ir (type I regressed) | Pleuropulmonary blastoma Ir (1 regressed) | 89732/3 | R | roman_numerals_and_karyotypes | Yes |
| 7 | 2 | Tumour, benign | Tumor benign | Tumour benign | 80000/0 | S | case_and_spelling_behavior | Yes |
| 8 | 1896 | Composite paraganglion tumour, extra-adrenal | Composite paraganglion tumor extra adrenal | Composite paraganglion tumour extraadrenal | 86935/3 | S + B | case_and_spelling_behavior; No direct test (gap) | Yes |
| 9 | 2015 | Clear Cell tumour with Melanocytic Differentiation and ACTIN::MITF Translocation | Clear Cell tumor with Melanocytic Differentiation and ACTIN::MITF Translocation | Clear Cell tumour with Melanocytic Differentiation and ACTIN MITF Translocation | 87272/0 | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 10 | 2845 | Yolk sac tumour, prepubertal (type I) | Yolk sac tumor prepubertal (type I) | Yolk sac tumour prepubertal (1) | 90712/3 | S + R | case_and_spelling_behavior; roman_numerals_and_karyotypes | Yes |
| 11 | 2624 | Carcinoma ex benign mixed tumour. | Carcinoma ex benign mixed tumor. | Carcinoma ex benign mixed tumour | 89410/3 | S + T | case_and_spelling_behavior; No direct test (gap) | Yes |
| 12 | 1665 | Infiltrating duct mixed with other types of carcinoma | Infiltrating duct mixed with others of carcinoma | Infiltrating duct mixed with other types of carcinoma | 85230/3 | W | whole_word_rules | Yes |
| 13 | 866 | Bronchiolo-alveolar carcinoma, NOS | Bronchiolo alveolar carcinoma | Bronchioloalveolar carcinoma | 82500/3 | B | No direct test (gap) | Yes |
| 14 | 886 | Bronchiolo-alveolar carcinoma, type II pneumocyte and goblet cell type | Bronchiolo alveolar carcinoma II pneumocyte and goblet cell | Bronchioloalveolar carcinoma 2 pneumocyte and goblet cell | 82540/3 | B + R | No direct test (gap); roman_numerals_and_karyotypes | Yes |
| 15 | 216 | DEK::AFF2 squamous carcinoma | DEK::AFF2 squamous carcinoma | DEK AFF2 squamous carcinoma | 80722/3 | P | punctuation_and_invisible_spacing | Yes |
| 16 | 3 | Unclassified tumour, benign | Unclassified tumor benign | Unclassified tumour benign | 80000/0 | S | case_and_spelling_behavior | Yes |
| 17 | 4327 | Pre-B-lymphoblastic leukaemia | Pre B lymphoblastic leukemia | PreB lymphoblastic leukaemia | 98110/3 | S + B | case_and_spelling_behavior; No direct test (gap) | Yes |
| 18 | 2017 | Clear Cell tumour with Melanocytic Differentiation and MITF::CREM Translocation | Clear Cell tumor with Melanocytic Differentiation and MITF::CREM Translocation | Clear Cell tumour with Melanocytic Differentiation and MITF CREM Translocation | 87273/0 | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |
| 19 | 2847 | Yolk sac tumour, postpubertal (type II) | Yolk sac tumor postpubertal (type II) | Yolk sac tumour postpubertal (2) | 90713/3 | S + R | case_and_spelling_behavior; roman_numerals_and_karyotypes | Yes |
| 20 | 1672 | Infiltrating lobular mixed with other types of carcinoma | Infiltrating lobular mixed with others of carcinoma | Infiltrating lobular mixed with other types of carcinoma | 85240/3 | W | whole_word_rules | Yes |
| 21 | 874 | Bronchiolo-alveolar carcinoma, non-mucinous | Bronchiolo alveolar carcinoma nonmucinous | Bronchioloalveolar carcinoma nonmucinous | 82520/3 | B | No direct test (gap) | Yes |
| 22 | 2413 | Pulmonary myxoid sarcoma with EWSR1::CREB1 fusion | Pulmonary myxoid sarcoma with EWSR1::CREB1 fusion | Pulmonary myxoid sarcoma with EWSR1 CREB1 fusion | 88421/3 | P | punctuation_and_invisible_spacing | Yes |
| 23 | 6 | Tumour, NOS | Tumor | Tumour | 80000/1 | S | case_and_spelling_behavior | Yes |
| 24 | 4331 | Pro-/pre-B-lymphoblastic leukaemia | Pro pre B lymphoblastic leukemia | Pro preB lymphoblastic leukaemia | 98110/3 | S + B | case_and_spelling_behavior; No direct test (gap) | Yes |
| 25 | 2212 | EWSR1::SMAD3-rearranged fibroblastic tumour | EWSR1::SMAD3 rearranged fibroblastic tumor | EWSR1 SMAD3 rearranged fibroblastic tumour | 88107/0 | S + P | case_and_spelling_behavior; punctuation_and_invisible_spacing | Yes |

**Table annotation:** Rule occurrences among these 25 selected examples: B=8, K=1, M=1, P=6, R=5, S=12, T=1, W=2. Mixed-rule rows count under each rule; these counts describe the sample only.

## Site-specific terms

Before is `icdo_site_specific_terms.term_clean`; after is direct `clean2(icdo_term)`. Codes are existing site-specific morphology codes, not an inferred topography code or a new assignment.

Location: `icdo_site_specific_terms`, primary key `term_id`. Test names below omit the `test_` prefix for readability.

| # | Record ID | Raw input | Before: stored key | After: direct Clean2 | Existing code | Rule IDs | Relevant test / gap | Baseline? |
| ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | 221 | Appendiceal mucinous neoplasm with extra-appendiceal spread | Appendiceal mucinous neoplasm with extra appendiceal spread | Appendiceal mucinous neoplasm with extraappendiceal spread | 8480/3 | B | No direct test (gap) | Yes |
| 2 | 1180 | Bronchiolo-alveolar carcinoma, type II pneumocyte and goblet cell type | Bronchiolo alveolar carcinoma II pneumocyte and goblet cell | Bronchioloalveolar carcinoma 2 pneumocyte and goblet cell | 8254/3 | B + R | No direct test (gap); roman_numerals_and_karyotypes | Yes |
| 3 | 3610 | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del (5q) | Myelodysplastic syndrome with isolated del(5q) | 9986/3 | K | roman_numerals_and_karyotypes | Yes |
| 4 | 3608 | Myelodysplastic syndrome with 5q deletion (5q-) syndrome | Myelodysplastic syndrome with 5q deletion (5q ) syndrome | Myelodysplastic syndrome with 5q deletion (5q−) syndrome | 9986/3 | M | punctuation_and_invisible_spacing | Yes |
| 5 | 3450 | Acute myeloid leukemia, AML1(CBF-alpha)/ETO | Acute myeloid leukemia AML1(CBF alpha) ETO | Acute myeloid leukemia AML1 (CBF alpha) ETO | 9896/3 | O | No direct test (gap) | Yes |
| 6 | 474 | BCOR::CCNB3 sarcoma | BCOR::CCNB3 sarcoma | BCOR CCNB3 sarcoma | 9368/3 | P | punctuation_and_invisible_spacing | Yes |
| 7 | 46 | CIN III with severe dysplasia | CIN III with severe dysplasia | CIN 3 with severe dysplasia | 8077/2 | R | roman_numerals_and_karyotypes | Yes |
| 8 | 3065 | BCL2-R-negative CD23-positive follicle centre lymphoma | BCL2 R negative CD23 positive follicle center lymphoma | BCL2 R negative CD23 positive follicle centre lymphoma | 9690/3 | S | case_and_spelling_behavior | Yes |
| 9 | 2075 | Carcinoma ex benign mixed tumor. | Carcinoma ex benign mixed tumor. | Carcinoma ex benign mixed tumor | 8941/3 | T | No direct test (gap) | Yes |
| 10 | 1637 | Infiltrating duct mixed with other types of carcinoma | Infiltrating duct mixed with others of carcinoma | Infiltrating duct mixed with other types of carcinoma | 8523/3 | W | whole_word_rules | Yes |
| 11 | 1164 | Bronchiolo-alveolar adenocarcinoma, NOS | Bronchiolo alveolar adenocarcinoma | Bronchioloalveolar adenocarcinoma | 8250/3 | B | No direct test (gap) | Yes |
| 12 | 3454 | FAB M2, AML1(CBF-alpha)/ETO | FAB M2 AML1(CBF alpha) ETO | FAB M2 AML1 (CBF alpha) ETO | 9896/3 | O | No direct test (gap) | Yes |
| 13 | 1971 | Pulmonary myxoid sarcoma with EWSR1::CREB1 fusion | Pulmonary myxoid sarcoma with EWSR1::CREB1 fusion | Pulmonary myxoid sarcoma with EWSR1 CREB1 fusion | 8842/3 | P | punctuation_and_invisible_spacing | Yes |
| 14 | 2120 | Pleuropulmonary blastoma, type Ir (type I regressed) | Pleuropulmonary blastoma Ir (type I regressed) | Pleuropulmonary blastoma Ir (1 regressed) | 8973/3 | R | roman_numerals_and_karyotypes | Yes |
| 15 | 3297 | Smouldering adult T-cell leukemia/lymphoma | Smoldering adult T cell leukemia lymphoma | Smouldering adult T cell leukemia lymphoma | 9827/3 | S | case_and_spelling_behavior | Yes |
| 16 | 1642 | Infiltrating lobular mixed with other types of carcinoma | Infiltrating lobular mixed with others of carcinoma | Infiltrating lobular mixed with other types of carcinoma | 8524/3 | W | whole_word_rules | Yes |
| 17 | 1165 | Bronchiolo-alveolar carcinoma, NOS | Bronchiolo alveolar carcinoma | Bronchioloalveolar carcinoma | 8250/3 | B | No direct test (gap) | Yes |
| 18 | 1972 | Pulmonary myxoid sarcoma with EWSR1::CREB1 translocation | Pulmonary myxoid sarcoma with EWSR1::CREB1 translocation | Pulmonary myxoid sarcoma with EWSR1 CREB1 translocation | 8842/3 | P | punctuation_and_invisible_spacing | Yes |
| 19 | 2220 | Postpubertal (type II) yolk sac tumor | Postpubertal (type II) yolk sac tumor | Postpubertal (2) yolk sac tumor | 9071/3 | R | roman_numerals_and_karyotypes | Yes |
| 20 | 1685 | Carcinoma with other types mesenchymal differentiation | Carcinoma with others mesenchymal differentiation | Carcinoma with other types mesenchymal differentiation | 8575/3 | W | whole_word_rules | Yes |
| 21 | 1172 | Bronchiolo-alveolar carcinoma, goblet cell type | Bronchiolo alveolar carcinoma goblet cell | Bronchioloalveolar carcinoma goblet cell | 8253/3 | B | No direct test (gap) | Yes |
| 22 | 2162 | CRTC1::TRIM11 cutaneous tumor | CRTC1::TRIM11 cutaneous tumor | CRTC1 TRIM11 cutaneous tumor | 9044/3 | P | punctuation_and_invisible_spacing | Yes |
| 23 | 2221 | Prepubertal (type I) yolk sac tumor | Prepubertal (type I) yolk sac tumor | Prepubertal (1) yolk sac tumor | 9071/3 | R | roman_numerals_and_karyotypes | Yes |
| 24 | 1687 | Metaplastic carcinoma with other types mesenchymal differentiation | Metaplastic carcinoma with others mesenchymal differentiation | Metaplastic carcinoma with other types mesenchymal differentiation | 8575/3 | W | whole_word_rules | Yes |
| 25 | 1173 | Bronchiolo-alveolar carcinoma, mucinous | Bronchiolo alveolar carcinoma mucinous | Bronchioloalveolar carcinoma mucinous | 8253/3 | B | No direct test (gap) | Yes |

**Table annotation:** Rule occurrences among these 25 selected examples: B=6, K=1, M=1, O=2, P=4, R=5, S=2, T=1, W=4. Mixed-rule rows count under each rule; these counts describe the sample only.

## Relationship to ICD-O code assignment

**No ICD-O code assignments were changed.** The before/after tables concern comparison keys, not code values. A key change can nevertheless change candidate matches when the matching pipeline is rerun.

### Newly merged CPC key with conflicting existing codes

| Raw CPC term | Before key | After key | Existing CPC ICD-O-4 code | Rule / test |
| --- | --- | --- | --- | --- |
| Tubulopapillary adenoma | Tubulopapillary adenoma | Tubulopapillary adenoma | 82600/0 | B; no direct prefix-joining test |
| Tubulo-papillary adenoma | Tubulo papillary adenoma | Tubulopapillary adenoma | 82631/0 | B; no direct prefix-joining test |

The two previously distinct keys merge, but their stored codes differ. This is an actual **potential code-assignment ambiguity** introduced by normalization, not evidence that either code should be reassigned. Do not resolve it by taking the first lookup result.

The same within-table scan (excluding null/empty codes) found **no newly merged conflicting-code groups in ICD-O morphology or site-specific terms**. It is not a cross-table or full matching-pipeline audit.

### Existing site-specific ambiguity, not created by Clean2

| Raw term | Before key | After key | Existing code | Existing preferred term | Rule / test |
| --- | --- | --- | --- | --- | --- |
| Acute myeloid leukemia with DEK::NUP214 fusion | Acute myeloid leukemia with DEK::NUP214 fusion | Acute myeloid leukemia with DEK NUP214 fusion | 9861/3 | Acute myeloid leukemia, NOS | P; test_punctuation_and_invisible_spacing |
| Acute myeloid leukemia with DEK::NUP214 fusion | Acute myeloid leukemia with DEK::NUP214 fusion | Acute myeloid leukemia with DEK NUP214 fusion | 9865/3 | Acute myeloid leukemia with t(6;9)(p23;q34); DEK-NUP214 | P; test_punctuation_and_invisible_spacing |

Both codes already share the same before key. Clean2 changes the spelling of that key (`::` to a space) but does **not** create this ambiguity.

### Existing coded mentions whose keys would change

| Mention ID | Raw term | Before term_clean | After direct Clean2 | Existing ICD-O code | Interpretation |
| ---: | --- | --- | --- | --- | --- |
| 10 | Solitary fibrous tumour | Solitary fibrous tumor | Solitary fibrous tumour | 8815/1 | S; direct Clean2 no longer Americanizes this spelling |
| 25 | Phaeochromocytoma | Pheochromocytoma | Phaeochromocytoma | 8700/3 | S; direct Clean2 no longer Americanizes this spelling |

Across `page_term_mentions`, **13,810 rows** have at least one changed normalized field; **13,810 of those already have a non-empty ICD-O code**. This does not mean that many code assignments would change. No re-matching or reassignment was performed.

**Before adoption:** validate the missing spelling stage and live SQL/Python parity, normalize both sides consistently, compare old/new candidate code sets, review the CPC collision above and existing ambiguities, and preserve explicit source codes and provenance rather than silently overwriting them from an ambiguous normalized-key lookup.
