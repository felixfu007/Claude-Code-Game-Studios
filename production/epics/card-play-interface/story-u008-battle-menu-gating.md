# Story U-008: 選單開關閘控 —— suspend/resume 成對、`paused`、三種拒絕開啟

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Presentation(戰鬥選單,與游標系統機制九的第一個呼叫方)
> **型別**: Integration
> **估時**: M
> **依賴**: U-007
> **解鎖**: U-009(不在本次 8 個單元授權範圍內)
> **波次**: 波 3(與 U-012 ∥ 真平行 —— `battle_menu.gd` vs `hand_bar.gd`,U-012 不在本次
>   8 個單元授權範圍內)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`design/ux/battle-menu.md`「三件本畫面必須主動呼叫、不會自動發生的事」節、
States & Variants(N5 拒絕開啟)。

**Governing ADR**:ADR-0005(**Accepted**)—— 機制九(焦點/暫停閘控),控制清單呈現層
規則「暫停/模態閘控採顯式旗標,不採 `SceneTree.paused`」。

## 目標

讓戰鬥選單開啟時真的呼叫 `CursorStateHost.suspend_arbitration()` 並設定
`SceneTree.paused = true`,關閉時對稱呼叫 `resume_arbitration()` 並設回 `false`;同時
實作三種拒絕開啟情境(權威寫入進行中 / 強制棄牌進行中,兩者外觀須可區分)。做完之後,
AC-M3、AC-M8、AC-M9 三條 BLOCKING 驗收條件第一次可以端到端驗證。

## 🔴 本 story 決定的原始碼目錄路徑

EPIC.md 第二節單元清單表已列出落點,本節把它明文複述在這裡——理由與 U-007 相同:實作者
沒有既有檔可以「照著找」,story 是他唯一會讀的東西。

- **累加**:`src/ui/menu/battle_menu.gd`(U-007 已新建此檔案並交付 M0~M2 版面/導覽;
  本 story 在同一個檔案裡加上開關閘控——`suspend_arbitration()`/`resume_arbitration()`
  呼叫、`SceneTree.paused` 設定、三種拒絕開啟情境的判斷式)

⚠️ **本 story 不新建任何檔案。** 依賴 U-007(見上方 Dependencies),U-007 必須先存在
`battle_menu.gd`/`battle_menu.tscn`,本 story 才有東西可以累加。若實作時發現 U-007 尚未
完成或該檔案不存在,應視為前置條件未滿足,不得自行重新建立一份。

## Implementation Notes

1. 🔴 **暫停選單有三件事要做,本 story 負責前兩件(EPIC.md 陷阱七,轉錄,U-006 已交付
   第三件)**:

   | 要做的事 | 用什麼 | 🔴 不可以用什麼 | 誰交付 |
   |---|---|---|---|
   | 遊戲真的暫停 | `SceneTree.paused = true` | —— | **本 story** |
   | 游標裁定閘門 | `CursorStateHost.suspend_arbitration()` 的**顯式旗標** | 🔴
     `SceneTree.paused` 或 `process_mode` | **本 story**(呼叫既有介面) |
   | 讓宿主不被暫停停掉 | `CursorStateHost.process_mode` 設為不受暫停影響 | —— | U-006
     (已交付) |

   `docs/registry/architecture.yaml` 的 `cursor_arbitration_suspension_gate` 條目,
   `not:` 欄逐字排除 `SceneTree.paused` 與 `process_mode` 當閘門用——**本 story 對
   「要不要裁定」這件事只能透過呼叫 `suspend_arbitration()`/`resume_arbitration()`
   決定,不得用 `if get_tree().paused: return` 這種寫法自製一套閘門。**

2. 🔴 **`suspend_arbitration()`/`resume_arbitration()` 已存在,本 story 是它們的第一個
   呼叫方(`battle-menu.md` BM-8,已於 2026-09-15 由游標系統 Story 008 交付,轉錄)**:

   > `src/ui/cursor/cursor_state_host.gd:364`(`suspend_arbitration()`)與 `:376`
   > (`resume_arbitration()`)——兩函式已落地,`grep -rn "^func suspend_arbitration\|
   > ^func resume_arbitration" src/` 為兩處命中,並有
   > `tests/integration/cursor/focus_pause_gating_test.gd` 15 條測試覆蓋(含成對暫停/
   > 恢復、暫停期間殘留事件被丟棄、恢復後以目前滑鼠座標重新播種)。**語意與本節的要求
   > 相符**:`suspend_arbitration()` 立旗標並清空當幀緩衝,`resume_arbitration()` 降旗標、
   > 清空緩衝並重新播種滑鼠奪權累計值。
   >
   > 🔴 **但本畫面自己尚未落地**——`src/` 對 `battle_menu` 零命中,目前沒有任何呼叫方
   > 把這兩個函式接進實際選單場景,見 Open Questions BM-8 的更新版與 BM-9。

   **本 story 是「本畫面」——即那個尚未存在的呼叫方。不要重寫這兩個既有函式**,只需要在
   選單開啟/關閉的程式碼路徑裡各呼叫一次。

3. **兩個呼叫必須成對,且不得等動畫**(`battle-menu.md`,轉錄):

   > ⚠️ **兩個呼叫必須成對。** 只暫停不恢復會讓游標系統在選單關閉後永久停止裁定,
   > **而那不會報錯:畫面上高亮還在(是舊的),只是不再更新**——這正是 AC-M3 要驗的東西。

   > 開啟的同一幀就要呼叫暫停裁定,不得等動畫;關閉時恢復裁定同樣在同一幀,不得等動畫
   > 播完。

