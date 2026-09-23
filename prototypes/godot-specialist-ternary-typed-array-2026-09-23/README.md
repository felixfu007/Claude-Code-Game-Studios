# 三元運算式賦值進型別化容器 —— 邊界探針(2026-09-23)

## 驗證的假說

2026-09-23 本專案一次真實事故:一位實作者交回未跑過引擎的程式碼,協調者實跑後拿到
**451 個執行期 `SCRIPT ERROR`**,全部同一則訊息,出自：

```gdscript
var card_target_legal_ids: Array[int] = (
    _controller.legal_targets() if _card_selecting_target else []
)
```

（`_controller.legal_targets()` 宣告為 `-> Array[int]`，見
`src/gameplay/battle/battle_controller.gd:403`。）

協調者的推測機制：「三元運算式的 `else []` 是未型別化空陣列，整個運算式的推論型別
退化成裸 `Array`，賦值進 `Array[int]` 在執行期中止」——但協調者自己標註這只是推測，
本探針的任務就是把它變成實測，或推翻它。

## 怎麼跑

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/godot-specialist-ternary-typed-array-2026-09-23/probe_ternary_typed_array.gd \
  -- --case=<name>
```

`<name>` 是腳本 `_run_case()` 裡的 match 分支之一（`q1_true`、`q1_false`、
`q2_as_cast_false`、`q2_as_cast_true`、`q2_pretyped_var_false`、
`q2_typed_array_constructor_false`、`q3_string_false`、`q3_string_true`、
`q3_vector2i_false`、`q3_typed_dict_false`、`q3_typed_dict_true`、
`q3_plain_dict_false`、`q4_untyped_target_false`、`q4_untyped_target_true`、
`q5_typed_source_true`、`q5_typed_source_false`）。**每個案例獨立呼叫引擎一次**——
不是為了偷懶，是因為一次執行期 SCRIPT ERROR 會中止當下的呼叫函式，混在同一次呼叫裡跑
會讓後面的案例要嘛沒機會執行、要嘛被前一個案例的中止污染，無法乾淨歸因。

`--check-only`（不加 `--case`，直接對整份腳本跑）驗證靜態/parse 期是否有任何訊號。

## 現狀

已完成，結論見下方「發現」。原始輸出：`run_output.txt`（q1–q4 全部案例 + Shape A）、
`run_output_q5.txt`（q5 Shape B + `--check-only`）。

## 發現

### Q1：crash 是「必然」還是「只藏在某個分支」？—— 答案是後者，但要看兩個分支各自的來源

引擎的判定不是「這個三元運算式整體的靜態推論型別是裸 `Array`，所以賦值必炸」，而是
「**執行期實際選中哪個分支，就檢查那個分支的執行期值本身有沒有型別化容器標籤**」——
兩個分支各自獨立算帳。

用兩種對照 shape 逐一實測釘死：

| Shape | true 分支來源 | false 分支 | cond=true | cond=false |
|---|---|---|---|---|
| **A**（兩側皆未型別化，`q1_*`） | 呼叫回傳裸 `Array` 的函式 | `[]` | 中止 | 中止 |
| **B**（逐字比照正式事故，`q5_*`） | 呼叫回傳 `Array[int]` 的函式（`_get_typed_array_int()`，簽章比照 `legal_targets()`） | `[]` | **成功** | 中止 |

Shape A 兩側都中止，乍看像是「這行程式碼只要被執行就必炸」；但 Shape B 換成一個真正
宣告為 `-> Array[int]` 的來源後，cond=true 完全不炸，只有選中 `[]` 分支時才炸。
**Shape A 兩側都中止只是因為它兩個分支的執行期值剛好都是未型別化的，不是三元運算式
本身有「整體退化」這件事。** 對正式事故而言：`_card_selecting_target` 為 false（常見/
預設狀態）時每次執行都炸，為 true 時完全正常——是「藏在冷分支裡的地雷」，不是「這行
程式碼必炸」。

逐字錯誤（兩種 shape 訊息格式相同，只替換型別名稱）：
```
SCRIPT ERROR: Trying to assign an array of type "Array" to a variable of type "Array[int]".
```

覆蓋狀態：✅ 已驗證（`q1_true`/`q1_false`/`q5_typed_source_true`/`q5_typed_source_false`，
見 `run_output.txt` 與 `run_output_q5.txt`）。

### Q2：標註能不能救？—— 能，但只保護「被標註的那一個分支」

三種寫法皆實測成功（`is_typed()` 為 `true`）：

1. `([] as Array[int])` —— `as` 轉型（`q2_as_cast_false`）
2. 先宣告 `var empty_typed: Array[int] = []` 再放進分支（`q2_pretyped_var_false`）——
   **這是正式事故實際採用的修法的精神**，實際程式碼進一步不用三元運算式，改成先宣告
   `var x: Array[int] = []` 再用 `if` 賦值（見 `src/ui/battle/battle_screen.gd` 的
   `card_target_legal_ids`）
3. `Array([], TYPE_INT, "", null)` 建構子明寫型別參數（`q2_typed_array_constructor_false`）
   —— 可行但可讀性最差，不建議常規使用

🔴 **三種修法都只保護「被標註的那一個分支」，不會讓另一側免疫**：`q2_as_cast_true` 把
`as` 轉型套在 false 分支，但 cond=true 選中的是另一個未型別化的 true 分支（Shape A 的
來源）——依然中止。與 Q1 的結論一致：失敗與否逐分支獨立判定，修好一側不會連帶修好
另一側。

覆蓋狀態：✅ 已驗證四個子案例，皆與預期一致。

### Q3：同樣的形狀套在 `Array[String]` / `Array[Vector2i]` / `Dictionary` 上，行為一致嗎？

`Array[String]`（`q3_string_false`/`q3_string_true`，兩側皆用未型別化來源，Shape A 形狀）、
`Array[Vector2i]`（`q3_vector2i_false`）、**型別化 `Dictionary[String, int]`**
（`q3_typed_dict_false`/`q3_typed_dict_true`）三者的錯誤訊息格式完全比照，只替換型別
名稱；`Dictionary` 版本逐字：
```
SCRIPT ERROR: Trying to assign a dictionary of type "Dictionary" to a variable of type "Dictionary[String, int]".
```
**這條陷阱不是 `Array[int]` 專屬，是 `Array[T]`、`Dictionary[K,V]` 共通的邊界行為。**
（未測 `q3_string`/`q3_vector2i` 的 Shape B 對照版本——即 true 分支換成真正型別化來源；
基於 Q1 的機制已經確立，判斷會與 `Array[int]` 一致，但這是外推，非直接量測，誠實登記
為未測。）

覆蓋狀態：✅ 已驗證 Shape A 對三種容器皆一致；⚠️ 未驗證 Shape A 之外每種容器的 Shape B
版本（外推，非量測）。

### Q4：反過來，賦值目標是裸 `Array`/`Dictionary`（未型別化）呢？

`q4_untyped_target_false`、`q4_untyped_target_true`、`q3_plain_dict_false` 三個案例
在任何分支組合下都**完全不會中止**——未型別化的 `Array`/`Dictionary` 本身不要求元素
型別一致，執行期直接接受任何陣列/字典值。**這條陷阱的必要條件是賦值目標本身宣告了
型別化容器**，不是三元運算式本身有問題。

覆蓋狀態：✅ 已驗證。

### Q5：有沒有任何靜態訊號會事先講？

`--check-only`（對整份含所有中止案例的腳本跑一次）：**`EXIT_CODE=0`，無任何輸出**——
連一行警告都沒有。此陷阱從編譯期/靜態分析角度完全不可見，唯一能抓到它的方式是實際
執行到那一行。這與協調者原先的宣稱（「parse 得過、靜態檢查零警告」）一致，已從「宣稱」
轉為「實測」。

⚠️ 編輯器 GUI 的即時診斷面板**未測試**——本庫方法論一貫只用 headless/`--check-only`，
未觸及 GUI 診斷路徑,比照 `docs/engine-reference/godot/modules/scripting-typing.md`
第 8 節已登記的同類方法論限制,不是本探針新增的缺口。

覆蓋狀態：✅ `--check-only` 已驗證；⚠️ 編輯器 GUI 診斷面板未測（方法論限制,非本探針
遺漏）。

## 交付物

- `probe_ternary_typed_array.gd` —— 自含探針腳本,16 個具名案例
- `run_output.txt` —— q1/q2/q3/q4 全部案例的原始輸出
- `run_output_q5.txt` —— q5（Shape B,逐字比照正式事故）+ `--check-only` 的原始輸出
- 本檔案已寫入 `docs/engine-reference/godot/modules/scripting-typing.md` 第 9 節
