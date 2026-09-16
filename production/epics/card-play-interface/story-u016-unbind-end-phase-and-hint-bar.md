# Story U-016:🔴 `battle_end_phase` 解綁 + 操作提示橫條更新

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:U-009(結束回合列已接上控制器)**與** U-015(強制棄牌已能擋住選單)——兩者都要在,見下方為什麼。
> **波次**:波 6(單獨一波,本 epic 最後一個單元,最短路徑第 7 波)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(AC-U12,Interaction Map 按鍵配置表)、`design/ux/battle-menu.md`(AC-M1)
- **權威 ADR**:無新增——本 story 是既有 `project.godot` `[input]` 節與 `battle_screen.gd` 既有按鍵處理的變更,不定義新的跨系統契約
- **Engine**:Godot 4.7.1

## 🔴 這是本 epic 唯一有驗收出口的單元

**AC-U12 與 AC-M1 是同一條驗收條件的兩側**,而它是本 epic 30 條 AC 裡**唯一一條「防止交付到一半就上線」的條件**:

> 取消鍵已重綁為 `battle_cancel` 之後 → 仍存在一條可完成「結束回合」的路徑(選單),鍵盤與手把各一。

🔴 **在本 story 完成前,「玩家在畫面上真的打得到牌」沒有任何東西可以驗收——這是 epic 的形狀,不是進度落後。** U-011~U-015 交付的是打牌流程的每一段(展開手牌、選對象、確認、強制棄牌),但整條流程要到本 story 才第一次符合驗收條件本身要求的狀態:取消鍵真正只做取消、`battle_end_phase` 真正沒有殘留的舊綁定、且結束回合的路徑(選單)已確認存在。EPIC.md 第四節逐字:「016 之前不會有任何『玩家在畫面上真的打得到牌』可以驗收。中間每一波都是可玩的建置,但打牌路徑要到 014 才第一次完整、016 才第一次符合驗收條件。這是本 epic 的形狀決定的,不是進度落後。」

## 為什麼依賴 U-009 **與** U-015 兩者都要在

`skill-card-play.md` 逐字警告過同一個坑踩了兩次:

> `battle_end_phase` 目前的兩個綁定(Esc、手把 B)**就是玩家唯一能把回合交給敵方的手段**。
> 一旦把它們移交給取消而選單還沒做好,**玩家無法結束回合,戰鬥永遠停在自己的回合。**

- 需要 **U-009**:選單的「結束回合」列必須已經真正接上 `BattleController.end_faction_phase()`,否則解綁 `Esc`/`B` 之後玩家連結束回合的替代路徑都沒有。
- 需要 **U-015**:強制棄牌必須已經能擋住選單開啟(AC-M16),否則玩家可能在棄牌阻塞期間打開選單、選到「結束回合」,繞過本應阻塞他的強制棄牌——這是 EPIC.md 陷阱六指出的同形狀風險在另一個角落的變體。

## 🔴 本 story 決定的原始碼目錄路徑

本 story 修改兩個既有檔案,不新建任何檔案:

- `project.godot`(`[input]` 節)——解綁 `battle_end_phase` 的 `Esc`/手把 B 綁定。
- `src/ui/battle/battle_screen.gd`——移除既有的 `battle_end_phase` 按鍵處理(第 407 行附近的 `is_action_pressed(&"battle_end_phase")` 分支)、`_end_faction_phase_pressed()` 方法(第 728 行)的去留、以及 `TEXT_CONTROLS_HINT` 常數(第 173 行)的內容更新。

## Implementation Notes

