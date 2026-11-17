# Story 024:既有好感度測試中「固定兩對」假設的盤點與改寫

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 依賴 013、014(行為改後才知道哪些斷言失效);兩者仍 Blocked,等 `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B)。
> **Type**: Logic(測試重構)
> **Estimate**: M(1~2 天,粗估未驗證;排程 N9「改幾支未量」)
> **依據**:排程 `docs/reviews/card-campfire-schedule-v1-2026-11-12.md` N9;規格 v1.0 第 0 節被推翻前提 1、2(「只有 2 對有關係」)。受影響測試清單**本單撰寫者未量**。

## 派工前須先決定

**無**(013/014 完成後由實作者盤點;若盤點結果超過 15 支測試 → 回報協調者重新估)。

## 規則

- 先**盤點**(列表:測試檔、受影響斷言、失效原因),再改。**不得刪斷言換綠**;每條改寫保留原本要保護的性質,只換掉「只有 2 對」的假設。
- 順帶:新增至少 1 條涵蓋「非人設配對、含麥子健配對」的對照斷言(規格驗收 (2))。

## Acceptance Criteria

- [ ] **AC1 盤點表**:回報附完整表,涵蓋指令 `grep -rln "affinity" tests --include=*.gd` 的每一檔(原始輸出貼出),每檔標「受影響/不受影響」。
- [ ] **AC2 逐條改寫說明**:每條被改的斷言附「原本保護什麼性質 / 改後仍保護」。
- [ ] **AC3 無新豁免**:測試總數不減少(貼改動前後 `Overall Summary`)。
- [ ] **AC4 敏感度證明**:每條**改過的**關鍵斷言至少有一個常駐 `test_sensitivity_proof_*` 證明它仍會因違反原性質而紅(列出 mutant 清單,一個 mutant 一次獨立執行)。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## Affected Files

- `tests/**/affinity*`(盤點後逐檔列於回報;超出先問)

## 與其他工單的順序

- **依賴 013、014**;不阻擋 015~019。
