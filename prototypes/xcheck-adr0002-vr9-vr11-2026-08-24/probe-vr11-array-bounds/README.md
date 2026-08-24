# VR#11 探針 —— 型別化 `Array` 越界索引讀取

**狀態:尚未執行。** 本探針由 `godot-gdscript-specialist` 撰寫,依協調流程規定
不自行執行,交由協調者用下方指令實跑並回填「結果」與「結論」兩節。

## 假設 / 要回答的問題

ADR-0002 機制二的 `AffinityRecordList` 提供 `get_at(index: int) -> AffinityRecord`
(`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`
第 148、775 行),內層儲存為型別化 `Array[AffinityRecord]`。ADR 文件自己在 VR 表
第 11 項寫明:「未查證(2026-08-21 新增)。四支探針測的全是型別化 `Dictionary`
對缺鍵 subscript(中止),不得沿用到 `Array`——不同容器、不同操作。**本項直接
決定 `get_at()` 是否需要自帶邊界檢查**」。

本探針測型別化 `Array`(`Array[int]`、`Array[Dictionary]`)在下列情況的行為:

1. `arr[arr.size()]`(剛好越界一格)
2. `arr[999]`(遠大於 `size()`)
3. `arr[-1]`(非空陣列)—— Godot 是否支援負索引?
4. `arr[-1]`(**空**陣列)—— 與非空陣列的 `-1` 是否行為不同?
5. `arr[-999]`(非空陣列,深度負索引)
6. `arr[0]`(空陣列)
7. `Array[Dictionary]` 重跑 #1、#3,確認元素型別不是純量時行為一致
8. 若 `Array` 有 `.get()` 方法,同樣情況下它與 `[]` 的行為是否不同——先用
   `reload()` 的 `Error` 回傳值確認**這個方法是否存在**(這本身就是一個未知數,
   不是型別化 `Array` 常見到會被順手假設有的方法),存在才進一步測執行期行為

## 為什麼是阻擋級

ADR 文件自己寫明這個答案「直接決定 `get_at()` 是否需要自帶邊界檢查」——若型別化
`Array` 的越界讀取是**中止呼叫函式**(如同型別化 `Dictionary` 對缺鍵讀取的既有
結論),那麼 `get_at()` 目前的簽章(裸回傳 `AffinityRecord`,無拒絕碼)在越界時
就會讓呼叫端函式整個中止,而不是回傳某種可辨識的失敗值——這對呼叫端的意義,與
「印錯誤但繼續、回傳 `null`」是完全不同的兩種契約,必須先測出來才能決定
`get_at()` 要不要包一層邊界檢查。

## 如何重跑

```bash
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
cd prototypes/xcheck-adr0002-vr9-vr11-2026-08-24/probe-vr11-array-bounds
mkdir -p logs
"$GODOT" --headless --path . --import > logs/00-import.txt 2>&1
"$GODOT" --headless --path . > logs/run1-unfiltered.txt 2>&1
```

`--import` 這一步**在本探針嚴格來說不是必要的**——本探針沒有任何 `class_name`
宣告或跨檔案類別引用(`probe_get_method.gd` 是 `extends RefCounted`,由
`runner.gd` 用 `ResourceLoader.load()` 依明確路徑載入,不靠 `class_name` 全域
索引)。保留這一步是為了與本專案其餘探針一致,並避免匯入雜訊混進
`run1-unfiltered.txt`。

`main_scene` 固定指向 `scenes/Main.tscn`。

## 探針設計

`scripts/runner.gd`(`extends Node`)每個風險讀取各自關在自己的函式裡,且**同一
函式**在讀取之後立刻印 `AFTER_READ`。若 `AFTER_READ` 沒有出現在 log 裡,代表該
讀取中止了那個函式的剩餘執行;呼叫端(`_ready()`)在呼叫每個 case 函式之後,
**另外**印一行 `RETURNED_TO_READY`,用來獨立確認「中止」是只影響那一個函式,還是
會往上層繼續中止——這正是任務指定要區分清楚的兩件事(印錯誤但繼續執行 vs.
中止呼叫端函式),本專案先前已有把兩者搞混的紀錄
(`docs/engine-reference/godot/modules/scripting-typing.md` 第 2 節有明確記載
`Dictionary` 版本的正確用詞是「中止呼叫函式」)。

`.get()` 是否存在是編譯期問題(對靜態型別的 `Array[int]` 呼叫未知方法,應該在
編譯期就能被型別檢查器抓到),故用 `scripts/probe_get_method.gd` +
`ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `.reload()` 的 `Error` 回傳值
判斷,**不用「`load()` 不是 `null`」**,沿用本專案既有探針紀律
(`prototypes/xcheck-adr0002-review-2026-08-24/scripts/runner.gd` 前例)。只有
確認編譯得過,才會執行 9b 的執行期行為比對;若編譯不過,直接記錄「不存在」並
略過比對,不硬湊結果。

## 結果

*(待協調者實跑後回填。預期 log 位置:`logs/run1-unfiltered.txt`。逐案對照表:)*

| # | 測項 | BEFORE_READ 出現? | AFTER_READ 出現?(function 是否中止) | RETURNED_TO_READY 出現?(中止是否往上傳染) |
|---|---|---|---|---|
| 1 | `Array[int]` 剛好越界一格 | | | |
| 2 | `Array[int]` 遠大於 size | | | |
| 3 | `Array[int]` 非空,`-1` | | | |
| 4 | `Array[int]` **空**,`-1` | | | |
| 5 | `Array[int]` 非空,`-999` | | | |
| 6 | `Array[int]` 空,`0` | | | |
| 7 | `Array[Dictionary]` 剛好越界一格 | | | |
| 8 | `Array[Dictionary]` 非空,`-1` | | | |
| 9 | `.get()` 方法是否存在(編譯期) | — | — | — |
| 9b | `.get()` 越界一格(若 9 存在) | | | |

## 結論

*(待回填。特別注意:若 3 跟 4 的 `-1` 結果不同——例如非空陣列 `-1` 乾淨回傳最後
一個元素,空陣列 `-1` 卻中止——代表「負索引」本身不是無條件安全,取決於陣列是否
為空,這對 `get_at()` 的邊界檢查設計是關鍵資訊,不能只測一種情況就下結論。)*

## 未涵蓋

- **`PackedInt32Array` 等打包陣列型別未測**——ADR-0002 用的是型別化 `Array[T]`,
  不是打包陣列,兩者是不同的引擎型別,行為不能互相外推,本探針刻意只測前者。
- **多維或巢狀情況未測**(例如 `Array[Array[int]]`)——`get_at()` 的內層是單層
  `Array[AffinityRecord]`,不涉及巢狀讀取。
- **`.get()` 若存在,只測了一個越界情境(one-past-end)**——沒有把 `.get()` 對
  #2~#6 的每一種越界情況都重跑一遍;若 9 確認存在,協調者可能需要視情況決定是否
  值得補測全部組合,或者一個代表性案例已足夠支持 `get_at()` 的設計決策。
- **執行緒/並發情境下的越界讀取未測**——ADR-0002 對 `_records` 有 Mutex 保護,但
  本探針只測單執行緒下的邊界行為,不測併發讀寫時的行為。
