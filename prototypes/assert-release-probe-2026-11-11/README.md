# assert() 在 debug / release 匯出的行為探針(2026-11-11)

狀態:已結論。技術債 C2/E6。

## 假說
release 匯出會整條移除 `assert()`,使前置條件防呆在發行版無聲失效。

## 做法
拋棄式空專案(系統暫存目錄,未載入本專案),原始檔副本在 `project/`(`core.gd` 是探針本體,
複製了 `cursor_types.gd` 的 encode/decode 的 assert 形狀)。引擎 4.7.1 console,全程 `--headless`,未開窗。
匯出:`--export-debug` / `--export-release`(Windows,pck 內嵌)。匯出的 exe 未複製進倉庫。
情境:(1) `-s` SceneTree 腳本  (1b) 編輯器引擎直接跑專案  (2) debug 匯出  (3) release 匯出。
release 匯出只有非 console 版 exe,以複製 debug 的 `.console.exe` 轉接器改名取得 console 輸出(輸出與 GUI 版相同,見 `run_release_gui.log`)。

## 結果 (A) —— 檔案:`project/core.gd`,log 如下

| 情境 | log | assert 觸發 | `AFTER_ASSERT` | 回傳 enum 的函式 | assert 內副作用 |
|---|---|---|---|---|---|
| 編輯器引擎 `-s` | `run_editor_s.log` | 是(SCRIPT ERROR) | **未印**(函式被中止) | `RET=0 is_NONE=true` | 求值 1 次 |
| 編輯器引擎跑專案 | `run_editor_main.log` | 是 | 未印 | `RET=0` | 1 |
| debug 匯出 | `run_debug.log`, `run_debug2.log` | 是 | 未印 | `RET=0 is_NONE=true` | 1 |
| **release 匯出** | `run_release.log`, `run_release3.log` | **否,無任何輸出** | **印出** `T1 AFTER_ASSERT` | **`RET=2 is_NONE=false`**(走到 assert 後的 return) | **0(運算式根本不求值)** |

原始行(release):
```
BUILD debug=false editor=false features release=true template=true
T1 BEFORE
T1 AFTER_ASSERT
T2 RET=2 is_NONE=false
T3 SIDE_EFFECT_EVALUATED_COUNT=0
T4 encode_tile((-1,0),13)=-1
T4 encode_tile((13,0),13)=13 (collides with (0,1)=13)
T5 decode_tile(-1,13)=(-1, 0)
```
原始行(debug 匯出):`T4 encode_tile((-1,0),13)=0`、`T5 decode_tile(-1,13)=(0, 0)`、`T3 SIDE_EFFECT_EVALUATED_COUNT=1`。

附帶發現:`decode_tile(5, 0)`(board_width=0,原本被 assert 擋)在 debug 下回 `(0,0)` 並繼續;
**在 release 下整個行程無聲結束,exit 127,無錯誤訊息、`DONE` 未印**
(`run_release3.log` 結尾停在 T5;`run_release_skip6.log` 加 `-- skip6` 跳過 T6 後 exit 0 且印 `DONE`,
可確認是 T6 的整數除以零造成)。debug 下該除法被 assert 先擋。

## 結論
假說成立 (A):release 匯出整條移除 assert(含運算式,副作用不執行),函式照常往下跑。
也印證 coding-standards 的現象:debug 下失敗的 assert 中止函式、回 enum ordinal 0;release 下則回後面的真實值。
