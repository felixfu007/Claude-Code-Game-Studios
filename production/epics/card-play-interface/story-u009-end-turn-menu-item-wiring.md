# Story U-009:「結束回合」列接上控制器,與既有查詢共用單一判斷式

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:Integration
> **狀態**:📋 Ready
> **估時**:S
> **依賴**:U-008(選單開關閘控,另一半交付)
> **波次**:波 4(與 U-010 同檔 `battle_menu.gd`,不可平行,但兩者順序可互換;U-013 可與兩者平行)

## Context

- **UX 規格**:`design/ux/battle-menu.md`(AC-M2、AC-M4、AC-M5、AC-M12)
- **權威 ADR**:ADR-0001(戰棋查詢原子性,**Accepted**)—— 玩家結束陣營回合是該 ADR 第一次修訂補登的六條權威寫入路徑之一(路徑 ⑤,`advance_faction()` 的玩家指令呼叫點)
- **Engine**:Godot 4.7.1

## 目標

把戰鬥選單的「結束回合」列真正接上 `BattleController`,並讓它的**可選/不可選狀態**與現有「打牌流程進行中不可攻擊」查詢**共用同一個判斷式**,不得在選單側另記一份會漂移的布林。

## 🔴 本 story 決定的原始碼目錄路徑

本 story 修改**既有檔案**(由 U-007/U-008 新建,非本 story 建立):`src/ui/menu/battle_menu.gd`——「結束回合」列的接線與可選判斷式接入點都在這支檔案裡。

## 本 story 必須讀而非重寫的既有程式碼

1. `src/gameplay/battle/battle_controller.gd:349`,**37 行既有程式**(提交 `1a62e6e`,已有 5 條測試,見 `tests/unit/gameplay/battle/battle_controller_test.gd`):

   ```gdscript
   func is_card_play_in_progress() -> bool:
       if _card_play_session == null:
           return false
       return _card_play_session.is_open()
   ```

   🔴 **不要重寫它,也不要在選單側另記一份狀態**——這正是 AC-M5 反向要驗的失敗形狀(EPIC.md 第六節裁定)。

2. `src/gameplay/battle/battle_controller.gd:562` 既有的 `end_faction_phase()`:

   ```gdscript
   func end_faction_phase() -> void:
       if _phase != Phase.PLAYER_INPUT:
           return
       if _state.has_pending_discard():
           return
       ...
   ```

   它**目前不檢查 `is_card_play_in_progress()`**——這是本 story 要補的判斷之一(AC-M4)。

3. `src/ui/battle/battle_screen.gd:728` 既有的鍵盤/手把入口 `_end_faction_phase_pressed()`:

   ```gdscript
   func _end_faction_phase_pressed() -> void:
       if _controller.phase() != BattleController.Phase.PLAYER_INPUT:
           return
       _controller.end_faction_phase()
       _controller.run_enemy_phase()
       _refresh_view()
   ```

   🔴 **2026-09-22 更正:上面那段程式碼是 U-018 之前的舊版,現行程式碼不長這樣。**

   實測現行 `battle_screen.gd` 的 `_end_faction_phase_pressed()` 是一個**跨幀協程**,
   迴圈呼叫 `step_enemy_phase()` 並累計 `_diagnostic_step_enemy_phase_call_count`,
   **不呼叫 `run_enemy_phase()`**。改動來自 `story-018-enemy-phase-stepped-playback.md`
   (敵方階段分步播放),本檔撰寫時尚未發生。

   ⚠️ **照舊版字面實作會造成本段自己明文禁止的結果**:選單若照抄
   `end_faction_phase()` → `run_enemy_phase()`,就會生出**第二個行為與鍵盤入口不同的
   敵方階段驅動器** —— 而本段原句的用意正是「不得另寫一條平行路徑」。
   **字面意思與用意在 U-018 之後開始互相矛盾,而沒有任何東西會發現。**

   ✅ **實作者(2026-09-22)偏離了字面、照現況實作,那是正確的處置。**
   現行作法:選單列只呼叫 `end_faction_phase()` 並發出 `end_faction_phase_confirmed` 訊號,
   由未來把本選單接進 `battle_screen.gd` 的 story 決定如何抽乾階段。
   理由全文寫在 `battle_menu.gd` 的 `_on_end_phase_row_pressed()` 文件註解裡。

   **本段保留的原意仍然成立**:不得另寫平行路徑。
   ⚠️ **這個既有入口在本 story 完成後依然存在**(它綁在 `battle_end_phase` 動作上,
   直到 U-016 才解綁),期間選單與 Esc/B 是兩條並存的觸發手段,互不衝突。

