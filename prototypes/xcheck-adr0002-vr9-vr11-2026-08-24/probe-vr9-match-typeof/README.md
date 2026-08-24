# VR#9 探針 —— `match typeof(x)` 對 `TYPE_NIL` 分支的比對行為

**狀態:尚未執行。** 本探針由 `godot-gdscript-specialist` 撰寫,依協調流程規定
不自行執行,交由協調者用下方指令實跑並回填「結果」與「結論」兩節。

## 假設 / 要回答的問題

ADR-0002 機制五的讀取入口用 `match typeof(t_query)` 做三分支閘門
(`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`
第 450–454 行):

```gdscript
match typeof(t_query):
    TYPE_NIL:   pass          # 走上方的條件式預設查詢時點
    TYPE_INT:   pass          # 繼續後續值域檢查
    _:          return <rejection = INVALID_T_QUERY_TYPE 的結果物件>
```

ADR-0002 的 VR 表第 9 項（`architecture.yaml`/ADR 文件內的驗證需求表）明白記載:
「`XCHECK-4` 已間接查證『比較運算子對 `String` 中止』這一半,但 `match typeof(x)`
本身對 `TYPE_NIL` 的比對未直接測。不假設」。本探針直接測。

四個子問題:

1. `match typeof(null)` 是否真的命中 `TYPE_NIL` 分支?
2. 案例標籤寫成 `TYPE_NIL` 常數 vs 寫成字面量 `0`,行為是否相同?
3. 若 `match` 同時有 `TYPE_NIL` 分支與 `_` 預設分支,且**故意把 `_` 寫在
   `TYPE_NIL` 前面**,`null` 會不會被 `_` 提前吃掉(來源順序是否影響比對優先權)?
4. 完全沒有 `TYPE_NIL` 分支時,`null` 是否乾淨落到 `_`?

**順帶測**(任務要求的額外覆蓋,防止「enum 型別化參數對數值近親靜默轉換」那種
陷阱在 `match` 上重演,見
`docs/engine-reference/godot/modules/scripting-typing.md` 第 3 節):
`TYPE_FLOAT`、`TYPE_INT`、`TYPE_STRING`(必測三項)+ `TYPE_BOOL`、空 `Array`、
空 `Dictionary`、`Vector2`(額外覆蓋)是否各自命中自己的分支、互不越界。

## 為什麼是阻擋級

這是 ADR-0002 2026-08-21 R7E-6 BLOCKING 修訂(機制五 `t_query` 型別閘門)的地基。
若 `null` 不落在預期分支,或 `_` 分支的來源順序會影響比對結果,這道閘門就有可能
漏放非法輸入,而目前**完全沒有實測依據**——只有「`typeof(null) == 0`」這個間接
佐證(型別枚舉表查證),從未測過 `match` 陳述式本身的分支選擇邏輯。

## 如何重跑

```bash
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
cd prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr9-match-typeof
mkdir -p logs
"$GODOT" --headless --path . --import > logs/00-import.txt 2>&1
"$GODOT" --headless --path . > logs/run1-unfiltered.txt 2>&1
```

`--import` 這一步**在本探針嚴格來說不是必要的**——本探針全程沒有任何
`class_name` 宣告或跨檔案類別引用(`docs/engine-reference/godot/modules/scripting-typing.md`
第 8 節的假否證陷阱只在有 `class_name` 全域註冊時才會觸發)。仍然保留這一步是
為了與本專案其餘探針的執行順序一致,並避免首次無匯入執行時任何 `.tscn`/`.gd`
匯入雜訊混進 `run1-unfiltered.txt`,讓 log 乾淨對應本次要測的內容。

`main_scene` 固定指向 `scenes/Main.tscn`。

## 探針設計

單一腳本 `scripts/runner.gd`,`extends Node`,不涉及編譯期問題(沒有
`class_name`、沒有跨檔引用),因此**不使用**本專案的
`ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `reload()` 編譯檢查紀律——那套
紀律是用來回答「這份程式碼編譯得過嗎」,而本探針要回答的是「執行期 `match`
選中了哪一支分支」,兩者是不同層級的問題,不應混用工具。

四個 `_classify_*` 輔助函式(命名式分支、字面量 0 分支、`_` 提前分支、無
`TYPE_NIL` 分支)+ 一個 `_run_case()` 逐一印出 `RESULT` 開頭的單行結果,每行都
可獨立對應到 log 裡的一行,符合「一次只測一件事」的紀律。

⚠️ **一個沒有把握的編譯期風險**:`_classify_default_before_nil()` 故意把 `_`
寫在 `TYPE_NIL` 前面,這讓 `TYPE_NIL` 那個分支在「`_` 先到先贏」的語意下會是
不可達的死碼。我不確定 GDScript 的編譯器對這種形狀是「印警告後照常編譯」還是
「直接 Parse Error 擋下整個檔案」。若是後者,`run1-unfiltered.txt` 會只看到
一條 `Parse Error`,A/B/D 三組的結果也會一併拿不到——**這本身就是問題 3 的答案
之一**(順序若真的重要到會被編譯器直接擋下,那答案甚至比「執行期選錯分支」更
明確),不代表探針設計有誤,只是回填「結果」時要先看檔案是否整個編譯失敗,再
決定要不要拆成獨立檔案重測 A/B/D。

## 結果

*(待協調者實跑後回填。預期 log 位置:`logs/run1-unfiltered.txt`,搜尋
`RESULT case=` 前綴可抓出全部 13+2 行結論。)*

## 結論

*(待回填。)*

## 未涵蓋

- **只測了 `match typeof(x)`,沒有測 `match x` 對 `Variant` 本身直接比對**(例如
  `match t_query: null: ...`)——ADR-0002 的閘門寫的是 `match typeof(t_query)`,
  不是 `match t_query`,故本探針刻意只測前者,不代表兩者行為一致。
- **沒有測 `match` 對其他容器/物件型別的分支**(`TYPE_OBJECT`、`TYPE_CALLABLE`
  等)——ADR-0002 的三分支閘門本來就只關心 `TYPE_NIL`/`TYPE_INT`/其餘全部併入
  `_`,故本探針把重點放在必測的三項(`TYPE_FLOAT`/`TYPE_INT`/`TYPE_STRING`)加上
  少數額外覆蓋,不求窮舉所有 `TYPE_*`。
- **`_` 提前分支的測試只用 `null` 一種輸入**——沒有交叉測「`_` 提前 + 其他型別
  輸入(例如 int)」是否也表現一致,若協調者跑完發現順序真的有影響,可能需要
  補測更多輸入組合。
