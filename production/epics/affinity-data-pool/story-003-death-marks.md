# Story S-003:陣亡標記表 —— `notify_death()` / `t_death()`

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:✅ Complete(狀態標記 2026-09-16 補正 —— 實作早已完成,但本欄一直停在 `Ready`)
> **估時**:S
> **依賴**:S-001

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules #1「陣亡標記表」段落、Core Rules #3「陣亡配對的預設查詢時點」對 `t_death(p)` 的定義
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制三(陣亡標記表——獨立結構,O(1))
- **Engine**:Godot 4.7.1

## 目標

建立陣亡標記表:一個獨立於 Delta Log 的 `Dictionary[Character, int]`,記錄「誰陣亡、陣亡當下的全域計數器值是多少」,以及對應的陣亡通知介面 `notify_death()`。做完之後,「角色陣亡」這件事第一次有資料通道可以被記下來——這是 S-004(寫入路徑的陣亡拒絕規則)與 S-007(讀取路徑的凍結規則)兩者都要查詢的表。

## 🔴 本 story 決定的原始碼目錄路徑

沿用 S-001/S-002 的決定:`src/gameplay/affinity_pool/`。**本 story 不新增獨立檔案**——陣亡標記表 `_death_marks` 是 `AffinityDataPool` 的內部欄位(ADR-0002 機制二逐字列出),本 story 交付的是 `notify_death()`/`t_death()` 兩個方法與 `_death_marks` 欄位本身,寫在 `affinity_data_pool.gd`(此檔由本 story 建立骨架,S-004 繼續往同一檔加東西——見 EPIC.md「開工順序」波次 1 的說明:S-002 與 S-003 是真平行,因為 S-002 寫 `affinity_record.gd`/`affinity_record_list.gd`,S-003 寫 `affinity_data_pool.gd`,不同檔案)。

## Implementation Notes

出自 ADR-0002 機制三:

