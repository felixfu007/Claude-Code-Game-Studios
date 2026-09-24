# 隱藏視窗可行性查證(2026-09-24)

**擁有者**:`godot-specialist`(依 `CLAUDE.md` Engine Specialists 節 Primary)。
**執行方式**:全程在拋棄式空白專案跑,只畫自訂色塊,不載入、不渲染本專案任何遊戲內容
(`res://src/...`、`assets/...` 一律未被觸碰)。視窗標題為 `probe`,未出現任何遊戲名稱或劇情字樣。

🔴 **協調者已下令停止再跑引擎(尤其不准再開視窗)。本報告只跑了一輪視窗化測試(RUN 1),
其餘規劃中的測試(cmdline `--position` 覆蓋測試、Q4 工作列圖示的 Win32 旗標查詢)
未執行 —— 不是查了沒查到,是根本沒有再啟動引擎去查。**

---

## 🔴 最重要的一件事:RUN 1 量到的視窗位置是 `(0, 0)`,不是我要求的 `(-5000, -5000)`

`project.godot` 寫的是:
```
window/size/initial_position_type=0
window/size/initial_position=Vector2i(-5000, -5000)
```

`run1_output_combined_offscreen_nofocus.txt` 逐字輸出:
```
Q1_WINDOW_POSITION=(0, 0)
Q1_WINDOW_SIZE=(170, 64)
```

**兩個數字都對不上我的設定**:位置要 `(-5000,-5000)` 結果讀回 `(0,0)`;寬度要 `64` 結果讀回 `170`。
`(0,0)` 是任何螢幕都必然可見的座標。

**我不知道為什麼。** 我查過本機 `docs/engine-reference/godot/` 底下 `breaking-changes.md` 與
`current-best-practices.md`,搜尋 `initial_position`、`no_focus`、`window_get_position`、
DPI/多螢幕相關字樣 —— **零命中**,本機參考庫沒有記載這個行為。我沒有再跑引擎去縮小可能成因
(協調者已下令停止),所以以下只列**未經驗證的假說**,不是結論:
- Godot 可能有「確保視窗至少部分落在可見螢幕內」的內建保護邏輯,把要求的螢幕外座標拉回可見範圍。
- `window_width_override`/`no_focus`/`borderless` 三者疊加可能有交互作用,蓋掉了 `initial_position`。
- DPI 縮放(`display/window/dpi/allow_hidpi` 預設 `true`)可能讓 64→170 的寬度變化說得通
  (170/64 ≈ 2.656,是一個不尋常的縮放倍率,對不上本機常見的 100%/125%/150%/200% 檔位,
  所以這個假說本身也存疑)。

**誠實結論,不是我原先樂觀的框架**:**以 RUN 1 目前的證據,不能宣稱「視窗成功推到螢幕外」——
量到的結果直接反駁了這個意圖。** 這一輪測試沒有回答「使用者的螢幕上有沒有出現一個小色塊視窗」,
只回答了「引擎回報的最終座標是 (0,0)」。這兩者不是同一件事,而我目前無法把後者換算成前者的答案。

⚠️ **這件事發生在什麼時間點,我也沒有量到。** `_ready()` 裡只印了一次 `window_get_position()`,
沒有在 `_init()`(視窗建立後最早能跑的腳本時機)就印一次做對照,所以無法判斷視窗是**從一開始
就在 (0,0)**,還是**先在別處、之後被移到 (0,0)**。這是我這次探針設計的疏漏,不是查了查不到。

---

## Q1:`--position` 把視窗推到螢幕外,Windows 會不會夾回可見範圍?

**未執行 cmdline `--position` 測試。** 原計畫的 RUN 2(用 `--position -4000,-4000` 啟動,
對照 project setting 版本的結果)在協調者下令停止前沒有跑。

