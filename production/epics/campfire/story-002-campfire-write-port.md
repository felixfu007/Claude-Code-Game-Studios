# Story 002:營火寫入口 —— 任選兩人,關心 `+m`/質問 `−m`

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 卡在 ①`lead-programmer`(好感度擁有者):營火寫入的許可路線與用哪個來源值(v1.0 10B 第 1 項);②`game-designer`:每輪可寫幾次。
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證;排程 F3 原估 1.5~2.5,v1.0 改寫共用池後約 −0.5)
> **依據**:v1.0 規格 4.3(寫共用池、走自己的入口、不經丙類 `legal_pairs()` 過濾)、6.1(營火關心麥子健會使他失去騎牆)、第 8 節旋鈕(`m`、每輪次數「未定」);creative-director 確認 `docs/reviews/card-campfire-v1-creative-confirm-2026-11-12.md` 第 3 節(條件:**單次 `m` 不得大於一次支援對話的寫入量**)。

## 背景(producer 2026-11-20 實查)

- 支援對話已經有「寫進戰役累積記錄」的寫入埠:`src/gameplay/narrative/support_conversation_ledger_write_port.gd`,由 `battle_screen.gd` 勝利時建立(grep `SupportConversationLedgerWritePort.new`)。營火寫入預期照同一形狀。
- `AffinityTypes.Source` 只有 `COMBAT_CARD / SUPPORT_CONVERSATION / STORY_EVENT`,**沒有營火**。
- 營火在兩場戰鬥之間發生,寫入落在下一場 `begin_mission()` 基準點**之前** —— 因此下一場打輸時 `rollback_current_mission()` **不會**回滾營火寫入。**這是否正確取決於管理者「戰敗回到哪」那一題**(見 story-006)。推論自 `campaign_affinity_ledger.gd` 檔頭說明,**`start_mission_affinity_ledger()` 是否呼叫 `begin_mission()` 未逐行驗證**。

## 派工前須先決定

| # | 題目 | 誰決定 | 備註 |
|---|---|---|---|
| 1 | 營火寫入要不要新許可;`can_write()` 保護等級如何對應 | `lead-programmer` | 若答案是「要改池的契約」→ 轉 `technical-director` 判斷是否觸及 ADR-0002 |
| 2 | 寫入用哪個 `Source` 值:沿用既有值,或在 enum **尾端**追加 `CAMPFIRE` | `lead-programmer` | v1.0 4.3:「不再有營火用標記」、與丙類同等計分 —— 沿用既有值可能較合規格;**協調者/producer 不代判** |
| 3 | 每輪營火可寫幾次(二手數字「最多四輪、每輪 2~3 次」,未驗證);同一輪能否重複選同一組 | `game-designer` | 放資料檔,不寫死 |
| 4 | `m` 初值 | `systems-designer` | **不擋開工**:用占位值放資料檔,標「不得直接上線」(比照 `neutral_band_centi`) |

## 規則摘要

- 輸入:兩名角色(10 組任一,含麥子健)、動作(關心/質問)。輸出:一筆寫進戰役累積記錄的 `(pair, ±m, source)`,或明確拒絕(同一角色兩次、超過本輪次數、非法角色)。拒絕零寫入、可觀測原因。
- **不呼叫** `PermanentAffinityWriteRules.legal_pairs()`(丙類卡路徑)。
- `m` 與每輪次數從 `assets/data/` 讀;資料檔副檔名用 `.txt`(不得 `.csv`,見 coding-standards)。
- 寫入後的 `v` 以 story-001 的共用函式重建池讀出,供 003 產卡用;關係狀態一律 `AffinityRelation.state_of()`。

## Acceptance Criteria

- [ ] **AC1** 10 組配對各寫一次關心:每組 `v` 增加 `m`、`n_pair` +1(單元測試;含 4 組麥子健配對)。
- [ ] **AC2** 質問寫 `−m`;冷淡區內的配對被質問到 `v < −k` 時 `state_of` 由 `NONE` 變 `NEG`(驗 v1.0 6.1「跨區是設計中的後果」)。
- [ ] **AC3** 拒絕:同一角色、超過本輪次數 → 零寫入、原因可讀。
- [ ] **AC4** 寫入後**下一場戰鬥開局**讀到新關係(以真實戰鬥場景檔載入,注入累積記錄;v1.0 驗收 (7))。
- [ ] **AC5** 麥子健四組原本全 `NONE`,營火關心其中一組使其跨出冷淡區 → 下一場騎牆 `lone_guard` 與 `hold_back` **同時關閉**(v1.0 驗收 (6),讀端用既有 story-014 的判定)。
- [ ] **AC6** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①寫入時誤用丙類 `legal_pairs()` 過濾 → AC1 麥子健那幾組紅 ②質問寫成 `+m` → AC2 紅 ③次數檢查拿掉 → AC3 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campfire/`(寫入口)、`assets/data/` 營火旋鈕資料檔(名稱實作者提)、`tests/unit/gameplay/campfire/`
- 若決定追加 `Source` 值:`src/gameplay/affinity_pool/affinity_types.gd`(**只能追加在尾端**)—— 屬好感度池檔案,**超出本 EPIC 範圍,須先問**
- 超出先問。

## 與其他工單的順序

- 依賴 001。003(產卡)、007(營火畫面)依賴本單。
