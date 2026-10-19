# static var 可行性探針 —— story-002(最小設定畫面)主要技術決定的依據

**日期**:2026-10-19
**執行者**:`godot-specialist`
**引擎**:`C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`
(hash `a13da4feb`,專案釘死版本 4.7.1-stable)

## 問的是什麼

`story-002-minimal-settings-screen.md`「開工前必答的一題」要求在三條路(Autoload /
static var / 存檔系統)之間選一條,並在交付時寫下理由。本探針回答兩個具體問題
(不是訓練資料推測,是實機跑出來的):

1. GDScript 的 `static var` + `static func`,在一個**未被實例化、未註冊為 Autoload**
   的 `class_name` 類別上,是否真的能像單例一樣跨呼叫端共用狀態?
2. 🔴 **更關鍵的問題**:這個共用狀態,在本專案**真正用來跑測試的 GdUnit4 執行環境**下,
   是否真的會**跨不同測試檔案**洩漏?(這是 `GameSettings` 類別文件註解裡「已知代價
   第 2 點」要求 `reset_for_test()` 的直接依據 —— 不能只用訓練資料裡「static 通常
   是行程範圍」這種一般認知帶過,要實測本專案實際的測試執行環境。)

## 問題一:裸 SceneTree 腳本,基本行為

**檔案**:`GameSettingsProbe.gd`(`class_name GameSettingsProbe extends RefCounted`,
與正式實作 `src/core/settings/game_settings.gd` 的 `GameSettings` 結構逐字相同,
只改了類別名稱避免與正式類別撞名)、`probe_static_var.gd`(`extends SceneTree`)。

**指令**:
```
godot --headless --path . -s prototypes/godot-specialist-static-var-probe-2026-10-19/probe_static_var.gd
```

**原始輸出**(`run_output_headless.txt`):
```
Q1 initial GameSettingsProbe.is_egm_enabled() = false
Q2 after set(true), same class access = true
Q3 after reset_for_test() = false
```

**結論**:`static var` 不需要實例化、不需要 Autoload 註冊,`ClassName.static_func()`
直接可用;寫入後另一次呼叫端讀到的是同一份狀態;`reset_for_test()` 真的能把它
重設回預設值。這部分是「static var 可以當設定值的家」這個提案的基本前提。

## 問題二:🔴 GdUnit4 真實測試環境下,跨「不同測試檔案」是否共用狀態

**為什麼問題一不夠**:問題一只證明同一個 `_init()` 函式裡連續兩次呼叫會共用狀態 ——
這不足以回答「本專案的 GdUnit4 測試套件,把全部測試檔案跑在同一個引擎行程裡,
所以某條測試忘記重置,真的會污染另一條完全無關的測試檔案」這個具體風險有沒有發生。

**檔案**:`probe_gdunit_cross_test_a.gd`、`probe_gdunit_cross_test_b.gd`
(兩者皆 `extends GdUnitTestSuite`,是真正的 GdUnit4 測試套件,不是裸腳本;
檔名刻意讓 `_a` 字母序排在 `_b` 之前)。

- `probe_gdunit_cross_test_a.gd` 的 `test_a_writes_true_and_deliberately_does_not_reset()`:
  先呼叫 `reset_for_test()` 確認起點是 `false`,再 `set_egm_enabled(true)`,
  **刻意不呼叫 `reset_for_test()`** 就結束。
- `probe_gdunit_cross_test_b.gd` 的 `test_b_observes_whatever_state_test_a_left_behind()`:
  印出它觀察到的 `is_egm_enabled()` 值(不預設方向,讓實測輸出自己說話),再清理。

**指令**(真正的 GdUnit4 CLI 入口,比照 `tests/README.md` 記載的驗證指令,
只是把 `-a` 範圍限定在本探針目錄,避免跟正式測試套件混在一起跑):
```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a prototypes/godot-specialist-static-var-probe-2026-10-19
```

**原始輸出**(`run_output_gdunit_cross_test.txt`,已去除 ANSI 顏色碼节錄關鍵三行):
```
PROBE test_a: 已寫入 true,刻意不呼叫 reset_for_test(),交給 test_b 觀察
PROBE test_b: 觀察到 GameSettingsProbe.is_egm_enabled() = true (true 代表 static var 真的跨測試檔案共用狀態;false 代表每個測試檔案是獨立行程/獨立狀態)
Overall Summary: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Exit code: 0
```

**結論(實測,不是推論)**:`test_b` 觀察到的值是 `true` —— **確認** GdUnit4 把
`probe_gdunit_cross_test_a.gd` 與 `probe_gdunit_cross_test_b.gd` 這兩個完全不同的
測試檔案,跑在**同一個引擎行程、共用同一份 `static var` 狀態**裡。這正是
`GameSettings` 類別文件註解「已知代價第 2 點」描述的風險,也是為什麼所有呼叫
`GameSettings.set_egm_enabled()` 的測試都**必須**在收尾呼叫 `reset_for_test()` ——
不這樣做,會像本探針刻意示範的一樣,把狀態洩漏給下一個完全無關的測試檔案。

## 這份探針回答了什麼、沒回答什麼

**回答了**:`static var` 方案在技術上可行,且「跨測試共用狀態」不是一個理論風險、
是本專案實際測試執行環境下會真實發生的行為 —— 選這條路必須付
`reset_for_test()` 紀律這個代價,而不是可以日後再說的假設性擔憂。

**沒回答、也不試圖回答**:GdUnit4 測試套件之間的**執行順序**是否永遠是字母序、
是否可被依賴 —— 本探針只證明了「兩個檔案跑在同一行程、狀態真的會共用」,
不證明「a 一定先於 b」這件事本身是穩定契約。正式實作與測試不依賴任何特定執行順序
(每條測試在收尾各自呼叫 `reset_for_test()`),所以這個未回答的問題不影響
`GameSettings` 的設計,僅誠實登記不過度宣稱涵蓋範圍。

## 🔴 問題三(2026-10-19 協調者補寫):`OS.get_cmdline_args()` 收不收得到 `--capture-battle`

**本題的探針與 log 原本就跑了**(`probe_cmdline_args.gd` / `run_output_cmdline_args.txt` /
`run_output_cmdline_args_with_separator.txt`),**但結論沒有被寫進本 README**,
而寫進 `src/ui/shell/title_screen.gd` 的那個結論**方向是反的**。本節補上實測逐字:

```
不帶 -- :  get_cmdline_args()      = ["-s", "...probe_cmdline_args.gd", "--capture-battle"]
           get_cmdline_user_args() = []
帶 -- :    get_cmdline_args()      = ["-s", "...probe_cmdline_args.gd"]   ← 旗標不在這裡
           get_cmdline_user_args() = ["--capture-battle"]                  ← 在另一個 API
```

**結論**:`OS.get_cmdline_args()` **只在沒有 `--` 分隔符時**收得到這個旗標。
`should_auto_start_battle()` 只看前者,所以 **`exe -- --capture-battle` 會安靜地什麼都不做**。

⚠️ **這是已登記的已知限制,不是缺陷** —— 截圖工具的呼叫形式是 `exe --capture-battle`(無分隔符),
該形式下行為正確。**但它失效時不報錯**,所以 `title_screen.gd` 與
`tools/build/capture_window.ps1` 兩處都已明文寫下「不要加 `--`」與失效時的正確修法。

📌 **這一節存在的理由**:原本的狀態是「log 是對的、README 沒寫、程式碼註解寫了相反的結論」——
**而三者之中只有程式碼註解會被下一個人讀到。**
