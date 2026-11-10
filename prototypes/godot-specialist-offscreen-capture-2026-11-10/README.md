# 螢幕外開窗取像素探針 (2026-11-10)

**假說**:Godot 4.7.1 視窗放在螢幕範圍外(-5000,-5000)、不搶焦點、`--audio-driver Dummy`,仍能從引擎內取到真實像素。
**狀態**:已結論。**判定:部分可行(啟動時位置設定不成立,事後 `window_set_position` 成立)。**
**方法**:拋棄式專案在 `%TEMP%/offscreen_probe_proj`(本資料夾存有同份副本:`project.godot`、`Probe.tscn`、`probe_main.gd`),
只有灰色(0.5)與紅色兩個色塊,未載入本遊戲。只用 Godot 自身 API,未用任何外部工具讀視窗/螢幕/行程。
引擎:`Godot_v4.7.1-stable_win64_console.exe`(不帶 `--headless`),`timeout 60`。共 3 次有效執行(另 1 次 `--import`)。

## 三次執行
| # | 設定 | 原始輸出 |
|---|---|---|
| 1 | 專案設定 `initial_position_type=0`、`initial_position=(-5000,-5000)`、`no_focus=true` + CLI `--position -5000,-5000` | `run_output_1.txt` |
| 2 | 不用上述位置設定,改在 `_ready()` 呼叫 `DisplayServer.window_set_position((-5000,-5000))` | `run_output_2_setpos.txt` |
| 3 | 只用專案設定(無 `--position`) | `run_output_3_projsettings_only.txt` |

## 四項量測(皆 (A) 級,探針 = `probe_main.gd`,原始行在上表各檔)
1. **位置是否被拉回**
   - 第 1 次(專案設定 + `--position`):`POS_T0=(0, 0)`、`POS_F9=(0, 0)` —— **啟動時設定的螢幕外位置被忽略/拉回主螢幕 (0,0),視窗在螢幕內。**
     (`SETTING init_pos=(-5000, -5000) type=0` 證實設定有被引擎讀到,只是沒生效;`--position` 同樣沒生效。)
   - 第 3 次(只用專案設定):`POS_T0=(0, 0)` 同上。
   - 第 2 次(事後 `window_set_position`):`SETPOS_CALLED`、`POS_T0=(-5000, -5000)`、`POS_F0/F4/F9` 與 `POS_END` 全為 `(-5000, -5000)` —— **事後設定成立,10 幀內未被系統拉回。**
2. **焦點**:三次的 `FOCUS_T0` / `FOCUS_F0/F4/F9` / `FOCUS_END` 全為 `false` —— **未拿到焦點**(`no_focus=true` 設定生效,讀回 `SETTING no_focus=true`)。
3. **像素**:三次皆 `IMAGE_IS_NULL=false`、`IMG_SIZE=(320, 180)`、`left=(0.502, 0.502, 0.502, 1.0) right=(1.0, 0.0, 0.0, 1.0)`,與色塊一致。**螢幕外(第 2 次)也取得真實像素。**
4. **逾時**:三次皆 `ENGINE EXIT=0`,無逾時。
5. **音訊驅動**:三次皆 `AUDIO_SERVER_DRIVER=Dummy`(`AudioServer.get_driver_name()`)—— 命令列覆寫生效,專案設定值為 `WASAPI`。(`AUDIO_OUTPUT_DEVICE=Default`、列表只有 Default。)

## 如實揭露(不淡化)
- **第 1、3 次視窗確實出現在主螢幕 (0,0)(主螢幕 1920×1200,另有第 2 螢幕),存活約數秒**;雖未拿焦點,但**可見於螢幕上**,違反「旁人看不到」。
- **第 2 次**:視窗由引擎先建立(依第 1、3 次證據,建立時位置為 (0,0)),`_ready()` 才移走。**建立到被移走之間是否有可見的閃現,未驗證**(沒有外部工具可看,也不得使用)。實務上視窗在 `_ready()` 之前很可能已短暫上屏。
- 未驗 (C):`initial_position_type` 其他值(1~3)、4.7.1 是否在別處有「螢幕外初始位置」API;`engine-reference` 對這些設定零命中(以實測為準)。
- 未驗:位置 -5000 在不同螢幕排列/縮放下是否仍不被拉回;長時間(>10 幀)是否被拉回;螢幕外視窗在真正的遊戲場景(大量繪製)下的行為。
- 行程清理:跑完 `tasklist` 仍見 2 個 `Godot_v4.7.1-stable_win64` 行程(PID 41948、38304),**我的三次執行皆 exit 0 正常結束,判斷為本機另有的既有行程,但無法確認**(查命令列被權限擋下,未再嘗試)。

