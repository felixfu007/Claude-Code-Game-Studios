# Story 012: 格位資訊面板

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M5
> **Status**: Ready(2026-10-05 解除封鎖 —— 本地化 Story 001 已 Complete,見下方註)
> ✅ **2026-10-05 解除封鎖。** 本行原文逐字為:
> `> **Status**: Blocked(見下方「阻擋條件」——本地化 Story 001 尚未完成)`
> **解除依據**:本地化 Story 001 的 A~E 五節全部完成並標 `Complete`
> (`production/epics/localization-infrastructure/story-001-core-lookup-api-and-locale-structure.md`
> 的檔頭完成註記),含 E 節在 production 匯出建置上的實機量測(`zh_TW` 四項全中)。
> 🔴 **注意本檔下方「阻擋條件」節的檢查方式是單向的** —— 它逐字寫「**若仍為零命中**,
> 本地化 Story 001 尚未完成」。零命中代表沒完成,**非零命中不代表完成**。
> 本次解除**不是**只憑那條 grep(現為 12 命中),而是憑 E 節 BLOCKING 項已關閉。
> ⚠️ **本 story 的 Dependencies 節所列的其他前置(004/006/008-011)仍未完成** ——
> 與本專案慣例一致:依賴未滿足標 `Ready` 不標 `Blocked`,但**實際動工前仍須確認那些已 Done**。
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## 🔴 阻擋條件(執行前必須確認,不只是規劃前)

**本 story 的開工(非規劃)前提**:`production/epics/localization-infrastructure/EPIC.md`
Story 001(核心 key 查找 API + locale 檔案結構)必須先完成並可用。理由(該 epic 原文,不重述
推導只摘錄結論):「M5 要做兩個新面板(格位資訊面板、攻擊二段確認面板),兩者都有文字。
若本地化晚一步,那些文字會先寫死、再回頭改一次」。

**檢查方式(可執行)**:
```bash
grep -rn "tr(\|TranslationServer" src/ --include=*.gd
```
若仍為零命中,本地化 Story 001 尚未完成,本 story **不得開工**(規劃/切 story 本身不受影響,
已完成)。

## Context

**GDD**: UI Requirements §1(格位資訊面板最小必要欄位)、UI Requirements §1a(敵方威脅範圍
疊加圖,面板欄位需求的一部分)、Visual/Audio §1.4(地形成本與遮蔽須分欄呈現,不得合併)。

**Requirement**: `TR-tactical-002`(地形正交屬性,現行文字待更正——見 story-001 同一保險條款)

**UX 規格**(`design/ux/tactical-combat-screen.md` 5.3(b)):「現況:`_info_label` 只在三種
情境顯示三選一的字串(好感度預覽/好感度現值/傷害預覽),**從未顯示**地形種類、`terrain_cost`、
遮蔽旗標、佔位單位的陣營/HP/當前行動旗標狀態、武器分層 `(min_range,max_range)`、或當前 MP。
……這是本畫面目前最大的 GDD 未涵蓋項」。

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 面板更新前須查詢有效性旗標
(見下),讀取的查詢須遵守即時性義務(AC-22(a))。`ADR-0005`(**Accepted**)—— 面板更新前須
查詢 `CursorStateHost` 的有效性旗標,旗標無效時走 `P-F1` 未解析態。

**Engine**: Godot 4.7.1 | **Risk**: LOW

**Control Manifest / 專案級紀律**:
- **本地化**:新增面板文字一律透過 key 查找,**零新增 `const \w+: String = "..."` 型式的
  裸字串常數**(`localization-infrastructure` epic Story 001 明文要求 M5 story 寫入此驗收
  條件,非本 story 自創)
- **`_process(priority=100)` 讀取時機**:裁定狀態(有效性旗標)必須在 `_process(priority=100)`
  讀,不得在按鍵處理常式內讀(否則讀到上一幀值,`design/ux/skill-card-play.md` 已記載過同一
  錯誤,本 story 須避免重演)

## Acceptance Criteria

*依 GDD UI Requirements §1,不引用 `TR-tactical-002` 現行文字(保險條款,見上方阻擋條件節
之外的 C5 事實,已於 story-001 記載):*

- [ ] 面板隨游標所在格**即時更新**,不得要求額外確認鍵,不得只在滑鼠懸停時出現(`P-I2`/
      無 hover-only 禁令)
- [ ] 最小必要欄位全部呈現:**地形種類**、**`terrain_cost`**、**是否標記遮蔽**、**佔位單位**
      (若有)之**陣營/HP/當前行動旗標狀態**(四態,依 story-004 的 getter)、**武器分層與
      `(min_range,max_range)`**、**當前 MP**
- [ ] `terrain_cost` 與遮蔽標記**必須分欄呈現**,不得合併為單一「特殊地形」欄位(Visual/Audio
      §1.4 正交性要求)
