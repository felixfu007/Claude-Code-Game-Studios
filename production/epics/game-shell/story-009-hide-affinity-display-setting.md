# Story 009:設定畫面加「隱藏好感度顯示」(驗收協議 2 忽視組用)

> **Epic**: `production/epics/game-shell/EPIC.md`
> **Status**: ✅ Done-pending-visual(2026-10-30;協調者重跑 1672 條全綠 / ENGINE EXIT 0)(原狀態:Ready(2026-10-30))
> ⚠️ 實作者查出 AC3 未涵蓋的洩漏(協調者寫單疏漏):左下資訊列「好感度 +a→+b / +n」、卡牌確認面板「好感度:」、預判模式整組 —— 開啟本設定時仍顯示。待管理者裁決是否補隱藏(真人測試已降為補充證據)
> **Type**: Integration
> **Estimate**: S
> **依據**(管理者裁決逐字,2026-10-30):
> - 「先定門檻,再用電腦跑對照(推薦)」
> - 「兩件都做(推薦)」—— ①遊戲加一個「隱藏好感度顯示」的設定(給不管組用)②電腦代打新增真正不看好感度的打法
> - 「電腦為正式,之後有人再補(推薦)」—— **本設定服務的是「之後有人再補」那一段真人測試**,不是正式判定
> 背景:`docs/reviews/protocol2-threshold-proposal-2026-10-30.md` 第 1 節(忽視組「不顯示好感度連線/Φ 預覽」)。

## 為什麼

驗收協議 2 的真人「忽視組」須在**看不到好感度資訊**的版本上玩。現行遊戲沒有這個開關(提案自標未查證,協調者 grep `src/core/settings/game_settings.gd` 只見預判模式一個設定)。

## Acceptance Criteria

- [ ] **AC1** `GameSettings` 新增一個設定「隱藏好感度顯示」,**預設關閉**(預設 = 現行行為,一個畫素都不變)。寫法比照既有 `_egm_enabled`(static var + getter/setter + `reset_for_test()` 一併重設)。
- [ ] **AC2** 設定畫面新增一列切換此設定;字串走 `strings.csv` 新鍵;鍵盤/手把/滑鼠皆可操作(與既有列一致)。
- [ ] **AC3** 開啟時,戰鬥畫面**不顯示**:①棋盤上的好感度連線 ②關係圖迷你地圖(含開啟它的按鍵/按鈕無效或隱藏,擇一並寫明)③右上資訊框傷害拆解中的好感度修正那一項(傷害總數**照常**顯示,且**數值不變** —— 好感度仍然在算,只是不顯示)。
- [ ] **AC4** 🔴 開啟時**戰鬥結算一個數字都不能變**。以測試斷言:同一場同一組動作,開/關此設定的扣血結果相同。
- [ ] **AC5** 每一項 AC3 的隱藏各一條測試,並至少一條敏感度證明(故意讓其中一項不隱藏 → 測試變紅 → 還原)。

## 實作者須查證並在回報中寫明(不要自己決定,寫明現況即可)

- 手牌中的**好感度對話卡牌**、**預判模式**選擇器,本身就在呈現好感度。本 story **不動它們**;請列出它們在開啟設定時仍會顯示什麼,交協調者轉呈管理者。

## 不在範圍

卡牌與預判模式的處理(見上)、設定持久化(無存檔系統)、電腦代打打法(另派 ai-programmer)。

## Affected Files

`src/core/settings/game_settings.gd`、`src/ui/shell/settings_screen.gd`、`src/ui/shell/SettingsScreen.tscn`、`src/ui/battle/board_view.gd`(只動連線顯示分支)、`src/ui/battle/relation_minimap.gd`、`src/ui/battle/battle_screen.gd`(只動迷你地圖開啟與資訊框拆解列的分支)、`src/ui/battle/hud_layout.gd`(若資訊框拆解列在此)、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、新測試檔;斷言設定畫面列數的既有測試(逐一列在回報)。