## 結論
- 可用:**不搶焦點**、**靜音(Dummy 驅動)**、**螢幕外也能取像素**、**事後移到螢幕外成立**。
- 不可用:**啟動時指定螢幕外位置**(專案設定與 `--position` 皆無效,視窗出現在 (0,0))。
- 剩餘風險:建立到 `_ready()` 移走之間的上屏閃現無法排除;若要完全避免,需另找方法(例如是否可在視窗建立前即定位,本次未找到)。

---

# 第二階段(2026-11-10):把「建立瞬間在 (0,0)」縮小
**方法**:`phase2/`(`project.godot`、`Probe.tscn`、`probe_main.gd`、三份 `run_output_*.txt`)。專案設定 `window_width/height_override=1`、`borderless=true`、`no_focus=true`、viewport 960×540;`_ready()` 先 `window_set_position(-5000,-5000)` 再 `window_set_size(960,540)`;等 60 幀後取像素。`--audio-driver Dummy`,`timeout 60`,三次 `ENGINE EXIT=0`。
三次:#1 先移位再放大(主流程)/ #2 只移位不放大 / #3 先放大再移位(變體,`--sizefirst` / `--poswonly` 為腳本內切換)。

## 量測 (A)(`phase2/run_output_1.txt` 原始行)
1. **建立後第一個可讀到的位置與尺寸**:`MIN_SIZE=(64, 64) BORDERLESS_FLAG=true`、`POS_T0=(959, 569) SIZE_T0=(64, 64) VP_T0=(64, 64) FOCUS_T0=false`。
   → **引擎有 64×64 下限(1×1 被抬到 64×64)**;建立時視窗是 **64×64 無邊框、位置 (959,569)(主螢幕中央,不是 (0,0))**。
2. **移走並放大後維持**:`AFTER_SET POS=(-5000, -5000) SIZE=(960, 540)`;`F0/F1/F5/F30/F59` 全為 `POS=(-5000, -5000) SIZE=(960, 540) VP=(960, 540)`,60 幀內未被拉回。
3. **像素**:`IMAGE_IS_NULL=false`、`IMG_SIZE=(960, 540)`、`left=(0.502,0.502,0.502,1.0) right=(1.0,0.0,0.0,1.0)` —— 尺寸為放大後尺寸、色塊正確。
4. **焦點(🔴 與第一階段不同,如實寫)**:`FOCUS_T0=false`,但**移位/放大之後 `F0` 起到 `FOCUS_END` 全為 `true`**。#2(只移位)、#3(先放大再移位)同樣 `FOCUS=true`(#3 的 `MID FOCUS=false`,即放大後、移位前仍 false)。**無法由此判定誰讓它變 true**:`window_set_position` 是 #1~#3 共有的步驟,且第一階段單純移位時焦點為 false,故**因果未解**。這表示 `no_focus` 並不保證全程不拿焦點;視窗在螢幕外拿到焦點,是否會搶走使用者鍵盤輸入,**未驗**。
5. **音訊**:`AUDIO_SERVER_DRIVER=Dummy`。
6. #2(只移位、視窗仍 64×64)取像素 `IMG_SIZE=(64, 64)`、兩點皆 `(0,0,0,1)` 黑 —— 非預期色塊,**未查原因**(與判定無關,僅記錄)。

## 「建立瞬間在螢幕內」目前量得到與量不到
- **量得到(A)**:建立時視窗為 **64×64 無邊框**,位於主螢幕中央 (959,569) 附近(第一階段無尺寸設定時在 (0,0),這次是中央,**位置差異原因未查**);`_ready()` 觸發時 `TICKS_AT_READY_MS=4019`(引擎啟動後 4019 ms;`#2`、`#3` 分別約 4~5 秒量級)。
- **量不到**:視窗實際何時上屏、在螢幕內顯示了幾毫秒、是否真的被看見 —— **引擎內 API 取不到「視窗何時第一次可見」,外部工具不得使用,所以可見閃現的時間長度量不到。** 4019 ms 是「引擎啟動到 `_ready()`」,**不等於**視窗可見時間(含引擎初始化、著色器編譯等,視窗可能晚於它才顯示,也可能更早,未知)。
- 可確定的最壞情況上限:**一個 64×64 無邊框視窗,可能出現在主螢幕中央,時間不超過啟動到 `_ready()` 的數秒**。比第一階段(整個 320×180 帶標題列視窗,位於 (0,0),存活數秒)已大幅縮小。

