# Story 040:資訊卡顯示「攻擊:原因」(打不到時說明為什麼)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)—— 2026-11-12 依 lead-programmer 審查改寫 AC。🔴 須在 story-039 提交後才開工(同一個檔)
> **Type**: Logic + UI
> **Estimate**: S~M
> **依據**:
> - 管理者試玩回報(2026-11-11):「敵方明明在射程內,我方卻無法攻擊…不確定是BUG還是機制」;
>   管理者判定成因「應該是3(倒木擋視線),因為都是色塊,我根本看不出來這些色塊代表什麼」。
> - 管理者 2026-11-12 裁決,選項逐字「**A 資訊框多一行「無法攻擊:原因」(推薦)**」;
>   被跳過:「B 按攻擊被拒時跳短提示」「C 棋盤上標字或常駐圖例」。紀錄:`production/session-state/active.md` 第九十九批節。
> - 管理者 2026-11-12 核准「可以,照專家意見改完就派工(推薦)」(AC 改寫依本單審查;紀錄在 `active.md` 第九十九批節,grep「040 工單」)。
> - 選項分析:`docs/reviews/tile-info-and-attack-reason-options-2026-11-12.md` 題二。
> - AC 審查全文:`docs/reviews/story-039-040-lead-review-2026-11-12.md` 第二節。
> - 文案:`docs/reviews/attack-reason-wording-2026-11-12.md`(ux-designer)。

## 為什麼

攻擊不合法目前只有橘色「視線被擋」高亮(`set_attack_los_blocked_highlights`),沒有任何文字。
打不到的原因有四種,玩家無從分辨。

## 派工前查核(2026-11-12,lead-programmer 已查)

1. **ADR-0001 `QueryResult` 契約是否適用本單新增的 controller 查詢** —— 🔴 **文件字面不決定,結論為「建議不用,但有歧義,實作者在回報中明寫採用的讀法」**。
   依據 `docs/architecture/query-result-scope-boundary-2026-10-12.md` 第二之一節三條判準:
   ①回傳值在 `_refresh_view()` 單次執行內被讀取;②進入 `_board_view.*` 或 HUD 渲染呼叫;③是計算導出結果。
   - 實測:`_update_tile_info_panel()` 的呼叫點(`battle_screen.gd` 約 4970 行)**在 `_refresh_view()`(起於 4620 行)函式體內**,
     所以本單新查詢**經由被呼叫的函式傳遞地**在同一次重繪內被讀;第③條成立(計算導出);去向是 HUD 資訊卡文字。
   - 但該文件第三節產生範圍清單的方法是對 `_refresh_view()` 函式體本身 grep,**不含被呼叫函式內部的讀取**
     (既有的 `_cursor_attack_target_id()` → `attack_targets()` 同樣是這種傳遞性讀取)。**字面讀法下不在範圍;傳遞性讀法下在範圍。**
     文件未說明用哪一種。
   - 我的建議:**不包成 `QueryResult`**。理由:該文件二之一節自己指出安全性由「`_refresh_view()` 同步、無權威寫入」這個性質撐著,
     同一次重繪內讀到的結果必然同版本;且本查詢回傳單一列舉,沒有「與其他疊加圖層合成一張盤面」的風險。
   - ⚠️ 該文件二之二節要求「新增會讀查詢結果並送進渲染的路徑時,回到文件重算範圍」。**實作者須在回報中明寫:
     採用字面讀法、不包 `QueryResult`,並指出這是一項未經裁決的歧義**,由協調者決定是否請示 `technical-director`。本單不自行裁決。
2. **`tests/integration/ui/battle_screen_tile_info_test.gd` 是否有在地化列數/鍵斷言** —— **沒有**。實測該檔無任何 `csv` /
   列數 / 鍵名斷言;它只斷言 `build_tile_info_text()` 輸出的行數(4 行、8 行)與文字。本單依 AC3 **不改** `build_tile_info_text` 簽章與輸出,
   故該檔預期**不受影響**。`tests/` 下 `battle.tile_info` 字樣只出現在 `tests/unit/core/i18n/locale_data_integrity_test.gd`;
   `strings.csv` 資料列數斷言在該檔 `is_equal(165)`(2026-11-12 story-039 後現值)。**本單新增 5 列 → 須改為 `170`**(註解照該檔既有格式追加一行),
   實作者交付前仍須 `grep -rn "is_equal(165)" tests` 確認沒有第二處。

