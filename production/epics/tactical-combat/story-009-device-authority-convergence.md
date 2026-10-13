# Story 009: 裝置權威收斂(退役 `device_authority.gd`)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M6(收斂表 #2)
> **Status**: Ready(⚠️ 依賴 story-008 完成)
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: `design/gdd/cursor-highlight-state.md`(裝置權威仲裁機制)、
`.claude/docs/technical-preferences.md`「全手把對等、無游標裝置假設」。

**ADR Governing Implementation**: `ADR-0005`(**Accepted**)—— EPIC.md M6 收斂表 #2:
「裝置權威——`battle_screen.gd:941` 自行 `DeviceAuthority.new()`,靠約 15 處手動
`note_pad_input()`/`note_mouse_motion()` 餵資料 → 收斂到 `CursorState.arbitrate_device_authority()`
(由 `cursor_state_host.gd:391` 以引擎事件流自動驅動)」。

**Engine**: Godot 4.7.1 | **Risk**: HIGH(post-cutoff——裝置權威判定與 4.7 鍵盤/滑鼠裝置 ID
重新編號有交集,`TR-tactical-026` 已登記此交集;ADR-0005 的既有實作已處理此風險,本 story
沿用其結論)

## 現況(2026-09-29 實測,EPIC.md「A3 查證結果」節逐字引用)

```
$ grep -n "^func \|^enum " src/ui/battle/device_authority.gd
51:enum Device { MOUSE, PAD }
64:func _init(initial: Device = Device.MOUSE) -> void:
69:func current() -> Device:
75:func note_mouse_motion() -> void:
81:func note_pad_input() -> void:
94:func resolve_frame() -> bool:
$ wc -l src/ui/battle/device_authority.gd src/ui/cursor/cursor_state.gd
  116 src/ui/battle/device_authority.gd
 1206 src/ui/cursor/cursor_state.gd
```
`battle_screen.gd:941` 自行 `DeviceAuthority.new()`,由**約 15 處手動** `note_pad_input()`/
`note_mouse_motion()` 呼叫餵資料,每幀在 `_process()`(line 1019)呼叫 `resolve_frame()`。
EPIC.md 原文警語:「兩份的差別不只是位置,是資料來源的性質——一份靠人工在每個輸入分支手動
插呼叫(漏插不會報錯),一份靠引擎事件流。漏插一處的後果是裝置權威在那個分支不切換,而畫面
看起來完全正常。」

## Acceptance Criteria

- [ ] 🔴 **自 story-008 移交(2026-10-13 管理者裁決)**:滑鼠路徑的游標目標寫入
      (`_handle_mouse_button()` / 滑鼠懸停)須改為在 `_TargetRetargetActor`
      (priority −60,ADR-0005 R5-2 的 (−100, −25) 開區間)呼叫
      `CursorStateHost.set_target()`,**閘門讀 `CursorStateHost.get_device_authority()`**
      (priority −100 解出,**無過期**),**不得**讀已退役的 `_device.current()`。
      ⚠️ **已知且接受的行為變更**:滑鼠奪回高亮改為需達 `board_tile_threshold_px`
      (`src/ui/cursor/mouse_reclaim_threshold_config.gd:31`,**暫定 75px**,該檔檔頭
      自標 `PROVISIONAL VALUES`)的累積淨位移,**不再是任意微小移動即生效**。
      白話:現在滑鼠動一點點游標就跳,改完要移動約半格(1080p 4× 下 75px ≈ 0.59 格)才跟。
      設計依據是 GDD Core Rules #3:防止「玩家手不慎碰到滑鼠,高亮就在他未察覺時跳到別格」。
      ⚠️ **已知且接受的缺陷擴大**:E1(按住方向鍵可無限期否決滑鼠奪權,100% 可重現、
      所在子機制為使用者明文凍結)**自此可從主棋盤路徑觸及**。
      📌 完整五選項評估:`docs/architecture/cursor-device-authority-for-board-tile-2026-10-13.md`。

- [ ] 全部約 15 處手動 `note_pad_input()`/`note_mouse_motion()` 呼叫**移除**,裝置權威判定改由
      `CursorState.arbitrate_device_authority(events)`(`cursor_state_host.gd:391` 已以引擎
      事件流自動驅動)提供
