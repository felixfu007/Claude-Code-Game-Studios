# Story U-010:離開確認 M4(預設焦點在取消、明說進度會消失)

> **Epic**:卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **型別**:UI
> **狀態**:📋 Ready
> **估時**:S
> **依賴**:U-007(選單畫面 M0~M2 版面、原生 focus,另一半交付)
> **波次**:波 4(與 U-009 同檔 `battle_menu.gd`,不可平行,但兩者順序可互換)

## Context

- **UX 規格**:`design/ux/battle-menu.md`(AC-M6、AC-M7,`Layout Specification` 的 M4 區、`Component Inventory` 的 `P-M4`)
- **權威 ADR**:無新增 ADR 需求——`P-M4`(破壞性動作確認)已於 2026-09-09 登記進 `design/ux/interaction-patterns.md`,本 story 是既有模式的第二個實例,非新模式。
- **Engine**:Godot 4.7.1

## 目標

建立「離開遊戲」的二次確認畫面(M4),且**預設焦點落在「取消」**——理由是機械性的,不是禮貌性的,見下方 Implementation Notes 第 1 點。

## 🔴 本 story 決定的原始碼目錄路徑

本 story 修改**既有檔案**(由 U-007 新建,非本 story 建立):`src/ui/menu/battle_menu.gd`——M4 離開確認畫面是這支檔案裡新增的一塊,不是獨立檔案。

## Implementation Notes

1. 🔴 **M4 預設焦點在「取消」的理由逐字轉錄(`battle-menu.md`)**:

   > **M4 的預設焦點必須在「取消」,而理由是機械性的而非禮貌性的**:確認鍵是
   > `battle_confirm`,**而玩家是用同一個鍵選到「離開遊戲」的** —— 若 M4 的預設焦點落在「離開」,
   > **連按兩下確認就會關掉遊戲**,而「連按兩下」正是誤觸的典型形狀。
   > **這與本檔要解決的問題是同一個,只是換了一層。**

   實作時務必確認:玩家在 M1 選單按 `battle_confirm` 選中「離開遊戲」後,M4 開啟瞬間焦點**不是**沿用「上一個被選中的項目」這種常見的模態畫面慣例,而是強制重設到「取消」按鈕。

2. **M4 疊在 M1 之上,M1 不消失**(`Navigation Position`:「玩家要看得出自己還在選單裡」)。M1 的遮罩(M0)與面板持續存在於 M4 底下。

3. **文案必須明說後果**(AC-M7),`battle-menu.md` 的 wireframe 給出具體措辭範例:

   ```text
   目前沒有存檔功能,離開後這場
   戰鬥的進度會消失。
   ```

   本作目前沒有存檔系統(`design/ux/battle-menu.md` 排除清單第一項:「戰鬥進行中不可手動存檔」的管理者裁決),故这句话是字面事实,不是保守的警告用语。

4. **尺寸規格**(`Layout Zones` 表):M4 寬 `14 fpx`,高 `7 fpx`,錨定 `HudLayout.safe_rect(window_size)`,`fpx = HudLayout.font_size(window_size)`——**呼叫既有函式,不得自行重刻**(本檔開頭紀律)。

5. ⚠️ **四螢幕 × 三字級的版面驗算表是 (C) 級,不是 (A) 級**(`battle-menu.md` 逐字:「上表為算術,非實機量測……依 (A) 級定義為 (C) 級」)。落地前須以呼叫 `HudLayout.font_size()` 與 `safe_rect()` 的拋棄式測試複驗,並附檔案路徑——這條驗算義務主要落在 U-007(M1 本身),但 M4 的 `14×7 fpx` 同樣未經實機驗證,實作本 story 時一併確認 M4 在 150% 字級下仍落在安全區內。

6. **上下導覽在 M4 內只有兩個選項**(取消/離開),不涉及 M1 的「不繞回」裁決(那是 M1 專屬,見 `battle-menu.md`「上下導覽的兩條裁決」)——本 story 不需要重新推導繞回規則,M4 只是左右或上下二選一。

7. **關閉 M4 回到 M1**:選定「取消」,或按 `battle_cancel`(`Esc`/`B`)——兩者皆回到 M1,不關閉整個選單。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- [ ] **AC-M6**:進入離開確認 → 預設焦點在「取消」;自「離開遊戲」列連按兩次確認 → 遊戲未關閉(UI,BLOCKING)
  🔴 **本條有一半永遠沒有自動防線,見 `design/ux/battle-menu.md` Acceptance Criteria 表格正下方的登記**(2026-09-22 管理者裁決)。
- [ ] **AC-M7**:離開確認的文字明確說出「進度會消失」(UI,ADVISORY)

## Test Evidence

**型別**:UI
**測試檔 / 證據**:`tests/integration/ui/battle_menu_leave_confirmation_test.gd` + `production/qa/evidence/story-u010-leave-confirmation-evidence.md`

預期涵蓋:

- `test_m4_default_focus_is_cancel_on_open`
- `test_double_confirm_from_leave_game_row_does_not_quit`(AC-M6 的核心宣稱)
- `test_m4_overlays_m1_without_hiding_it`
- 手動截圖驗證文案含「進度會消失」字樣(AC-M7,ADVISORY,依 `coding-standards.md` 截圖規則——須有人打開圖檔確認)

## Out of Scope

- **M1 選單本身的版面、開關閘控**——屬 U-007 / U-008(另一半)。
- **「結束回合」列的接線**——屬 U-009。
- **標題畫面**——`project.godot` 的啟動場景直接是戰鬥畫面,「離開遊戲」目前只能結束行程、不能回主選單(EPIC.md 限制第 6 條,BM-5,待有標題畫面時回頭處理)。
- **視覺樣式**(遮罩透明度、面板邊框、焦點標記形狀)——`art-director` + `/art-bible`(BM-7)。
