# Story 023:營火接口預留 — 卡牌效果值外部覆寫的載入端 seam(只預留,不設計營火)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Deferred(管理者 2026-11-17:本批不做;依據答案檔題 12)—— 011 的 `effect_value` 維持由建構者/載入器傳入、不寫死,營火批再追加覆寫入口(追加式小改)。原:依賴 011;且範圍待確認:規格 v1.0 第 4.4/4.5 節的營火卡強度公式屬營火部分,不在本批;本單只保留「讓外部給一張卡覆寫 `effect_value`」的 seam。
> **Type**: Logic
> **Estimate**: S(0.5~1 天,粗估未驗證;data-format S8)
> **依據**:`docs/reviews/card-rework-data-format-2026-11-12.md` S8(「規格 6-5 效果值外部覆寫的載入端 seam」,規格 v0.3 第 6 節,本單撰寫者未讀);規格 v1.0 第 4.4(營火產卡快照、`source=CAMP`)。

## 派工前須先決定

1. **是否現在做**:營火整段延到 2027-01-22、不在本批。若協調者判定「本批不做 seam」→ 本單撤銷。
   - **已決:本批不做**(管理者 2026-11-17 裁決「023 本批不做」;設計角度本批不必要,答案檔題 12)。本單保留為 Deferred,不撤檔,營火批啟動時重新排程。工程上無此 seam 也不阻擋 010~022。
2. seam 形狀:以建構期參數覆寫 `effect_value`(`Card` 為純值型別,不可事後改)還是產卡時另建新 `Card`?**lead-programmer 在 011 完成後決定**,不阻擋。

## 規則

- `Card` 仍為不可變值型別;seam = 工廠接受 `effect_value` 與 `source` 外部值(011 已有欄位,工廠預設值尾端參數)。**本單不新增載入器、不新增存檔欄位**(規格 7 節:存檔無變更)。
- 不實作營火入口、不寫池。

## Acceptance Criteria

- [ ] **AC1** 以工廠建立 `source=CAMP`、外部 `effect_value` 的卡,打出時使用該值(與 BASE 卡同路徑結算)。
- [ ] **AC2** 外部值不在合法範圍(負數)被拒(沿用 011 值域規則),`push_error` + 明確失敗值。
- [ ] **AC3** `BASE` 卡行為不變(回歸)。
- [ ] **AC4** 不新增存檔欄位:`grep -rn "Card\|deck" src/gameplay/save --include=*.gd | grep -v "^\S*:[0-9]*:\s*#"` 回報原始輸出,對照改動前後相同(路徑 `src/gameplay/save` 為暫定,**實作者當場確認存檔目錄**)。
- [ ] **AC5 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①覆寫被忽略(用卡表值)→ AC1 紅 ②負數被接受 → AC2 紅 ③BASE 卡也吃覆寫 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火入口、營火畫面、營火卡強度公式、牌組編輯與「一輪記憶」。**本單不依賴牌組記憶。**

## Affected Files

- `src/gameplay/cards/card.gd`(工廠)、新測試 `tests/unit/gameplay/cards/card_effect_value_override_test.gd`

超出此清單先問。

## 與其他工單的順序

- **依賴 011**;可延後,不阻擋 12/11 檢查點。