**但 project-setting 版本的等價測試已經跑了(見上一節),結果是負面的**:
`initial_position=Vector2i(-5000, -5000)` + `initial_position_type=0`(下面 Q2-coordinator-問题
證實這個 `0` 確實是「Absolute」)最終讀回 `(0, 0)`。**這對「螢幕外座標會被拉回可見範圍」這個
假設方向是同向的證據,但不是同一支測試,不能直接當作 cmdline 版本的答案** —— cmdline
`--position` 與 project setting `initial_position` 在引擎內部可能走不同的程式碼路徑
(cmdline 是啟動參數覆寫,project setting 是初始化預設值),兩者是否有同一個保護邏輯,未驗證。

**結論**:Q1 原問題(cmdline 版本)**未測**;但功能上等價的 project-setting 版本測出**負面結果**
(座標被改變,不再是螢幕外),這是本次查證中風險最高的發現。

---

## Q2:`unfocusable`/`WINDOW_FLAG_NO_FOCUS` 設得起來嗎?生效時機是什麼時候?

### 好消息(協調者原派工單裡自己講錯、現在更正的一項):存在一個 project setting,能在任何 GDScript 執行前就把 NO_FOCUS 設好

`reflect_output_property_reflection.txt` 逐字:
```
display/window/size/no_focus | has=true | default_or_current=false
```
(協調者原本查的鍵名是 `display/window/no_focus`,少了中間的 `size/`,所以查到 `false`
「不存在」;正確鍵名 `display/window/size/no_focus` 確實存在。)

我把它設成 `true` 之後,`run1_output_combined_offscreen_nofocus.txt` 逐字:
```
Q2_INIT_TIME_USEC=4003268
Q2_NO_FOCUS_FLAG_AT_SCRIPT_INIT=true
```
`Q2_NO_FOCUS_FLAG_AT_SCRIPT_INIT` 是在 `_init()`(整個場景樹裡**最早**能跑 GDScript 的時機)
讀到的旗標值,結果已經是 `true`。**亦即:用 project setting 而不是 runtime 呼叫
`window_set_flag()`,可以讓「視窗存在但還沒設定 no_focus」這段空窗期在 GDScript 可觀測的範圍內
完全消失** —— 因為旗標是在原生視窗建立時就套用的,不是腳本跑起來才補設的。這是這次查證裡
**最乾淨的正面結果**,原派工單擔心的「建立到設定之間有多久」這個問題,在這個做法下答案是
「GDScript 觀測不到任何空窗,因為根本沒有『腳本補設』這個步驟」。

`_ready()` 裡的覆核,同樣是 `true`:
```
Q2_NO_FOCUS_FLAG_AT_READY=true
Q2_BORDERLESS_FLAG_AT_READY=true
Q2_WINDOW_IS_FOCUSED=false
```
`Q2_WINDOW_IS_FOCUSED=false` 是額外佐證:引擎自己回報「這個視窗目前沒有 OS 焦點」,
與「no_focus 生效」的方向一致(但這只是引擎自己的認知,不是外部工具對 OS 焦點的獨立覆核——
見下方「未驗證清單」)。

### 協調者追問「視窗存在了多久」——只能給部分答案,不是完整答案

`Q2_INIT_TIME_USEC=4003268`,單位微秒,即約 **4.003 秒**。`Time.get_ticks_usec()` 量的是
「engine 行程啟動後經過的時間」,不是「視窗存在的時間」——但因為視窗是在腳本能執行**之前**
的原生初始化階段建立的,`_init()` 印出這個數字時,視窗必然已經存在了一段時間,4.003 秒是
這段時間的**上界**(而且從 log 看得出這台機器這次冷啟動的 Vulkan/顯示卡初始化就吃掉了
大部分時間:`Vulkan 1.4.325 - Forward+ - Using Device #0: Intel - Intel(R) Graphics` 這行
印在 `_init()` 之前)。

🔴 **但我沒有在 `_init()` 印 `window_get_position()`,只在 `_ready()` 印**——所以「這 4 秒鐘
視窗在哪裡」完全沒有量到,前面那個 `(0,0)` 之謎也連帶無法回答「是不是從第一格畫面就在 (0,0)」。

