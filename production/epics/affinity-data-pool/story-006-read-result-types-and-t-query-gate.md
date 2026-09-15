# Story S-006:讀取結果型別與 `t_query` 型別閘門 + 拒絕哨兵兩張表

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:S-004

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules #3(讀取函數的 `t_query` 語意)、Edge Cases「若 `t_query` 大於目前實際的 `t_now`」
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制五(讀取路徑——三個純函數 + 公式四,條件式預設查詢時點)、機制五之二(拒絕的回報形狀——逐函數可達性表與哨兵值)
- **Engine**:Godot 4.7.1

## 目標

建立三個讀取函數共用的回傳結果型別(`AffinityReadResult`/`ShapeFeatureResult`)與 `t_query` 參數的型別閘門,並把拒絕情境的哨兵值寫死到位。做完之後,「一次讀取呼叫該回傳什麼形狀的東西」第一次有定案的容器可以裝——S-007(真正的加權計算邏輯)接著往這個容器裡填值。**本 story 不實作三個讀取函數的計算邏輯本身**,只實作型別、`t_query` 閘門與拒絕分流。

## 🔴 本 story 決定的原始碼目錄路徑

沿用既定決定:`src/gameplay/affinity_pool/affinity_data_pool.gd`。

🔴 **同檔強制規則(ADR-0002 2026-08-24 修訂,不可違反)**:`AffinityReadResult`/`ShapeFeatureResult` 因跨檔裸引用 `AffinityDataPool` 巢狀 enum(`ReadRejection`)在 Godot 4.7.1 是**編譯期限制**(已實機驗證:同檔裸引用 `COMPILED OK`,跨檔裸引用 `Parse Error`),兩者**必須是 `affinity_data_pool.gd` 同檔的並列 inner class**,不得獨立成檔、不得擁有自己的 `class_name`。

## Implementation Notes

出自 ADR-0002 機制五/五之二:

1. **兩個結果型別(inner class,見上方同檔強制規則)**:

   ```gdscript
   class AffinityReadResult extends RefCounted:
       var rejection: ReadRejection = ReadRejection.NONE   # 必須先檢查此欄位
       var value: float
       var t_query: int
       var n_pair: int
       var diagnostic_visited_count: int  # QA-only,見 S-007——業務邏輯不得依賴此欄位

   class ShapeFeatureResult extends RefCounted:
       var rejection: ReadRejection = ReadRejection.NONE
       var reversal_count: int
       var source_distribution: Dictionary
       var time_distribution: Variant
       var source_polarity: Dictionary
       var total_churn: float
       var segment_profile: Variant
       var low_confidence: Variant
       var source_absence: Dictionary
       var n_pair: int
       var t_query: int
       var c_now: int
       var diagnostic_visited_count: int
   ```

   本 story 只交付**型別定義本身與哨兵值的填寫規則**——`ShapeFeatureResult` 的七項形狀特徵欄位(`reversal_count`/`source_distribution`/`time_distribution`/`source_polarity`/`total_churn`/`segment_profile`/`low_confidence`/`source_absence`)的**實際計算邏輯**屬 S-007,本 story 只保證欄位存在、拒絕時的哨兵值正確。
2. **`t_query` 的型別閘門(機制五,先於任何其他運算)**:

   ```gdscript
   match typeof(t_query):
       TYPE_NIL:   pass          # 走條件式預設查詢時點
       TYPE_INT:   pass          # 繼續後續值域檢查
       _:          return <rejection = ReadRejection.INVALID_T_QUERY_TYPE 的結果物件>
   ```

   🔴 **`match` 的 case 順序不可交換**(已實測)——若把 `_` 預設分支寫在 `TYPE_NIL` 之前,`null` 會被 `_` 提前吃掉,`TYPE_NIL` 分支變成不可達的死碼,且**引擎既不擋編譯、執行期也不印任何警告**。實作時不應調整這三個 case 的先後順序。