## Acceptance Criteria

- [ ] **AC1 規則層(分兩層,不可全塞一處)**
      新增列舉 `AttackBlockReason { NONE, OUT_OF_RANGE, TOO_CLOSE, LOS_BLOCKED, ACTION_SPENT }`(放 `combat_rules.gd`)。
      - `CombatRules.attack_block_reason(from, to, min_range, max_range, is_occluding)`:只做純幾何,回 `NONE / OUT_OF_RANGE / TOO_CLOSE / LOS_BLOCKED` 之一。
        🔴 **只呼叫既有 `is_in_range` / `is_attack_blocked_by_los`,以及 `CombatRules` 類內既有的 `_manhattan_distance`(僅用來區分過近/過遠)。
        不得新寫距離或視線算法;不得在 UI 層重算。** 專案已登記「同一公式兩份實作、只是今天答案一致」失效模式。
      - `BattleController` 新增一個查詢(例如 `attack_block_reason_for(target_id)`):**外層閘門與 `_attack_targets_for()` 完全相同**
        (非 `PLAYER_INPUT`、無選取 → 回「不適用」,即 `NONE`;`_order.can_attack(selected)` 為假 → `ACTION_SPENT`),其餘委派 `BattleState` → `CombatRules`。
        ⚠️ **`BattleState` 不持有 `TurnOrder`,「已用完」不能放 `BattleState`**(原工單此處寫錯,已更正)。
      - 🔴 **優先序(寫死)**:`ACTION_SPENT` > 射程類(`TOO_CLOSE` / `OUT_OF_RANGE`,兩者互斥)> `LOS_BLOCKED`。
        `LOS_BLOCKED` 只在已落在射程帶內才成立,故不會與射程類並存;`ACTION_SPENT` 涵蓋「攻擊旗標已用」與「已被結束行動」兩種成因,不區分。
      - 🔴 **不得用 `assert()` 守「不可達」分支**(回傳列舉的函式,失敗時會靜默回 ordinal 0 = `NONE` = 「可攻擊」,與意圖相反);
        用 `push_error()` + 明確 `return` 非 `NONE` 值。見 `coding-standards.md`。
- [ ] **AC2 一致性測試(預言機必須是既有函式)**
      - 測試掃過一批 `from / to / min_range / max_range / 遮蔽樣式`,斷言
        `(reason == NONE) == CombatRules.is_attack_legal(...)`,**且** `(reason == LOS_BLOCKED) == CombatRules.is_attack_blocked_by_los(...)`。
        **測試內不得自己算曼哈頓距離或視線。**
      - 🔴 **防空洞**:測試須統計掃描結果中 `NONE / OUT_OF_RANGE / TOO_CLOSE / LOS_BLOCKED` **各至少出現 1 次**,否則失敗(避免輸入集恰好沒覆蓋某原因而「全綠」)。
      - **整合層**:對一個真實 `BattleController`(注入合成資料依 `technical-preferences.md` 第 5 點,不得自組替身節點鏈),
        對每個敵兵斷言 `attack_targets().cells.has(位置) == (reason == NONE)`;並有一條斷言攻擊旗標已用的單位對任一敵兵回 `ACTION_SPENT`,
        另一條斷言優先序(已用完且距離過遠 → 回 `ACTION_SPENT`)。
