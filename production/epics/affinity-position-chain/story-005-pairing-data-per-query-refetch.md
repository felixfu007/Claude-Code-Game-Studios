# Story 005: 配對資料改為逐次查詢(M2 主線 —— 唯一真正改變行為的故事)

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready(⚠️ 依 story-004 的判定結果,實作前請先確認 004 已 Done)
> **Layer**: Gameplay(控制清單「核心層規則(Core)」——好感度數值池段直接適用)
> **Type**: Integration
> **Estimate**: M(1～2 session)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`(Interactions ①、States and Transitions)+
`design/gdd/affinity-data-pool.md`(#1,Formulas 節,`combat_strength_read` 定義與
`n(p)=0` 邊界慣例)
**需求**: R1(關係表資料來源,上游即時查詢)+ R9 配對側(位置快照與配對資料同級新鮮度)
**TR-ID**: ⚠️ 本系統(#5)尚未登記進 `tr-registry.yaml`。本 story 是介面契約
`docs/registry/architecture.yaml` → `interfaces` 節 → `affinity_pairing_data_per_query_refetch`
條目**唯一的完成定義**——該條目今天是 `status: active` 但行為尚未落地。

**Governing ADR**: **ADR-0002**(`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`,**Accepted**)——本 story 是 #5 第一次真正呼叫
`combat_strength_read()`,ADR-0002 對讀取端的全部義務(機制五之二)直接適用。
**次要參考**:登記表 `interfaces` 節 `affinity_pairing_data_per_query_refetch` 條目
(`adr: none`——記錄的是義務而非新架構選擇,見 EPIC.md 第 5.3 節③);
`docs/reviews/affinity-read-rejection-consumer-obligation-2026-09-29.md`(裁決 4 的完整
查證報告)。
**ADR 決策摘要**:讀取結果一律用 `result.rejection` 欄位表達拒絕,不丟例外;呼叫端**必須
先確認 `result.rejection == ReadRejection.NONE` 才可讀取其他欄位**;哨兵值(`NAN`/`-1`)
設計理念是「絕不能讓失敗值長得像合法的成功值」。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純函式與資料物件呼叫,不涉及節點生命週期或
post-cutoff 引擎變更範圍)

**Engine Notes**: 無 post-cutoff 風險。

**Control Manifest Rules(此層,直接摘自「好感度數值池(ADR-0002)」段,本 story 逐條相關)**:
- Required:**必須先確認 `result.rejection == ReadRejection.NONE`,才可讀取任何其他欄位。**
- Required:**`pair_of()` 的呼叫端必須先以 `AffinityTypes.is_valid_character()` 驗證兩個
  參數**(story-004 已交付對映層,本 story 直接使用)。
- Required:**呼叫端的邏輯分支絕不依 `rule_id` 判斷,一律只依 `rejection`。**
- Forbidden:**絕不寫 `if t_query != null and t_query > _t_now`**——對 `String` 會在比較
  運算子處中止所在函式(本 story 預期省略 `t_query`,不主動傳遞,故此陷阱結構上不太可能
  觸發,但仍列出以防未來有人加上 `t_query` 參數)。
- Performance guardrail:**好感度讀取為熱路徑**,GDD Interactions ② 明文
  「呼叫頻率為輸入事件級,非每回合一次(游標移動即觸發預覽)」——本 story 的查詢函式
  會在游標每次移動時被呼叫,效能特性見 story-008(M5 PERF 基準)。

---

## 🔴 完成的定義(EPIC.md 明文,唯一的驗收判準)

`tests/unit/gameplay/affinity/affinity_phi_provider_test.gd` 內的
`test_phi_reflects_a_pairing_polarity_flip_made_after_construction`(目前刻意紅、
專案唯一已知既有失敗)**必須變綠,且不是靠改測試本身變綠**。這條測試釘的正是
「配對資料在建構後才翻轉極性,下一次查詢必須反映新極性,不必重建 provider」——
測試本身已存在,不需要新寫,本 story 要做的是修 production 程式碼讓它通過。

**本 story 完成後,本專案的測試套件會第一次全綠**(`.claude/docs/technical-preferences.md`
Autoload 節記載的「唯一失敗」就是這一條)——**請不要在本 story 之外順手把它關掉或改斷言**。

## Acceptance Criteria

- [ ] `test_phi_reflects_a_pairing_polarity_flip_made_after_construction` 通過。
- [ ] `AffinityPhiProvider`(或其替代/重構後的等價物)**不再於建構時一次性讀取並凍結**
  配對資料——每一次 `phi()` 查詢都重新向 `AffinityDataPool.combat_strength_read()` 取得
  極性與強度,與 `positions()` 同一個新鮮度等級(GDD Interactions ① 逐字:
  「遷移時真正要改的是這一點,不只是把靜態檔換成函式呼叫」)。
- [ ] **拒絕碼降級處理(裁決 4,見下方專節)**:讀取被拒絕的配對,`Φ` 貢獻視為 0,
  畫面借用既有 `AffinityLineStatus.State.NEUTRAL`,不新增第四種狀態,另留一筆不驚動
  玩家的技術診斷紀錄。
- [ ] `assets/data/affinity/vs01_affinity_links.txt` 的**讀檔路徑退場**——不再是
  `Φ` 計算的資料來源(該檔案本身是否整個刪除,或保留給其他用途如測試夾具,由實作者
  依現況判斷,本 story 不強制)。
- [ ] `docs/registry/architecture.yaml` 的 `affinity_pairing_data_per_query_refetch`
  條目狀態更新,反映本 story 完成後的實況(EPIC.md DoD 明文要求)。

## 🔴 裁決 4(2026-09-29 管理者裁決)—— 讀取被拒絕時的降級處理

**背景**:結構上唯一可能觸發 `combat_strength_read()` 拒絕碼的情境,是 #5 自己把「兩個
角色是誰」轉換成 `AffinityTypes.Pair` 這一步寫錯(工程錯誤),或關係資料檔本身壞掉導致
解析出不存在的角色配對——**不是任何正常遊玩會走到的合法遊戲狀態**
(`docs/reviews/affinity-read-rejection-consumer-obligation-2026-09-29.md` 第 2.5 節,
逐條推算 `_validate_read_query()` 的三個分支後得出的結論)。這條驗收條件驗的是
「工程師寫錯配對時,系統該不該吵起來」,不是「玩家會不會看到這個畫面」。

**裁決逐字(管理者選項 A)**:

- **`Φ` 怎麼算**:被拒絕的那條關係線,對 `Φ` 的貢獻視為 `0`(等同這條線目前沒生效),
  不影響其他線正常加總。
- **畫面顯示什麼**:那條線不畫成發光的正向或負向,畫成中性/無效果的樣子——借用既有的
  `AffinityLineStatus.State.NEUTRAL`,**不需要新增第四種畫面樣式**。
- **失敗時長什麼樣**:玩家完全看不出任何異常——這條線就是安安靜靜地「目前沒加成」,
  跟兩個角色距離太遠時的中性線看起來一模一樣。**但工程師這邊要留一筆診斷紀錄**
  (例如 `push_warning()` 或某個可觀測的計數器,不彈窗、不中斷遊戲),讓開發期間能發現
  「這裡配對錯了」,不會像 bug 一樣悄悄消失不留痕跡。
- **相容性**:與 Edge Cases「`amp` 超出合法值域」既有先例(`affinity_link.gd` 的
  `push_warning` 模式)同一種精神——修正但留痕,不悄悄吞掉;與「`Φ` 回傳純量即可滿足
  結算快照契約」相容,不需要改變 `Φ` 的回傳型別。

**實作建議**:在把 `combat_strength_read()` 結果轉換成內部使用的配對資料(polarity/amp)
之前,先檢查 `result.rejection == ReadRejection.NONE`(控制清單強制要求);若不等於
`NONE`,**跳過這條線的建構**(不產生對應的 `AffinityLink`/貢獻項),並呼叫
`push_warning()` 或等價機制記錄事件(含哪一對角色、什麼拒絕碼),然後繼續處理其餘配對——
不得因單一配對被拒絕就中止整個 `Φ` 查詢。

## ⚠️ 待決問題(本 story 作者發現,未經覆核,需管理者或 systems-designer 裁決)

**`combat_strength_read()` 回傳 `result.rejection == NONE` 且 `result.n_pair > 0`,
但 `result.value` 恰好等於 `0.0`**——即這對角色之間**確實有真實的互動記錄**
(不是「從未互動」),只是正負記錄剛好抵銷,淨值為 0。

`design/gdd/affinity-data-pool.md` 明文警告這個情況**合法且可能發生**
(Edge Cases 節逐字:「讀值 0 也可能是大量正負記錄剛好抵銷的合法結果」),
並要求下游系統**以 `n_pair == 0` 而非讀值是否為 0 作為「無資料」的權威判斷依據**——
這正是本系統(#5)需要區分「戊沒有任何關係線」(`n_pair == 0`,應該完全不產生線)與
「這對角色有關係、但淨值剛好抵銷」(`n_pair > 0`,`value == 0.0`,應該仍然是一條線,
只是不知道該畫成正向還是負向)這兩種不同情況的地方。

**問題**:OQ-3 已裁決 `amp` 恆為 1、只取 `value` 的符號、丟棄量值——但 `value == 0.0`
**沒有符號**。而 R3 的曲線在距離 1 或距離 ≥3 時,正向與負向的數值並不相同
(`+3` vs `−1`,或 `−1` vs `+2`)——**任意指定一個極性會產生一個沒有依據的具體數字**,
只有在距離剛好落在死區(距離 2)時,選哪個極性都無所謂(結果都是 0)。

**本 story 作者(lead-programmer)的建議,尚未經覆核,不是決定**:
建議**借用裁決 4 的同一套機制**處理這個案例——即 `value == 0.0 且 n_pair > 0` 時,
對 `Φ` 的貢獻視為 0、畫面借用 `NEUTRAL` 樣式,並留一筆診斷紀錄(但用**資訊等級**而非
警告等級,因為這不是工程錯誤,是遊戲內合法產生的資料狀態)。理由:這與裁決 4 面對的
結構問題相同(「有一條線,但不知道該用哪個具體數字表示它」),重用同一個已核准的降級路徑
比發明第三種處理方式風險更低,且不違反「線不會騙人」的紅線(中性線本來就代表「目前沒有
淨效果」,與「淨值抵銷為 0」在玩家可觀察的意義上一致)。

**🔴 這是本 story 作者的判斷,未經管理者或 systems-designer 覆核,不得當成已裁決的事實
實作。實作前請先確認是否已有更新的裁決;若沒有,建議在實作本 story 時一併提出,
而不是自行假設本節建議已經生效。**

## Implementation Notes

- **禁止建構時快取**是本 story 的核心變更:`AffinityPhiProvider._links`
  (目前在 `_init()` 賦值一次、文件註解自稱「fixed for the provider's lifetime」)
  必須改為每次 `phi()`/`lines_for()` 呼叫時重新取得,做法上可比照 `positions()`
  現有模式(每次呼叫從 `_state` 重建,不快取)——即把「取得配對資料」也變成一個
  每次呼叫都重新執行的方法,而非建構時賦值的欄位。
- **候選配對集合**:`AffinityTypes.Pair` 只涵蓋 5 位主角兩兩配對(10 組),不包含敵方
  單位。實作時只需對「目前在場且存活的主角」兩兩配對呼叫 `combat_strength_read()`,
  不必(也不能)對敵方單位呼叫——敵方 roster id 6～10 經 story-004 的對映層驗證後
  會被 `is_valid_character()` 擋下。
- **對每一組配對**:呼叫 `combat_strength_read(pair)`(省略 `t_query`,依 GDD 語意
  「永遠只反映查詢當下的極性」,採用預設值)→ 檢查 `rejection == NONE` →
  若拒絕,依裁決 4 處理(跳過,留診斷紀錄)→ 若成功,檢查 `n_pair == 0`
  (無資料,跳過,不產生線)→ 否則依 `value` 符號決定 `polarity`
  (`value > 0` → POSITIVE,`value < 0` → NEGATIVE,`value == 0.0` 見上方待決問題)、
  `amp` 恆為 1(OQ-3 已裁決)。
- 建構出來的配對資料餵進既有 `AffinityRules.lines_for_at()` / `bonus_for_at()` 等函式
  **不需要改動**——這些函式本來就接受 `Array[AffinityLink]` 參數,只是這個陣列現在
  是每次查詢時新建的,不是建構時凍結的一份。
- `AffinityLink` 類別本身(unit_a/unit_b/polarity/amp 的資料結構)可以繼續沿用,
  只是不再透過 `links_from_text()` 讀檔產生,而是由本 story 新增的轉換邏輯依
  `combat_strength_read()` 結果建構。

## Out of Scope

- story-004 已交付的「池實例擁有權」與「id 對映層」——本 story 直接使用,不重新實作。
- story-006(M3 本系統側,夾限狀態揭露 API)——本 story 不涉及。
- 陣亡通知的轉發——GDD 明文陣亡通知不經本系統轉發,本 story 不新增任何轉發邏輯。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生,以下為作者依 GDD/裁決 4 直接轉寫:*

- **完成判準測試**(已存在,不必新寫):
  - Given: 兩單位相距 1 格,初始配對為正向關係(`Φ = +3`)
  - When: 配對極性在 provider 建構後翻轉為負向(透過重新指派一份全新配對資料,
    而非原地修改陣列元素,見該測試檔頭的既有理由)
  - Then: 下一次 `phi()` 查詢反映新極性(`Φ = −1`),不需要重建 provider
- **裁決 4 降級處理**(需新增測試):
  - Given: 一組會觸發 `INVALID_PAIR` 拒絕碼的配對(例如刻意構造一個不合法的角色組合)
  - When: 查詢該配對涉及的 `Φ`
  - Then: 該配對貢獻視為 0,不拋出例外、不中止其餘配對的計算,且產生一筆可觀測的診斷紀錄
  - Edge cases: 同一次查詢中若同時存在合法配對與被拒絕配對,合法配對的計算不受影響
- **`n_pair == 0` 邊界**(需新增測試):
  - Given: 一對角色的 `combat_strength_read()` 回傳 `rejection == NONE` 且 `n_pair == 0`
  - When: 查詢 `Φ`
  - Then: 這對角色之間不產生任何線(對 `Φ` 貢獻為 0,且不出現在 `lines_for()` 的結果中)

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/gameplay/affinity/affinity_phi_provider_test.gd` 的既有紅測試變綠。
- 新增測試涵蓋裁決 4 的降級路徑與 `n_pair == 0` 邊界(建議放在同一測試檔,或
  `tests/integration/gameplay/affinity/` 下,依實作規模由實作者判斷)。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: **story-004 必須先 Done**(需要已存在的池參照與 id 對映層)。
- Unlocks: None(M2 完成即代表 EPIC.md DoD 的核心項達成)。
- 🔴 **排程限制(協調者派工單明文要求)**:**本 story 與 story-006(M3 本系統側)
  不可同時派人**——兩者都可能涉及 `src/ui/battle/battle_screen.gd` 既有呼叫慣例的
  調整面(EPIC.md 風險 R-4,實測 6 處既有呼叫點)。本 story 對 `battle_screen.gd`
  的接觸面預期是**接線點本身**(呼叫端如何取得 `Φ` 的方式改變),風險比 006 更直接,
  應優先排本 story,待其 Done 後再排 006。
