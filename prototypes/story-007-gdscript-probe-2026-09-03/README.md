# Story 007 拋棄式引擎探針(2026-09-03)

**用途**:`src/ui/cursor/cursor_state.gd`(Story 007,機制十)實作期間,對兩項引擎行為做
(A) 級實機驗證 —— 兩項都直接決定了實作寫法,不是好奇心。

**執行方式**(本探針是**獨立空專案**,不掛本專案任何程式碼;因此它驗證的是**引擎行為**,
不是本專案的類別 —— 依 `technical-preferences.md` 的 (A) 級定義,這一點必須明講):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path prototypes/story-007-gdscript-probe-2026-09-03 -s probe.gd
```

輸出:`logs/probe_output.txt`

## 兩項結論

| # | 問題 | 實測結果 | 影響到的實作決定 |
|---|---|---|---|
| 1 | `Signal` 的 `.emit` 能不能直接當成 `connect()` 的 `Callable`? | **能**,且引數原樣傳遞(`seen=42`) | `CursorState._init()` 以 `_reclaim.reset_triggered.connect(reclaim_reset_triggered.emit)` 做純轉發(R5-3),**不需要**多寫一個 `_on_...` 處理函式 —— 那會讓這個類別多出第七個底線開頭的方法,而「恰六條私有路徑」是 Validation Criteria #13 要靜態查核的不變式 |
| 2 | `get_script_property_list()` 回傳哪些成員? | **只回傳 `var`**。`const`、`enum`、`signal` 皆不出現;另有一筆 `usage=128`(`PROPERTY_USAGE_CATEGORY`)的合成分類標頭 | Story 007 新增的 6 個機制欄位**一定**會被 `tests/unit/cursor/state_host_test.gd` 的 AC-1 反射測試算進去 → 該測試的排除名單**必須**同步擴充,否則必紅。新增的 3 個 `enum` 與 1 個 `const` 則不會影響它 |

## 一句提醒

第 2 點是**先量到、才動手**的:若照直覺假設「反射只看得到我宣告的狀態欄位」,
會在跑全套測試時才發現 AC-1 紅掉,而那時已經很難分辨是「真的多了第四個狀態欄位」
還是「反射把機制欄位一起算進來了」——**這兩件事的正確處置完全相反。**