## Implementation Notes

1. **可選判斷式 = 三個既有查詢的合取**,不得新增第四個:
   `_controller.phase() == BattleController.Phase.PLAYER_INPUT`
   `and not _controller.is_card_play_in_progress()`
   `and not _controller.has_pending_discard()`
   選單列的 disabled 旗標與原因文字必須由**呼叫這個判斷式**產生,而不是選單自己算一份。

2. **AC-M5 的驗收方式是「改 `phase()` → 選單列同步變,選單零改動」**——這意味著選單這一側只能持有一個讀取這個判斷式的 Callable/介面,不能持有任何自己的布林快取。實作時請把這個判斷式抽成 `BattleController` 或呼叫端的一個具名查詢(例如 `can_end_faction_phase() -> bool` + 一個回傳原因字串的伴隨方法),避免同一段邏輯在選單裡重複一次。

3. **U-007/U-008(`battle_menu.gd`)屬另一半,目前尚未落地**——本 story 撿到的介面形狀(選單如何接收「這一列可不可選 + 原因文字」)取決於那邊實際交付的 API。若撿到時尚未確定,先與該工作單的實作者對齊介面契約,不要自行假設欄位名稱。

4. **AC-M4 的原因文字**必須是玩家看得懂的白話(例如「請先完成或取消打牌」,`battle-menu.md` wireframe 的既有措辭),不是欄位名稱或錯誤碼。

5. **AC-M12 驗的是「原因文字不隨焦點出現/消失」**——這句話管的是**資料**而非畫面:本 story 提供的判斷式與原因字串必須是**選單開啟時算一次、全程不變**(除非底層狀態真的改變),不得隨游標移到哪一列才臨時算。實際的「常駐顯示」渲染邏輯屬 U-007 既有的 M3 元件,本 story 不重複實作,只需確保餵給它的資料不因焦點而閃爍或消失。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-M2**:全程不接滑鼠、只用手把 → 完成「開選單 → 結束回合」與「開選單 → 關閉」兩條路徑(UI,BLOCKING,`P-I2`)
- [ ] **AC-M4**:打牌流程進行中開選單 → 「結束回合」不可選、且畫面上出現原因文字;其餘兩項仍可選(UI,ADVISORY)
- [ ] **AC-M5**:🔴 把 `BattleController.phase()` 改成非玩家回合 → 選單列的不可選狀態同步改變,不需要改動選單自己的任何程式碼(Logic,BLOCKING——這條驗的是「兩者共用同一判斷式」,不是外觀)
- [ ] **AC-M12**:打牌流程進行中開選單,焦點移到「回到遊戲」或「離開遊戲」列(不在「結束回合」列上)→ M3 的原因文字仍然可見(UI,BLOCKING——驗的正是「常駐不隨焦點」這條裁決,不驗會與「灰掉但只在選到時才顯示原因」混淆)

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/menu/battle_menu_end_turn_wiring_test.gd`(🔴 2026-09-22 更正:原寫 `tests/integration/ui/` 根層,而 U-008 的 `battle_menu_gating_test.gd` 早已在 `ui/menu/` 子目錄。實作者依既有慣例放置,非偏離)

預期涵蓋:

- `test_end_turn_item_disabled_when_card_play_in_progress`
- `test_end_turn_item_disabled_when_pending_discard`
- `test_end_turn_item_enabled_reverts_when_phase_becomes_player_input`(AC-M5 的注入測試——把共用改成各記一份,本測試必須轉紅,見 `battle-menu.md` 該條註記)
- `test_selecting_end_turn_calls_end_faction_phase`(🔴 2026-09-22 更正:原名含 `_then_run_enemy_phase`,而現行程式碼已不走 `run_enemy_phase()`——見本檔「既有程式碼」第 3 項的更正說明)
- `test_reason_text_persists_when_focus_moves_off_end_turn_row`(AC-M12)
- `test_gamepad_only_path_completes_open_menu_to_end_turn`(AC-M2)

## Out of Scope

- **選單本身的開關、暫停閘控、M0~M2 版面**——屬 U-007 / U-008(另一半)。
- **離開確認 M4**——屬 U-010。
- **`authoritative_write_in_progress` 旗標的真陽性驗證**——`src/` 裡它只是一句註解,尚無實體(EPIC.md 限制第 1 條)。本 story 不涉及該旗標(結束回合不受它閘控,只受上述三個既有查詢閘控)。
- **`battle_end_phase`(Esc/B)綁定的移除**——屬 U-016,本 story 完成後兩條路徑(選單 + Esc/B)並存,不衝突。
