# Story 003:一致率計數器的畫面呈現

> **Epic**: 戰鬥 HUD(僅預判標記)—— `production/epics/battle-hud/EPIC.md`
> **Status**: Ready(2026-10-28 建立)
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **規格權威**: `design/quick-specs/battle-hud-prediction-marker.md` 第 5 節與 AC9、AC11、AC14
> **前置**: `story-001`(✅ Done,`EffectGuessTracker` 已算好一致率)、`story-002`(猜測選擇器接線,2026-10-28 實作完成)

## 為什麼有這張

**管理者 2026-10-28 裁決**,選項逐字:**「今天開一張新工作單接著做(推薦)」**;
被跳過的:併進 story-002 一起做 / 先不做。

成因:規格第 5 節要求「EGM 開啟時,HUD 疊加小型計數器(例如『猜中 6/8』)」,
但 EPIC 的工作單表把 AC9 分給 story-001(純邏輯),story-002 的 AC 清單又沒有列它 ——
**計數已經算好,卻沒有任何工作單負責把它畫出來。** 是 story-002 實作者交件時自己指出的。
這個數字是新手測試驗收協議 80% 門檻要讀的那個值;不顯示,這個功能存在的目的就達不到。

## Acceptance Criteria

- [ ] **AC1 有計數器**:EGM 開啟 → 戰鬥畫面顯示一致率計數器,內容由
      `EffectGuessTracker.get_scored_correct()` / `get_scored_total()` 組成(例如「猜中 6/8」)。
      **不得自行重算** —— 一律讀追蹤器。
- [ ] **AC2 EGM 關閉時不存在**:EGM 關閉 → 計數器不顯示,既有畫面逐字不變(要有測試)。
- [ ] **AC3 即時更新**:一次「已鎖定猜測 + 已確認移動」之後,計數器立即反映新值;
      跳過、取消都不改變它(與規格 AC7 一致)。
- [ ] **AC4 位置與字級**:疊在棋盤上方角落,**不得佔用側邊固定欄位**(畫面架構硬性約束:
      1080p/4K 棋盤旁邊零邊區)。字級**必須**經 `src/ui/battle/hud_layout.gd` 的
      `font_size()`(其內部呼叫 `WorldLayout.compute_scale()`)取得,**不得自行計算或複製公式**。
      位置以 `hud_layout.gd` 新增一支 `*_rect()` 函式提供,比照同檔既有寫法。
- [ ] **AC5 在地化**:所有玩家可見文字走 `assets/data/locales/strings.csv` 的鍵。
- [ ] **AC6 不持久化**:計數器不得出現在任何存檔讀寫路徑(規格 AC14;本專案目前沒有存檔程式,
      這條是「不要新增」的禁令)。

📌 **「可收合」暫不做**:規格寫「可收合」,但目前全專案沒有任何 HUD 收合機制可比照,
做它等於發明新的互動。**本 story 不做收合,留待畫面簽核時由管理者看實際遮擋程度再決定。**
這是協調者的範圍判斷,不是管理者裁決。

## Affected Files

| 檔案 | 預期動作 |
|---|---|
| `src/ui/battle/battle_screen.gd` | 修改(建立並更新計數器 Label) |
| `src/ui/battle/hud_layout.gd` | 修改(新增計數器矩形函式) |
| `assets/data/locales/strings.csv` | 修改(新增計數器文字鍵) |
| `tests/unit/core/i18n/locale_data_integrity_test.gd` | 修改 —— **只改寫死的列數**(每新增一列 +1),比照 2026-10-28 管理者裁決「把 85 改成 95」的處理方式 |
| `tests/integration/ui/battle/...` | 新建 |

🔴 `src/ui/battle/effect_guess_tracker.gd` 不得修改。

## 驗收

- 改 CSV 後一律用 `GODOT_BIN=... bash tools/build/run_tests_with_import.sh`(否則假綠)。
- 畫面(位置、遮擋、字級)要人眼看,留待管理者在家簽核。截圖證據屬 Category C(裁切)。
- 測試須符合 2026-09-16 敏感度證明門檻:每條要嘛有常駐變種證明,要嘛寫下為什麼證明不了。
