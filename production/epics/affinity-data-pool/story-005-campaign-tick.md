# Story S-005:戰役刻度 —— `advance_campaign_tick()` + 標記列表 + `c_now(t_query)`

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:✅ Complete(狀態標記 2026-09-16 補正 —— 實作早已完成,但本欄一直停在 `Ready`)
> **估時**:S
> **依賴**:S-004

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules #1「戰役刻度標記列表」段落、Formulas 3c(時間分布、`c_now(t_query)` 精確定義)
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制二末段(`_campaign_tick_marks: Array[int]`)、機制四之四(`AdvanceRejection` enum)
- **Engine**:Godot 4.7.1

## 目標

建立獨立於 Delta Log 的戰役刻度標記列表,與 `advance_campaign_tick()` 介面。做完之後,「這段關係在整場戰役中,實際跨越了多少比例的戰役進程」這個問題第一次有穩定的分母可用——不受「別的配對有沒有被寫入」污染。

🔴 **管理者裁決收進切片的理由(EPIC.md 既定前提,轉錄)**:跨結構不變量第 1 條是「Delta Log 非空則標記列表必非空」,若在 `c=0` 狀態下累積過記錄再做 S-013(切片外),那顆池的存檔會被它自己的驗證器判為非法,而失敗點離寫入點很遠(要等玩家存過檔才會出現)。

## 🔴 本 story 決定的原始碼目錄路徑

沿用既定決定:`src/gameplay/affinity_pool/affinity_data_pool.gd`(同檔,S-003/S-004 已在此檔累加)。

## Implementation Notes

出自 ADR-0002:

1. **`_campaign_tick_marks: Array[int]` 是獨立於 Delta Log 的 append-only 結構**:每次 `advance_campaign_tick()` 呼叫時,附加當下的 `_t_now` 值。
2. **介面**:

   ```gdscript
   enum AdvanceRejection {
       NONE,
       SERIALIZATION_WINDOW_ACTIVE,
   }
   func advance_campaign_tick() -> AdvanceRejection   # 目前僅 SERIALIZATION_WINDOW_ACTIVE 一種拒絕情境
   ```

   本 story **只交付 `NONE` 分支的正常路徑**——`SERIALIZATION_WINDOW_ACTIVE` 依賴 S-014(切片外),理由與檢查點結構要求同 S-003/S-004,程式碼結構須保留這個檢查點,不宣稱測過。
3. **`c_now(t_query)` 精確定義(Formulas 3c)**:`c_now(t_query) = |{標記 ∈ 戰役刻度標記列表 : 標記記下的 t_now 值 ≤ t_query}|`——即在 `t_query` 這個全域時間點以前(含當下),「前進戰役刻度」介面總共被呼叫過幾次。省略 `t_query` 時,等同目前已呼叫次數。**這個定義不依賴 Delta Log 中任何配對是否被寫入**——這正是本 story 存在的理由。ADR-0002 的實作選擇是對 `_campaign_tick_marks` 做線性計數(`O(m)`),滿足 GDD 鎖定的 `O(n_p+m)` 契約。
4. **`c_now()` 本身作為 `AffinityDataPool` 的方法,還是留給 S-006/S-007 讀取函數內部呼叫?** 本 story 交付 `advance_campaign_tick()` 與能滿足上述定義的 `_campaign_tick_marks` 資料結構本身,以及一個計算 `c_now(t_query)` 的內部/私有輔助方法(供 S-006/S-007 呼叫)——不對外公開獨立的 `c_now()` 查詢介面,理由:GDD 明文 `c_now` 是隨三個讀取函數的回傳值一併附帶的欄位(見 Core Rules #3「回傳值中的計數器可觀測性」),不是獨立方法;本 story 只保證底層資料結構與計算邏輯正確,S-006/S-007 負責把它接進各自的回傳簽章。
5. 🔴 **每筆記錄的 `c` 欄位在本 story 落地前恆為 0(EPIC.md 限制第 2 條,轉錄)**:S-004 的 `append_record()` 已經在寫 `c_i = 寫入當下戰役刻度計數器現值`,但在本 story 完成前,戰役刻度計數器從未被推進,故所有記錄的 `c` 欄位恆為 0。此腳手架**只在 S-004→S-005 之間存在**,本 story 完成後不再成立。
6. **陣亡標記表無關**:`advance_campaign_tick()` 與 `_death_marks` 無耦合,不需要查詢 S-003。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-39**: **GIVEN** 這是戰役最初一章,章節/戰役結構系統依 2026-08-03 修訂的呼叫時機於該章**開始時**呼叫「前進戰役刻度」介面,**WHEN** 該章開始後、結束前的任一時間點觸發好感度事件並寫入記錄,**THEN** 該筆記錄的 `c_i ≥1`,查詢 `shape_feature_read` 的 `spread_ratio` 時 `c_now ≥1`,不出現 `0/0` 或除以零錯誤——驗證 Formulas 3c 的 `c_now≥1` 保證在戰役最初一章確實成立。⚠️ **觀測 `c_now` 需 S-010(切片外)——見 GDD「AC 措辭與 Core Rules #3 不一致」登記**:本 story 先以池的內部狀態(白箱)驗證 `_campaign_tick_marks` 本身的行為(呼叫一次即非空、`c_now(t_query)` 計算正確),`spread_ratio` 本身的黑箱驗證待 S-010 落地後補一次黑箱複驗,`producer` 已登記此項。
- **AC-41**(2026-08-03 新增,驗證 `c_now` 歷史重建修正):**GIVEN** 戰役刻度標記列表已有 5 筆標記(對應第 1~5 次「前進戰役刻度」呼叫,分別發生於全域計數器 t=1、t=3、t=3、t=3、t=8,其中 t=3 那三次代表連續三章開始時皆無任何好感度事件寫入),**WHEN** 以 `t_query=5`(晚於第 4 次標記、早於第 5 次標記)呼叫任一讀取函數取得 `c_now`,**THEN** 回傳值精確等於 4(t≤5 的標記筆數),而非依賴 Delta Log 記錄本身反推出的任何較低值——證明 `c_now` 的歷史重建不受該期間「有無配對被寫入」影響。⚠️ **同上,黑箱透過讀取函數觀測待 S-006/S-007 落地**——本 story 先以直接呼叫池內部 `c_now(t_query)` 計算方法驗證此案例,S-006/S-007 落地後應能透過任一讀取函數的回傳值重驗同一案例。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_data_pool_campaign_tick_test.gd`

預期涵蓋:

- `test_advance_campaign_tick_appends_current_t_now_to_marks_list`
- `test_advance_campaign_tick_does_not_increment_t_now`
- `test_c_now_at_query_is_count_of_marks_at_or_before_query`(AC-41,白箱)
- `test_c_now_unaffected_by_periods_with_no_affinity_writes`(AC-41 的核心宣稱——密度污染不再發生)
- `test_first_chapter_start_tick_makes_c_i_at_least_one_for_subsequent_writes`(AC-39,白箱,與 S-004 的 `append_record()` 銜接)

## Out of Scope

- **`spread_ratio`/`c_now` 透過 `shape_feature_read` 的黑箱驗證**——屬 S-010(切片外),本 story 只白箱驗證池內部狀態,producer 已登記待補黑箱複驗。
- **三個讀取函數把 `c_now` 接進回傳簽章**——屬 S-006(讀取結果型別)/S-007(形狀特徵讀取)。
- **`SERIALIZATION_WINDOW_ACTIVE` 真實觸發**——依賴 S-014(切片外)。
