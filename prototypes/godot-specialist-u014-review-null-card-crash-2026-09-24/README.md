# U-014 獨立覆核用探針(2026-09-24)—— **失敗的探針,保留作為兩個引擎事實的物證**

> 🔴 **這支探針沒有達成它的目的。** 保留它不是因為它有結論,
> 而是因為**它失敗的方式本身記錄了兩個會重演的引擎陷阱**,而那兩個陷阱的物證只在這裡。

## 它本來要做什麼

`godot-specialist` 在 U-014 獨立覆核中推導出一條崩潰路徑(`_card_confirming` 旗標設在
null 檢查之前 → 取消時解參考 `null.category`),想用引擎實測證實它,而不是只交一個
**(C) 級的推導結論**。

**結果:兩次執行都沒有取得結論。** 該缺陷後來由實作者用**注入法**(暫時改壞生產程式碼、
跑全套、確認具名測試轉紅、再還原)證實,原始輸出留在
`production/qa/evidence/story-u014-confirm-panel-evidence.md`,並已修正(提交 `62cd70d`)。

## 🔴 陷阱一:`extends SceneTree` 的進入點是 `_initialize()`,不是 `_init()`

第一版誤用 `_init()`。**後果不是報錯就停** —— 引擎起來了、腳本沒跑成,而且
**沒有任何東西會結束它**。本機因此累積 4 個空轉的 `Godot_v4.7.1-stable_win64` 行程,
由協調者量到並手動清除。

📌 **這與本專案長期記憶登記的「漏 `quit()` 的 headless 引擎會永遠空轉」是同一個後果,
但成因不同** —— 腳本裡**有**寫 `quit()`,只是那幾行從來沒有被執行到。
**所以「我有寫 `quit()`」不足以保證引擎會結束。**

對照組:`tests/gdunit4_runner.gd` 用的就是 `_initialize()`。

## 🔴 陷阱二:`-s` 直接跑腳本時,Autoload 不保證已掛上

`run_output.txt` 逐字:

```
SCRIPT ERROR: Compile Error: Identifier not found: CursorStateHost
   at: GDScript::reload (res://src/ui/battle/battle_screen.gd:1665)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
```

`CursorStateHost` 是專案已註冊的 Autoload(見 `.claude/docs/technical-preferences.md`
的 Autoloads 清單),而**任何相依於 `battle_screen.gd` 的拋棄式腳本會連帶編譯失敗**。

⚠️ **未查證的部分,不要當成已知**:本檔**不宣稱**已經釐清「為什麼在這個時機點找不到它」
(是 `-s` 的載入順序?是 `_init()` 階段太早?還是兩者都有?)。
第二版改用 `_initialize()` 後**未取得完成輸出**,所以**這兩種可能都沒有被排除**。
下一個要寫同類探針的人:**先假設會撞到這個,並準備好從 `run_output.txt` 對照**。

## 檔案

| 檔案 | 說明 |
|---|---|
| `probe_null_card_cancel_crash.gd` | 探針本體。**第一版的 `_init()` 錯誤已改為 `_initialize()`,但改完後未取得完成輸出** |
| `run_output.txt` | 第一次執行的原始輸出(第二次以 `>` 覆寫,但未寫入完整結果) |

**本目錄不是任何工作單的交付物**,不得被 `src/` 引用。