1. **解綁,不是刪除動作**。`project.godot` 的 `[input]` 節裡 `battle_end_phase` 這個動作本身要不要保留、要不要改名,是 **BM-1**(`battle-menu.md` Open Questions)明文登記為未決的問題,擁有者是「戰棋系統(#4)/`lead-programmer`」。本 story 只移除 `Esc` 與手把 `B` 這兩個**綁定**,不删除 `battle_end_phase` 這個 action 本身,也不重新命名它——那件事留給 BM-1 的裁決,不在本 story 範圍內自行決定。

2. **`battle_screen.gd:407` 既有的按鍵處理要拿掉**:

   ```gdscript
   if event.is_action_pressed(&"battle_end_phase"):
       _device.note_pad_input()
       _end_faction_phase_pressed()
       return
   ```

   這段(連同 `_end_faction_phase_pressed()` 方法本身是否保留、是否被選單的呼叫路徑取代)需要一併處理,確保 Esc/B 只再觸發 `battle_cancel`,不再同時觸發結束回合。⚠️ **U-005 到 U-015 期間,`Esc` 同時觸發 `battle_end_phase` 與 `battle_cancel` 是管理者已核准的過渡態(2026-09-15 裁決 F,見下)**,本 story 是關閉這個過渡態的地方。

3. 🔴 **過渡期雙重觸發是已裁決事實,不要重新開放討論,也不要重提被否決的方案**。2026-09-15 管理者裁決(EPIC.md 第八節第 2 項)逐字:

   > **裁決內容**:接受過渡期 `Esc` 同時觸發 `battle_end_phase` 與 `battle_cancel`。
   > U-005 與 U-016 維持分開,不合併。
   > 🔴 **知情代價(裁決當下明示)**:U-005 到 U-015 期間,按 `Esc` 取消卡牌會一併結束回合。
   > **這是已知且被接受的,不是 bug,不要當成缺陷去修**——它由 U-016 一次解決。

   協調者當場另提的第三案(過渡期讓 `battle_cancel` 先綁一個臨時鍵)已被管理者否決,**不要在本 story 裡重新提出這個方案**——EPIC.md 已記錄否決理由(代價是一條沒有自動檢查的紀律,臨時鍵可能被忘記而出貨)。

4. 🔴 **操作提示橫條的 12px 餘裕問題(EPIC.md 陷阱十)**。`TEXT_CONTROLS_HINT`(`battle_screen.gd:173`)現有一行實測 452px,可用約 464px,餘裕僅 12px,而本 epic 新增 5 個動作(取消、開手牌、跳目標×2、選單)。本 story 必須帶著處置方向開始,不要寫到一半才發現。**本 story 的判斷(未經覆核,擁有者是本 story 的實作者,可推翻)**:改成**兩行顯示**(例如第一行常態操作,第二行新增的打牌/選單操作),而非做分頁系統或縮小字級——分頁需要額外的頁面狀態與導覽,縮小字級會撞上無障礙字級可調的下限。若實作時發現兩行仍放不下或有更好的既有元件可用,請在該行為落地前與 UX-8 的擁有者(戰鬥 HUD #10,目前無人)或 `lead-programmer` 確認,不要沉默地各自決定。

5. **`TEXT_CONTROLS_HINT` 的既有內容**含 `"結束回合 Esc/B"` 這一段文字——本 story 完成後這段文字必須移除或改寫(結束回合已經不再是任何單一按鍵,而是選單裡的一項),並新增本 epic 引入的 5 個動作提示。

6. **最終按鍵配置**(`skill-card-play.md` Interaction Map 表,本 story 完成後應成立的終態):

   | 動作 | 鍵盤 | 手把 |
   |---|---|---|
   | 取消/退一步 | `Esc` | B |
   | 開/收手牌 | 建議 `C` | 建議 X |
   | 跳下一個/上一個合法目標 | `Tab`/`Shift+Tab` | RB/LB |
   | 開啟選單(結束回合的新家) | 建議 `M` | Start |
   | 結束回合 | 選單內選項 | 選單內選項 |

   **「結束回合」不再是任何單一按鍵**——這正是 AC-U12/AC-M1 要驗證的最終狀態。

## Acceptance Criteria

*以下為兩份 UX 規格的條文原文轉錄,未改寫——兩條是同一條驗收條件的兩側,兩份都要過:*

- [ ] **AC-U12**(`skill-card-play.md`):取消鍵已重綁為 `battle_cancel` 之後 → 仍存在一條可完成「結束回合」的路徑(選單),鍵盤與手把各一(Integration,BLOCKING)
- [ ] **AC-M1**(`battle-menu.md`):🔴 取消鍵已重綁為 `battle_cancel` 之後 → 鍵盤與手把各存在一條可完成「結束回合」的路徑,且該路徑實際使敵方回合開始(Integration,BLOCKING)

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/end_phase_unbind_test.gd`

預期涵蓋:

- `test_battle_end_phase_action_has_no_bindings_after_unbind`(驗證 `project.godot` 解綁,不驗證 action 是否仍存在——那是 BM-1 的範圍)
- `test_pressing_escape_only_triggers_cancel_not_end_turn`
- `test_pressing_gamepad_b_only_triggers_cancel_not_end_turn`
- `test_end_turn_via_menu_keyboard_path_actually_starts_enemy_phase`(AC-U12/AC-M1 鍵盤側)
- `test_end_turn_via_menu_gamepad_path_actually_starts_enemy_phase`(AC-U12/AC-M1 手把側)
- `test_controls_hint_bar_fits_within_available_width_with_all_new_actions`(陷阱十,量測實際渲染寬度,不得只靠人工目測)

## Out of Scope

- **`battle_end_phase` 這個 action 本身要不要改名/移除**——BM-1,擁有者戰棋系統(#4)/`lead-programmer`,本 story 只解綁不刪除、不改名。
- **選單本身、「結束回合」列的接線邏輯**——屬 U-007/U-008/U-009(已交付),本 story 只移除舊路徑,不重新實作新路徑。
- **操作提示橫條的視覺樣式**(字型、配色、分行的具體排版細節)——`art-director` + `/art-bible`;本 story 只保證資訊放得下、可讀,不定案最終美術。
- **強制棄牌本身的行為**——屬 U-015(已交付,本 story 只依賴其「選單被擋」的效果來確認終態安全)。
