---
name: project-affinity-data-pool-cross-file-drift
description: affinity-data-pool.md + game-concept.md + systems-index.md repeatedly drift from each other during same-session cross-file propagation edits — check round-number attribution specifically, not just substance
metadata:
  type: project
---

The `design/gdd/affinity-data-pool.md` cluster (itself, `design/gdd/game-concept.md`
"常設風險"/獨特賣點 sections, and `design/gdd/systems-index.md`'s Cross-System
Obligations Registry) has a recurring, documented pattern of same-session edits
introducing fresh cross-file drift even in rounds explicitly intended to fix prior
drift. Confirmed instances:

- 2026-08-09: a same-day remediation-validation round found new blockers introduced
  by the prior day's fix (see `production/session-state/active.md` history).
- 2026-08-10 round 12 (targeted systems-designer+qa-lead recheck of round 11):
  round 11 added a "沉默處置的驗證義務" to `affinity-data-pool.md` Dependencies
  Obligation A and claimed (in its own GDD header changelog) to have connected this
  to a new second retest pass-condition in `game-concept.md`'s "常設風險" section.
  The pass-condition text itself was added correctly and its *substance* agrees
  across all three files (`affinity-data-pool.md` Dependencies, `game-concept.md`
  line ~86, `systems-index.md` row ~180). But `game-concept.md`'s own inline edit
  note mislabels the addition as "2026-08-10 第九輪新增" when it was actually a
  round-11 edit — contradicted by both `affinity-data-pool.md`'s own round-11
  changelog (which claims the connected edit) and by `systems-index.md` row 180
  (which correctly cites "常設風險通過條件擴充(第十一輪)"). Round 9's own
  changelog in `affinity-data-pool.md` makes no mention of touching `game-concept.md`
  at all, confirming round 9 did not do this edit.

**Why**: Rapid multi-file propagation edits within a single session are where this
project's drift keeps recurring — the substantive content usually ends up correct,
but the round/date attribution metadata embedded inline (used for traceability by
future reviewers) gets typo'd or copy-pasted from an adjacent, differently-dated
sentence.

**How to apply**: When reviewing any round of cross-file propagation in this
cluster (or likely other GDD clusters with the same heavily-annotated inline
changelog style), do not just check that the substantive requirement text agrees
across files — independently verify the ROUND NUMBER each file attributes to the
same edit. Cross-check against the originating file's own changelog (which round's
summary explicitly claims the cross-file edit) as the source of truth, since that
is usually accurate; the *receiving* file's inline round-label is the one most
likely to be wrong.
