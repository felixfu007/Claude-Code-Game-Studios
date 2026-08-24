# ADR-0002 核准條件一 —— VR#9 / VR#11 收尾探針(2026-08-24)

**狀態:兩支探針皆已寫好,尚未執行。** 由 `godot-gdscript-specialist` 撰寫,依
協調流程規定不自行執行探針——這是機械工作,交由協調者用各子目錄 README 裡的
指令實跑,再回填「結果」與「結論」兩節。

## 背景

架構總監判定 ADR-0002 核准條件一還卡著兩個**真缺口**,理由是「最壞的答案會改變
設計」:

| VR # | 項目 | 卡住的設計點 |
|---|---|---|
| 9 | `match typeof(x)` 對 `TYPE_NIL` 分支的比對行為 | 機制五 `t_query` 三分支型別閘門(2026-08-21 R7E-6 BLOCKING 修訂)的地基 |
| 11 | 型別化 `Array` 對越界索引的讀取行為 | 直接決定 `AffinityRecordList.get_at()` 是否需要自帶邊界檢查 |

兩項在 ADR-0002 文件本身(VR 表第 9、11 列)都標「未查證」,且明文指出現有探針
**不能**外推到這兩個問題——VR#9 只有「`typeof(null)==0`」這個間接佐證,從未測過
`match` 陳述式本身；VR#11 現有四支探針全測型別化 `Dictionary`,型別化 `Array`
零覆蓋。

## 兩支探針

| 子目錄 | 對應 VR # | 一句話 |
|---|---|---|
| `probe-vr9-match-typeof/` | 9 | `match typeof(x)`:`null` 是否命中 `TYPE_NIL`、常數 vs 字面量 `0`、`_` 順序是否影響優先權、`TYPE_FLOAT`/`TYPE_INT`/`TYPE_STRING` 是否互不越界 |
| `probe-vr11-array-bounds/` | 11 | 型別化 `Array` 越界讀取:剛好越界一格、遠越界、負索引(含空陣列的差異)、空陣列讀首位、`.get()` 是否存在及其行為差異 |

每個子目錄都是獨立的 Godot 4.7.1 專案(`project.godot` + `scenes/Main.tscn` +
`scripts/`),各自有完整的 README(假設、如何重跑、探針設計、結果表格骨架、
未涵蓋),不是共用一個專案跑兩套邏輯——這樣任一支探針的執行期錯誤不會污染
另一支的 log。

## 完整跑法(協調者專用)

```bash
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

# VR#9
cd prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr9-match-typeof
mkdir -p logs
"$GODOT" --headless --path . --import > logs/00-import.txt 2>&1
"$GODOT" --headless --path . > logs/run1-unfiltered.txt 2>&1
cd -

# VR#11
cd prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr11-array-bounds
mkdir -p logs
"$GODOT" --headless --path . --import > logs/00-import.txt 2>&1
"$GODOT" --headless --path . > logs/run1-unfiltered.txt 2>&1
cd -
```

**兩支探針都不含任何 `class_name` 宣告或跨檔案類別引用**,因此嚴格來說都不會
踩到 `docs/engine-reference/godot/modules/scripting-typing.md` 第 8 節記載的
「`class_name` 全域註冊依賴匯入產生的快取」假否證陷阱。保留 `--import` 這一步
只是為了與本專案其餘探針的執行順序一致、避免匯入雜訊混進主要的
`run1-unfiltered.txt`,並非本探針本身需要它才能拿到正確結論。

兩支探針執行完都應該 `exit 0`,`get_tree().quit()` 是每支 `runner.gd` 的最後
一行。若任一支非 0 結束或印出非預期的 `SCRIPT ERROR`/`Parse Error`,那本身就是
一個需要回報的發現,不要當雜訊過濾掉——保留在未過濾 log 裡。

## 每支探針預期回答的問題(供跑完對照;若結果與此不同,那本身就是發現)

**VR#9(`probe-vr9-match-typeof/`)**:

- 預期 `null`(`typeof()==0`)命中 `TYPE_NIL` 分支,而非落入 `_`。
- 預期 `TYPE_NIL` 常數與字面量 `0` 作為 case 標籤行為完全等價(兩者本質是同一個
  整數值),`agree=MATCH`。
