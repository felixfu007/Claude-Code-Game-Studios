# Story 004:收藏區與牌組 —— 只在本輪遊玩記得

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 ①`lead-programmer`:牌組寫在哪個執行期物件、戰敗重打保留牌組是否可行(v1.0 10B 第 4、5 項);②**管理者**:打輸後回到哪裡(見 story-006 第 1 題,決定戰敗時牌組要不要回滾)。
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證;含排程 N8「戰敗重打保留牌組」0.5)
> **依據**:v1.0 規格 4.6(只記本輪、不進存檔、「一輪」= 新遊戲起至回標題或關閉止、戰敗重打預設保留);v0.3 第 6B 節表格(8~14 張、全部可移出、移出回收藏區、營火卡不消耗、預設 14 張 = c01~c12 + card_07 + card_08、c13/c14 在收藏區、新卡自動入組、`default_deck` 放資料檔)。

## 背景(producer 2026-11-20 實查)

- 現行戰役的跨場狀態:`CampaignProgress`(靜態)與 `CampaignAffinityLedger`(一般類別,`RefCounted`)。
- `campaign_affinity_ledger.gd` 檔頭引 `.claude/rules/gameplay-code.md` 裁決④:靜態狀態持有者已有兩個登記例外,「再要第三個,請重新裁決」。**牌組若做成第三個靜態持有者,需要管理者重新裁決**。

## 派工前須先決定

| # | 題目 | 誰決定 |
|---|---|---|
| 1 | 牌組/收藏區放在哪(掛在既有 `CampaignProgress` 底下、或一般類別由誰持有) | `lead-programmer`;若結論是「需要第三個靜態持有者」→ **管理者** |
| 2 | 打輸後牌組:保留最近一次確認的牌組(規格預設),還是回滾 | **管理者**(與 story-006 第 1 題同一題) |
| 3 | `deck_min`/`deck_max` 初值 8/14 的前提是「抽牌公式查定後重定」(v0.3 6B 自述未驗證) | `systems-designer`(不擋開工) |

## 規則摘要

- 收藏區 = 擁有的全部卡;牌組 = 本場洗進牌庫的卡。新遊戲時兩者由 `default_deck` 資料檔初始化。
- 移入/移出:任何卡皆可移出並回收藏區;營火卡不消耗。確認時張數須在 `deck_min`~`deck_max`,否則拒絕並回報原因。
- 新營火卡:牌組未滿 `deck_max` 自動加入並標「新」;已滿則留收藏區。
- 回標題、新遊戲 → 回到預設。**不寫任何檔案、不新增存檔欄位。**

## Acceptance Criteria

- [ ] **AC1** 新遊戲:牌組 14 張、收藏區含 c13/c14,內容與 `default_deck` 資料檔一致(資料測試讀真實檔)。
- [ ] **AC2** 張數 7 或 15 → 確認被拒、原因可讀;8 與 14 → 可確認(邊界值)。
- [ ] **AC3** 營火卡移出後仍在收藏區、可再移入;新卡在未滿時自動入組並帶「新」標記,滿時留收藏區。
- [ ] **AC4** 回標題後重開新遊戲 → 回到預設;全專案無任何寫檔(v1.0 驗收 (9);以 grep 證明本單新增碼不呼叫 `FileAccess`,指令須寫成不會命中自己的形式)。
- [ ] **AC5** 依第 2 題裁決結果:打輸同一場重打時,牌組 = 裁決指定的狀態。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①上下限比較寫成 `<`/`>` 錯一格 → AC2 紅 ②移出時刪除而非回收藏區 → AC3 紅 ③回標題不重置 → AC4 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campfire/` 或 `src/gameplay/campaign/`(依第 1 題)、`assets/data/` 的 `default_deck` 資料檔(`.txt`)、新測試
- 若掛在 `CampaignProgress`:`src/core/campaign/campaign_progress.gd`(既有,第 1 題定案後列入範圍)
- 超出先問。

## 與其他工單的順序

- 依賴 003(營火卡物件)。005、008、009 依賴本單。