**行程總長度(從視窗建立到 `quit()`)我沒有量到。** 腳本裡只有兩次 `await process_frame`
加一次 `await RenderingServer.frame_post_draw`,理論上是幾十毫秒等級,但我沒有在 `quit()`
前印時間戳,所以這只是推算不是量測,**不應該當成已驗證的數字**。

---

## Q3:看不見的視窗拍出來的像素,是不是真的?

**8 項逐點斷言全部通過**,`run1_output_combined_offscreen_nofocus.txt` 逐字:
```
Q3_CHECK name=TL_quadrant_center pos=(42, 16) expect=(1.0, 0.0, 0.0, 1.0) actual=(1.0, 0.0, 0.0, 1.0) pass=true
Q3_CHECK name=TR_quadrant_center pos=(127, 16) expect=(0.0, 1.0, 0.0, 1.0) actual=(0.0, 1.0, 0.0, 1.0) pass=true
Q3_CHECK name=BL_quadrant_center pos=(42, 48) expect=(0.0, 0.0, 1.0, 1.0) actual=(0.0, 0.0, 1.0, 1.0) pass=true
Q3_CHECK name=BR_quadrant_center pos=(127, 48) expect=(1.0, 1.0, 0.0, 1.0) actual=(1.0, 1.0, 0.0, 1.0) pass=true
Q3_CHECK name=corner_TL_marker pos=(0, 0) expect=(1.0, 0.0, 1.0, 1.0) actual=(1.0, 0.0, 1.0, 1.0) pass=true
Q3_CHECK name=corner_TR_marker pos=(169, 0) expect=(1.0, 0.0, 1.0, 1.0) actual=(1.0, 0.0, 1.0, 1.0) pass=true
Q3_CHECK name=corner_BL_marker pos=(0, 63) expect=(1.0, 0.0, 1.0, 1.0) actual=(1.0, 0.0, 1.0, 1.0) pass=true
Q3_CHECK name=corner_BR_marker pos=(169, 63) expect=(1.0, 0.0, 1.0, 1.0) actual=(1.0, 0.0, 1.0, 1.0) pass=true
Q3_RESULT=PASS
```
判準不是「不是全黑」,而是**逐點座標斷言顏色完全等於我寫死進腳本裡的期望值**
(四象限色塊 RED/GREEN/BLUE/YELLOW + 四角 2×2 MAGENTA 標記),對得上才算真,對不上就算假——
本次 8 項全對。**結論:即使視窗被裁定為「不可見/不搶焦點」,`get_viewport().get_texture().get_image()`
拍出來的像素仍然是真實渲染結果,不是空圖或預設色。** 這一題的答案是穩的,不受上面 `(0,0)`
之謎影響——像素真假與視窗位置是兩個獨立的問題。

（截圖已另存 `probe_screenshot.png`,4 色塊 + 4 角標記,64×64,無任何遊戲相關內容。）

---

## Q4:工作列會不會冒出一個圖示?

**未量測。** 我只拿到了原生視窗控制代碼(Win32 HWND 的整數值):
```
Q4_NATIVE_HANDLE=527452
```
這只是「這個視窗的 HWND 是多少」,**不是**「這個 HWND 有沒有工作列按鈕」。要回答後者,
至少需要額外查詢 `GetWindowLong(hwnd, GWL_EXSTYLE)` 的 `WS_EX_TOOLWINDOW`/`WS_EX_APPWINDOW`
位元(這兩個位元決定預設工作列行為,但仍是「引擎/OS 設定了什麼」的間接推論,不是「工作列
實際上有沒有圖示」的直接觀察),而這需要另一支 Win32 層級的檢查工具或 PowerShell 腳本,
**我沒有寫、也沒有跑**——不是查了查不到,是這次連上場的機會都還沒排到就被叫停。

**照實回答:Q4 完全未量測,不是「查不到」,是「沒有嘗試查」。** 剩下的風險是使用者未知數。

