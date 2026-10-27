# 開場自動載入文件:過期「現況」宣稱提案(2026-10-27,producer)

> 本檔只是提案,**本輪未修改任何既有檔**。每一條加註都要管理者核准後才寫入(文件類,依 `CLAUDE.md` 必須先問)。

## 給管理者的白話摘要

這 7 份文件每次對話一開始都會自動讀進每個 agent 的腦袋。裡面如果有一句「某事目前還沒做好」,
而那件事其實早就做好了,每個 agent 每天都會照著錯的現況做判斷。

- **查了 28 條**描述「現在怎樣」的句子,每條都實際跑指令核對。
- **21 條仍然正確**,不用動。
- **6 條已過期**:1 條今天稍早已經加註更正,**剩 5 條待你核准加註**(下表 #1~#5)。
- **1 條查不到證據可以判斷**(下表 #6),只登記、不建議動。

**最嚴重的兩條(#1、#2)是同一件事**:`technical-preferences.md` 兩處寫「戰棋系統還不能開工,
因為我方數值表沒人負責」。實際上那個問題 9 月 9 日就解決了,戰棋工作包 9 月 29 日就已經可開工,
程式碼也早就在寫。**照著讀的 agent 會以為戰棋被卡住,可能拒絕接戰棋的工作,或去追一個早已解決的問題。**

第三嚴重是 #4:文件說「目前測試都不會改動游標系統的共用狀態」,但現在**有 5 支測試會改**。
讀到的人會以為不必擔心測試之間互相干擾。

建議做法與本專案慣例相同:**原句一字不刪,在後面加一行「2026-10-27 實測已不成立」並附查證指令。**

## 已失效 / 無法查證 清單

均在 `.claude/docs/technical-preferences.md`(#1~#5)與 `.claude/docs/coding-standards.md`(#6)。
「舊片段」皆已用 `grep -c` 確認在該檔恰好命中 `1`。

| # | 檔案 | 舊片段(逐字,唯一) | 判定 | 查證原始輸出 | 建議加註(逐字) |
|---|---|---|---|---|---|
| 1 | technical-preferences.md | `另受其自身 **OQ-2(我方基準數值表無人擁有)**` | **已失效** | `design/gdd/tactical-combat-system.md:1124: …~~**OQ-2**~~ ✅ **已解除(2026-09-09 更正)** …**目前本節無待清償的阻擋項**`;`production/epics/tactical-combat/EPIC.md:13:> **Status**: ✅ **Ready — 2026-09-29 管理者裁決…`;`ls src/gameplay/combat` → `combat_rules.gd` | 緊接在「阻擋,ADR-0001 不是它唯一的鎖。」之後另起一行:`> ✅ **2026-10-27 實測:上一句已不成立** —— OQ-2 已於 2026-09-09 關閉(擁有者為 `design/quick-specs/unit-stats-provisional.md` 第 1 節),戰棋 epic 自 2026-09-29 起為 `Ready`。當場查:`grep -n "目前本節無待清償的阻擋項" design/gdd/tactical-combat-system.md`、`grep -n "Status" production/epics/tactical-combat/EPIC.md`。原句保留。` |
| 2 | technical-preferences.md | `但戰棋系統仍不能開工` | **已失效**(同 #1,ADR 狀態表 ADR-0001 那一列) | 同 #1 | 該句位於表格儲存格內,不能另起一行。建議在同一格該句後面接:`(✅ 2026-10-27 實測已不成立:OQ-2 於 2026-09-09 關閉、戰棋 epic 於 2026-09-29 轉 Ready —— 見本節下方「核准不等於全部能開工」段的加註)` |
| 3 | technical-preferences.md | `三個 Foundation 系統合計 73 項**只有 1 項缺口**` | **已失效**(數字) | `docs/architecture/traceability-index.md:17: \| affinity-data-pool.md \| Foundation \| Approved \| 24 \|…`;`:18: \| save-system.md \| Foundation \| Approved \| 30 \| 22 \| 7 \| 1 \|`;`:19: \| cursor-highlight-state.md \| Foundation \| Approved \| **18**(原 19,見下方 2026-09-03 note)…` → 24+30+18 = **72** | 緊接其後另起一行:`> ✅ **2026-10-27 實測:上一句的 73 已不成立** —— 游標系統 2026-09-03 取消一項需求,現為 24+30+18 = **72 項**;缺口仍為 1 項(`TR-save-030`)。當場查:`grep -n "\| Foundation \|" docs/architecture/traceability-index.md`。原句保留。⚠️ 這行正是同段上兩句「此處不再抄任何數字」要防的形狀。` |
| 4 | technical-preferences.md | `但 Story 005/007 一旦出現會改寫全域狀態的` | **已失效**(預言的條件已成立) | `grep -c` 寫入呼叫於 `tests/unit/cursor/state_host_test.gd` → `0`(該檔仍唯讀);但改寫 `CursorStateHost` 的測試檔現有 5 支:`tests/integration/cursor/frame_buffer_ordering_test.gd`、`tests/integration/ui/battle_cursor_navigation_convergence_test.gd`、`tests/integration/ui/card_target_selection_test.gd`、`tests/integration/ui/shell/scene_router_test.gd`、`tests/integration/ui/shell/title_screen_scene_switch_test.gd`(呼叫次數:`15 register_surface(`、`11 set_target(`…) | 緊接該段之後另起一行:`> ✅ **2026-10-27 實測:上段的條件已經成立** —— 現有 5 支測試會改寫 `CursorStateHost` 全域狀態;`state_host_test.gd` 本身仍為唯讀。當場查:`grep -rl "CursorStateHost\.\(set_target\|register_surface\)(" tests`。⚠️ 這 5 支的 teardown 是否完整、GdUnit4 隔離行為是否確認過,**本次未查證**。原句保留。` |
| 5 | technical-preferences.md | `重寫後該檔全文不再出現「第幾次修訂」字樣` | **已失效**(字面不精確,結論不變;自 2026-10-12 重寫當天即不精確) | `grep -c "次修訂" docs/architecture/adr-0001-…md` → `5`;其中一行逐字:`> **本文件自此不再標註「第幾次修訂」** —— …` —— 這四個字就在 ADR 裡。其餘 4 行皆「兩次修訂」等敘述性用法 | 緊接該段之後另起一行:`> ✅ **2026-10-27 實測:上一句字面不精確** —— ADR 裡「本文件自此不再標註『第幾次修訂』」這句本身就含這四個字;`grep -c "次修訂"` 現為 5,全部是敘述性用法,**結論(沒有任何決定以修訂次序標註)不變**。原句保留。` |
| 6 | coding-standards.md | `478 目前無人能解釋成因` | **無法查證** | 掃了 `docs/reviews/`、`production/session-state/`、`design/art/` 樣式 `478`;`git log --since=2026-09-24 --grep=478` → 空。命中只有 2026-09-23 的三份意見書與 `active.md` 重述「`478 / 108134` 殘值…」。**沒找到後來解開它的紀錄,但「沒找到」不等於「沒人解開」** | **不建議加註**。該句有日期脈絡(屬 2026-09-23 登記),且新量法已改讀 `SubViewport` 原生緩衝區、結構上不再碰到 478。僅登記。 |

**已在今天處理、不重提**:technical-preferences.md「計畫檔 §6② 的對應句**至今仍寫「兩份」**」——
緊接其後已有 `✅ **2026-10-27 實測:上一句已不成立**` 加註(commit `20e0aa4`)。

## 判定為真的 21 條(只列名,不展開)

CLAUDE.md「49 個 subagent」(`ls .claude/agents | wc -l` → 49)/ directory-structure 列出的 29 個子目錄全部存在 /
「addons 目前僅 GdUnit4」/ VERSION.md「8 份模組停在 4.6、只有 2 份到 4.7.1」/ VERSION.md「`input.md`、`ui.md` 對兩大 4.7 變更零命中」(兩者 `grep -c` 皆 0)/
Autoload 只有一個(`project.godot [autoload]` 只有 `CursorStateHost`)/ GdUnit4 v6.2.1(`plugin.cfg`)/ 對話正文字型尚未選定(`assets/fonts/` 只有 `Cubic_11.ttf`)/
五份 ADR 只剩 0004 為 `Proposed` / 第八輪架構審查從未執行(`docs/architecture/` 最後一份為 `…round7.md`)/ `TR-save-030` 仍為缺口 /
coding-standards「WORKFLOW-GUIDE 的 minimum 3 ADR 仍未調和」(`docs/WORKFLOW-GUIDE.md:490`)/ 「CI 目前不用 filter」/ `tests.yml` 同列 unit+integration /
runner 的 `FORCED_ARGS` 含兩層(`tests/smoke/` 只有 `critical-paths.md`,不是測試層)/ `capture_window.ps1` 存在 /
coordination-rules haiku 7 個、opus 3 個名單逐一相符 / 73 個 skill / 六個 skill `model: sonnet` 配 director 級 agent(逐一相符)/ 該項登記在 `doc-audit-2026-09-01.md:153` /
context-management.md 無現況宣稱(全為流程規則)。

## 掃描範圍、方法與限制

- **7 份全部掃過**。初篩樣式:`至今|仍|尚未|目前|唯一|只有|待|未決|還沒|不存在|未同步|still|currently|only`,
  再人工挑出「描述現況」者;**裁決內容與規則本身一律不碰**。
- **未逐條查證的類別**:帶明確日期的實測快照(如「2026-09-01 實測 512 檔」「956 test cases」)視為有日期的紀錄,不算現況宣稱;
  `Memory Ceiling` / `Minimum Coverage` 的 `[TO BE CONFIGURED]` 是設定佔位,不判;
  ADR-0002 那列「VR#4/#7 未量測」未查(需讀 ADR 全文,超出本輪)。
- **自我命中陷阱**:所有 grep 的掃描路徑都不含宣稱所在檔;#5 本身正是這個陷阱的變形(宣稱要搜的字串出現在被搜的檔裡)。
- 📌 **順帶觀察,非過期宣稱**:directory-structure 的頂層圖沒畫 `.github/`(實際存在,CI 設定在內)。
  該圖只承諾「只畫存在的東西」,沒承諾「畫全」,故不列入;要不要補由擁有者決定。
