# Story Index — Epic: 好感度—位置連鎖系統(#5)第一批

> 本檔是切 story 前先落地的思考骨架,不是 story 檔本身,不計入 EPIC.md 的 Stories 表。
> 依 2026-09-29 管理者裁決 2:本批只切「不產生畫面」的部分(M1 / M2 / M5 + M3 本系統側)。
> M0、EPIC.md、index.md 不動——本批範圍之外。

## 一、故事清單(依模組)

| # | 檔名 | 模組 | 一句話範圍 | Type | 依賴 |
|---|---|---|---|---|---|
| 001 | story-001-ac-r1-external-data-driven-test-backfill.md | M1 | AC-R1 反查後補標或補寫:證明極性/強度來自外部資料而非硬編碼 | Logic | 無 |
| 002 | story-002-ac-r3-delta-curve-label-backfill.md | M1 | AC-R3 反查後補標:四種(極性×距離)組合已有行為測試,只補代號 | Logic | 無 |
| 003 | story-003-ac-r5-multi-beneficiary-release-test.md | M1 | AC-R5 新增測試:多名負向夥伴同時解除負擔,現有測試只驗單一夥伴 | Logic | 無 |
| 004 | story-004-affinity-pool-instance-and-id-mapping.md | M2(前置) | 建立 `AffinityDataPool` 執行期實例擁有權 + roster id↔Character 對映層(P-1、P-2) | Integration | 無,但需先查 S-009 是否已部分解決(見下) |
| 005 | story-005-pairing-data-per-query-refetch.md | M2(主線) | 配對資料改為逐次查詢 `combat_strength_read()`,含拒絕碼與 n_pair==0 的降級處理(R1+R9 配對側) | Integration | 004 must be Done first |
| 006 | story-006-clamp-and-contribution-disclosure-query-api.md | M3(本系統側) | 新增查詢 API:原始和、是否被夾限、夾到哪一邊——讓消費端不必自行加總 | Logic | 無 |
| 007 | story-007-manhattan-implementation-count-guard.md | M5 | R2「仍只有兩份曼哈頓實作」的結構紀律守衛(乙類源碼掃描測試) | Logic | 無 |
| 008 | story-008-ac-perf-query-baseline-benchmark.md | M5 | AC-PERF:建立 1000 次查詢效能基準(今天沒有基準,本 story 的產出就是那條基準) | Logic | 無 |

**排程限制(寫進 004/005/006 三張的前置條件欄,不只留在 EPIC.md)**:
🔴 **004→005 必須依序;005 與 006 不可同時派人**(兩者都可能touch `src/ui/battle/battle_screen.gd` 的呼叫慣例——見下方 M3 邊界判斷的例外說明)。

## 二、M3「本系統側 vs 畫面側」切線判斷(協調者要求必須寫下理由)

**判斷:006(本批要切的 M3 部分)本身不修改 `src/ui/battle/battle_screen.gd`。**

理由:
- EPIC.md 模組切分表明文:M3 觸及的檔案只有 `affinity_rules.gd`(新增查詢面)與
  `affinity_line_status.gd`,不含 `battle_screen.gd`。
- M3 真正會動 `battle_screen.gd` 的部分,是**消費端**——也就是畫面上要不要呼叫這個新
  查詢 API、要不要因此改寫游標預覽的呼叫方式。那一段依裁決 2 本批不切,等 #5 的畫面規格。
- 因此 006 的範圍是:在 `affinity_rules.gd` 新增一個回傳「原始和 / 是否被夾限 / 夾到哪一邊」
  的查詢函式,並可能在 `affinity_line_status.gd` 補上對應欄位。這是純系統內部的新增讀取
  介面,呼叫端(battle_screen.gd、UI)在本批完全不知道它存在,也不必知道。

⚠️ **但這條線不是完全乾淨,以下是我認為切不乾淨的地方,誠實列出**:
- EPIC.md 風險 R-4 明文說「M2 與 M3 都會碰 `battle_screen.gd`」,並附了 6 處呼叫的查證指令。
  **那 6 處呼叫指的是現行 `battle_screen.gd` 已經在呼叫 `AffinityRules.*`/`AffinityPhiProvider.*`
  的既有呼叫點**,不是「M3 本系統側這次新增的程式碼會去改那些呼叫點」。我判斷 R-4 描述的
  衝突面主要來自 M2(M2 明文要接線、要改 `battle_screen.gd` 的呼叫慣例)與**未來** M3 消費端
  (畫面側,本批不切),而不是 006 本身。
- 但我沒有把握這條界線在實作時一定守得住——如果開發 006 的人為了驗證新查詢 API 的正確性,
  順手在 `battle_screen.gd` 裡加一行呼叫來手動試,那就會踩進 M2 的檔案。**這是判斷,不是保證。**
  依協調者派工單的明文要求,006 的 story 檔仍會寫上「M2 與 M3 不可同時派人」的排程警語,
  即使我判斷 006 本身結構上不需要碰那個檔案。

## 三、未查證清單(先寫下,不回頭讀檔)

1. ⚠️ **`production/epics/affinity-data-pool/story-009-wiring.md`(S-009,#1 好感度數值池的
   接線故事)是否已經解決 `AffinityDataPool` 的實例擁有權問題(EPIC.md 的 P-1)。**
   本批發現該檔存在(`production/epics/affinity-data-pool/story-009-wiring.md`),但依協調者
   中途指示,故意不讀取其內容以節省時間。**004 的第一個動作應該是先讀這張 S-009,
   如果它已經解決 P-1,004 的範圍應該收斂成只剩 P-2(id 對映)甚至直接關閉。**
2. ⚠️ **`value == 0.0` 但 `n_pair > 0`(關係真實存在、但淨值剛好抵銷為 0)這個邊界情況,
   在整個查證過程中(epic、GDD、決策報告)都沒有被任何人明文處理過** —— 這是我在讀
   `design/gdd/affinity-data-pool.md` 時自己發現的,不在管理者已裁決的 5 項之列。
   已在 005 的 story 檔裡明文列為需要決定的問題,並給了一個建議(借用裁決 4 的機制),
   但這是我的判斷,未經覆核。
3. ⚠️ 004/005 的 `AffinityDataPool` 實例最終應該掛在哪個物件上(`BattleState`?一個新的
   battle-scope manager?)沒有查證哪一個是「已存在、可以直接掛」的物件——只確認了
   ADR-0002/控制清單明文禁止 Autoload。細節留在 004 的 story 裡標未查證。
