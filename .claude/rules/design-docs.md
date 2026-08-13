---
paths:
  - "design/gdd/**"
---

# Design Document Rules

- Every design document MUST contain these 8 sections: Overview, Player Fantasy, Detailed Rules, Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria
- Formulas must include variable definitions, expected value ranges, and example calculations
- Edge cases must explicitly state what happens, not just "handle gracefully"
- Dependencies must be bidirectional — if system A depends on B, B's doc must mention A
- Tuning knobs must specify safe ranges and what gameplay aspect they affect
- Acceptance criteria must be testable — a QA tester must be able to verify pass/fail
- No hand-waving: "the system should feel good" is not a valid specification
- Balance values must link to their source formula or rationale
- Design documents MUST be written incrementally: create skeleton first, then fill
  each section one at a time with user approval between sections. Write each
  approved section to the file immediately to persist decisions and manage context
- **Single source of truth per term**: a shared term, entity, or rule (e.g. `Pair`,
  a status name like "拒絕讀取", a formula, an index-key convention) is defined in
  exactly one GDD — its owning document. Every other document that needs it
  references the definition by pointer (e.g. "見 `affinity-data-pool.md` Core
  Rules #3") and never restates, paraphrases, or copies the definition itself.
  This applies to `design/registry/entities.yaml` too: it is a pointer index, not
  a second copy of the definitions — entries should link to the owning GDD's
  section rather than duplicate its content. Rationale: this project's recurring,
  most expensive failure mode across every multi-round `/design-review` has been
  the same fact restated in multiple places and one copy silently falling out of
  sync (stale cross-references, enum drift, a renamed status not propagated
  everywhere) — never two people disagreeing about what a term means. A glossary
  or dictionary file that stores definitions itself would just add one more place
  that fact needs to stay in sync; a pointer-only index does not have this problem
  because there is nothing in it to go stale except the pointer's target path.
- **No line-number self-references**: never point to another passage in a design
  doc, `systems-index.md`, or a `*-review-log.md` by line number (e.g. "見下方第
  151 列", "see line 295"). Documents in this family grow and get edited by many
  rounds of `/design-review`; line numbers drift within the same session and are
  routinely stale by the next round (confirmed recurring: `systems-index.md`'s
  own header referenced "第 151/171 列" and "第 151/153 列" for rows that had
  already moved to different line numbers by the time those references were
  checked). Point to the target instead by a stable handle: the row's obligation
  keyword/subject (e.g. "見 Cross-System Obligations Registry『序列化生命週期
  通知介面』列"), a Core Rules/AC number, or a section heading — none of these
  shift when unrelated content is inserted above them.