- [ ] `_update_cursor_visual()`(`battle_screen.gd:2417`)原本以 `_device.current()` 決定游標
      走滑鼠座標還是 `_cursor_cell` 的邏輯,改讀 `CursorStateHost` 提供的等效裝置權威查詢
- [ ] `src/ui/battle/device_authority.gd`(116 行)**整份退役**(刪除檔案,或至少確認全專案
      無任何呼叫端引用——依 EPIC.md Definition of Done 明文要求)
- [ ] `battle_screen.gd:941` 的 `DeviceAuthority.new()` 建構呼叫移除
- [ ] 完成後跑一次完整回歸(同 story-008 的回歸義務——本 story 是對移動/攻擊路徑裝置權威判定
      的首次真實測試,之前兩條路徑時間上互斥從未被比較過)

## Implementation Notes

1. 🔴 **本 story 硬性依賴 story-008 先完成**——`_update_cursor_visual()` 的裝置權威判斷邏輯
   與 story-008 收斂的游標座標讀寫是同一段程式碼的相鄰邏輯,若裝置權威先被拆除、游標座標
   還沒接進 `CursorStateHost`,游標會在退役瞬間失去座標來源(EPIC.md 原文明確警告此順序錯誤
   的後果)。
2. **15 處呼叫點需要逐一確認,不得只改動一部分**——`note_pad_input()`/`note_mouse_motion()`
   分散在多個輸入處理函式中(方向鍵、滑鼠移動、確認鍵等),遺漏任何一處會讓該輸入分支的
   裝置權威判定停留在舊邏輯,與新邏輯並存卻互不同步——這正是 EPIC.md 警告的「漏插一處,
   裝置權威在那個分支不切換,畫面看起來完全正常」。建議:先完整 `grep -n "note_pad_input\|
   note_mouse_motion" src/ui/battle/battle_screen.gd` 列出全部呼叫點清單,逐一比對移除。
3. ⚠️ **未查證**:`CursorState.arbitrate_device_authority()` 的確切呼叫慣例與所需的事件格式——
   下一個人應讀該函式與 `cursor_state_host.gd:391` 週邊的既有呼叫端(打牌流程應已有正確用法
   可參照)。

## Out of Scope

- **方向鍵去抖收斂**——story-010。
- **輸入缺口補強**——story-011。
- **游標導航本身**——story-008,本 story 的前置依賴。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **裝置權威切換正確(滑鼠 → 手把)**
  - Given: 玩家先用滑鼠移動游標,再按下方向鍵
  - When: 檢查裝置權威判定結果
  - Then: 判定切換為手把,不再讀滑鼠座標
- **裝置權威切換正確(手把 → 滑鼠)**
  - Given: 玩家先用方向鍵移動游標,再移動滑鼠
  - When: 檢查裝置權威判定結果
  - Then: 判定切換為滑鼠
- **`device_authority.gd` 無殘留呼叫端**
  - Given: 全專案原始碼
  - When: `grep -rn "DeviceAuthority" src/`
  - Then: 零命中(檔案已刪除或確認無引用)
- **完整回歸——15 處移除後無退步**
  - Given: 全部既有 + story-008 新增測試
  - When: 執行測試套件
  - Then: 無新增失敗

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ui/battle_device_authority_convergence_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-008 的**鍵盤/手把半部**(已於 2026-10-13 落地,提交 `b4c8e6d`)。
  🔴 原本的「結構性依賴」理由(「先拆裝置權威會讓游標當場沒有來源」)**對鍵盤/手把分支
  已不再成立** —— 該分支現在讀 `CursorStateHost.get_current_target()`。
  滑鼠分支的座標來源仍不在 host 內,而**補上它正是本 story 併入的範圍**(見 AC 新增項)。
  ⚠️ **原文保留**:~~Depends on: story-008(游標導航收斂,結構性依賴,不得反過來)~~
- Unlocks: story-010(方向鍵去抖收斂,建議但非結構性依賴——見該 story）

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M6,M6 全部(008-011)須先於 M5、M4 執行完成,理由同 story-008。
