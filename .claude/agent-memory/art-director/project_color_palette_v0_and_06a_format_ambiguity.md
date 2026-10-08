---
name: color-palette-v0-and-06a-format-ambiguity
description: color-palette.csv v0.1 exists (38/64 colors); 06a §4.2's own CSV format example is internally ambiguous about '#'-prefixed data rows vs comments
metadata:
  type: project
---

`design/art/color-palette.csv` v0.1 was created 2026-10-08 (manager ruling, direct mandate —
not a full question-first cycle since the manager had already accepted the "deciding before
real art exists" tradeoff). 38 of 64 shared colors used: skin 7 / cloth 10 / metal 4 /
nature 10 / ui 6 / reserved 1 (chroma key). Outline colors: 4, one per material
(skin/cloth/metal/nature), all non-pure-black per art-direction.md §4. UI's 6 colors were
extracted from existing shipped `Color()` constants in `board_view.gd` / `battle_menu.gd` /
`card_confirm_panel.gd` (not invented) — but this is only a partial inventory; HP-bar fill
colors and a few others are known-not-yet-included. `nature` maps to board.gd's actual 3
terrain types (open/brush/fallen_log) — an earlier draft invented "stone/water" terrain
that doesn't exist in code; caught by checking `board.gd` before finalizing instead of
inventing plausible-sounding terrain names.

**Why:** This is the file `06a-change-request-art-requirements-2026-10-08.md` §7 registered
as the biggest blocking gap for the AI art post-processing handoff (chroma-key safety check,
"零離盤色像素" validation) — both were stuck at "無法驗證" without this file.

**Separately, found a real defect in my own `06a` §4.2 CSV format spec** (already handed to
the external AI_IMG team, I cannot edit it — not my file to touch per this task's scope):
it states "`#`-prefixed lines are comments," but its own example data rows are
`#FF00FF,reserved,...` — also `#`-prefixed. If their parser does a naive "skip any line
starting with #," it will skip every data row including the spec's own example. I resolved
this for my own CSV by assuming the sane reading ("# + 6 valid hex chars = data row,
otherwise comment") and keeping every descriptive comment line free of that exact shape, but
did **not** fix the ambiguity in 06a itself — flagged it in the CSV's header comments and in
the handback report instead.

**How to apply:** Before trusting `06a`'s CSV format description again, or before the AI_IMG
team's parser behavior is confirmed, treat this as an open, unverified risk — don't assume
it parses just because the format "looks" specified. If a follow-up change request to AI_IMG
is drafted, this ambiguity should be resolved explicitly (either change the comment-detection
rule, or change the data-row convention so colors don't start with literal `#`). Revision
triggers for the palette itself (first real art batch, character-count expansion, terrain
evolution system, chroma-key re-check) are written in the CSV's own header — don't duplicate
them here, they'll drift; read the file.

See also [[project_art_production_path_undecided]] for the adjacent, still-open question of
who actually produces art (this memory is about the color-data deliverable, not that decision).