- [ ] 「當前狀態」不得只顯示二元狀態——依 story-004 的四態 getter,分辨「皆未用/只剩攻擊/
      只剩移動/已行動」
- [ ] 面板更新前查詢 `CursorStateHost` 的有效性旗標;旗標無效時呈現明確的**未解析態**,
      不得沿用上一格的殘留內容(Player Fantasy 具名失敗模式「狀態轉換造成的資訊斷裂」)
- [ ] **本 story 新增的面板文字一律透過 key 查找**,零新增裸字串常數(本地化紀律)
- [ ] 裁定狀態讀取發生在 `_process(priority=100)`,不在按鍵處理常式內讀

## Implementation Notes

1. **現況 `_info_label` 是三選一窄版摘要,不是本 story 要求的通用格位面板**——UX 規格明確
   判定兩者不同。本 story 建議新增獨立元件(比照 `card_confirm_panel.gd` 的既有模式,而非
   擴充 `_info_label` 承載更多欄位),但具體是否重用/擴充現有元件屬本 story 判斷。
2. ⚠️ **未查證**:`_info_label`/`StatusLabel` 各自呼叫的確切 rect 函式名稱——UX 規格明文
   「本規格未逐一核對,下一個實作故事應直接讀 `battle_screen.gd` 的 `_ready()`/`_apply_layout()`
   確認現有錨點,不在此重述座標」。本 story 須直接讀該函式取得現有錨點慣例,不得憑空另創
   一套座標系統。
3. **`HudLayout` 已確認存在的錨點函式**(UX 規格已附證據,`grep -n "^static func" src/ui/battle/hud_layout.gd`):
   `font_size(window_size)`、`safe_rect(window_size)`、`controls_hint_bg_rect(window_size)`。
   新面板的字級須呼叫 `font_size()`,**不得自行計算或複製公式**
   (`.claude/docs/technical-preferences.md`「HUD 字級所需的倍率 N 必須呼叫
   `world_layout.gd` 的 `compute_scale()` 取得,不得自行計算」——同一紀律適用於任何新增的
   世界層/介面層座標運算)。
4. **武器分層欄位的資料來源**:依賴 story-006 的基準值/有效值存取層(或現有 `Unit` 資料結構,
   視 story-006 完成進度而定)。⚠️ **未查證**:若 story-006 尚未完成,本 story 是否有替代
   資料源可讀武器 `(min_range, max_range)`——現有戰鬥系統應已有武器資料表可直接查詢(不需要
   等待 story-006 的拆解查詢,那是給傷害預覽用的,武器射程本身應為既有的 `Unit`/武器資料
   欄位)。下一個人應先確認武器射程資料是否已可獨立於 story-006 讀取。

## Out of Scope

- **回合層級剩餘旗標總覽**(`P-D4`)——歸屬 #10 戰鬥 HUD。
- **敵方威脅範圍疊加圖的繪製**——story-014(M4)。
- **未解析態與「無資訊可顯示」的區分細節**(U-T3)——UX 規格明文列為 Open Question,待
  `ux-designer` 設計,本 story 只需實作「明確的未解析態」這個最低要求,不需解決 U-T3 的
  完整區分規則。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **即時更新**
  - Setup: 玩家將游標移到不同格
  - Verify: 面板內容隨游標移動立即更新,不需額外確認鍵
  - Pass condition: 每次游標移動後面板顯示對應格的正確資訊
- **最小欄位完整性**
  - Setup: 游標停在一個有佔位單位的格
  - Verify: 面板同時顯示地形種類、`terrain_cost`、遮蔽旗標、單位陣營/HP/四態狀態、武器分層、
    當前 MP
  - Pass condition: 六類欄位全部可見且分欄呈現(`terrain_cost` 與遮蔽不合併)
- **未解析態**
  - Setup: 游標目標的有效性旗標被標記為無效(例如目標剛陣亡)
  - Verify: 面板呈現明確未解析態,不顯示上一格殘留內容
  - Pass condition: 未解析態與正常內容視覺上可區分
- **零裸字串常數**
  - Setup: 檢視本 story 新增的原始碼
  - Verify: `grep -n "^const.*String = \"" [本 story 新增檔案]`
  - Pass condition: 零命中(全部文字走 key 查找)

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/tile-info-panel-evidence.md`(依 Category A/B/C
分類,人工複核)+ 手動走查文件

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-004(單位行動四態 getter)、story-006(部分——武器/傷害相關欄位,若
  存取層未完成需另尋既有資料源,見 Implementation Notes)、story-008~011(M6 全部完成,
  執行序列化)、`localization-infrastructure` Story 001(**開工前置條件,非規劃前置條件**)
- Unlocks: None(面板為終端消費者)

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M5,**M6(008-011)須先執行完成**,本 story 才可開工;本 story 完成後才輪到
M4(014-015)。三者共用 `src/ui/battle/battle_screen.gd`,不得並行施工。
