# Story 015: 單位行動旗標持久非色彩標記 + 不可通行地形呈現

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M4
> **Status**: Ready(規劃層無阻擋;執行層見下方序列化)
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: S~M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: States and Transitions(「可行動」複合狀態,四種可觀測值)、Visual/Audio §1.1
「規格要求改動現行實作——行動旗標指示」(四種可觀測值皆未用/只剩攻擊/只剩移動/已行動,
必須是非色彩通道可辨識的持久標記,「常駐於棋盤上,不需要選取或開啟面板才看得到」)、
Tuning Knobs #4(不可通行地形 `passable` 呈現)。

**ADR Governing Implementation**: `ADR: N/A —— 純呈現層繪製,無跨系統契約`(消費 story-001/004
的既有查詢輸出)

**Engine**: Godot 4.7.1 | **Risk**: LOW

## Acceptance Criteria

- [ ] 四種行動旗標可觀測值(皆未用/只剩攻擊/只剩移動/已行動)在世界層有**持久**、**非色彩
      通道**的視覺標記——貼棋子右上,比照 `skill-card-play.md` Z4 的既有先例(不要求沿用
      同一美術,但要求「常駐於棋盤上,不需要選取或開啟面板才看得到」)
- [ ] 不可通行地形(`passable=false`)有明確的世界層呈現(GDD Tuning Knobs #4——起始三個地形
      種類皆 `passable=true`,故本 story 完成時**可能沒有實際可見的不可通行地形資料**可供
      驗收,見下方 Implementation Notes)
- [ ] 全部新增層須通過灰階複驗(比照 `skill-card-play.md` HP 對比度修復批次的既有紀律)

## Implementation Notes

1. **`battle_controller.gd` 是否已有『查詢單一單位剩餘旗標』的公開方法**——本 story 直接消費
   story-004 的新查詢,不重新設計旗標判斷邏輯。
2. **`battle_screen.gd` 的 `_refresh_view()` 需為每個存活單位查詢其旗標狀態並傳入**
   (`board_view.gd` 新增一層,比照 `StatsLayer` 的作法)——這是本 story 對 `battle_screen.gd`
   的唯一改動,規模輕於 story-014。
3. ⚠️ **未查證,且屬本 story 執行時須誠實面對的落差**:起始關卡資料(`vs01_terrain.txt`)
   三個地形種類皆 `passable=true`(GDD Tuning Knobs #4 起始建議),意即**現有關卡資料裡目前
   沒有任何一格會觸發不可通行地形的呈現**。本 story 仍須實作該呈現邏輯(供未來新增地形時
   立即可用),但驗收測試需要**測試專用**的合成地形資料(依 `.claude/docs/coding-standards.md`
   的測試資料規則,使用 in-test 常數或工廠函式建構含 `passable=false` 格的測試棋盤,不需要
   真實關卡資料檔存在對應地形)。

## Out of Scope

- **單位行動四態 getter 本身**——story-004,本 story 的前置依賴。
- **`passable` 資料層本身**——story-001,本 story 的前置依賴。
- **移動範圍/攻擊範圍疊加圖**——story-014,獨立的另一張 story(可與本 story 同屬 M4 但各自
  獨立驗收)。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。Visual/Feel 型 story,以下為手動驗證步驟。

- **四態持久標記可辨識**
  - Setup: 建構四個單位,分別處於四種行動旗標狀態,不選取任一單位
  - Verify: 每個單位的世界層標記各自可辨識,不需選取或開面板
  - Pass condition: 灰階模式下四態仍可互相區分
- **不可通行地形呈現(測試專用合成資料)**
  - Setup: 使用 in-test 建構的合成棋盤,含至少一格 `passable=false`
  - Verify: 該格有明確的世界層視覺標記,與其他地形種類可區分
  - Pass condition: 灰階模式下該標記仍可辨識

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/action-flag-impassable-terrain-evidence.md`

🔴 **截圖批次化**:與 story-014 相同處置——**不要求逐 story 截圖複核**,累積至 M4(本 story
+ story-014)全部完成後,一次交由管理者在家中桌機複核。理由與方式見 story-014 的
「截圖批次化」節,本節不重述。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001(`passable()`)、story-004(單位行動四態 getter)、
  story-012/013(M5 完成,執行序列化)
- Unlocks: None

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M4,M6(008-011)與 M5(012-013)須先執行完成,本 story 才可開工。
建議與 story-014 同批施工(皆改動 `board_view.gd` 新增圖層),但驗收各自獨立。
