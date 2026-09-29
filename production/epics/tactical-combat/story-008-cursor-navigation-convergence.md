# Story 008: 一般移動/攻擊路徑接入 `CursorStateHost`(游標導航收斂)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M6(收斂表 #1)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: `design/gdd/cursor-highlight-state.md`(游標系統,本 story 的收斂目標)、
`design/gdd/tactical-combat-system.md` Dependencies(單一游標/高亮狀態系統為上游硬依賴)、
Core Rules #10/UI Requirements §6(確認鍵輸入生效前須先查詢游標系統的有效性旗標)。

**ADR Governing Implementation**: `ADR-0005`(單一游標/高亮狀態系統:裝置權威輸入架構,
**Accepted**)。本 story 是 EPIC.md M6 節「✅ 2026-09-29 管理者裁決:選(甲)——全部收成一份」
的第一項落地(逐處對應表 #1:游標導航)。

**管理者裁決背景(EPIC.md 原文,不重複推導,僅摘錄裁決本體)**:選(甲)「一般移動/攻擊路徑
接進 `CursorStateHost`」而非(乙)「保留兩份,登記為已知重複」——理由是選(乙)會讓
`design/ux/tactical-combat-screen.md` 5(c) 與 GDD line 644「確認鍵生效前須先查詢有效性旗標」
在一般移動/攻擊路徑上**永久無法滿足**(該路徑上沒有旗標可查)。管理者是看過此代價後選(甲)。

**Engine**: Godot 4.7.1 | **Risk**: HIGH(post-cutoff——鍵盤/滑鼠裝置 ID 重新編號、
`InputEventKey.echo` 過濾行為皆屬 4.7 變更範圍,ADR-0005 已對此逐項驗證,本 story 沿用其結論
不重新查證引擎行為本身)

**Control Manifest Rules(Presentation 層,ADR-0005 相關,直接摘錄)**:
- 「兩條隨 ADR-0005 核准生效的硬性義務」之一:**游標圖層必須獨佔一顆 `CanvasLayer`**——
  本 story **不得**破壞此義務(已在 #3 落地,本 story 只是新增一條路徑去使用它,不重做)
- 「絕不用 `_unhandled_input()` 做裝置權威判定」
- 「絕不在 `_unhandled_input()` 讀確認動作」
- 「已註冊表面絕不使用原生 Control focus/hover」
- 「絕不從自己的訊號處理器寫入游標狀態」

## 現況(2026-09-29 實測,EPIC.md「A3 查證結果」節逐字引用)

```
$ awk '/^func /{fn=$0} /register_surface|unregister_surface/{print NR": ["fn"] "$0}' src/ui/battle/battle_screen.gd
1887: [func _confirm_selected_card()]  register_surface(BOARD_TILE, self)
2052: [func _after_target_selection_advanced()]  unregister_surface(BOARD_TILE)
2226: [func _handle_card_confirm_cancel_transition()]  register_surface(BOARD_TILE, self)
2263: [func _handle_target_selection_cancel_transition()]  unregister_surface(BOARD_TILE)
```
四個註冊點**全部**是打牌路徑。一般移動/攻擊路徑完全沒有註冊 `BOARD_TILE` surface。

```
$ awk '/^func /{fn=$0} /_cursor_cell *=/{print NR": ["fn"] "$0}' src/ui/battle/battle_screen.gd
955:  [_ready()]                 _cursor_cell = _state.position_of(player_ids[0])
1706: [_handle_mouse_button()]   _cursor_cell = cell
1733: [_handle_directional()]    _cursor_cell = clamp_cursor_move(_cursor_cell, _DIRECTION_VECTORS[action])
2421: [_update_cursor_visual()]  _cursor_cell = cell
```
四處直寫,完全繞過 `CursorStateHost`。`clamp_cursor_move()`(`battle_screen.gd:1206`)是自有
static 函式,與 `CursorState.apply_buffered_navigation()`(`cursor_state.gd:534`)是兩份各自
實作的方向鍵導航。

## Acceptance Criteria

- [ ] 一般移動/攻擊路徑(非打牌流程)須在適當時機呼叫
      `CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)`
      /`unregister_surface(...)`,比照打牌路徑既有的四個註冊點模式
- [ ] `_cursor_cell` 的 4 個直寫點(`_ready()`、`_handle_mouse_button()`、`_handle_directional()`、
      `_update_cursor_visual()`)改為讀取 `CursorStateHost.get_current_target()`,不再由
      `battle_screen.gd` 自行維護游標座標的權威來源
- [ ] `_handle_directional()` 的導航邏輯改呼叫 `CursorState.apply_buffered_navigation()`
      (`cursor_state.gd:534`),`clamp_cursor_move()`(`battle_screen.gd:1206`)本 story 完成後
      應無呼叫者(是否刪除該函式屬本 story 判斷,不強制,但不得兩份並存繼續被呼叫)
- [ ] **完成後跑一次完整回歸**(EPIC.md 明文:「收斂後的第一件事是跑完整回歸,把差異當成
      發現而非退步——今天兩條路徑時間上互斥,所以沒有任何既有測試在比較它們」)——
      ADR-0005 的有效性旗標語意首次套用到移動/攻擊路徑,**可能暴露既有行為差異**,此為已知
      並接受的代價,不是本 story 的失敗
- [ ] **不破壞 ADR-0005 已落地的兩條硬性義務**(回歸測試須維持綠燈):
      `tests/unit/cursor/cursor_layer_transform_test.gd`(游標圖層獨佔 `CanvasLayer`)、
      `cursor_types.gd:165` 的 `InputEventKey.echo` 過濾邏輯

## Implementation Notes

1. 🔴 **本 story 必須先於 story-009(裝置權威收斂)完成**——EPIC.md 明文:「收斂的順序是
   『先接線、再退役』,不是反過來……現況 `_update_cursor_visual()` 以 `_device.current()`
   決定游標走滑鼠座標還是走 `_cursor_cell`,先拆裝置權威會讓游標當場沒有來源」。
2. **打牌路徑的四個註冊點是現成的實作範本**——本 story 不是設計新模式,是把既有模式套用到
   一般移動/攻擊路徑。閱讀 `_confirm_selected_card()`/`_after_target_selection_advanced()`/
   `_handle_card_confirm_cancel_transition()`/`_handle_target_selection_cancel_transition()`
   四個函式的完整實作,依樣套用到一般選取/取消流程的對應時機點。
3. ⚠️ **未查證**:一般移動/攻擊流程的「進入」「離開」時機點(對應打牌流程的選卡確認/取消)
   具體落在 `battle_screen.gd` 的哪些函式——下一個人需要先讀完整個輸入分派流程
   (`_input()` → `_handle_mouse_button()`/`_handle_directional()` → `_confirm_at_cursor()`)
   才能決定 register/unregister 的精確呼叫點。

## Out of Scope

- **裝置權威收斂**(`device_authority.gd` 退役)——story-009,依賴本 story 完成。
- **方向鍵去抖收斂**(echo 過濾)——story-010。
- **輸入缺口補強**(U-T6/7/8)——story-011。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **一般移動路徑正確註冊/取消註冊**
  - Given: 玩家選取單位進入移動預覽狀態
  - When: 檢查 `CursorStateHost` 已註冊的 surface
  - Then: `BOARD_TILE` surface 已註冊;取消選取後應正確取消註冊
- **`_cursor_cell` 不再是權威來源(回歸測試)**
  - Given: 一般移動流程中游標移動
  - When: 比對 `CursorStateHost.get_current_target()` 與畫面實際游標位置
  - Then: 兩者一致,且畫面游標位置的權威來源是前者
- **完整回歸——既有測試套件**
  - Given: 全部既有單元/整合測試
  - When: 執行 `tests/gdunit4_runner.gd`
  - Then: 無新增失敗(既有的 1 個既知紅燈 `affinity_phi_provider` 測試除外);任何新發現的行為
    差異須明確記錄為「發現」並個別評估,不得因為「以前沒測過」而略過不報

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ui/battle_cursor_navigation_convergence_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(不依賴 M2/M3,但**必須先於 story-009 完成**——執行順序見下方)
- Unlocks: story-009(裝置權威收斂,結構性依賴——見上方 Implementation Notes 第 1 點)

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M6,**M6(008-011)必須先於 M5(012-013)、M4(014-015)完成執行**——三者共用
`src/ui/battle/battle_screen.gd`(2702 行),規劃層產出互不依賴但執行不可並行(EPIC.md
「依賴與實作順序」節)。理由:M5 的面板要讀「裁定後的狀態」,讀的是哪一份必須在它動工前
就是唯一解;M6 完成後 `_cursor_cell` 的讀寫語意才固定。
