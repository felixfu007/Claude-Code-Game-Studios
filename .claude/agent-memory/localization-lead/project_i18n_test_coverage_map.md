---
name: project-i18n-test-coverage-map
description: Which i18n test file covers which acceptance-criterion slice, so future localization-lead work doesn't re-derive this or duplicate assertions already in place.
metadata:
  type: project
---

As of story-003 completion (2026-10-13), the `localization-infrastructure` epic's test
coverage is split across three files under `tests/unit/core/i18n/`, each owning a distinct
slice — **do not duplicate an assertion that already lives in one of these**:

- `loc_localize_test.gd` (story-001) — the `Loc` API itself: dot-notation key lookup exact
  match, missing-key-never-returns-bare-key, missing-key debug/release fallback branches,
  `is_missing()` true/false logic. This is the file that answers "does the lookup API work
  and fall back safely."
- `i18n_migrated_strings_test.gd` (story-002) — every migrated key (45 total) resolves to its
  exact pre-migration literal. This answers "did the migration preserve content," not "does
  the API work" — kept deliberately separate from the file above even though both call
  `Loc.localize()`.
- `locale_data_integrity_test.gd` (story-003, A4) — CSV *source* format validation: no
  duplicate keys, no empty values, correct row/column shape, and a hand-rolled quote-aware
  CSV parser (needed because `TranslationServer` silently absorbs both defects — last
  duplicate wins, empty value just resolves empty — so neither is visible by calling
  `Loc.localize()`; the only way to catch them is reading the raw CSV text).
- `i18n_source_discipline_test.gd` (story-003, B) — static regression guard: zero bare
  Chinese-text `const` declarations remain under `src/**/*.gd` (scope is `const` only, not
  all string literals — matches story-002's original migration scope). Currently 0 violations
  (migration is complete as of this writing).

**Non-obvious fact worth keeping**: `TranslationServer`'s CSV import behavior for malformed
source data (duplicate keys, empty values) is *silent* — no error, no warning surfaced to
`Loc.localize()` callers. Any future i18n data-integrity check must read the raw CSV text
directly; it cannot be inferred by calling the lookup API, no matter how many keys you probe.

See [[feedback_sensitivity_proof_via_pure_function_decomposition]] for how the A4/B tests
satisfy the project's sensitivity-proof requirement despite reading real files.