3. **`ReadRejection` 統一列舉(六值,機制五)**:

   ```gdscript
   enum ReadRejection {
       NONE,
       INVALID_PAIR,
       INVALID_T_QUERY_TYPE,
       FUTURE_TIME_QUERY,
       EMPTY_HYPOTHETICAL_SET,   # 僅 speculative_read(S-012,切片外)
       DEAD_PAIR_NOT_ALLOWED,    # 僅 speculative_read(S-012,切片外)
   }
   ```

   本 story 交付列舉本身與三個真實讀取函數(`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`)可達的四個值(`NONE`/`INVALID_PAIR`/`INVALID_T_QUERY_TYPE`/`FUTURE_TIME_QUERY`)。後兩個值(`EMPTY_HYPOTHETICAL_SET`/`DEAD_PAIR_NOT_ALLOWED`)屬公式四,S-006 只需要讓列舉包含它們(避免 S-012 落地時要改列舉型別),不需要讓任何本 story 的分支回傳它們。
4. **明文禁止 `if t_query != null and t_query > _t_now`**——對 `String` 會在**比較運算子處中止所在函式**(已實測)。`t_query` 的型別判定**只能用 `typeof()`**:不可用 `!= null`、不可用比較、不可用賦值進型別化變數當檢查。**`TYPE_FLOAT` 一律拒絕**(不接受 `3.0`)——理由與陷阱二(浮點截斷靜默通過值域檢查)相同。
5. **拒絕時哨兵值(機制五之二,逐欄位列全,本 story 必須照抄不得自行決定)**:

   **`AffinityReadResult`**

   | 欄位 | 哨兵值 |
   |---|---|
   | `value` | `NAN` |
   | `t_query` | `-1` |
   | `n_pair` | `-1` |
   | `diagnostic_visited_count` | `-1` |

   **`ShapeFeatureResult`**

   | 欄位 | 哨兵值 | | 欄位 | 哨兵值 |
   |---|---|---|---|---|
   | `reversal_count` | `-1` | | `source_absence` | `{}` |
   | `source_distribution` | `{}` | | `n_pair` | `-1` |
   | `time_distribution` | `null` | | `t_query` | `-1` |
   | `source_polarity` | `{}` | | `c_now` | `-1` |
   | `total_churn` | `NAN` | | `diagnostic_visited_count` | `-1` |
   | `segment_profile` | `null` | | `low_confidence` | `null` |

   🔴 **為何 `value`/`total_churn` 用 `NAN` 而不是 `0.0`**:多筆記錄正負相消時,**成功呼叫**完全可能算出 `0.0`;呼叫端若漏檢 `rejection`,拿到 `0.0` 無法區分「淨值為零」與「被拒絕」。同理 `diagnostic_visited_count` 用 `-1` 而非 `0`。**三個 `Dictionary` 欄位用 `{}` 而不是 `null`**——它們的成功型別是 `Dictionary`(非雙態),改成 `null` 會讓下游對它們的 `.has()`/`.get()` 操作變成中止風險。**三個雙態欄位維持 `null`**,因為 `null` 本來就是它們的合法成功值之一。
