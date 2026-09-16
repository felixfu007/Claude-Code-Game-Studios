# Story U-012:Z2 展開層 + Z3 卡牌細節 + 選牌導覽(S1)

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:UI
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:U-011(Z1 手牌縮圖帶)
> **波次**:波 3(與 U-008 真平行——`hand_bar.gd` vs `battle_menu.gd` 各自往下長)

## Context

- **UX 規格**:`design/ux/skill-card-play.md`(AC-U2、AC-U6、AC-U8〔部分〕、AC-U10〔部分〕,`Layout Zones` Z2/Z3,`States & Variants` S1,`Interaction Map` 四步流程第 1~2 步)
- **權威 ADR**:ADR-0001——本 story 涉及的是 S0→S1→S2 的零寫入步驟(開手牌、選牌),不觸及任何權威寫入路徑
- **Engine**:Godot 4.7.1

## 本 story 決定的原始碼目錄路徑

沿用 U-011 的既定路徑:`src/ui/battle/hand_bar.gd`(同檔往下長)。

## 目標

讓玩家能展開手牌(Z1 原地長大為 Z2)、左右瀏覽每一張卡並看到 Z3 的卡牌細節,並呼叫既有邏輯層 `CardPlaySession.select_card()` 完成 S1→S2 的轉換。

## 本 story 必須讀而非重寫的既有邏輯層

`src/gameplay/cards/card_play_session.gd` 已交付完整的 S0~S4 狀態機(`enum Step { CLOSED, SELECTING_CARD, SELECTING_TARGET, SELECTING_TARGET_B, CONFIRMING }`),本 story **只是把 UI 接上它,不重寫任何狀態轉換邏輯**:

- `open_hand() -> bool`:S0→S1,若權威寫入進行中同步回傳 `false`(對應 AC-U8 的閘門)。
- `select_card(card: Card) -> bool`:S1→S2/S2p,只檢查 `card` 是否在手牌內。
- `cancel() -> void`:從任一步退回一步,S1 時回到 S0(CLOSED)。

🔴 **不要在 `hand_bar.gd` 裡另外維護一份「目前選到第幾張」以外的狀態機**——本 story 的 UI 層只負責「游標停在第幾張、觸發哪個 session 方法」,S1/S2 的合法性判斷全部委派給 `CardPlaySession`。

## Implementation Notes

1. **Z2 尺寸與位置**(`Layout Zones` 表):介面層,同 Z1 錨點,原地向上長大;單卡 `4.5 × 6 fpx`,間距 `0.5 fpx`(合計 `24.5 fpx` 寬)。🔴 **卡面尺寸是被無障礙 150% 反推出來的硬上限**,`skill-card-play.md` 逐字:「任何日後加寬卡面的提案,先驗算 `5w + 4g ≤ 26.2 fpx`」——不得自行加寬。

2. **Z3 卡牌細節**:選定卡的正上方,寬 ≥ 該卡,高 `≤ 4 fpx`。內容含逐條修正的來源與量值(讀 `Unit.active_modifiers()`,已實作,見下方第 5 點)。

3. **AC-U2 的兩個要求都要驗**:①Z2 完全可讀 ≤ 200ms;②轉場動畫期間按 `←` **立即**選到前一張,輸入不被吞掉。`Transitions & Animations` 表:「不得阻塞輸入——動畫期間按鍵照收」。

4. 🔴 **AC-U6 的驗收跨兩個單元**:三組灰階可區分性(甲類 vs 丙類、剩 1 vs 剩 2、可用 vs 不可用)中,「可用 vs 不可用」那組的畫面實際在 U-011(S0/S5 對照);本 story 只需交付「甲類 vs 丙類」與「剩 1 vs 剩 2」兩組在 Z2/Z3 上的呈現,並在測試裡明確標註哪一組畫面來自哪個 story,避免重複或漏測。

5. **逐條修正清單已有現成介面,不必新建**:`Unit.active_modifiers() -> Array[CardModifier]`(`src/gameplay/units/unit.gd:122`),每筆 `CardModifier` 有獨立 `clone()`,欄位為 `source_name`、`atk_delta`/`def_delta`(帶號、分開兩欄)、`remaining_turns`。回傳空陣列即為「該單位確實無生效中修正」,**不需要佔位文字**(空是合法狀態)。

