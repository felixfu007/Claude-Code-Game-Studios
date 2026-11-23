# Story 004:收藏區與牌組 —— 只在本次開著遊戲時記得

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 依賴 **story-003**(營火卡物件,未 Done)。專家與管理者題已解除;剩一個**不擋開工**的資料題(收藏區初始內容,第 3 題)。「回營火時牌組要不要回滾」已移到 story-015。
> (原狀態:Blocked —— 卡在 ①`lead-programmer`:牌組寫在哪個執行期物件、戰敗重打保留牌組是否可行(v1.0 10B 第 4、5 項);②**管理者**:打輸後回到哪裡(見 story-006 第 1 題,決定戰敗時牌組要不要回滾)。)
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證)
> **依據**:v1.0 規格 4.6;v0.3 第 6B 節表格(8~14 張、全部可移出、移出回收藏區、營火卡不消耗、新卡自動入組、`default_deck` 放資料檔);管理者 2026-11-20 裁決第 4 題「預設改 12 張,上限 14(推薦)」、第 8 題(牌組放 `CampaignProgress` 底下的 `RefCounted`,不另開全域保管處)(`docs/reviews/campfire-rulings-2026-11-20.md`);2026-11-23 裁決第 1 題「照設計師建議(推薦)」、第 3 題(`docs/reviews/campfire-rulings-2026-11-23.md`);`docs/reviews/campfire-default-deck-12-2026-11-23.md`。

## 背景(producer 2026-11-20 實查;2026-11-23 更新)

- 現行戰役的跨場狀態:`CampaignProgress`(`src/core/campaign/campaign_progress.gd`,靜態)與 `CampaignAffinityLedger`(`src/gameplay/campaign/`,`RefCounted`)。
- ✅ 牌組放哪已裁決:做成一般可 `new()` 的 `RefCounted`(lead 暫名 `CampaignDeck`,`src/gameplay/campaign/`),由 `CampaignProgress` 掛成第二份靜態資料,比照 `_affinity_ledger` 先例;`reset_campaign()` 一併 `clear()`。依管理者 11-20 第 8 題,**不算第三個靜態持有者**。
- ✅ 戰敗「直接重打」:`rollback_on_defeat()` 只動累積記錄,牌組自然保留(`campfire-technical-answers-2026-11-20.md` ②)。
- 🔴 **`default_deck` 資料檔不存在**(game-designer 實測 `assets/data` 零命中);現況是「各場牌表即牌組」。本單新建它。
- 各場牌表實測(11-23 裁決檔「協調者查證的前提」):第 1 場 `vs01_cards.txt` **8 張**;第 2~5 場 `vs02~vs05_cards.txt` 各 **14 張**、資料列逐列相同(card_11~card_22 + card_07、card_08)。

## 已解除的待決(2026-11-23)

| # | 原題目 | 結論 | 出處 |
|---|---|---|---|
| 1 | 牌組放哪 | `CampaignProgress` 底下的 `RefCounted` | 管理者 11-20 第 8 題 |
| 2 | 打輸後牌組 | **直接重打 → 保留**;**回營火 → 待決,移到 story-015 第 1 題** | 管理者 11-20 第 1 題 |
| — | 預設張數 | **預設 12、上限 14、下限 8**;12 張 = card_11~card_22 拿掉 **card_19 聯手破門、card_21 臨時搭檔**,加 card_07、card_08;**第 1 場 8 張不動**(不走牌組,見 005) | 管理者 11-20 第 4 題、11-23 第 1 題 |

## 派工前須先決定(不擋開工)

| # | 題目 | 誰決定 | 備註 |
|---|---|---|---|
| 3 | 收藏區初始內容:被拿掉的 card_19、card_21 是否放收藏區(玩家可自己移回);v0.3 6B 原寫的 c13/c14(即 card_23/24 補血卡)是否仍放收藏區 | `game-designer` | 放資料檔,不寫死;實作者先用「card_19、card_21 進收藏區,card_23/24 不放」當占位並標未定 —— **此占位是 producer 推論,未經設計確認** |
| 4 | `deck_min`/`deck_max` 初值 8/14 的前提是「抽牌公式查定後重定」(v0.3 6B 自述未驗證) | `systems-designer` | 不擋開工 |

## 規則摘要

- 收藏區 = 擁有的全部卡;牌組 = 本場洗進牌庫的卡。新遊戲時兩者由 `default_deck` 資料檔初始化(`.txt`,不得 `.csv`)。
- 移入/移出:任何卡皆可移出並回收藏區;營火卡不消耗。確認時張數須在 `deck_min`~`deck_max`,否則拒絕並回報原因。
- 新營火卡:牌組未滿 `deck_max` 自動加入並標「新」;已滿則留收藏區(預設 12 張,前兩次營火卡會自動入組)。
- **「一輪」的邊界改為「新遊戲」**:回標題後按「繼續」保留牌組;按「新遊戲」或關閉遊戲 → 回到預設(管理者 11-20 第 5 題、11-23 第 3 題;標題按鈕在 story-014)。**不寫任何檔案、不新增存檔欄位。**

## Acceptance Criteria

- [ ] **AC1** 新遊戲:牌組 12 張(card_11~18、20、22、07、08),內容與 `default_deck` 資料檔一致(資料測試讀真實檔);收藏區內容與資料檔一致。
- [ ] **AC2** 張數 7 或 15 → 確認被拒、原因可讀;8 與 14 → 可確認(邊界值)。
- [ ] **AC3** 營火卡移出後仍在收藏區、可再移入;新卡在未滿時自動入組並帶「新」標記,滿時留收藏區。
- [ ] **AC4** `reset_campaign()` 後牌組回到預設;全專案本單新增碼無任何寫檔(v1.0 驗收 (9);以 grep 證明不呼叫 `FileAccess`,指令須寫成不會命中自己的形式)。
- [ ] **AC5** 戰敗後經 `rollback_on_defeat()` 直接重打:牌組 = 最近一次確認的牌組。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①上下限比較寫成 `<`/`>` 錯一格 → AC2 紅 ②移出時刪除而非回收藏區 → AC3 紅 ③`reset_campaign()` 不清牌組 → AC4 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campaign/`(牌組 `RefCounted`)、`assets/data/` 的 `default_deck` 資料檔(`.txt`)、新測試
- `src/core/campaign/campaign_progress.gd`(既有,掛牌組 + `reset_campaign()` 接 `clear()`;**列入本單範圍**)
- 超出先問。

## 與其他工單的順序

- 依賴 003(營火卡物件)。005、008、009、015 依賴本單。014「新遊戲」清牌組由本單的 `reset_campaign()` 接線涵蓋。
