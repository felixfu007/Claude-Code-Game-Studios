# Story 010: 方向鍵去抖收斂至 `InputEventKey.echo` 過濾

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M6(收斂表 #3)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S~M(視驗證結果而定,見下方查證步驟)
> **Manifest Version**: 2026-09-09

## Context

**ADR Governing Implementation**: `ADR-0005`(**Accepted**)—— EPIC.md M6 收斂表 #3:
「方向鍵去抖——`battle_screen._direction_just_pressed()` 自維護 pressed-state Dictionary →
收斂到 ADR-0005 的 `InputEventKey.echo` 過濾(`cursor_types.gd:165`)」。

**Control Manifest 硬性義務(直接摘錄)**:「`classify_action()` 必須自行過濾
`InputEventKey.echo`——已實測 `InputMap.event_is_action()` **不過濾**;不濾的話,玩家按住
方向鍵會每一影格都被判為導覽,亦即每一影格都在主張裝置權威」。

🔴 **本 story 與 story-008/009 不同,EPIC.md 明文這是「解決同一問題但手法不同,語意未必等價」**,
**收斂前必須先驗證**,不是直接替換。

**Engine**: Godot 4.7.1 | **Risk**: HIGH(post-cutoff——`InputEventKey.echo` 行為與鍵盤事件
處理相關,屬 4.7 高風險範圍,但 ADR-0005 已對此逐項驗證過鍵盤路徑;本 story 新增的驗證範圍是
**手把類比搖桿**,ADR-0005 是否已涵蓋此裝置類型未查證,見下方)

## 現況(2026-09-29 實測,EPIC.md「A3 查證結果」節逐字引用)

```
$ sed -n '1756,1760p' src/ui/battle/battle_screen.gd
func _direction_just_pressed(action: StringName, tracker: Dictionary) -> bool:
	var pressed_now: bool = Input.is_action_pressed(action)
	var was_pressed: bool = tracker.get(action, false)
	tracker[action] = pressed_now
	return pressed_now and not was_pressed
```
`battle_screen.gd` 用「自己維護 pressed-state Dictionary」做長按去抖,ADR-0005 那邊走的是
`InputEventKey.echo` 過濾(`src/ui/cursor/cursor_types.gd:165`)。兩者解決同一個問題
(長按/echo 重複觸發),手法不同。

## Acceptance Criteria

**第一步(查證,BLOCKING 於第二步之前)**:
- [ ] 確認 ADR-0005 的 `InputEventKey.echo` 過濾機制**是否涵蓋手把類比搖桿長按**——
      EPIC.md 明文:「Dictionary 那份明文是為它寫的」,意即現行 `_direction_just_pressed()`
      的 Dictionary 去抖是專門為手把類比搖桿長按設計。`InputEventKey.echo` 顧名思義是**鍵盤**
      事件的重複觸發旗標,手把類比搖桿的長按是否會產生對應的 `echo` 事件、或需要另一套機制
      (例如 deadzone + 輪詢間隔),**未查證**——這是本 story 存在的核心理由,不得假設兩者
      涵蓋範圍相同就直接刪除 Dictionary 去抖。
- [ ] 把查證結論寫回本 story 的 Implementation Notes 節。

**第二步(依查證結果)**:
- [ ] **若 `echo` 過濾確實涵蓋手把類比搖桿長按**:方向鍵/十字鍵/手把輸入的去抖邏輯改用
      `cursor_types.gd:165` 的既有過濾機制,`_direction_just_pressed()`/`tracker: Dictionary`
      **退役**(移除或確認無殘留呼叫端)。
- [ ] **若 `echo` 過濾不涵蓋手把類比搖桿長按**:**不得**收掉 Dictionary 去抖這條路徑——
      EPIC.md 明文警告「收斂前必須先確認 echo 過濾涵蓋『手把類比搖桿長按』,否則會收掉一個
      還在用的行為」。此情況下,本 story 的驗收條件改為:明確登記「鍵盤路徑收斂至 `echo` 過濾,
      手把類比搖桿路徑維持既有 Dictionary 去抖或另尋等效機制」,並記錄為技術債(兩套並存,
      但涵蓋範圍不重疊,不是同一輸入源的重複實作)。

## Implementation Notes

⚠️ **未查證,待本 story 執行時補**:
1. `InputEventKey.echo` 是否只對鍵盤事件有意義(依 Godot API 命名,`InputEventKey` 本身即為
   鍵盤事件類別,手把輸入走 `InputEventJoypadButton`/`InputEventJoypadMotion`,兩者是否有
   對應的 `echo` 概念)——這是本 story 第一步查證的核心問題。若手把事件類別沒有 `echo` 概念,
   則 EPIC.md 期待的「收斂」在字面上不可能對手把路徑成立,需要重新評估 EPIC.md 該項收斂表
   的可行性,而非強行套用。
2. 若手把類比搖桿確實沒有對應的 `echo` 概念,`cursor_types.gd:165` 的過濾邏輯具體實作方式
   (是否只判斷 `event is InputEventKey and event.echo`,對 `InputEventJoypadMotion` 完全不
   處理)——下一個人應直接讀該檔案該行週邊程式碼確認。
3. **本 story 的查證步驟本身可能導致驗收條件被下修**(從「完全收斂」降為「部分收斂 + 明確
   登記技術債」)——這是允許的結論,不是本 story 失敗,只要查證過程與結論誠實記錄。

## Out of Scope

- **游標導航收斂**——story-008。
- **裝置權威收斂**——story-009。
- **鍵盤路徑以外的其他輸入去抖機制設計**——若查證發現需要為手把新設計一套去抖機制,
  該設計本身屬於一次新的工作單,不在本 story 範圍內展開(本 story 僅需明確登記缺口)。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。**以下測試規格假設查證結果為「echo
過濾涵蓋手把」的情境;若查證結果相反,測試範圍限縮為鍵盤路徑,手把路徑另行登記。**

- **鍵盤長按不重複觸發導覽**
  - Given: 玩家按住方向鍵不放
  - When: 檢查連續多幀的導覽觸發次數
  - Then: 只在按下瞬間觸發一次,長按期間不重複觸發(依 `echo` 過濾)
- **鍵盤放開後再按下正確重新觸發**
  - Given: 玩家按下方向鍵 → 放開 → 再次按下
  - When: 檢查觸發次數
  - Then: 兩次按下動作各自觸發一次
- **手把類比搖桿長按行為(依查證結果二選一)**
  - Given: 玩家推住類比搖桿不放
  - When: 檢查連續多幀的導覽觸發次數
  - Then: **若查證確認 `echo` 涵蓋此裝置**——行為與鍵盤一致,只觸發一次;**若不涵蓋**——
    此測試改為驗證既有 Dictionary 去抖邏輯（維持現況）仍正確運作,不得因收斂鍵盤路徑而
    意外破壞手把路徑

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ui/direction_key_debounce_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-008(建議先完成游標導航收斂,確保输入分派邏輯已穩定,再處理去抖細節;
  非嚴格結構性依賴,但建議依施工序執行)
- Unlocks: None(獨立收斂項目)

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M6,M6 全部(008-011)須先於 M5、M4 執行完成。