1. **陣亡標記表資料結構**:

   ```gdscript
   var _death_marks: Dictionary[AffinityTypes.Character, int]   # 獨立於 Delta Log
   ```

   鍵為 `Character`(值型別,5 名固定主角之一),值為呼叫當下的 `_t_now`。**此呼叫不遞增 `_t_now`**(比照 GDD Core Rules #1「前進戰役刻度」的既有慣例——記錄呼叫當下的現值,不推進計數器本身)。
2. **介面**:

   ```gdscript
   func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult
   ```

   `DeathNotifyResult` 三值(ADR-0002 機制四之四補完):

   ```gdscript
   enum DeathNotifyResult {
       NONE,
       SERIALIZATION_WINDOW_ACTIVE,
       DUPLICATE_DEATH_NOTIFICATION,
       INVALID_CHARACTER,
   }
   ```

   本 story **只交付 `DUPLICATE_DEATH_NOTIFICATION`/`INVALID_CHARACTER`/`NONE` 三個分支**——`SERIALIZATION_WINDOW_ACTIVE` 依賴序列化生命週期權杖集合,屬 S-014(切片外)。本 story 的 `notify_death()` 實作**必須把該分支的檢查點留在程式碼結構裡**(例如以 `# TODO(S-014): SERIALIZATION_WINDOW_ACTIVE 檢查` 標註,或直接讀一個恆為空的 `_serialization_tokens` 佔位欄位),不得讓 S-014 落地時要重寫整個驗證順序——理由與 EPIC.md 限制表第 3 條(`SERIALIZATION_WINDOW_ACTIVE` 是一條測不出真陽性的分支)相同。
3. **驗證順序**:先 `.has(character)` 檢查冪等性(已存在 → `DUPLICATE_DEATH_NOTIFICATION`,不覆寫既有標記),再檢查序數合法性(非法 → `INVALID_CHARACTER`)——🔴 **順序須注意**:若序數非法,`.has()` 對非法序數必然回傳 `false`(不在鍵集合中),故序數檢查放在冪等性檢查之前或之後皆不影響正確性,但**必須在寫入 `_death_marks[character] = _t_now` 之前**完成——非法序數若不擋,會靜默寫入非法鍵(見下方陷阱二)。
4. 🔴 **`t_death(pair: Pair) -> Variant`(回傳 `int` 或 `null`)**:對 `pair` 的兩名成員各查一次 `_death_marks`(至多 2 次鍵查找,O(1)),取較早值;兩者皆不存在時回傳 `null`。**呼叫端義務(ADR-0002 機制四之三之二,`Variant` 出口 #6)**:呼叫端必須先 `typeof()`/null 檢查,**絕不直接做數值比較**——已實測 `is_finite`/`==`/`>=` 等操作對非數值型別皆會中止所在函式,`null` 亦不安全。
5. 🔴 **陷阱二(EPIC.md)適用本 story**:`notify_death()` 若不先驗證序數合法性,`_death_marks[非法序數] = _t_now` 會**靜默寫入非法鍵**——ADR-0002 明文指出這是修訂初稿曾漏掉的具體反例(R7-P1 修法列表第 2 項)。本 story 必須用 `_validate_character_ordinal()`(或等效的 `AffinityTypes.is_valid_character()`)在寫入前擋下。
6. 🔴 **`_death_marks` 刻意不預填,一律 `has()` 守衛——與 S-004 的 `_records` 預填策略相反,不要「為了一致性」套用同一套**。理由(ADR-0002 逐字):`_death_marks` 的**鍵存在本身就是「該角色已陣亡」**——預填會讓 5 名角色全部變成「已陣亡」,摧毀語意。`import_state()`(S-013,切片外)亦不預填。已登記禁令 `death_marks_prefill_or_unguarded_read`。本 story 的 `_init()` **不得**對 `_death_marks`做任何預填動作。
7. **文件註解**:`notify_death()`/`t_death()` 為公開方法,須有 `##` 文件註解,說明回傳值語意與 `DeathNotifyResult` 各分支。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-73**(陣亡通知介面基本功能): **GIVEN** 陣亡標記表為空,**WHEN** 以角色 X 呼叫陣亡通知介面,**THEN** 陣亡標記表新增一筆 `(X, 呼叫當下的全域好感度寫入計數器現值)`,全域好感度寫入計數器**不**遞增(呼叫前後 `t_now` 相同)。**邊界案例(2026-08-10 第十輪新增,回應對抗性覆核 systems-designer 發現此邊界完全未測)**:**GIVEN** 這是戰役最初,`t_now=0`(尚無任何好感度寫入發生過),**WHEN** 角色 Y 於此時陣亡並呼叫陣亡通知介面,**THEN** 陣亡標記表新增一筆 `(Y, 0)`,此標記值合法(見上方 Dependencies 反序列化驗證規則值域修正為 ≥0),不觸發任何驗證錯誤——證明 `t_now=0` 時陣亡是合法情境,不是資料損毀信號。
- **AC-74**(陣亡通知冪等性拒絕): **GIVEN** 陣亡標記表已含角色 X 的標記,**WHEN** 再次以角色 X 呼叫陣亡通知介面,**THEN** 呼叫被拒絕並拋出驗證錯誤,陣亡標記表中 X 的既有標記值不變。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_data_pool_death_marks_test.gd`

⚠️ 本檔名刻意標注 `_death_marks`,以便與 S-004/S-005/S-006/S-007 各自的測試檔(同樣測 `AffinityDataPool`,但涵蓋不同機制切面)區分——四張 story 共用同一個實作檔 `affinity_data_pool.gd`,但依 EPIC.md 陷阱五各自維持獨立測試檔,不合併。

預期涵蓋:

- `test_notify_death_records_current_t_now_without_incrementing_it`(AC-73 主案例)
- `test_notify_death_at_t_now_zero_is_legal`(AC-73 邊界案例)
- `test_notify_death_twice_for_same_character_is_rejected`(AC-74)
- `test_notify_death_rejected_call_does_not_overwrite_existing_mark`(AC-74 後半)
- `test_notify_death_with_invalid_character_ordinal_is_rejected`(陷阱二,`INVALID_CHARACTER`)
- `test_death_marks_not_prefilled_all_five_characters_are_alive_initially`(禁令 `death_marks_prefill_or_unguarded_read` 的正面驗證)
- `test_t_death_returns_null_when_neither_member_has_died`
- `test_t_death_returns_earlier_value_when_both_members_have_died`

## Out of Scope

- **`SERIALIZATION_WINDOW_ACTIVE` 分支的真實觸發**——依賴 S-014(切片外)的序列化生命週期權杖集合,本 story 只保留檢查點結構,不宣稱測過。
- **陣亡配對的寫入拒絕(`DEAD_PAIR_COMBAT_CARD_FORBIDDEN`)**——屬 S-004,本 story 只交付 `t_death()` 供 S-004 查詢。
- **陣亡凍結的讀取行為**(`combat_strength_read`/`narrative_depth_read` 省略 `t_query` 時凍結於 `t_death(p)`)——屬 S-007。
- **陣亡標記表的持久化**(`export_state()`/`import_state()` 對 `death_marks` 的往返)——屬 S-013(切片外)。
