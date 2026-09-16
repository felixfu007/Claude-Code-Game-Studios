# Story U-006: 游標宿主 —— `process_mode` 排除暫停 + 診斷用唯讀狀態

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: 📋 Ready
> **層**: Presentation(游標系統,#3)
> **型別**: Logic
> **估時**: S
> **依賴**: 無
> **解鎖**: U-007
> **波次**: 波 0(與 U-001 ∥ U-002 ∥ U-004 四路真平行 —— 四個不同檔,零交集)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**權威來源**:`design/ux/battle-menu.md`「三件本畫面必須主動呼叫、不會自動發生的事」節、
Open Questions **BM-9**、**BM-10**。

**Governing ADR**:ADR-0005(**Accepted**)—— 機制九(焦點/暫停閘控),控制清單呈現層
規則「暫停/模態閘控採顯式旗標,不採 `SceneTree.paused`」。

## 目標

讓 `CursorStateHost`(`src/ui/cursor/cursor_state_host.gd`)在 `SceneTree.paused = true`
期間**不被引擎自動停止 `_process()`**,並新增一個診斷用唯讀狀態(或訊號),供之後的選單
工作單(U-008)佐證「暫停期間 `_process()` 仍在執行,裁定的暫停/恢復是由 `suspend_arbitration()`
/`resume_arbitration()` 的顯式旗標決定,不是被 `SceneTree.paused` 連帶停掉」。做完之後,
`battle-menu.md` 的 **BM-9** 與 **BM-10** 兩個缺口關閉。

## Implementation Notes

1. 🔴 **暫停選單有三件事要做,而第一直覺會把它們混成一件(EPIC.md 陷阱七,轉錄)**:

   | 要做的事 | 用什麼 | 🔴 不可以用什麼 |
   |---|---|---|
   | 遊戲真的暫停 | `SceneTree.paused = true` | —— |
   | 游標裁定閘門 | `CursorStateHost.suspend_arbitration()` 的**顯式旗標** | 🔴
     **`SceneTree.paused` 或 `process_mode`** |
   | 讓宿主不被暫停停掉 | `CursorStateHost.process_mode` 設為不受暫停影響 | —— |

   `docs/registry/architecture.yaml` 的 `cursor_arbitration_suspension_gate` 條目,
   `not:` 欄逐字列出 `SceneTree.paused` 與 `process_mode` **不得當閘門用**。理由回指游標
   GDD 的 AC-60:那條的情境正是**一個不會讓 `paused` 變 true 的未登記表面** —— 亦即引擎
   的暫停機制與「游標要不要裁定」是兩件不同的事。

   **本 story 只做上表第三件事**(`process_mode` 排除暫停)——第一件事(`SceneTree.paused`
   本身)是 U-008 的職責(它是選單畫面觸發的);第二件事(`suspend_arbitration()`/
   `resume_arbitration()` 呼叫)已由游標系統 Story 008 交付(見下),也不是本 story 要做的。

2. **`CursorStateHost.process_mode` 現況零命中(`battle-menu.md` BM-9,轉錄)**:

   > **`CursorStateHost` 需新增「不受 `SceneTree.paused` 影響」的 `process_mode` 設定**,
   > 現況零命中(`grep -n "process_mode" src/ui/cursor/cursor_state_host.gd`)。本畫面
   > (U-008)首次要求真的設定 `SceneTree.paused = true`,若不排除,暫停期間該 Autoload
   > 的 `_process()` 會連同旗標邏輯一起停擺。

   **實作**:在 `CursorStateHost`(Autoload,`Node` 基底)設定
   `process_mode = Node.PROCESS_MODE_ALWAYS`(或引擎文件確認的等效設定 —— 具體常數名稱
   實作時對照 Godot 4.7.1 API 確認,不假設訓練資料裡的舊名稱仍然正確)。**理由**:
   `suspend_arbitration()`/`resume_arbitration()` 這兩個已交付的介面(見下)本身用的是
   **顯式旗標**(`_arbitration_suspended`),但**旗標的檢查邏輯寫在 `_process()` 裡**
   (`cursor_state_host.gd:324`:`func _process(_delta: float) -> void: if
   _arbitration_suspended or _frame_events.is_empty(): return` ...)——若 `_process()`
   本身被 `SceneTree.paused = true` 停掉,旗標邏輯根本不會被執行到,**兩套機制疊在一起時
   若不做這個排除,暫停選單開著的時候裁定會真的停,但停的理由是節點被暫停,不是旗標生效,
   下一次有人移除暫停機制時邏輯會悄悄壞掉而不報錯**(EPIC.md 陷阱七的延伸後果)。

3. **`suspend_arbitration()`/`resume_arbitration()` 已存在,不要重寫(`battle-menu.md`
   BM-8,已於 2026-09-15 由游標系統 Story 008 交付,轉錄)**:

   > `src/ui/cursor/cursor_state_host.gd:364`(`suspend_arbitration()`)與 `:376`
   > (`resume_arbitration()`)——**兩函式已落地**,並有
   > `tests/integration/cursor/focus_pause_gating_test.gd` 15 條測試覆蓋(含成對暫停/
   > 恢復、暫停期間殘留事件被丟棄、恢復後以目前滑鼠座標重新播種)。**語意與需求相符**。

   **本 story 不修改、不重寫這兩個函式** —— 它們已經是完成品。本 story 只補 `process_mode`
   排除(讓它們在暫停期間真的能被呼叫到)與診斷狀態(下一點)。

4. 🔴 **新增一個診斷用唯讀狀態或訊號,供 AC-M14 佐證(`battle-menu.md` BM-10,轉錄)**:

   > `CursorStateHost` 需新增一個診斷用唯讀狀態或訊號,供 AC-M14 佐證「暫停期間
   > `_process()` 仍在執行」——`src/ui/cursor/cursor_state_host.gd` 現況未提供此介面
   > (僅一般 `_process()`,無診斷輸出)。

   依控制清單全域規則「診斷欄位(`diagnostic_*`)為 QA/測試專用,下游業務邏輯不得依賴」
   ——建議命名 `diagnostic_last_process_frame_count` 或等效的、每次 `_process()` 執行就
   遞增的唯讀計數器(或一個 `process_tick` 訊號),供 U-008 的整合測試在
   `SceneTree.paused = true` 期間觀察它是否持續變化,證明 `_process()` 確實還在跑。
   **命名與具體形狀(計數器 vs 訊號)由實作時判斷**,只要求滿足「測試能在 headless 模式下
   觀察到它,且它不影響任何裁定邏輯本身」。

5. ⚠️ **本單元同時承接陷阱十三的通則(EPIC.md,轉錄,適用本單元)**:

   > 本 epic 有 11 個 UI / Integration 單元。通則:**把元件的「決定」與引擎的「套用」
   > 拆成兩個斷言**——決定用唯讀 `diagnostic_*` getter 在 headless 驗,套用在開視窗的
   > 執行驗。**兩個都要,不是二選一。**

   本 story 交付的「診斷用唯讀狀態」正是這條通則要求的「決定」半部——它可以在 headless
   下被測試觀察。「套用」半部(`SceneTree.paused = true` 期間引擎確實仍呼叫這顆節點的
   `_process()`)理論上也能在 headless 下驗證(`process_mode` 的效果不依賴視窗渲染,
   與 `Input.mouse_mode` 那種「headless 下寫入為 no-op」的情況不同——`SceneTree.paused`
   與 `process_mode` 都是純邏輯層狀態,headless 下應該完全生效),但實作者仍應在
   Test Evidence 裡明確驗證這一點,不得假設。

## Acceptance Criteria

*以下為 `design/ux/battle-menu.md` 的條文原文轉錄,未改寫:*

- **AC-M14**:選單開啟(`SceneTree.paused = true`)期間 → `CursorStateHost` 的
  `_process()` **仍在執行**(以其診斷用唯讀狀態或訊號佐證),游標裁定的暫停/恢復由旗標
  而非暫停狀態決定 | Integration | **BLOCKING**——見 BM-9,實作前置條件未滿足前本條無法
  通過

  ⚠️ **本 story 只交付 AC-M14 的前置條件**(`process_mode` 排除 + 診斷狀態)——**AC-M14
  完整驗證需要 `SceneTree.paused = true` 這個觸發動作,而那是 U-008(選單開關閘控)才會
  做的事。本 story 完成後,AC-M14 的「前半段」(診斷狀態存在且行為正確)可獨立驗證,
  「後半段」(它在真的選單開關時确实有效)要等 U-008 落地才能端到端驗證。**

## Test Evidence

**型別**:Logic
**測試檔**:`tests/unit/cursor/cursor_host_pause_exclusion_test.gd`

預期涵蓋:
- `test_process_mode_is_set_to_always_or_equivalent`
- `test_process_continues_incrementing_diagnostic_counter_while_scene_tree_paused`
  (headless,直接設定 `get_tree().paused = true` 後觀察診斷計數器)
- `test_diagnostic_state_does_not_affect_arbitration_suspended_flag`(確保診斷欄位是
  純觀察用,不影響裁定邏輯本身,呼應控制清單「下游業務邏輯不得依賴」的反面驗證)

## Out of Scope

- **`SceneTree.paused = true`/`false` 的實際設定時機(開關選單時)**——屬 U-008
- **`suspend_arbitration()`/`resume_arbitration()` 的呼叫時機與成對保證**——屬 U-008,
  本 story 不修改這兩個既有函式
- **選單畫面本身的任何版面或行為**——屬 U-007/U-008

## Dependencies

- 依賴:無
- 解鎖:U-007(選單畫面需要游標宿主先具備暫停排除能力,才能安全地讓選單觸發
  `SceneTree.paused`)
