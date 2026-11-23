# Story 002:營火寫入口 —— 任選兩人,關心 `+m`/質問 `−m`

> **Epic**: `production/epics/campfire/EPIC.md`
> **Status**: Blocked —— 只剩依賴 **story-001**(In Progress,未 Done)。專家與管理者題已全部解除(2026-11-23 producer 依裁決更新,見下表)。
> (原狀態:Blocked —— 卡在 ①`lead-programmer`(好感度擁有者):營火寫入的許可路線與用哪個來源值(v1.0 10B 第 1 項);②`game-designer`:每輪可寫幾次。)
> **Type**: Logic
> **Estimate**: M(1~1.5 估計天,粗估未驗證;排程 F3 原估 1.5~2.5,v1.0 改寫共用池後約 −0.5)
> **依據**:v1.0 規格 4.3(寫共用池、走自己的入口、不經丙類 `legal_pairs()` 過濾)、6.1(營火關心麥子健會使他失去騎牆)、第 8 節旋鈕(`m`);creative-director 確認 `docs/reviews/card-campfire-v1-creative-confirm-2026-11-12.md` 第 3 節(條件:**單次 `m` 不得大於一次支援對話的寫入量**);管理者 2026-11-20 裁決第 3 題(`docs/reviews/campfire-rulings-2026-11-20.md`,採 game-designer 建議);2026-11-23 裁決檔「營火寫入來源值」節(`docs/reviews/campfire-rulings-2026-11-23.md`)。

## 背景(producer 2026-11-20 實查;2026-11-23 依專家回答更新)

- 支援對話已經有「寫進戰役累積記錄」的寫入埠:`src/gameplay/narrative/support_conversation_ledger_write_port.gd`。營火寫入照同一形狀(`lead-programmer` 2026-11-20:池的 `append_record` 沒有「誰有資格寫」的許可層;`can_write()` 在正式程式無呼叫端 —— **不需要新許可、不觸及 ADR-0002**,`docs/reviews/campfire-technical-answers-2026-11-20.md` ①)。
- ✅ **已逐行確認**:`start_mission_affinity_ledger()` 會呼叫 `begin_mission()`(同檔 ③)。營火寫入落在下一場基準點**之前**,下一場「直接重打」時不被回滾。「回營火」的回滾由 story-015 負責。

## 已解除的待決(2026-11-23)

| # | 原題目 | 結論 | 出處 |
|---|---|---|---|
| 1 | 要不要新許可 | **不需要**,不轉 `technical-director` | `campfire-technical-answers-2026-11-20.md` ① |
| 2 | 寫入用哪個 `Source` 值 | **`SUPPORT_CONVERSATION`**,不追加 `CAMPFIRE`。實測讀回值 = 寫入值、不乘 alpha、新池無陣亡封鎖;`COMBAT_CARD` 會被折成約 0.275 倍,**不可用** | `campfire-open-tech-2026-11-23.md` 題 1,探針 `prototypes/lead-programmer-campfire-source-probe-2026-11-23/run_output.txt`(證據等級 (A)) |
| 3 | 每輪幾次、能否重複同一組 | **每輪 3 次**(關心、質問合計);**同一輪同一組不可重複**;輪數不設旋鈕 = 戰役場數 − 1 | 管理者 11-20 第 3 題(採 `docs/reviews/campfire-rules-gd-2026-11-20.md` 題 1;協調者轉述、管理者可推翻) |
| 4 | `m` 初值 | 不擋開工:占位值放資料檔,標「不得直接上線」;須 ≤ 一次支援對話寫入量 | `systems-designer` 日後校準 |

## 新增規則:寫入先後(2026-11-23)

`lead-programmer` 實測:同樣兩筆記錄順序對調,讀出值差 0.06~0.24(較舊的記錄會衰減;`[2,3]` 讀 4.88、`[3,2]` 讀 4.82)。11-23 裁決檔明令「營火寫入先後須有確定規則,寫進 story-002」。
- **規則**:每次玩家確認一個動作,**立即**寫一筆,依確認先後附加;不得在營火結束時批次寫入、不得排序或重排。(依 lead 舉的例子「依玩家操作順序」;**若 lead 另有規則,以 lead 為準**。)

## 規則摘要

- 輸入:兩名角色(10 組任一,含麥子健)、動作(關心/質問)。輸出:一筆寫進戰役累積記錄的 `(pair, ±m, SUPPORT_CONVERSATION)`,或明確拒絕(同一角色兩次、本輪次數已用完、本輪已選過這一組、非法角色)。拒絕零寫入、可觀測原因。
- **不呼叫** `PermanentAffinityWriteRules.legal_pairs()`(丙類卡路徑)。
- `m` 與每輪次數(`camp_actions_per_round`,初值 3,game-designer 建議範圍 2~4)從 `assets/data/` 讀;資料檔副檔名用 `.txt`(不得 `.csv`,見 coding-standards)。
- 本輪計數與「本輪已選過的組」在每輪營火開始時清空(由誰在何時呼叫清空,與 006 介接;回營火時要不要清,見 story-015 第 2 題)。
- 寫入後的 `v` 以 story-001 的共用函式重建池讀出,供 003 產卡用;關係狀態一律 `AffinityRelation.state_of()`。

## Acceptance Criteria

- [ ] **AC1** 10 組配對各寫一次關心(跨多輪,每輪 3 次):每組 `v` 增加 `m`、`n_pair` +1(單元測試;含 4 組麥子健配對)。
- [ ] **AC2** 質問寫 `−m`;冷淡區內的配對被質問到 `v < −k` 時 `state_of` 由 `NONE` 變 `NEG`(驗 v1.0 6.1「跨區是設計中的後果」)。
- [ ] **AC3** 拒絕:同一角色、本輪第 4 次、本輪重複同一組 → 零寫入、原因可讀;換到下一輪後同一組可再選。
- [ ] **AC4** 寫入後**下一場戰鬥開局**讀到新關係(以真實戰鬥場景檔載入,注入累積記錄;v1.0 驗收 (7))。
- [ ] **AC5** 麥子健四組原本全 `NONE`,營火關心其中一組使其跨出冷淡區 → 下一場騎牆 `lone_guard` 與 `hold_back` **同時關閉**(v1.0 驗收 (6),讀端用既有 story-014 的判定)。
- [ ] **AC6** 寫入來源值為 `SUPPORT_CONVERSATION`;同一輪寫兩筆,累積記錄中的順序 = 確認順序。
- [ ] **AC7** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①寫入時誤用丙類 `legal_pairs()` 過濾 → AC1 麥子健那幾組紅 ②質問寫成 `+m` → AC2 紅 ③次數檢查拿掉 → AC3 紅 ④同組不重複檢查拿掉 → AC3 紅 ⑤來源值改 `COMBAT_CARD` → AC6 紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## Affected Files

- 新檔:`src/gameplay/campfire/`(寫入口)、`assets/data/` 營火旋鈕資料檔(名稱實作者提)、`tests/unit/gameplay/campfire/`
- **不改** `src/gameplay/affinity_pool/affinity_types.gd`(來源值沿用既有,不追加)。
- 超出先問。

## 與其他工單的順序

- 依賴 001。003(產卡)、007(營火畫面)、015(回營火)依賴本單。
