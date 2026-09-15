# Story S-004:池骨架與寫入路徑 —— 建構子預填 10 對、`append_record()` 六步驗證、七類拒絕

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:S-001、S-002、S-003

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules #1(per-pair 索引與效能介面要求)、Core Rules #2(寫入規則、陣亡配對的寫入限制)、Edge Cases(幅度為 0/來源非法/配對非法/NaN 的拒絕規則)
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制二(`_records` 容器與建構子預填)、機制四(寫入路徑——7 類拒絕情境)、機制四之二(型別保證三層與兩條邊界規則)、機制四之三(驗證順序與呼叫端型別義務)、機制四之四(8 個入口統一序數驗證,本 story 涵蓋其中入口 1)
- **Engine**:Godot 4.7.1

## 目標

把 `AffinityDataPool` 從 S-003 的骨架擴充成一個真正能寫入的池:建構子預填全部 10 對配對的空 `AffinityRecordList`,並實作 `append_record()` 的六步驗證順序(含 `t_death(pair)` 查詢,銜接 S-003)。做完之後,「打一張丙類卡 → 好感度數值真的改變」這條路的**寫入端**第一次成立——雖然還沒有真正的呼叫方(那是 S-008/S-009 的事)。

## 🔴 本 story 決定的原始碼目錄路徑

沿用 S-001~S-003 的決定:`src/gameplay/affinity_pool/affinity_data_pool.gd`(同一檔,S-003 已建立骨架,本 story 繼續往裡加)。

## Implementation Notes

出自 ADR-0002:

1. **建構子預填全部 10 對配對(機制二,R7E-2)**:

   ```gdscript
   var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]
   var _t_now: int
   var _pair_ordinals: Array
   var _character_ordinals: Array
   var _source_ordinals: Array

   func _init() -> void:
       _pair_ordinals = AffinityTypes.Pair.values()
       _character_ordinals = AffinityTypes.Character.values()
       _source_ordinals = AffinityTypes.Source.values()
       for p in _pair_ordinals:
           _records[p] = AffinityRecordList.new()
   ```

   🔴 **為什麼必須預填(探針 A 實測)**:型別化 `Dictionary` 對**從未寫入的鍵**做 subscript 讀取是 `SCRIPT ERROR: Out of bounds get index` 並**中止呼叫函式**——不是 `null`、不是預設值。若不預填,戰役開場 `_records` 是空的,第一次 `combat_strength_read(pair)`(S-007)必然中止,而 `n(p)=0` 是 GDD 跨結構不變量第 4 條明文的**合法**狀態,不是邊緣情境。
   `_pair_ordinals`/`_character_ordinals`/`_source_ordinals` 快取的理由:`.values()` 每次呼叫都重新配置一個新 `Array`,而讀取函數(S-007)是每回合多次的熱路徑;**不能用 `const`**——GDScript 的 `const` 不支援方法呼叫作初始化式。
