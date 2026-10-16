---
name: gdd-8-section-format-tension
description: design/gdd/ mandates an 8-section GDD format; lightweight content skeletons dispatched into that directory may conflict with it — flag, don't silently resolve
metadata:
  type: feedback
---

`design/CLAUDE.md` and `.claude/rules/design-docs.md` both mandate that **every** document
in `design/gdd/` contain the 8 required sections (Overview, Player Fantasy, Detailed Rules,
Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria). This is a directory-wide
rule, not a per-document opt-in.

**Observed precedent (2026-10-16)**: `design/gdd/vertical-slice-level-01.md` — a *level content*
document, not a system mechanic — still follows the 8-section format in full. By contrast,
`design/quick-specs/support-conversation-system.md` deliberately deviates from the 8-section
format ("輕量規格"), but it lives in `design/quick-specs/`, which has no such mandate — so it
never actually conflicts with the rule.

**The conflict case**: when a dispatch brief asks for a *content skeleton* (e.g. a multi-level
roadmap with custom parts like "一句話節拍 / 轉場點 / 開放問題") to be written into
`design/gdd/` with an explicit non-8-section structure and a line cap, that collides with the
directory-wide rule. I hit this writing `design/gdd/mvp-five-levels-skeleton.md`.

**Why**: Neither the dispatch brief nor any prior ruling explicitly grants an exception for this
file's location. Silently following the dispatch brief's custom structure would violate the
documented directory standard; silently forcing the 8-section format would violate the explicit,
detailed instructions just given (and most of those 8 sections don't even apply to a multi-level
roadmap — there's no single Formulas/Tuning Knobs for 5 levels at once).

**How to apply**: Don't resolve this tension unilaterally in either direction. Write the content
the dispatch brief actually asked for, but add an explicit "格式偏離聲明" (format-deviation
disclosure) in the document itself, and list it as an open item in the report back to the
coordinator/manager for a real ruling — the same way the project handles every other
directory-vs-instruction conflict (it gets registered, not silently picked). Check
`design/quick-specs/` as the likely correct home if the manager decides the skeleton should not
live in `design/gdd/` at all.

---

## ✅ 2026-10-16 的實際處置(協調者,已結案):搬檔,不是補發豁免

**你拒絕自行豁免是對的** —— 那條規則確實套用於 `design/gdd/**`,衝突是真的。

**但處置不是「請管理者補發一次豁免」,而是【把檔案搬到 `design/quick-specs/`】。**

**理由**:`design/quick-specs/` 是管理者 2026-09-07 已經建立好的既有路線
(`support-conversation-system.md`、`battle-hud-prediction-marker.md`、
`unit-stats-provisional.md` 都在那裡),它不受 8 節規則約束。
**走既有路線不需要任何新裁決;補發豁免則要開一個新的例外。**

🔴 **可執行結論 —— 下次先判斷落點,不要先寫完才發現**:

> **派工單指定了 `design/gdd/` 底下的落點,但要寫的東西不是「單一系統的機制規格」時
> (例如跨多關的內容骨架、數值表、對照清單),先回報落點疑義,不要直接寫。**
> 問一句的成本遠低於寫完 113 行再搬。

📌 **判斷準則(2026-09-07 管理者裁決的實質區分)**:
- `design/gdd/` = **單一系統的完整機制規格**,8 節格式適用
- `design/quick-specs/` = 輕量規格、暫行數值、內容骨架 —— **8 節多半不適用**

⚠️ **協調者那次也有責任**:派工單直接指定了 `design/gdd/mvp-five-levels-skeleton.md`,
而沒有先檢查那個目錄的規則適不適用。**這不是單方面的疏忽。**