---

## 逐題彙總

| 題目 | 狀態 | 一句話結論 |
|---|---|---|
| 位置是否真的推到螢幕外(project setting 版) | ❌ **負面結果** | 要求 `(-5000,-5000)`,量到 `(0,0)`;成因未驗證,`(0,0)` 對任何螢幕都可見 |
| Q1(cmdline `--position`,原題) | ⚪ 未執行 | 被叫停前沒排到這一輪 |
| Q2(NO_FOCUS 能不能設、空窗期多長) | ✅ 部分回答,含一項好消息 | project setting 可在任何腳本執行前就生效,GDScript 觀測不到空窗期;**但視窗實際存在了多久、這段時間位置在哪,沒有量到** |
| Q3(像素是否為真) | ✅ **8/8 通過** | 逐點色彩斷言全對,截圖是真實渲染,不是空圖或預設色 |
| Q4(工作列圖示) | ⚪ 未量測 | 只拿到 HWND 整數值,沒有查 ex-style 位元,沒有任何工作列相關證據 |

---

## 最終結論(一句話)

**這條路目前不能宣稱可行**:核心防護機制(project-setting 版 NO_FOCUS)證實有效且沒有
GDScript 可觀測的空窗期,是好消息;但唯一一次實測的「推到螢幕外」在同一輪測試裡**沒有成功**
(量到 `(0,0)` 而非要求值),而且我不知道為什麼、也沒有量到那段時間視窗實際在哪、更沒有查過
工作列圖示——**在這三個未解問題釐清之前,不能對使用者保證「畫面一秒都不會出現」這個硬約束**。

---

## 我沒有做到/沒有查證的每一件事(照實列,不美化)

1. **`(0,0)` 之謎的成因** —— 三個候選假說都未驗證,沒有再跑引擎去排除。
2. **cmdline `--position -4000,-4000` 的原題測試** —— 完全沒執行(RUN 2 未跑)。
3. **視窗在 `_init()` 當下、以及 4.003 秒冷啟動期間的實際位置** —— 沒有在 `_init()` 印
   `window_get_position()`,無法回推視窗是否曾經短暫出現在可見範圍。
4. **從視窗建立到 `quit()` 的總存活時間** —— 沒有在結束前印時間戳,只能推算不能宣稱已量測。
5. **工作列圖示(Q4)** —— 完全未量測,連 Win32 ex-style 位元查詢都沒寫。
6. **`Q2_WINDOW_IS_FOCUSED=false` 是否等於「OS 真的沒有把焦點給它」** —— 這只是引擎自己
   回報的信念,沒有用引擎之外的獨立工具(例如查詢當時真正持有 OS 焦點的是哪個 HWND)覆核過。
7. **多螢幕/DPI 環境下是否會有不同結果** —— 本次只在使用者當前這台機器、當前螢幕配置跑過一次,
   沒有測試其他解析度或縮放比例。
8. **RUN 1 是否曾經真的在螢幕上一閃而過** —— 這是使用者最在意的問題,而我**完全沒有辦法從
   引擎內部的任何 log 回答它**;唯一能回答這件事的做法(外部畫面錄製/Win32 視窗事件監控)
   這次都沒有用上。

## 檔案清單

- `project.godot`、`Probe.tscn`、`probe_main.gd` —— RUN 1 使用的完整拋棄式專案原始碼
- `ReflectProbe.tscn`、`ReflectProbe.gd` —— headless 反射查詢腳本(用來確認
  `display/window/size/no_focus`、`initial_position_type` 的真實列舉值,不是憑記憶)
- `reflect_output_property_reflection.txt` —— 上述反射查詢的原始輸出
- `run1_output_combined_offscreen_nofocus.txt` —— RUN 1(唯一一次視窗化執行)的原始輸出
- `probe_screenshot.png` —— RUN 1 截圖(4 色塊 + 4 角標記,64×64,無遊戲內容)
