# `QueryResult` 骨架可行性探針(2026-10-12)

**為什麼有這支探針**:`technical-director` 於同日裁定 `QueryResult` 的酬載形狀為
「每支查詢一個具名子類別」,並交出可照抄的 GDScript 骨架 —— **但它誠實標示該骨架為 (C) 級:
沒有執行過引擎、沒有任何 log**。語法、`super(source)` 的呼叫形式、
`for r: QueryResult in results` 的迴圈變數標註皆未驗證。

本探針把其中**一個**前提升級為 (A) 級。

## 問的是什麼 / 答案是什麼

| # | 問題 | 答案 | 原始輸出行 |
|---|---|---|---|
| 1 | `Array[QueryResult]` 收不收**子類別**實例? | ✅ **收** | `PROBE1: Array[QueryResult] accepted 2 subclass instances` |
| 2 | `assert_same_version()` 同版本 | ✅ 回 `true` | `PROBE1: assert_same_version same-version -> true` |
| 3 | `assert_same_version()` 混版本 | ✅ 回 `false` **且觸發 `push_error`** | `PROBE1: assert_same_version mixed-version -> false` |
| 4 | `is_stale()` 語意 | ✅ 正確 | `move_result.is_stale() -> true`(建於版本 0,之後被推進)/ `stale_result.is_stale() -> false`(建於推進**後**) |

🔴 **第 1 項是整個裁決能否成立的前提** —— 若它是 `false`,`assert_same_version(results: Array[QueryResult])`
的簽章就必須改,**而那會動到 ADR-0001 的字面條文**。

⚠️ **第 4 項的變數命名會誤導**:`stale_result` 其實**不是**過期的那一個(它建立於版本推進之後)。
行為正確,命名不佳。協調者讀過原始碼確認語意沒有搞反。

## 🔴 這支探針**沒有**關掉的事(不要以為它關了)

**`technical-director` 列的「探針 2」——`QueryResult` ↔ `BattleState` 的互參照會不會觸發
`Cyclic reference`——本探針【沒有】測到。**

- **本探針測到的**:`query_result.gd` 宣告 `_version_source: BattleState`,探針腳本同時載入兩者 → 只證明「單向參照 + 探針腳本」可以解析。
- **真正的環是**:`battle_state.gd` 的 `preview_damage_breakdown()` **回傳 `DamageBreakdownResult`**
  → 而它 `extends QueryResult` → 而 `query_result.gd` 宣告 `BattleState` 型別欄位。
  **本探針執行時 `battle_state.gd` 還沒有引用任何子類別,所以那個環還沒成形。**

✅ **該項已於同日稍晚由遷移本身關掉**:簽章改完後,協調者獨立重跑全套 ——
`1127 test cases | 0 errors | 1 failures | 0 orphans`、`ENGINE EXIT CODE = 100`、
**`Parse Error` / `Cyclic` / `Abnormal exit` 皆為 0**。

🔴 **為什麼這一項特別值得寫下來**:它若發作是 parse error → 測試線 `exit 105`,
而本專案已登記「exit 105 時 `grep "Overall Summary"` 與 `grep " FAILED"` **兩個都回空**,
看起來跟乾淨通過一模一樣」。**所以它不能靠『測試沒紅』來判定,必須看引擎自己的 exit code。**

## 怎麼重跑

```bash
"<Godot 4.7.1 執行檔路徑>" --headless --path . -s prototypes/query-result-probe-2026-10-12/probe_array_typing.gd
```

⚠️ **輸出開頭會有四行 `Board.from_ascii` 的 `push_error`** —— 那是探針自己用了一個
3 列 × 5 寬的迷你棋盤(真實棋盤是 13×6),觸發 `story-016` 新增的載入時驗證。
**不是缺陷,反而順帶證明了那道驗證在跑**,且 `from_ascii()` 仍回傳可用的 `Board`(AC5)。

## 這支探針已被固化成常駐測試,可以丟掉

`tests/unit/gameplay/battle/query_result_test.gd` 的
`test_subclass_instances_accepted_into_typed_query_result_array` 就是第 1 項。
**探針會被遺忘,測試不會。** 本目錄保留只為留下原始 log 作為 (A) 級的物證。