- [ ] **AC3 顯示**
      落入「單位資訊」分支(**非**傷害預覽分支)、佔位者為 `Unit.Faction.ENEMY`、且查詢結果 `!= NONE` 時,在單位資訊之後附加一行(整行 `攻擊：%s`)。
      **以查詢結果為唯一判斷來源,不重複條件。** 可攻擊、我方單位、空格、未選取、非玩家輸入階段 → 不顯示此行。
      **以 `"\n" + 行` 附加(仿現有 `guard_text` 做法),不得改 `build_tile_info_text` 簽章**(它已因 story-039 長出預設參數,不再增加)。
      文案與鍵名(在地化,不得寫死)照 `docs/reviews/attack-reason-wording-2026-11-12.md`:
      | 鍵 | 值 |
      |---|---|
      | `battle.tile_info.attack_line_format` | `攻擊：%s` |
      | `battle.tile_info.attack_reason_action_spent` | `已用完` |
      | `battle.tile_info.attack_reason_out_of_range` | `目前太遠` |
      | `battle.tile_info.attack_reason_too_close` | `目前太近` |
      | `battle.tile_info.attack_reason_los_blocked` | `視線被擋` |
      (注意:該文件第二節寫「兩段式前綴 + 原因」、第四節卻給了整行 `%s` 格式鍵;本單依協調者指示採**整行 `攻擊：%s`**,不另設前綴鍵。)
      CSV 為 `assets/data/locales/strings.csv`(唯一合法的 `.csv`),改完須走 `run_tests_with_import.sh`。
- [ ] **AC4 面板高度**
      原因行只對敵方、現有「減傷列」只對我方,**互斥**,故共用現有 `_tile_info_extra_line`「多一行」旗標,面板最多仍為 9 行。
      測試斷言:①兩列不會同時出現 ②顯示原因行時 `_TILE_INFO_PANEL_LINE_COUNT + 1` 行高度足夠,不溢出。
- [ ] **AC5 敏感度證明**(🔴 **一個 mutant 一次獨立執行**——GdUnit4 第一個失敗斷言會中止同檔後續測試,同一次執行無法證明後面的斷言):
      至少三個 mutant,各自「改壞 → 紅 → 還原」:①互換 `CombatRules.attack_block_reason` 內過近/過遠比較方向 ②移除 `LOS_BLOCKED` 分支
      ③移除 `BattleController` 的 `ACTION_SPENT` 閘門。另 AC3 顯示條件各一條(可攻擊不顯示、我方不顯示)。交付前掃描殘留注入標記。
- [ ] **AC6 像素層待驗(非單元測試門檻)**
      實作後在 **960×540 最小視窗**截圖,確認四句原因整行不被截斷、不換行(換行會撐高框)。ux-designer 估算可用約 7 個全形字(含前綴與冒號),
      四句最長恰為 7 字、無餘裕,**該估算未經實測**(未讀 Label 內距與 autowrap 設定)。超出時退路依序:①「視線被擋」→「被擋住」、「目前太遠/近」→「太遠/太近」
      (見 `attack-reason-wording-2026-11-12.md` 第三節);②才考慮加寬框(管理者 10/28 說過框太大,不建議)。**截圖須依 `coding-standards.md` 截圖證據規則分類(此為 Category C 裁切或 A 全窗,先判類別再套檢查),並由人開圖確認。**
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,貼 `ENGINE EXIT` 與 `Overall Summary` 原始行。

## 未涵蓋(刻意)

- 文字放不放得進框寬(像素層)→ AC6 開窗目視,不是單元測試門檻。
- 「按攻擊被拒時」的回饋(管理者跳過 B 案)。
- 原因以**目前位置**計算(不考慮先移動再攻擊);「目前」二字是文案對此的唯一提示,是否需要更明確的教學提示等試玩再議。
- 文件同步(`tactical-combat-system.md` / UX 文件)→ 協調者另行請示。
- `build_tile_info_text` 預設參數(`occupant_id` / `occupant_code_name`)改必填 → 兩單落地後另開清理單。

## Affected Files

- `src/gameplay/combat/combat_rules.gd`(列舉 + `attack_block_reason`)
- `src/gameplay/battle/battle_controller.gd`(新查詢 + 外層閘門)
- `src/ui/battle/battle_screen.gd`(附加原因行、共用 `_tile_info_extra_line`)
- `assets/data/locales/strings.csv`(新增 5 列,見 AC3)
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(列數 165 → 170 與註解)
- 新測試檔:`tests/unit/gameplay/combat/combat_rules_attack_block_reason_test.gd`(AC2 掃描與一致性)、
  `tests/integration/ui/battle_screen_attack_reason_line_test.gd`(AC2 整合層、AC3、AC4)
- (`BattleState` 預期**不需**修改;若實作者發現需要動,先問。)

超出此清單先問。
