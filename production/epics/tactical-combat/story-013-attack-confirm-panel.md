# Story 013: 攻擊確認面板(二段確認,`_confirm_at_cursor()` 拆段)

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

## 🔴 阻擋條件(執行前必須確認)

同 story-012:`localization-infrastructure` Story 001 必須先完成並可用
(`grep -rn "tr(\|TranslationServer" src/` 非零命中)方可開工。

## Context

**GDD**: UI Requirements §4(攻擊確認與傷害拆解面板)、UI Requirements §5(預判模式的 UI
生命週期,與確認面板不得共用元件)、Visual/Audio §2(傷害回饋須拆解 `Φ` 貢獻)。

**UX 規格**(`design/ux/tactical-combat-screen.md` 5.3(a)、7.3):「現況:`_confirm_at_cursor()`
直接呼叫 `_controller.click_tile(_cursor_cell)`,而 `click_tile()` 一旦判定目標在
`_attack_targets_for()` 內,**同一次呼叫內直接執行 `_apply_attack()`**——兩者之間沒有任何
面板或第二次確認」。

**這是本 epic 唯一一項改變既有互動語意的工作**(EPIC.md M5 節原文)。

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 面板開啟期間(T2' 狀態)為
零寫入,`combat_state_version` 不得因面板開關本身遞增(控制清單:「唯讀操作一律不得使其
遞增:游標移動、開關疊加圖、預判標記、單位選取/取消選取」——本面板開啟屬同類唯讀操作)。
`ADR-0005`(**Accepted**)—— 確認去重與 `_process(priority=100)` 讀取時機。

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM(涉及既有結算路徑的呼叫時機改動,需仔細驗證
不破壞 ADR-0001 的原子性契約)

## Acceptance Criteria

- [ ] 新增攻擊確認面板(模態,比照 `card_confirm_panel.gd` 既有模式,**不得沿用同一元件**——
      `P-M2`「預判/確認元件不得共用」原則同樣適用於攻擊路徑)
- [ ] 欄位:`ATK`(攻擊方有效攻擊力)、`DEF`(目標有效防禦力)、`Φ`(帶號,`=0` 仍顯示)、
      結果傷害、目標結算後預估 HP(依 story-006 的拆解查詢)
- [ ] **確認鍵在此面板上變成第二次動作**:第一次選定目標鍵入確認 → 開啟本面板(**零寫入**);
      面板上再次確認 → 執行 `click_tile()` 對應的攻擊路徑(**權威寫入**)
- [ ] **移動維持單鍵直接執行,不加面板**——UX 規格 7.2 已明文判定,本 story **不得**「順手
      也給移動加一個」面板
- [ ] 面板開啟期間(T2'),游標移動/開手牌/開選單皆須被拒絕(比照 `card_confirm_panel` 開啟
      期間的既有模式)
- [ ] 面板開啟期間發生的一切操作**零寫入**;僅面板上「再次確認」觸發 `_apply_attack()` 的
      實際結算
- [ ] 取消(步驟 2 或 3)回上一步且零寫入(比照 `P-N3`)
- [ ] **裁定狀態讀取發生在 `_process(priority=100)`**,不在按鍵處理常式內讀(比照
      `skill-card-play.md` 既有義務,避免讀到上一幀值)
- [ ] **同幀鍵盤+手把各送一次確認的去重保護**(不得提交兩次攻擊)
- [ ] **本 story 新增的面板文字一律透過 key 查找**,零新增裸字串常數
- [ ] **不影響 `battle_controller.gd` 的公開介面**——`click_tile()`/`_apply_attack()` 的執行
      語意不變,改動只在 UI 層何時呼叫它(UX 規格明文)

## Implementation Notes

1. **具體拆段方式**:`_confirm_at_cursor()`(`battle_screen.gd:2285`)需要拆成「開面板」與
   「面板上再次確認才呼叫 `click_tile()`」兩段,比照既有卡牌確認的
   `_open_card_confirm_panel()` / `_apply_pending_card_confirm()` 兩段式寫法(UX 規格明文
   指出此既有先例可直接參照)。
2. **U-T1(是否需要拆 `click_tile()`/`_apply_attack()` 本身)已由 UX 規格定案**:「本規格只
   定案『必須有二段確認』,不定案 `battle_controller.gd` 是否要改公開介面——那是 M5 的第一張
   story 要決定的事」。本 story **建議維持 `battle_controller.gd` 公開介面不變**,拆段只發生
   在 UI 層(`battle_screen.gd`),因為 UX 規格明文「不影響 `battle_controller.gd` 的公開介面」
   已是傾向性判斷,但介面形狀的最終決定權在本 story。
3. **焦點順序**(UX 規格 12 節):確認鍵預設應落在「確認執行」而非「取消」——這與 `P-M4`
   (破壞性動作確認,預設焦點在取消)**不同**,理由是攻擊在盤面上早已被三態高亮與傷害預覽
   揭露過後果,第二次確認是「拆解後再看一眼」而非「你可能誤觸的破壞性動作」。UX 規格明文
   此為其自身判斷,待面板落地時由 `/ux-review` 覆核。
4. **`Φ` 上界風險傳導**(UX 規格明文):`Φ` 目前無上界,數值欄寬須能容納非預期大數值而不
   截斷、不溢位、不改變版面。

## Out of Scope

- **預判模式的獨立設計**(是否需要獨立於本面板另外設計,U-T9)——待本面板落地後由
  `ux-designer` + `game-designer` 一併決定,不在本 story 範圍先行假設答案。
- **移動確認面板**——UX 規格明文移動不加面板,不得擴大範圍。
- **`ATK`/`DEF`/`Φ` 拆解查詢本身**——story-006,本 story 的前置依賴。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **二段確認零寫入(第一次)**
  - Setup: 玩家選定攻擊目標,按下確認鍵
  - Verify: 攻擊確認面板開啟,盤面/HP/好感度數值池狀態不變
  - Pass condition: 面板顯示 `ATK`/`DEF`/`Φ`/結果傷害/預估 HP 五欄位,無任何寫入發生
- **二段確認權威寫入(第二次)**
  - Setup: 承上,玩家在面板上再次按下確認鍵
  - Verify: `_apply_attack()` 被呼叫,傷害套用
  - Pass condition: 結算結果與拆解查詢顯示的預覽數字一致
- **取消回上一步零寫入**
  - Setup: 面板開啟後,玩家按取消鍵
  - Verify: 回到 T2(攻擊目標可視狀態),無寫入發生
- **面板開啟期間操作被拒絕**
  - Setup: 面板開啟期間,玩家嘗試移動游標/開手牌/開選單
  - Verify: 上述操作皆被拒絕
- **同幀去重**
  - Setup: 同一幀內鍵盤與手把各送一次確認鍵事件
  - Verify: 只提交一次攻擊,不得提交兩次
- **`Φ=0` 仍顯示**
  - Setup: `Φ=0` 的攻擊情境
  - Verify: 面板明確顯示 `Φ: 0`,不隱藏該欄位
- **零裸字串常數**
  - Setup: 檢視本 story 新增原始碼
  - Verify: `grep -n "^const.*String = \"" [本 story 新增檔案]`
  - Pass condition: 零命中

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/attack-confirm-panel-evidence.md` + 互動測試
(`tests/integration/ui/attack_confirm_panel_test.gd`,涵蓋零寫入/去重等可自動化部分)

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-006(`ATK`/`DEF`/`Φ` 拆解查詢)、story-008~011(M6 全部完成,執行序列化)、
  `localization-infrastructure` Story 001(開工前置條件)
- Unlocks: None

## 執行層序列化(M6 → M5 → M4)

本 story 屬 M5,M6(008-011)須先執行完成,本 story 才可開工;完成後才輪到 M4(014-015)。