6. 🔴 **AC-U8 目前只能驗「閘門有接」,不能驗「旗標會變真」**——`authoritative_write_in_progress` 在 `src/gameplay/battle/battle_state.gd` 目前只是一句文件註解,不是實體欄位(`_authoritative_write_in_progress_check: Callable` 是 `CardPlaySession` 建構時注入的一個可選 Callable,未設定時視為「永不阻擋」)。本 story 能驗證的是:當這個 Callable 回傳 `true` 時,`open_hand()` 確實回傳 `false` 且 UI 顯示對應的拒絕外觀;**不能構造出「今天遊戲裡這個旗標真的被結算路徑設成 true」的真陽性場景**——那需要 #4 戰棋系統把 `authoritative_write_in_progress` 從註解變成真正的欄位(EPIC.md 限制第 1 條)。

7. 🔴 **AC-U10 只能驗 4 組,不能驗 12 組**——75%/150% 兩檔字級功能不存在(`HudLayout.font_size()` 目前無玩家可調係數,UX-5)。本 story 只驗證 100% 檔位 × 四種螢幕共 4 組不溢出。⚠️ **不得抽樣宣稱「12 組已驗」**——`skill-card-play.md` 明文警告 150% 是唯一會溢出的那個,只測 100% 會全綠而那正是原條件要防的事;本 story 誠實只claim 4 組。

8. ⚠️ **版面驗算表是 (C) 級,不是 (A) 級**(EPIC.md 陷阱十二)——四螢幕表格下方本檔自陳「上表為算術、非實機量測」,依 (A) 級定義為 (C) 級,因為它重新實作了 `HudLayout.font_size()` 與 `safe_rect()` 各一條規則。**落地前須以呼叫這兩個函式的拋棄式測試複驗並附檔案路徑**——沒有附檔案路徑的「(A) 級」一律降為 (C)。

## Acceptance Criteria

*以下為 `design/ux/skill-card-play.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-U2**:按 `開手牌` → Z2 完全可讀 ≤ 200ms;且轉場動畫期間按 `←` 立即選到前一張(輸入未被吞掉)(UI,ADVISORY)
- [ ] **AC-U6**:把三組狀態區分的截圖轉為灰階 → 甲類 vs 丙類、剩 1 vs 剩 2、可用 vs 不可用三組皆仍可區分(UI,BLOCKING,`P-F3` 無例外——本 story 交付前兩組,第三組見 U-011)
- [ ] **AC-U8**:權威寫入進行中按 `開手牌` → 手牌未開啟,且出現的拒絕回饋與「目標不合法」的拒絕回饋外觀不同(Integration,BLOCKING)⚠️ **部分**——旗標不存在,只能驗「閘門有接」
- [ ] **AC-U10**:四種螢幕 × 字級 75%/100%/150% 共 12 組 → Z2 五張卡完整落在安全區內,無裁切、無溢出(UI,BLOCKING)⚠️ **部分**——只能驗 100% 檔的 4 組

## Test Evidence

**型別**:UI
**測試檔 / 證據**:`tests/integration/ui/hand_bar_expand_selection_test.gd` + `production/qa/evidence/story-u012-hand-expand-evidence.md`

預期涵蓋:

- `test_open_hand_transitions_session_to_selecting_card`
- `test_input_not_blocked_during_expand_animation`(AC-U2 後半)
- `test_open_hand_rejected_when_authoritative_write_in_progress_check_returns_true`(AC-U8,白箱注入 Callable)
- 手動截圖:甲類 vs 丙類、剩 1 vs 剩 2 轉灰階仍可區分(AC-U6 前兩組)
- 四螢幕 × 100% 字級截圖比對(AC-U10 的 4 組,注明 75%/150% 未涵蓋)
- 拋棄式測試複驗 `HudLayout.font_size()` / `safe_rect()` 的呼叫結果與版面驗算表一致(陷阱十二義務,記錄檔案路徑於測試檔頭註解)

## Out of Scope

- **手牌縮圖帶 Z1 本身、S0/S5/S7 三態**——屬 U-011(已交付,本 story 只讀）。
- **選作用對象 S2/S2p/S2q、合法目標高亮**——屬 U-013。
- **確認面板 S3**——屬 U-014。
- **75%/150% 字級功能**——UX-5,無障礙檔登記 `Not Started`。
- **`authoritative_write_in_progress` 真正變成 `true` 的場景**——#4 戰棋系統,ADR-0001 機制一。