2. **`AffinityDataPool` 內部三個私有驗證器(機制四之四,讀 `_init()` 快取而非每次呼叫 `.values()`)**:

   ```gdscript
   func _validate_pair_ordinal(pair: AffinityTypes.Pair) -> bool:      return _pair_ordinals.has(pair)
   func _validate_character_ordinal(c: AffinityTypes.Character) -> bool: return _character_ordinals.has(c)
   func _validate_source_ordinal(s: AffinityTypes.Source) -> bool:     return _source_ordinals.has(s)
   ```

   **這與 S-001 交付的 `AffinityTypes.is_valid_*()`(公開靜態,低頻)是兩條獨立實作路徑**——ADR-0002 刻意接受這個「同一個檢查散寫在兩個地方」的形狀(熱路徑不能每次重配 `.values()` 陣列、靜態函式讀不到實例成員),但兩條路徑對同一輸入必須回傳完全一致的結果(Validation Criteria #13,本 story 須寫對應的一致性測試)。
3. **`append_record()` 七類拒絕(機制四)**:

   ```gdscript
   enum WriteRejection {
       NONE,
       SERIALIZATION_WINDOW_ACTIVE,      # 序列化/還原非原子視窗期間 —— S-014 前恆為 false 分支
       ZERO_AMPLITUDE,                    # m == 0
       NON_FINITE_AMPLITUDE,              # m 為 NaN 或 ±Infinity
       INVALID_SOURCE,                    # source 不在三個合法值之內
       INVALID_PAIR,                      # pair 不在 10 對固定組合內
       DEAD_PAIR_COMBAT_CARD_FORBIDDEN,   # 配對已符合 t_death(pair) 條件,且 source == COMBAT_CARD
   }

   func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> WriteRejection
   ```

   **驗證順序(ADR-0002 決定,GDD 未規定順序,只規定情境本身須被涵蓋)**:
   1. `_serialization_tokens` 非空 → `SERIALIZATION_WINDOW_ACTIVE`(本 story 恆為空集合,此分支結構上不可達——見下方限制登記,**不得刪除這一步**,S-014 落地時要重新推導整個驗證順序的成本比留著這個恆假分支高)
   2. `m == 0.0` → `ZERO_AMPLITUDE`
   3. `is_nan(m) or is_inf(m)` → `NON_FINITE_AMPLITUDE`
   4. `_source_ordinals.has(source) == false` → `INVALID_SOURCE`
   5. `_pair_ordinals.has(pair) == false` → `INVALID_PAIR`
   6. `t_death(pair) != null and source == AffinityTypes.Source.COMBAT_CARD` → `DEAD_PAIR_COMBAT_CARD_FORBIDDEN`(查詢 S-003 交付的 `t_death()`)

   全數通過 → 建立 `AffinityRecord`,以 `_records[pair].append(record)` 附加,`_t_now += 1`,回傳 `NONE`。**任何拒絕路徑皆不遞增 `_t_now`、不附加記錄。**
4. 🔴 **陷阱二(EPIC.md 本節主戰場)——步驟 4/5 是唯一防線,不是防禦層**:探針 B 實測——越界 int(`-1`/`999`)原封不動抵達函式本體,零錯誤零檢查,**`INVALID_PAIR`/`INVALID_SOURCE` 是唯一防線**。⚠️ **本 ADR 結構上無法攔截的一類**:上游若夾帶 `float 3.7`,呼叫端**不中止**,參數靜默截斷為合法序數 `3` → 步驟 4/5 會通過 → 記錄寫進**錯誤配對**、回傳 `NONE`。值域檢查看到的已經是「合法的 3」,無從得知它原本是型別錯誤的浮點數。**唯一防線是呼叫端義務**(見下方第 6 點),本 story 不新增 `INVALID_TYPE` 拒絕碼——那會是一個結構上不可能被回傳的死碼。
5. **陣亡配對的寫入限制(機制四步驟 6)查詢 S-003 的 `t_death()`**——`t_death(pair) != null` 且 `source == COMBAT_CARD` 才拒絕;支援對話/劇情事件來源對陣亡配對正常成功(死後追憶,見 S-007 讀取端的凍結行為)。
6. 🔴 **呼叫端型別義務(機制四之三)——本 story 的 `append_record()` 不涵蓋**:型別化參數(`m: float`、`source: AffinityTypes.Source`、`pair: AffinityTypes.Pair`)的阻擋方式是**整段呼叫端函式中止**,不是可判斷的回傳值。GDScript 無 try/catch,型別錯誤是本系統錯誤處理哲學**唯一涵蓋不到**的失敗類別。**上游系統若持有來源不明的 `Variant`,必須在呼叫 `append_record()` 之前自行以 `typeof()` 收斂型別**——這是 S-008(丙類寫入轉接器)必須落實的義務,本 story 只交付 `append_record()` 本身,不代為驗證呼叫端。
7. **實作提醒(機制四原文)**:寫入路徑假設 `_records[pair]` 對全部 10 個合法配對永遠存在(建構子預填),不需要「檢查—建立」這一步;非法序數在入口即被步驟 5 攔下,不會走到 `_records[pair].append()`。
8. 🔴 **`INVALID_PAIR` 在接縫兩側同名不同義(EPIC.md 限制第 9 條)——本 story 內部自洽,但寫下這條給 S-008 看**:埠側(`AffinityWritePort.Rejection.INVALID_PAIR`)= 「這兩人在劇情上沒有關係線」;池側(本 story 的 `WriteRejection.INVALID_PAIR`)= 「配對序數不在 10 個合法值內」。**S-008 不可把兩者當同一件事直接轉送**——正解是靠 S-001 的驗證器讓池側這個值永遠不會發生(S-008 在呼叫 `append_record()` 之前,自己的 roster id → `Character` 對映邏輯已經先驗證過)。本 story 不需要為此做任何事,只需保證 `WriteRejection.INVALID_PAIR` 語意如上,不與埠側混淆。
9. 🔴 **陷阱四(EPIC.md)**:本 story 不新增 `class_name`(沿用 S-001~S-003 已建立的),但若這是工作副本第一次執行本張測試,仍須確認已 import 過。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-2**: **GIVEN** 一份已有 N 筆記錄的 Delta Log(N≥1),**WHEN** 呼叫寫入介面新增第 N+1 筆合法記錄,**THEN** 前 N 筆記錄的 `pair`、`m_i`、`t_i`、`c_i`、`source_i` 五欄位逐一比對前後完全相同(浮點欄位以位元完全相同或誤差 <1e-12 擇一判定相同),且新記錄的 `t_i` = 寫入前全域好感度寫入計數器值 + 1,`c_i` = 寫入當下的戰役刻度計數器現值。⚠️ **`c_i` 斷言需 S-005(戰役刻度)已落地**——本 story 若先於 S-005 完成,此條僅驗證 `c_i` 欄位存在且不變,精確值斷言待 S-005。
- **AC-7**: **GIVEN** 同一回合內連續觸發兩次好感度對話卡牌效果,**WHEN** 兩筆寫入依序呼叫寫入介面,**THEN** 兩筆記錄取得不同且遞增的 `t_i` 值(呼叫順序即記錄順序),整份 Delta Log 中任兩筆記錄的 `t_i` 皆不重複。
- **AC-24**: **GIVEN** 任一上游系統嘗試以 m=0 呼叫寫入介面,**WHEN** 該次寫入被提交,**THEN** 寫入被拒絕:全域計數器不遞增、Delta Log 不新增記錄、目標配對的 `n(p)` 不變(呼叫前後 `t_now` 與 `n(p)` 逐一比對相同)。
- **AC-27b**: **GIVEN** 一個不在合法 10 對組合內的配對值,**WHEN** 以該值呼叫寫入介面,**THEN** 寫入被拒絕(比照 AC-30 的非法配對拒絕行為),不遞增任何計數器、不產生記錄——證明沒有任何程式碼路徑能讓非法配對進入 Delta Log。
- **AC-28**: **GIVEN** 任一上游系統嘗試以不在三個合法值({combat_card, support_conversation, story_event})內的來源標籤呼叫寫入介面,**WHEN** 該次寫入被提交,**THEN** 寫入被拒絕:全域好感度寫入計數器不遞增、Delta Log 不新增記錄、目標配對的 `n(p)` 不變(呼叫前後 `t_now` 與 `n(p)` 逐一比對相同),行為與 AC-24(幅度為0)一致。
- **AC-29**: **GIVEN** 任一上游系統嘗試以幅度 `m=NaN` 呼叫寫入介面,**WHEN** 該次寫入被提交,**THEN** 寫入被拒絕,行為與 AC-24/AC-28 一致,不允許 NaN 以任何形式(例如靜默轉換為 0)進入 Delta Log。**只在池的直接單元測試可構造**——埠的 `m: int` 造不出 NaN,本 story 直接呼叫 `AffinityDataPool.append_record()` 構造。
- **AC-30**: **GIVEN** 任一上游系統嘗試以不在固定 10 對組合內的配對值呼叫寫入介面,**WHEN** 該次寫入被提交,**THEN** 寫入被拒絕,行為與 AC-24/AC-28/AC-29 一致(此 AC 亦作為 AC-27b 引用的具體驗證)。
- **AC-63**: **GIVEN** 配對 (A,B) 中 A 已陣亡(**不論 B 是否亦已陣亡,行為相同——見 Core Rules #2「陣亡配對的寫入限制」的判定條件為「至少一人」存在於陣亡標記表中,2026-08-10 第十輪補充,回應對抗性覆核 qa-lead 審查發現**),**WHEN** 以 `source_i` =「戰鬥好感度對話卡牌」對該配對寫入,**THEN** 拒絕並拋出驗證錯誤,全域計數器不遞增、`n(p)` 不變;**WHEN** 以「支援對話」或「劇情事件」對同一配對寫入,**THEN** 正常成功、正常遞增全域計數器。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_data_pool_write_path_test.gd`

預期涵蓋(對應上方 8 條 AC,另加陷阱驗證):

- `test_append_record_preserves_existing_records_and_advances_t_i`(AC-2 前半)
- `test_two_writes_in_same_turn_get_distinct_increasing_t_i`(AC-7)
- `test_append_record_rejects_zero_amplitude`(AC-24)
- `test_append_record_rejects_out_of_range_pair_ordinal`(AC-27b/AC-30)
- `test_append_record_rejects_invalid_source_label`(AC-28)
- `test_append_record_rejects_nan_amplitude`(AC-29)
- `test_append_record_rejects_combat_card_for_dead_pair_member_a`(AC-63 前半)
- `test_append_record_rejects_combat_card_for_dead_pair_member_b`(AC-63「不論 B 是否亦已陣亡」)
- `test_append_record_accepts_support_conversation_for_dead_pair`(AC-63 後半)
- `test_append_record_accepts_story_event_for_dead_pair`(AC-63 後半)
- `test_all_ten_pairs_readable_immediately_after_construction`(建構子預填的正面驗證,支撐 S-007 的 `n(p)=0` 讀取不中止)
- `test_two_ordinal_validation_paths_agree_on_same_inputs`(Validation Criteria #13,`AffinityTypes.is_valid_pair()` vs 內部驗證器)

## Out of Scope

- **`c_i` 欄位的精確戰役刻度值**——依賴 S-005,本 story 只保證欄位存在、寫入時取現值。
- **`AC-4`(呼叫圖分析)**——GDD 明文執行前提為技能卡牌/支援對話/章節戰役結構三者皆有實際程式碼,本切片不涵蓋(EPIC.md AC 對照表已排除)。
- **`SERIALIZATION_WINDOW_ACTIVE` 真實觸發**——依賴 S-014(切片外),本 story 的步驟 1 恆假分支不宣稱測過。
- **讀取路徑**(`combat_strength_read` 等)——屬 S-006/S-007。
- **呼叫端(S-008)是否正確履行 `typeof()` 收斂義務**——本 story 只交付被呼叫方,不驗證呼叫方。
