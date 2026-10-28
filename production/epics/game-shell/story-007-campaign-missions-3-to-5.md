# Story 007:戰役序列接上第 3~5 場

> **Epic**: `production/epics/game-shell/EPIC.md`
> **Status**: Ready(2026-10-28;關卡資料 15 檔已交件,協調者驗過地形尺寸、座標不重疊不出界、數值與 vs02 相同)
> **Type**: Integration
> **依據**: 管理者 2026-10-28 裁決,選項逐字「**做第 3~5 場關卡資料(推薦)**」;被跳過:關係圖迷你地圖 / 教學關。
> **前置**: level-designer 新增的 `assets/data/*/vs03_*` ~ `vs05_*` 共 15 檔。

## 為什麼

`assets/data/levels/campaign_sequence.txt` 只有 2 列,打完第 2 場即「戰役完成」,
支援對話 SC-02(第 2 場後)與 SC-03(第 3 場後)在正式遊玩中**播不到**。

## Acceptance Criteria

- [ ] **AC1** 序列表補上第 3、4、5 列,指向 vs03~vs05 的五個檔(含 `card_text_path` 第 6 欄)。更新序列表檔頭註解(比照該檔 2026-10-27 那段的寫法,原文保留)。
- [ ] **AC2** `tests/unit/gameplay/campaign/campaign_sequence_test.gd` 寫死的 `has_size(2)`(兩處)改為 5,並在旁加註原因。其餘斷言不放寬。
- [ ] **AC3 每一場都真的載得起來**:新增一條測試,對序列表**每一列**用真實 `BattleScreen.tscn`(經 `*_path_override` 注入)進樹,斷言 `_ready()` 後沒有任何資料載入失敗(`diagnostic_resolved_data_paths()` 等既有診斷,grep 既有載入失敗測試的觀察法),棋盤與雙方單位數正確。讀真實資料檔屬甲類例外,檔頭聲明。
- [ ] **AC4 對話可達**:第 2 場勝利 → 對話畫面 `["SC-02"]`;第 3 場勝利 → `["SC-03"]`;第 4 場勝利 → 不出現對話、直接進第 5 場;第 5 場勝利 → 「戰役完成」並回標題。可沿用 `tests/integration/ui/shell/support_conversation_transition_flow_test.gd` 的寫法(該檔 AC2 目前是手動清空播放清單模擬第 4 場,**改為真實第 4 場**並在註解說明)。
- [ ] 敏感度證明門檻。

## Affected Files

`assets/data/levels/campaign_sequence.txt`、`tests/unit/gameplay/campaign/campaign_sequence_test.gd`、`tests/integration/ui/shell/support_conversation_transition_flow_test.gd`、`tests/integration/ui/shell/...`(新)。
**正式程式碼預期零改動**;若需要改,停下回報。
