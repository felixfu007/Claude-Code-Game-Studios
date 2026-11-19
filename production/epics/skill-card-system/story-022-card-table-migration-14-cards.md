# Story 022:資料遷移 — 14 張卡牌表 + 牌面文字 + id 一致性測試擴成 5 關

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: ✅ Done(2026-11-19,提交 `1046399`;管理者同日裁決:c03 借用 target_range=2、D4 vs02~05 退役 card_01~06、牌組照規格 14 張不放 c13/c14;已知缺陷:新牌面單行溢出 Z3 → story-029)(原狀態:Ready(2026-11-18:依賴 011/015/017/018/019 皆已完成;牌面文字已定稿 `design/narrative/card-face-text-14-2026-11-18.md`;待決:c03「與另一名我方距離 ≤2」用哪個欄位表達)(原狀態:Blocked —— 派工前三題(卡 id、10A-1、D4)已於 2026-11-17 全部決定(答案檔題 2、7、8);**仍卡**:①依賴 011、015、017、018、019 尚未完成 ②14 張卡的牌名/牌面文字須由 `narrative-director`/`writer` 交付(是否已交付:**未驗證**,派工前須向其索取)。))
> **Type**: Config/Data + Logic(一致性測試)
> **Estimate**: M(1~1.5 天,粗估未驗證;data-format S7)
> **依據**:規格 v1.0 第 6.2(c11/c14 敘事前提;**預設採甲案中性改名**)、v0.3 第 4 節 14 張卡池;data-format 2.7、2.5(5 份牌表逐列相同:資料列 vs02~05 與 vs01 相同,2026-11-12 量);`tests/integration/gameplay/cards/card_table_id_consistency_test.gd` 目前只檢 vs01。**5 份 `vsNN_cards.txt` 是否仍逐列相同 2026-11-17 未重驗**,實作者第一步 `diff` 資料列。

## 派工前須先決定

1. **卡 id 命名**(同 011 第 2 題):`c01`/`card_01`。
   - **已決:`card_11`~`card_24`**(c01 → card_11 … c14 → card_24);現行 `vs02_cards.txt` 的 `card_01`~`card_08` 已佔用,`card_09`、`card_10` 空著。(答案檔題 2;v0.3 第 3 節規則 13。)營火產出卡的 id 規則規格未定,營火批再定。
2. **10A-1**(管理者待決):預設甲案;裁決前以甲案不阻擋實作,但**牌名/牌面文字由 `narrative-director`/`writer` 提供,不由工程師自擬**。
   - **已決:牌面 = 中性改名(= 10A-1 甲案)**,管理者 2026-11-12 裁決(`production/session-state/active.md` 第 278 行:「牌面 =『中性改名(設計師與創意總監都推薦)』」)。(答案檔題 7。)文案仍由 `narrative-director` 提供,是否已交付:**未驗證**。
3. **D4 舊 6 張甲類去留**:退役則寫死 `card_0N` 的 4 個測試檔(data-format 2.7 稱 4 檔)須改指向保留 id 或內嵌字面值;保留則 14 張為新增。
   - **已決:vs02~vs05 退役舊 6 張免費甲類卡(`card_01`~`card_06`),vs01 教學場保留現狀**(v0.3 第 4 節末、第 10 節表;答案檔題 8)。⚠️ 這是設計師定案、**非管理者裁決,管理者可推翻**(設計師找不到管理者針對 D4 的明確裁決原文)。連帶:v0.3 6B 預設牌組 = c01~c12 + card_07 + card_08(共 14 張);丙類 `card_07`/`card_08` 不退役;寫死 `card_01`~`card_06` 的測試須改指向保留 id 或內嵌字面值(`grep -rln "card_0[1-8]" tests` 當場確認)。
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