6. **型別通過後,`t_query` 大於目前 `_t_now`(僅適用三個真實讀取函數,不適用公式四)一律視為非法呼叫** → `FUTURE_TIME_QUERY`。**若 `t_query` 早於配對 p 最早一筆記錄的 `t_i`**:視同該配對在 `t_query` 當下 `n(p, t_query)=0`,回傳中性/哨兵值(此為合法情境,非拒絕)——本 story 需保證此分支不誤觸 `FUTURE_TIME_QUERY`。
7. **新增呼叫端義務(機制五之二)**:必須先確認 `result.rejection == ReadRejection.NONE`,才可讀取任何其他欄位。此義務已登記進 `docs/architecture/control-manifest.md`。
8. 🔴 **本 story 的三個讀取函數(`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`)只交付「入口 + `t_query` 閘門 + `pair` 序數驗證(機制四之四入口 3–5)+ 拒絕分流」**——`n(p)=0` 時的合法回傳、以及有記錄時的實際加權計算,屬 S-007。本 story 完成後,三個函數對非法輸入的行為應已完整可測;對合法輸入,可先回傳一個**佔位的中性值**(例如 `value=0.0`、空的形狀特徵),待 S-007 補上真正的計算邏輯——但這個佔位不得使 AC-36(本 story 的驗收條件)以外的任何 AC 誤判通過,故本 story 的測試範圍嚴格限定在型別/閘門/拒絕層級,不涉及加權公式的正確性。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-36**: **GIVEN** Delta Log 目前的全域好感度寫入計數器值 `t_now=N`(N≥0),**WHEN** 公式一/二/三**任一真實讀取函數**(`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`;**不含**公式四預判讀取,見 Formulas 公式四的豁免說明與 AC-50)以 `t_query=N+1` 呼叫,**THEN** 呼叫被拒絕並拋出驗證錯誤,不回傳任何讀值——呼應 Edge Cases「若 `t_query` 大於目前實際的 `t_now`」條款,比照 AC-30 系列的非法輸入拒絕行為。**(2026-08-03 第五輪修訂:原版本「任一讀取函數」的措辭與公式四的預判讀取設計互相矛盾,已限定範圍為三個真實讀取函數,見 /design-review 第五輪 systems-designer 審查發現。)**

🔴 **本 story 的 AC 歸屬只有這一條,但本 story 交付的範圍(型別 + 閘門)比這一條 AC 涵蓋的行為更廣**——其餘與讀取行為相關的 AC(AC-8/AC-34/AC-35/AC-50 等)依 EPIC.md 對照表歸屬 S-007/S-010/S-012,因為它們斷言的是**實際計算結果**,不是純粹的閘門行為。本 story 的測試範圍以 AC-36 為準,另補充 EPIC.md 提及但未單獨列 AC 編號的「未來 `t_query` 拒絕」擴及 `shape_feature_read` 之驗證(GDD 明文「閘門在 006;010 落地後須擴及 `shape_feature_read`」——`shape_feature_read` 本身也是三個真實讀取函數之一,本 story 的閘門本就涵蓋它,此處只是提醒 S-010 落地後其新增欄位不得繞過此閘門)。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_data_pool_read_gate_test.gd`

預期涵蓋:

- `test_combat_strength_read_rejects_future_t_query`(AC-36)
- `test_narrative_depth_read_rejects_future_t_query`(AC-36)
- `test_shape_feature_read_rejects_future_t_query`(AC-36)
- `test_t_query_string_type_returns_invalid_t_query_type_without_aborting`(型別閘門,`typeof()` 三分支)
- `test_t_query_float_type_returns_invalid_t_query_type`(浮點一律拒絕)
- `test_t_query_null_falls_through_to_default_query_point_branch`(`match` case 順序驗證,防止未來重排)
- `test_rejected_read_result_carries_nan_sentinel_for_value`(哨兵值——`AffinityReadResult`)
- `test_rejected_shape_feature_result_carries_full_sentinel_table`(哨兵值——`ShapeFeatureResult` 11 欄逐一斷言)
- `test_t_query_earlier_than_earliest_record_is_not_a_rejection`(早於最早記錄 ≠ 拒絕,是合法 `n(p)=0`)

## Out of Scope

- **加權計算邏輯本身**(公式一/二/三的實際數學)——屬 S-007。
- **`n(p)=0` 的完整合法回傳值**(七項形狀特徵的哨兵/中性值)——屬 S-007。
- **陣亡配對的條件式預設查詢時點**(`t_death(pair)` 作為省略 `t_query` 時的預設)——屬 S-007,本 story 只保證省略時能落到「條件式預設查詢時點」這個分支,不決定該分支實際算出什麼。
- **`speculative_read()`/公式四**——屬 S-012(切片外),本 story 只在 `ReadRejection` 列舉裡預留其兩個專屬值,避免列舉型別日後變動。