- **這一項沒有把握**:`_` 提前於 `TYPE_NIL` 時,`match` 是否仍然選中更具體的
  `TYPE_NIL` 分支,還是因為 `_` 先出現而被提前吃掉。我對 GDScript `match` 的
  匹配順序語意沒有查證過的把握,寫這個子測項正是因為不確定,不是走個過場。
- 預期 `TYPE_FLOAT`/`TYPE_INT`/`TYPE_STRING`/`TYPE_BOOL` 等各自命中自己的分支,
  互不越界(不會出現 ADR-0002 已知的「enum 型別化參數對數值近親靜默轉換」那種
  跨型別誤判)。

**VR#11(`probe-vr11-array-bounds/`)**:

- 預期越界讀取(剛好越界一格、遠越界)的行為與型別化 `Dictionary` 缺鍵讀取一致
  ——即 `BEFORE_READ` 印出、`AFTER_READ` 不印出(中止該函式)、但
  `RETURNED_TO_READY` 仍會印出(中止不往呼叫鏈上層傳染)。這是類比既有
  `Dictionary` 結論做的推測,**不是已驗證的事實**,VR#11 之所以列為未查證正是
  因為「不同容器、不同操作,不得外推」。
- **負索引是本探針裡我最沒把握的一項**:是否支援 `arr[-1]` 這種 Python 風格的
  負索引存取,以及非空陣列與空陣列在 `-1` 上是否行為不同(例如非空陣列
  `-1` 乾淨回傳最後一個元素、空陣列 `-1` 因為換算後仍越界而中止)。這正是為何
  #3(非空)跟 #4(空)分開測,不能只測一種就下結論。
- **`.get()` 是否存在**:不確定型別化 `Array` 在 Godot 4.7.1 是否有 `Dictionary`
  風格的 `.get(index, default)` 方法。若編譯失敗(方法不存在),9b 會被跳過,
  這本身就是一個結論,不代表探針設計有缺陷。

## 寫作過程中發現的事

- **VR#9 與 VR#11 是兩種完全不同層級的問題**,不能用同一套判斷工具:VR#9 問的是
  「執行期 `match` 選中了哪一支分支」,必須靠印出實際執行到的分支名稱來回答;
  VR#11 混合了兩層問題——`.get()` 存不存在是**編譯期**問題(靜態型別檢查器該不
  該在解析階段就擋掉未知方法呼叫),越界讀取本身的中止/繼續行為則是**執行期**
  問題。一開始若把兩者混在同一套「跑起來看 exit code」的邏輯裡,會把「方法不
  存在的 Parse Error」跟「越界讀取的 SCRIPT ERROR」搞混成同一種失敗,因此
  `.get()` 檢查特別拉出來用 `reload()` 的 `Error` 回傳值單獨判斷,不跟其餘執行期
  case 共用邏輯。
- **GDScript 沒有辦法在同一個函式內,用単純的「印一行再印一行」判斷「中止」跟
  「繼續但印錯誤」以外的第三種可能**——例如「靜默回傳錯誤值、不印任何錯誤訊息、
  也不中止」。若 log 裡完全沒有任何 `SCRIPT ERROR`/`ERROR` 字樣,但 `AFTER_READ`
  也確實印出來了,那代表的是「安靜地繼續」而非「印錯誤後繼續」——這兩者在我的
  探針設計裡都會讓 `AFTER_READ` 出現,必須靠協調者對照 log 裡有沒有伴隨的錯誤
  訊息行,才能進一步區分「安靜繼續」vs.「印錯誤後繼續」這兩種子情況。README
  的結果表格只問了「AFTER_READ 出現與否」這個一階問題,協調者若要下更精細的
  結論,需要額外回頭讀 log 裡 `AFTER_READ` 那一行**前後**是否夾著錯誤訊息。
- 沒有辦法用純 GDScript 語法「同時」測試 `TYPE_NIL` 常數與字面量 `0` 在**同一個**
  `match` 陳述式裡的差異(一個 `match` 只能有一組 case 標籤,不能同時測兩種寫法
  對同一份程式碼的影響)——因此設計成兩個結構相同、只有 case 標籤寫法不同的
  獨立函式,靠比對兩者對同一組輸入的輸出是否一致來間接得出「等價」的結論,而非
  直接測「同一份程式碼裡兩種寫法哪個生效」。