4. **裝置權威轉移是正確行為,不是缺陷**(`battle-menu.md`,轉錄,寫給下一個讀者避免
   誤判為 bug):

   > 開啟選單會轉移裝置權威,而這一點與「本畫面不登記為游標表面」無關。游標 GDD 的
   > AC-60 修訂明文記載:**裝置權威判定緩衝是全域的、與表面登記無關,未登記表面上的
   > 原生方向鍵導覽仍會轉移裝置權威。** → 玩家用手把在選單裡導覽之後回到棋盤,裝置權威
   > 已經是手把。**這是正確行為,不是缺陷。**

5. **三種拒絕開啟情境**(States & Variants N5,`battle-menu.md`,轉錄):

   > **N5 拒絕開啟**:權威寫入進行中,**或強制棄牌(S4)進行中** → 🔴 **不開啟,且拒絕
   > 須可觀測**;**兩種原因的拒絕回饋外觀須可區分**——強制棄牌須**明說原因**(比照
   > 「請先完成棄牌」一類文字),不得與權威寫入那種拒絕共用同一個外觀。

   ⚠️ **本 story 只交付「權威寫入進行中」這一種拒絕情境的完整驗證(AC-M8)**——強制棄牌
   拒絕(AC-M16)屬 U-015(不在本次授權範圍),**但本 story 的拒絕外觀設計必須預留兩種
   外觀可區分的空間**(例如拒絕回饋文字/圖示是參數化的,不是寫死單一文字),讓 U-015
   落地時只需要傳入不同的原因文字,不需要重構拒絕機制本身。

6. **選單開啟前後棋盤選取必須完整保留**(AC-M9)——選單本身不持有任何遊戲狀態
   (`battle-menu.md`:「本畫面不持有任何遊戲狀態。它讀三個判斷式、呼叫兩個介面,自己
   只保管『現在焦點在第幾列』與『M4 有沒有開著』」)——**本 story 不得對棋盤上已選定的
   單位做任何清除或修改**,選單開關只疊加/卸除視覺與暫停狀態,不觸碰棋盤選取狀態本身。

7. ⚠️ **本單元承接陷阱十三的通則(EPIC.md,轉錄)**:

   > 把元件的「決定」與引擎的「套用」拆成兩個斷言——決定用唯讀 `diagnostic_*` getter 在
   > headless 驗,套用在開視窗的執行驗。**兩個都要,不是二選一。**

   `SceneTree.paused` 的讀寫在 headless 下是否完全生效(不像 `Input.mouse_mode` 那種
   headless no-op),**本 story 不得假設,必須在 Test Evidence 裡實際驗證後才能宣稱
   headless 測試覆蓋了套用半部**;若驗證後發現 headless 下有任何非預期行為,必須改為
   「決定用 headless、套用用開視窗」兩層驗證,並在 story 完成時記錄下來。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- **AC-M3**:選單開啟 → **游標系統的裁定已暫停**;關閉 → **已恢復**,且關閉後移動游標,
  高亮確實更新 | Integration | **BLOCKING**
- **AC-M8**:權威寫入進行中按選單鍵 → **選單未開啟**,且拒絕回饋與其他拒絕外觀不同 |
  Integration | **BLOCKING**
  ⚠️ **部分涵蓋**——旗標 `authoritative_write_in_progress` 在 `src/` 只是一句註解
  (EPIC.md 限制表第 1 項,承接自 skill-card-system epic 限制 2),**本 story 只能驗
  「閘門有接」,不能驗「旗標會變真」,構造不出真陽性**。此限制由 #4 戰棋系統
  (ADR-0001 機制一)解除,不在本次授權範圍。
- **AC-M9**:選單開啟前棋盤上已選定一個單位 → 開啟後關閉 → **該選取完整保留** |
  Integration | **BLOCKING**

## Test Evidence

**型別**:Integration
**測試檔**:`tests/integration/ui/menu/battle_menu_gating_test.gd`

預期涵蓋:
- `test_opening_menu_calls_suspend_arbitration_and_sets_scene_tree_paused`
- `test_closing_menu_calls_resume_arbitration_and_unsets_scene_tree_paused`
- `test_suspend_and_resume_are_always_called_in_pairs_across_multiple_open_close_cycles`
- `test_moving_cursor_after_close_updates_highlight`(AC-M3 後半)
- `test_menu_key_rejected_while_authoritative_write_flag_true`(AC-M8,受限第 1 項限制,
  以測試替身模擬旗標為真,不構造真實陽性)
- `test_rejection_appearance_differs_between_authoritative_write_and_forced_discard`
  (預留外觀可參數化,U-015 落地前僅驗證機制存在)
- `test_board_selection_preserved_across_menu_open_and_close`(AC-M9)

## Out of Scope

- **強制棄牌拒絕情境的完整驗證**(AC-M16)——屬 U-015,不在本次授權範圍;本 story 只
  預留拒絕外觀的可參數化空間
- **「結束回合」列的功能與 AC-M5 共用判斷式**——屬 U-009,不在本次授權範圍
- **離開確認 M4**——屬 U-010,不在本次授權範圍
- **`process_mode` 排除設定本身**——已由 U-006 交付,本 story 只是它的第一個受益方
  (`suspend_arbitration()`/`resume_arbitration()` 呼叫得到執行,依賴 U-006 的排除設定)

## Dependencies

- 依賴:U-007(選單畫面本體)
- 解鎖:U-009(結束回合列需要本 story 的選單開關骨架才能接上),不在本次授權範圍
