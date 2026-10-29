# Story 008:教學關接進遊戲(按「開始」先打教學 4 場,標題另有「略過教學」)

> **Epic**: `production/epics/game-shell/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-29,提交 `5d20edf`;協調者重跑 1653 條全綠)(原狀態:Ready(2026-10-29))
> **Type**: Integration
> **Estimate**: M
> **依據**(管理者裁決逐字):
> - 2026-10-29「**按「開始」先打教學 4 場再進第 1 場;標題另有「略過教學」(推薦)**」(被跳過:標題另加「教學」選項、開始直接進戰役)
> - 2026-10-29「**只讓預覽框的 Φ 數字自然出現,不刻意安排(推薦)**」→ 本 story 不改地圖
> - 2026-10-28「約 10 分鐘,標題畫面可選『略過教學』(推薦)」、「不做,全靠地形與敵人配置引導」(無提示文字)、「都不教,教學關只教五件基本功(推薦)」(無技能卡)
> 設計:`design/quick-specs/tutorial-level.md`。資料:`assets/data/levels/tut0{1..4}_terrain.txt`、`assets/data/units/tut0{1..4}_roster.txt`、`assets/data/affinity/tut04_affinity_links.txt`(10/28 已做、未接線)。

## 為什麼

教學地圖已做好但遊戲裡進不去。**不能插成新的第 1 場**:支援對話依戰役場次編號觸發(`CampaignProgress.current_mission()`),編號一移位對話就錯場。故教學是**獨立序列**。

## Acceptance Criteria

- [ ] **AC1** 標題畫面:「開始」→ 教學第 1 場;新增一列「略過教學」→ 直接進戰役第 1 場(即現行「開始」的行為)。新列字串走 `strings.csv` 新鍵;可用鍵盤/手把/滑鼠操作(與既有列一致)。
- [ ] **AC2** 教學序列 4 場依序:tut01 → tut02 → tut03 → tut04。序列寫成資料檔(建議 `assets/data/levels/tutorial_sequence.txt`,格式比照 `campaign_sequence.txt`,解析**沿用 `CampaignSequence`**,不得另寫第二份解析器)。
- [ ] **AC3** 教學場勝利 → 下一個教學場;第 4 場勝利 → 進戰役第 1 場(等同按「略過教學」)。**不觸發任何支援對話。**
- [ ] **AC4** 教學場戰敗 → 原地重打**同一場**(設計稿第 6 節推薦 B;本 story 以「重載同一場」實作,不做場內檢查點)。不回標題、不影響戰役。
- [ ] **AC5** 🔴 教學全程**不改動**戰役狀態:`CampaignProgress.current_mission()` 不變、戰役好感度累積紀錄(campaign affinity ledger)不寫入。以測試斷言教學前後兩者相同。
- [ ] **AC6** 教學場無技能卡:手牌為空且不報錯(若現行在無卡片檔時會退回 `vs01_cards.txt`,須改為教學場明確給空卡;實作者查證並寫明做法)。tut01~03 無好感度連線檔時,好感度為空且不報錯。
- [ ] **AC7** 教學場的結果畫面(story-025 遮罩)照常顯示;「戰役完成」文字不得在教學第 4 場出現。
- [ ] **AC8** 每個教學場能實際載入並開打:比照 game-shell story-007 的「五場引擎載入測試」,4 場各一條(載入真實 `BattleScreen.tscn`,`instantiate()` → 設 override → `call_deferred("add_child")` → 等幀;見 technical-preferences「第 5 點」的兩個實作坑)。
- [ ] 敏感度證明:AC3(第 4 場後應進戰役)與 AC5(戰役狀態不變)各一條。

## 不在範圍

教學 S5 小考(等數值,設計稿 Q3)、提示文字、場面級檢查點、「已看過教學」記憶(無存檔系統)、地圖修改。

## Affected Files

`src/ui/shell/title_screen.gd`、`src/ui/shell/TitleScreen.tscn`、`src/ui/shell/scene_router.gd`、`src/ui/battle/battle_screen.gd`(只動「結果後去哪」與資料路徑選擇的分支)、可新增 `src/core/campaign/tutorial_progress.gd`(若需要教學進度狀態)、`assets/data/levels/tutorial_sequence.txt`(新)、教學空卡資料檔(若需要,新)、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、新測試檔;斷言標題列數/「開始」行為的既有測試(逐一列在回報)。
