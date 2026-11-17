# Story 022:資料遷移 — 14 張卡牌表 + 牌面文字 + id 一致性測試擴成 5 關

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Blocked —— 依賴 011、015、017、018、019;卡在卡 id 命名與 10A-1(牌面敘事,預設甲案中性改名)、D4(舊 6 張甲類去留)。
> **Type**: Config/Data + Logic(一致性測試)
> **Estimate**: M(1~1.5 天,粗估未驗證;data-format S7)
> **依據**:規格 v1.0 第 6.2(c11/c14 敘事前提;**預設採甲案中性改名**)、v0.3 第 4 節 14 張卡池;data-format 2.7、2.5(5 份牌表逐列相同:資料列 vs02~05 與 vs01 相同,2026-11-12 量);`tests/integration/gameplay/cards/card_table_id_consistency_test.gd` 目前只檢 vs01。**5 份 `vsNN_cards.txt` 是否仍逐列相同 2026-11-17 未重驗**,實作者第一步 `diff` 資料列。

## 派工前須先決定

1. **卡 id 命名**(同 011 第 2 題):`c01`/`card_01`。
2. **10A-1**(管理者待決):預設甲案;裁決前以甲案不阻擋實作,但**牌名/牌面文字由 `narrative-director`/`writer` 提供,不由工程師自擬**。
3. **D4 舊 6 張甲類去留**:退役則寫死 `card_0N` 的 4 個測試檔(data-format 2.7 稱 4 檔)須改指向保留 id 或內嵌字面值;保留則 14 張為新增。
4. 教學場 `tutorial_cards.txt`:規格 6.1「教學場沿用既有牌表」→ **不動**,但須確認 011 的集合式欄數對舊 8~10 欄列仍合法(AC 內含)。

## 規則

- 資料檔一律 `.txt`(不得 `.csv`,`coding-standards.md` 2026-11-06 條);牌面文字表新增 14 列;集中欄位定義文件於 vs01 檔頭,其餘四份指向它。
- 遷移可逐關:先只 vs02 放新列試玩,vs01 與教學場保持現狀(不阻擋)。
- 一致性測試擴成 5 關:表 id 集合 == 牌面文字表 id 集合,逐關。

## Acceptance Criteria

- [ ] **AC1** 5 關牌表皆可被 `Card.cards_from_text()` 成功解析(非 `null`)。
- [ ] **AC2 一致性**:每關牌表 id 集合與牌面文字表 id 集合相同(5 關各 1 條),缺任一列被測試抓到。
- [ ] **AC3 14 張卡數值**:逐張與規格 v0.3 第 4 節核對(實作者製表:卡 id/類別/數值/距離/代價,貼進回報,附規格行號)。
- [ ] **AC4 舊表仍可載**:教學場與保留的舊卡(依 D4)解析結果不變。
- [ ] **AC5 `.csv` 零新增**:`git status`/`git diff --name-only` 於 `assets/data/` 無新 `.csv` 檔(貼原始輸出)。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行,以記憶體內替身表餵測試):①牌面文字表少一列 → AC2 紅 ②牌表多一列無文字 → AC2 紅 ③欄數 12 的列 → AC1 紅 ④類別字串拼錯 → AC1 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 營火卡(`source=CAMP`,不在本批)、牌組編輯、卡教學關。

## Affected Files

- `assets/data/cards/vs01~vs05_cards.txt`、`vs01~vs05_card_text.txt`
- `tests/integration/gameplay/cards/card_table_id_consistency_test.gd`、寫死 `card_0N` 的測試檔(`grep -rln "card_0[1-8]" tests` 當場確認)

超出此清單先問。

## 與其他工單的順序

- **依賴 011、015、017、018、019**(資料列用到的 Category/欄位要先存在);025 依賴本單。