## 第二階段判定:部分可行
- 成立:建立尺寸縮到引擎下限 64×64 並無邊框;移走+放大後 60 幀維持;螢幕外取得正確尺寸與色塊;Dummy 音訊。
- 不成立/未解:①64×64 無法再小;②建立瞬間可見度量不到;③🔴 **移位後焦點變 true**(`no_focus` 失效或被系統授予,因果未解)。

---

# 第三階段(2026-11-10):移位後重設 `WINDOW_FLAG_NO_FOCUS`
**方法**:`phase3/`(`probe_main.gd` 以 `--pre`/`--post`/`--alt` 切換;三份 `run_output_*.txt`),沿用第二階段主流程(64×64 無邊框 → 移位 → 放大),逐幀印 `window_is_focused()` 60 幀,再取像素。三次 `ENGINE EXIT=0`。
列舉名稱 (A):`WINDOW_FLAG_NO_FOCUS=4`、`WINDOW_FLAG_POPUP=5`、`WINDOW_FLAG_MOUSE_PASSTHROUGH=7`、`WINDOW_FLAG_POPUP_WM_HINT=10`、`WINDOW_FLAG_EXCLUDE_FROM_CAPTURE=9` 等(`run_output_1_post.txt` 的 `FLAG_ENUMS` 行)。

## 量測 (A)
| # | 做法 | 同步讀 FOCUS(移位/放大/重設後立即) | `FOCUS_TRACE_60` | 像素 |
|---|---|---|---|---|
| 1 | 移位+放大後 `set_flag(NO_FOCUS,true)` | 全 `false`,`NOFOCUS_FLAG=true` | 60 幀**全 1**,`TRUE_COUNT=60` | `IMG_SIZE=(960, 540)` 灰/紅正確 |
| 2 | 移位前先重設一次 + 移位放大後再重設 | 全 `false` | 60 幀**全 1** | 同上正確 |
| 3 | 另加 `POPUP_WM_HINT` + `MOUSE_PASSTHROUGH` | 見 `run_output_3_alt.txt` | 見該檔 `FOCUS_TRACE_60` | 見該檔 |
(`NOFOCUS_FLAG_T0=true`:專案設定的 no_focus 一開始就生效,重設是冪等的。)

## 觀察與解讀
- 焦點在**同一個函式內同步讀都是 false**,**進入第一個 `process_frame` 後變 true 並維持**。重設旗標(前/後/前後)**完全沒改變**這個形狀 —— `no_focus` 旗標本來就是 true,重設沒有新資訊。(A)
- 🔴 **未能分辨** `window_is_focused()=true` 是「引擎內部視窗狀態旗標被事件設成 true」還是「作業系統真的把鍵盤焦點給了這個螢幕外視窗」。**後者沒有任何引擎內證據,外部工具不得使用 —— 量不到。** (C) 假說:Windows 對 `-5000` 的視窗仍發 WM_SETFOCUS/ACTIVATE 類事件,但 `no_focus`(不啟用)是否阻止真實前景切換,未驗。
- 像素、尺寸、位置、Dummy 音訊皆正常(同第二階段)。

## 第二階段「只移位 64×64 取得全黑」的線索
**未查。** 僅有的線索 (C):該次視窗在螢幕外且尺寸 64×64,而 960×540 時同樣在螢幕外卻能繪出正確色塊,故「螢幕外不繪製」不能解釋;可能與 64×64 下 viewport/anchor 佈局在第一次繪製時尚未更新有關,**未驗證**。與本探針的最終用途(960×540)無關。

## 第三階段判定:不可行(對「焦點保持 false」這個目標)
- 焦點保持 false:**不成立**。`NO_FOCUS` 重設三種順序都沒用,視窗在第一幀後回報 focused=true。
- 其餘(螢幕外、尺寸、像素、Dummy)維持第二階段結論。
- 第 3 次(popup 類旗標組合)結果見上表第 3 列/`run_output_3_alt.txt`。
