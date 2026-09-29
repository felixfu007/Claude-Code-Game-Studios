# Story 008: AC-PERF 效能基準建立(M5)

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready
> **Layer**: Gameplay(控制清單「核心層規則(Core)」涵蓋範圍)
> **Type**: Logic
> **Estimate**: S(0.5～1 session)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`(Acceptance Criteria 節,ADVISORY 段)
**需求**: AC-PERF——「GIVEN vs01 同規模合成資料,WHEN 連續 1000 次查詢取平均,THEN
較上一版基準劣化 ≤ 20%(相對回歸門檻,非絕對毫秒——避免 CI 環境雜訊誤判)」。
**TR-ID**: ⚠️ 本系統(#5)尚未登記進 `tr-registry.yaml`。

**Governing ADR**: `ADR: N/A`——效能基準本身不是架構決策,是量測與紀律問題。

**Engine**: Godot 4.7.1 | **Risk**: LOW

**Engine Notes**: 無 post-cutoff 風險——純 headless 可測的計算效能,不涉及渲染管線,
不落入 `.claude/docs/coding-standards.md` 記載的「像素量測只能開窗」那類限制。

**Control Manifest Rules(此層)**: Performance guardrail 摘自控制清單:
「好感度讀取為熱路徑,`AffinityTypes.is_valid_*()` 與內部讀快取檢查的語意必須完全相同」
——本 story 的基準應該涵蓋完整的查詢路徑(含 story-005 完成後的池查詢,若已完成),
不能只量測本系統自己內部的計算,漏掉跨系統呼叫的開銷。

---

## 🔴 這條 AC 今天做不成,因為沒有基準可比——本 story 的產出就是那條基準本身

AC-PERF 的判準是「較**上一版基準**劣化 ≤ 20%」,而 EPIC.md 明文指出**今天沒有這個基準**。
**本 story 第一次執行時,產出的數字本身就是基準,不是「通過」或「失敗」**——比照
`.claude/docs/coding-standards.md` 對「沒有可測對象要寫 N/A、不得寫通過」的紀律
(EPIC.md 風險 R-5 已明確引用這條紀律做類比):第一次執行不是驗證回歸,是建立起點。

## Acceptance Criteria

- [ ] 建立一個可重複執行的效能量測(建議寫成一支 GdUnit4 測試或獨立的 headless 量測腳本,
  由實作者依專案既有慣例判斷),對 vs01 同規模合成資料連續執行 1000 次 `Φ` 查詢,
  記錄平均耗時。
- [ ] 量測結果**寫入一個進版控的基準檔案**(而非只印在 CI log 裡消失),供未來的
  回歸比對讀取——具體格式由實作者決定,但必須包含:量測日期、當時的
  `combat_state_version`/程式碼版本(或 commit hash)、平均耗時數字、量測方法簡述
  (含「連續 1000 次」的資料規模與查詢種類)。
- [ ] **本次執行結果不判定「通過」或「失敗」**——文件與提交訊息應明確標註「建立基準」,
  不是「效能驗證通過」,避免下一個讀報告的人誤以為這代表已經驗證過回歸門檻。
- [ ] ⚠️ **若本 story 排在 story-005(M2)之前完成**:本次基準量測的是**遷移前**
  (讀靜態檔)的效能特性,不是遷移後(逐次查詢資料池)的效能特性——GDD 明文警告
  「呼叫頻率為輸入事件級,非每回合一次」,而遷移後每次查詢會多一次跨系統呼叫
  (`combat_strength_read()`),**遷移前的基準不能直接拿來當作遷移後的回歸比較對象**。
  建議做法(留給實作者判斷,本 story 不強制排程順序):若 story-005 尚未完成,本次
  建立的基準應明確標註「遷移前(讀靜態檔)基準」;待 story-005 完成後應**再量一次**
  並標註為「遷移後(逐次查詢)基準」,取代前者作為未來回歸比對的權威版本。

## Implementation Notes

- 合成資料規模:GDD 提到「vs01 同規模」,建議直接使用
  `assets/data/units/vs01_roster.txt` 與(遷移前)`assets/data/affinity/vs01_affinity_links.txt`
  或(遷移後)story-004/005 建立的池查詢路徑作為量測輸入,不要另外發明一組資料規模。
- 查詢種類:GDD Interactions ② 明文查詢觸發點是「游標移動即觸發預覽」,故量測應包含
  **預覽查詢**這個路徑(`bonus_for_at()` / `positions_with()` 那條,而非只測
  `bonus_for()` 的實際站位查詢),因為這是實際遊玩中最高頻的呼叫路徑。
- 量測方式建議使用引擎的 `Time.get_ticks_usec()` 或等價的 headless 可執行計時方式,
  避免依賴任何需要開窗渲染的計時機制(參照
  `.claude/docs/coding-standards.md` 對 headless 限制的既有記載,雖然那些限制主要針對
  像素量測,但計時仍應確認選用的 API 在 headless 下行為正常)。
- ⚠️ **未查證**:本 story 撰寫時沒有查證專案內是否已有其他系統的效能基準檔案格式可以
  沿用(例如是否已有 `production/qa/` 底下的效能基準前例)。**下一個人從
  `production/qa/` 目錄查起,若已有慣例格式,優先沿用,不要另創一套。**

## Out of Scope

- AC-FEEL(人工試玩校準,ADVISORY,依 OQ-2 待基礎數值校準,不在本 epic 範圍)。
- story-007(結構紀律守衛)——雖同屬 M5,驗收條件完全獨立。
- 效能不合格時的優化——本 story 只建立基準,不承諾也不要求任何效能改善工作;
  若量測結果顯示明顯的效能疑慮,應回報而非在本 story 內自行優化(避免範圍蔓延)。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生:*

- **基準建立**:
  - Given: vs01 同規模合成資料,1000 次連續查詢
  - When: 執行量測
  - Then: 產出一筆記錄在進版控檔案裡的平均耗時數字,標註為基準而非通過/失敗判定
- **未來回歸比對**(本 story 不執行,留給下一次效能變更時使用):
  - Given: 本 story 建立的基準
  - When: 未來任何觸及 `Φ` 查詢路徑的變更完成後重新量測
  - Then: 劣化 ≤ 20% 視為通過,> 20% 視為需要調查的回歸

## Test Evidence

**Story Type**: Logic
**Required evidence**: 一份進版控的基準檔案(格式由實作者決定),含平均耗時、量測日期、
程式碼版本標記。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(可獨立執行,但見上方 Acceptance Criteria 對「遷移前 vs 遷移後基準」
  的排程建議——若能在 story-005 之後執行,基準的參考價值更高)。
- Unlocks: None
