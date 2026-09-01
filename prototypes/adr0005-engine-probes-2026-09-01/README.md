# Spike:ADR-0005 核准門檻條件一 —— 剩餘六項引擎探針

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證,不是實作,不進 `src/`
> **日期**:2026-09-01
> **執行者**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,可跑非 headless 視窗模式)
> **對應文件**:`docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`
>              Verification Required #2 / #3 / #5 / #9 / #10 / #13

## 要驗證的假設

ADR-0005 核准門檻卡在「條件一:文件依賴的引擎行為都要在真引擎上跑過」。派工單列了六項:
`_input()`/`_process()` 定序(#2)、Agile Event Flushing 設定鍵真名(#3)、Steam 疊加層焦點通知
(#5)、`FOCUS_NONE` 是否關閉 hover 繪製(#9)、焦點通知相對 `process_priority` 的時序(#10)、
`event_is_action()` 是否過濾 `InputEventKey.echo`(#13)。

## 如何重跑

```bash
GODOT="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

# 一次性:建立 class_name 快取
"$GODOT" --headless --path . --import

# #13 + #3(安全、headless)
"$GODOT" --headless --path . scenes/Probe13And3.tscn

# #2(headless 即可 —— 實測 Input.parse_input_event() 在 headless 下正常觸發 _input())
"$GODOT" --headless --path . scenes/Probe2InputOrder.tscn

# #9(需要非 headless —— GUI hover 判定走 Viewport 的輸入路徑)
"$GODOT" --path . scenes/Probe9FocusNoneHover.tscn

# #10(需要非 headless + 真實 OS 焦點切換,見下方「探針 #10 的設計」,
#     單獨執行這個場景不會自動觸發焦點事件 —— 需要外部腳本或真人 alt-tab)
"$GODOT" --path . scenes/Probe10FocusTiming.tscn
```

---

## 逐項判定

### #2 —— `_input()` 是否於整幀派發完畢後才進 `_process()` 鏈:**成立**

**這是機制六六行為者定序的全部基礎,本次最重要的一項。**

**方法**(`scripts/probe2_main.gd` + `probe2_recorder.gd` + `probe2_injector.gd`):5 個
recorder 節點,`process_priority` 分別設為 **−100 / −60 / −25 / 0 / 100**(逐字對照機制六
表格裡①②③④⑥五個實際數值,只省略⑤因為⑤與④⑥同為純讀取角色、優先序值無關本題),各自覆寫
`_input()`(命中 `KEY_UP` 按下且非 echo 時記錄)與 `_process()`(每影格記錄)。1 個 injector
節點以 `Timer.timeout`(刻意不掛在 `_process()`/`_physics_process()` 鏈上,避免注入時機
被 `process_priority` 排布本身汙染)每 0.35 秒呼叫一次 `Input.parse_input_event()` 注入
`KEY_UP` 按下事件,共 6 次。全部紀錄寫進同一份單執行緒序列 log(`_seq` 遞增,單執行緒下
即嚴格執行順序,不依賴時間戳)。

**判定方式**:對每一個偵測到事件的影格,檢查該影格內 5 個 recorder 的 INPUT 紀錄序號
是否全部小於該影格內 5 個 recorder 的 PROCESS 紀錄序號。

**執行**:`logs/probe2_headless.txt`(headless,`Input.parse_input_event()` 在此模式下
實測正常觸發 `_input()`,不需要真實視窗)。

**逐字結果**(`logs/probe2_headless.txt` 末尾):

```
frame=000044  INPUT 命中數=5/5  max(INPUT seq)=225  min(PROCESS seq)=226  => PASS
frame=000096  INPUT 命中數=5/5  max(INPUT seq)=491  min(PROCESS seq)=492  => PASS
frame=000147  INPUT 命中數=5/5  max(INPUT seq)=752  min(PROCESS seq)=753  => PASS
frame=000198  INPUT 命中數=5/5  max(INPUT seq)=1013  min(PROCESS seq)=1014  => PASS
frame=000249  INPUT 命中數=5/5  max(INPUT seq)=1274  min(PROCESS seq)=1275  => PASS
frame=000300  INPUT 命中數=5/5  max(INPUT seq)=1535  min(PROCESS seq)=1536  => PASS

總結:有 INPUT 紀錄的影格數=6  PASS=6  FAIL=0
```

逐行明細(第一次注入,`logs/probe2_headless.txt` 第 230-245 行)也直接可讀:

```
0219  frame=000043  INJECT  (about to call Input.parse_input_event, remaining=6)
0220  frame=000043  PROCESS R(100)
0221  frame=000044  INPUT   R(100)
0222  frame=000044  INPUT   R(0)
0223  frame=000044  INPUT   R(-25)
0224  frame=000044  INPUT   R(-60)
0225  frame=000044  INPUT   R(-100)
0226  frame=000044  PROCESS R(-100)
0227  frame=000044  PROCESS R(-60)
...
```

可以看到:injector 在 frame 43 呼叫 `parse_input_event()`,但 5 個 recorder 的 `_input()`
命中全部落在**下一個影格**(frame 44),且**全部先於**該影格任何一個 recorder 的 `_process()`。
6 次獨立注入,結果完全一致。

**判定**:**成立**。實測支持機制六的定序基礎——`_input()` 對全部訂閱節點的派發,在
4.7.1 是一個先於該影格 `_process()` 鏈的獨立階段,不受 `process_priority` 影響
(5 個 recorder 橫跨 −100~100 全部一致),且此階段本身相對呼叫時機是「下一影格」而非
「立即插入呼叫者當下的執行流」。

**樣本數的誠實評估(回應追問)**:6 次獨立注入、6/6 一致,**但這是低估比高估安全的地方,
必須直說**——本次量測是在**空場景、無其他負載**下跑的,且是 headless(dummy 渲染,
無真實 GPU 畫面呈現耗時)。這代表「該影格 `_input()` 全數派發完畢才進 `_process()`」的
**階段順序**本身理由是引擎架構性的,不太可能因負載變化而動搖;但 6 次樣本**不足以**
排除「在某種極端幀時間抖動下,某個 recorder 的 `_process()` 被跳過或延後一影格」這類
邊緣情況——本次測試沒有製造任何幀時間抖動或掉幀情境。若要更強的信心,應在有實際渲染負載
(非 headless、非空場景)下重測,且拉高樣本數到數十次以上。**目前的 6/6 對「這是機制六的
定序基礎」這個問題已經足夠回答「成立,可重現」,但不足以聲稱「在任何負載下都成立」。**

---

### #3 —— Agile Event Flushing 設定鍵真名:**成立(推測正確),且與 2026-08-20 舊 spike 互相印證**

**方法**(`scripts/probe13_and_3.gd`):(1) `ProjectSettings.has_setting()` 直接查詢推測鍵名;
(2) `ProjectSettings.get_setting()` 取值;(3) **另外**呼叫 `ProjectSettings.get_property_list()`
遍歷全部已知設定、篩選 `input_devices` 前綴,交叉核對——**這一步是回應追問**:本次同時
問了 `get_property_list()`(列出引擎實際登記的屬性)與 `get_setting()`(對特定鍵取值)兩種
API,不是只用後者猜。`get_setting()` 對不存在的鍵回傳 `null` 這件事本身**不能**用來確認
鍵存在,所以判定鍵是否存在的依據是 `has_setting()`(先查)+ `get_property_list()`(交叉核對
它有沒有出現在引擎自己回報的屬性清單裡),`get_setting()` 只用來取值,三者合起來才是完整證據。

**執行**:`logs/probe13_and_3_headless.txt`(headless)。

**逐字結果**:

```
ADR-0005 推測鍵名    : input_devices/buffering/agile_event_flushing
has_setting(推測值)  : true
get_setting(推測值)  : false

── 名稱以 'input_devices' 開頭的全部已知鍵(交叉核對)──
    ...
    input_devices/buffering/agile_event_flushing = false
    ...
```

該鍵確實出現在 `get_property_list()` 的完整清單裡,值與 `get_setting()` 直接查詢一致
(`false`,即目前**已關閉**,正是機制七要求的狀態)。

**判定**:**成立**。鍵名 `input_devices/buffering/agile_event_flushing` 正確,現值 `false`。

**⚠️ 重要背景(檢索紀律,回應「請確認你的搜尋範圍」)**:這件事**早在 2026-08-20 就已經
被另一批 spike 關閉過** —— `prototypes/engine-verification-spike-2026-08-20/README.md`
的 **F-4** 逐字寫著同一個鍵名、同一個值(`false`),判定「**已關閉**」,且該檔明文記錄
「回寫目標:ADR-0005 VR #3」。**但 ADR-0005 本文從未被更新** —— 第 83 行與第 591 行至今
仍寫「推測」「未經查證」。本次是**第二次獨立重驗**(不同的探針程式碼、同一結論),
可以視為雙重確認,但**真正該做的動作是把 ADR-0005 第 83、591 行的措辭改掉**,這是本檔
「是否推翻 ADR 說法」一節要處理的事,不只是「再測一次」。

---

### #5 —— Steam 疊加層是否觸發 `NOTIFICATION_APPLICATION_FOCUS_IN`:**做不到**

**沒有任何檔案對應這一項——如實回報,不是遺漏。**

**做不到的原因**:本專案的 `addons/` 底下**只有 GdUnit4**(`.claude/docs/technical-preferences.md`
明文記載,已用 `find addons -maxdepth 1 -type d` 於本次覆核),沒有 GodotSteam 或任何
Steamworks 綁定。要讓 Steam 疊加層真的彈出並產生(或不產生)焦點轉移事件,至少需要:

1. 一份 Steam App ID(即使是測試用的、Steamworks 提供的 480 範例 App ID 也需要 Steam 客戶端
   登入並辨識該遊戲程序);
2. GodotSteam 插件(或直接呼叫 Steamworks SDK)整合進本 spike 專案,讓遊戲程序被 Steam
   客戶端辨識為「正在執行的遊戲」;
3. Steam 客戶端本身在背景執行且已登入;
4. 一次**真人**按下 Steam 疊加層快捷鍵(預設 Shift+Tab)的操作 —— 疊加層的觸發本身
   就不是可程式化模擬的動作,需要 Steam 客戶端辨識到該按鍵組合。

以上四項本機環境一項都不具備,且新增 GodotSteam 依賴超出本次派工的檔案權限範圍
(`prototypes/adr0005-engine-probes-2026-09-01/` 之外不可動,而且新增第三方插件依專案規則
需要 technical-director 核准,見 `.claude/docs/coordination-rules.md`)。**這不是「懶得測」,
是「這個環境結構性缺三個先決條件」。**

**判定**:**做不到**。ADR 已經為這個不確定性做了防線(`suspend_arbitration()` 讓呼叫方
可以在最壞情況〔不觸發〕下顯式處理),**這一項維持開啟**,不因本次派工而關閉。

---

### #9 —— `focus_mode = FOCUS_NONE` 是否也排除 Control 主題內建的 hover 繪製:**成立(不排除)**

**方法**(`scripts/probe9_focus_hover.gd`):建立一個 `Button`,`focus_mode = FOCUS_NONE`,
先確認 `is_hovered()`/`get_draw_mode()` 的初始值,再用 `get_viewport().push_input()` 注入
一個定位在按鈕中心的 `InputEventMouseMotion`,重新讀值。

**執行**:`logs/probe9_windowed.txt`(非 headless,真實視窗,Vulkan Forward+,Intel 內顯)。

**逐字結果**:

```
btn.focus_mode = 0  (Control.FOCUS_NONE = 0)

── 模擬滑鼠移動到按鈕中心之前 ──
  is_hovered()    = false
  get_draw_mode() = 0

── 模擬滑鼠移動到按鈕中心之後(get_viewport().push_input(InputEventMouseMotion)) ──
  is_hovered()    = true
  get_draw_mode() = 2   (NORMAL=0 PRESSED=1 HOVER=2 DISABLED=3 HOVER_PRESSED=4)
```

**判定**:**成立**——`FOCUS_NONE`**不**排除滑鼠 hover 主題繪製。`is_hovered()` 從 `false`
變 `true`,`get_draw_mode()` 從 `0`(NORMAL)變 `2`(HOVER),與 `godot-specialist` 原本
「大概率不排除」的印象判斷一致,現由印象升級為已查證。

**輸入模擬方式的差異揭露(回應追問)**:本項用的是 `Viewport.push_input()`,不是
`Input.parse_input_event()`(#2 用的是後者)。兩者的差異——`push_input()` 是直接餵給
**特定 viewport** 的 GUI 輸入管線(繞過 `_input()`/`_unhandled_input()` 那條一般節點路徑,
專門用於 GUI 互動模擬),`parse_input_event()` 則是餵進**全域 Input 單例**,會走完整的
`_input()` 派發鏈。這個差異**不影響 #9 的結論**,因為 #9 問的正是「Control 的 hover 主題
繪製這條 GUI 管線」,`push_input()` 正是該管線的正確注入點;但這也代表 #9 的結果**不能
直接推廣**去回答「真人用實體滑鼠移動,是否也會產生同樣的 hover 判定」——這點與真實輸入的
差異在於:真人滑鼠移動會產生一連串連續的 `InputEventMouseMotion`(伴隨真實的 OS 游標位置
變化),而本次只注入了一個單一事件。**這足以回答「hover 判定的門檻邏輯有沒有被 FOCUS_NONE
擋住」(問題的核心),但不足以驗證「連續移動下的 hover 進入/離開時序」**(那是另一個問題,
本次未涉及)。

---

### #10 —— `NOTIFICATION_APPLICATION_FOCUS_IN`/`_OUT` 相對 `process_priority`(`_process()`)的時序:**成立(乾淨、無交錯)**

**方法**(`scripts/probe10_main.gd` + `probe10_recorder.gd`):5 個 recorder,`process_priority`
同 #2(−100/−60/−25/0/100),覆寫 `_notification()`(記錄 FOCUS_OUT/FOCUS_IN)與 `_process()`
(每影格記錄,但用 `log_event_silent()` 不即時印出,避免洗版)。**本檔絕不自己呼叫
`notification()` 模擬焦點事件**——那樣就只是在測自己的程式碼,不是測引擎。真實的 OS
焦點切換由外部 PowerShell 腳本負責(見下方「探針 #10 的設計」)。

**執行**:`logs/probe10_windowed.txt`(非 headless,真實視窗;外部腳本
`focus_steal_probe10_v2.ps1` 於本次對話的 scratchpad 目錄執行,已複製一份存在
`logs/focus_steal_script_used.ps1` 供追溯)。

**逐字結果**(兩個完整的 OUT→IN 循環,`logs/probe10_windowed.txt`):

```
frame=000024  FOCUS 命中數=5/5  focus_seq範圍=[120,124]  process_seq範圍=[125,129]
    => 該影格內,全部 FOCUS 通知先於全部 PROCESS —— 乾淨的「先通知後處理」
frame=000233  FOCUS 命中數=5/5  focus_seq範圍=[1170,1174]  process_seq範圍=[1175,1179]
    => 該影格內,全部 FOCUS 通知先於全部 PROCESS —— 乾淨的「先通知後處理」
frame=000475  FOCUS 命中數=5/5  focus_seq範圍=[2385,2389]  process_seq範圍=[2390,2394]
    => 該影格內,全部 FOCUS 通知先於全部 PROCESS —— 乾淨的「先通知後處理」
frame=000604  FOCUS 命中數=5/5  focus_seq範圍=[3035,3039]  process_seq範圍=[3040,3044]
    => 該影格內,全部 FOCUS 通知先於全部 PROCESS —— 乾淨的「先通知後處理」
```

（frame 24/233 為第一次 OUT/IN 循環,frame 475/604 為第二次)

**判定**:**成立**,在本次測到的 2 個完整循環(4 個事件影格)裡,每一次都是「5 個 recorder
的 FOCUS 通知全數早於 5 個 recorder該影格的 PROCESS」——沒有觀察到 ADR VR #10 擔心的
「交錯」情況(部分 recorder 的 `_process()` 用舊狀態、部分用新狀態)。

**樣本數與此項優先級的誠實評估**:本項是派工單標記的🟡「答案再壞也不改變 ADR 決定」的
四項之一,本次只取得 2 個循環(4 個事件)。相對 #2 的 6 次,樣本更少,原因是每個循環
需要真實的 OS 焦點切換(PowerShell 呼叫 `WScript.Shell.AppActivate`),比純程式內注入慢
很多,且不同視窗管理器/DE 環境下的行為可能不同(本次是 Windows 11)。**在本機、本次測試
下,結果是乾淨的**,但由於樣本量小、且只在單一作業系統上測過,若日後想把這一項的答案
拿去做比 VR #10 目前登記的優先級更高的用途,應該加測更多循環。

---

### #13 —— `InputMap.event_is_action()` 是否過濾 `InputEventKey.echo`:**成立(不過濾)—— 危險方向**

**方法**(`scripts/probe13_and_3.gd`):建三個 `InputEventKey`(皆為 `KEY_UP`/`ui_up` 對應鍵):
`pressed=true, echo=false`、`pressed=true, echo=true`、`pressed=false, echo=false`(對照組),
分別呼叫 `InputMap.event_is_action(event, "ui_up")`。

**執行**:`logs/probe13_and_3_headless.txt`(headless)。

**逐字結果**:

```
event_is_action(pressed=true,  echo=false, ui_up) = true
event_is_action(pressed=true,  echo=true,  ui_up) = true
event_is_action(pressed=false, echo=false, ui_up) = true   (對照組:放開鍵)
```

**判定**:**成立,且是危險方向**——`echo=true` 與 `echo=false` 回傳**完全相同**(皆
`true`)。`event_is_action()` 對 `echo` **沒有**任何過濾。(對照組回傳 `true` 是預期
行為——`event_is_action()` 對放開事件的判定本來就依 `allow_echo`/`exact_match` 等參數
語意而定,這裡只是確認函式對這個 action 名稱是有反應的,不是異常。)

---

## 是否有任何一項推翻了 ADR 的說法?

**有一項,而且是危險方向。其餘五項與 ADR 既有登記一致或已被獨立確認。**

### #13 推翻/確認了什麼(這是本次最有價值的產出)

ADR-0005 第 404-406 行(機制四之二 `classify_action()` 的程式碼註解)寫:

> ⚠️ InputEventKey.echo 是否被過濾未經查證(Verification Required #13)——若不過濾,
> 按住方向鍵的每一個重複事件都會被判為 NAVIGATION。此處不預先加過濾。

以及 Verification Required 表第 91 行(#13 條目)的風險欄:

> 若不過濾,玩家**按住**方向鍵產生的重複 echo 事件會與初次按下同樣被機制四之二判為
> `NAVIGATION`,亦即每一影格都在主張裝置權威。這會直接餵進機制八觸發點 (d)(同幀否決)
> 與 E1 缺陷(類比搖桿持續按住造成滑鼠奪權永久鎖死)的因果鏈——上一版 ADR 對此完全未討論。

**本次實測把「若不過濾」的條件句坐實了:不過濾,已查證。** 具體後果鏈(照 ADR 自己
寫的因果鏈複述,不新增設計):

1. 玩家按住方向鍵 → OS 以固定間隔產生一連串 `echo=true` 的 `InputEventKey`。
2. `classify_action()` 對每一個 echo 事件呼叫 `event_is_action()`,回傳 `true` →
   每一個 echo 事件都被判為 `ActionClass.NAVIGATION`。
3. 機制六①`arbitrate_device_authority()` 的仲裁規則是「KEYBOARD_GAMEPAD 恆勝於 MOUSE」——
   只要當幀緩衝區裡有任何一個 NAVIGATION 事件,鍵盤/手把就重新主張裝置權威。
4. 因為 echo 事件按住期間**每一影格**都在產生,這代表**只要玩家按住方向鍵不放,
   鍵盤裝置權威在每一影格都被重新確認**,持續介入機制八的觸發點 (d)(同幀否決)——
   與 ADR 自己登記的 E1 缺陷(**已知確認缺陷**:類比搖桿持續按住造成滑鼠奪權永久鎖死)
   是同一形狀的因果鏈,只是本次確認的是**鍵盤路徑**也適用,而 ADR 原本登記 E1 時的
   實測證據只涵蓋**類比搖桿**路徑(`design/gdd/cursor-highlight-state.md` 的 `Known
   Confirmed Defects` 節與 ADR 第 665-672 行皆只寫「類比搖桿」)。
5. **新事實(本次新增,ADR 原文未寫)**:E1 缺陷此前的已知觸發輸入方式只有「類比搖桿
   持續按住」;本次確認**鍵盤持續按住方向鍵也會餵進同一條因果鏈**,因為 echo 事件與
   `NAVIGATION` 分類之間沒有過濾。這代表 E1 的**已知受影響輸入方式清單應該從「類比搖桿」
   擴大為「類比搖桿 + 鍵盤持續按鍵」**——這是一個事實登記,不是一個新缺陷,也不是要
   本次修的東西。

**⚠️ 界線(遵照派工單指示,只登記不設計)**:上述整條因果鏈落在 `MouseReclaimPolicy`
子機制範圍內,而該子機制已由使用者於 GDD 第十二輪(2026-08-11)**明文裁決凍結** ——
「硬性閘門降級為建議事項、重新設計暫停、候選修法(`InputEventKey.echo` 過濾)正式標記為
不再追加投入,待取得手把硬體」。依核准門檻文件第四節第 4 項,**凍結是決定,不是缺陷,
不阻擋核准**。因此本報告**只登記上述事實與因果鏈,不提出修法,不重啟該子機制的設計**。
ADR-0005 第 91 行(VR #13)與第 404-406 行的措辭應從「未經查證」改為「已查證:不過濾」,
但**風險欄的判定與因應方式維持 ADR 現有寫法**(登記、不預先設計修法)。

### #3 的措辭需要更新(次要,不影響決策,但文件現在是錯的)

ADR-0005 第 83 行(VR 表)與第 591 行(機制七 (b))目前寫「推測」「未經查證」。
本次(及 2026-08-20 的舊 spike,`prototypes/engine-verification-spike-2026-08-20/README.md`
F-4)都已確認鍵名正確、現值 `false`。**這兩處措辭是過時的,應更新為「已查證」**,
但**不影響任何決策**——機制七的 `has_setting()` 防衛本來就不因為鍵名查證成功而移除
(ADR 自己在 F-4 對照那次已經講過這點,理由是「鍵名可能隨版本改變」)。

### 其餘四項(#2、#5、#9、#10):與 ADR 既有登記一致,沒有推翻任何說法

- **#2**:ADR 押注「`_input()` 全數完成後才進 `_process()`」,本次證實成立。**機制五/六
  不需要重新設計。**
- **#5**:ADR 原本就沒有斷言 Steam 疊加層一定觸發,而是預先設了 `suspend_arbitration()`
  作為呼叫方顯式處理的退路——本次「做不到測試」正是 ADR 這個設計原本就準備因應的情況,
  沒有新增資訊,但也沒有推翻任何東西。
- **#9**:ADR 原文寫「`godot-specialist` 判斷大概率不排除」,本次證實**確實不排除**——
  印象升級為已查證,決策方向(機制十四需要 `focus_mode` 之外的額外手段)不變。
- **#10**:ADR 把這項列為印象等級的中風險疑慮,本次在 2 個循環裡都沒有觀察到交錯——
  這把一個懸而未決的疑慮往「未觀察到問題」的方向推了一步,但樣本數不足以徹底排除,
  不構成「推翻」,ADR 對這一項本來就沒有下決定性結論(只是登記疑慮)。

---

## 複驗後的「仍開著項目」清單

派工單給的六項,複驗後**只剩一項真正開著**:

| 項 | 派工單狀態 | 複驗後狀態 |
|---|---|---|
| #2 | 待驗證 | ✅ **已關閉**(成立) |
| #3 | 待驗證 | ✅ **已關閉**(成立;且發現這其實是第二次關閉,第一次在 2026-08-20 就做過,只是 ADR 沒更新) |
| #5 | 待驗證 | 🔴 **仍開**(做不到,環境結構性缺 Steam 整合) |
| #9 | 待驗證 | ✅ **已關閉**(成立) |
| #10 | 待驗證 | ✅ **已關閉**(成立,但樣本數少,見上方誠實評估) |
| #13 | 待驗證 | ✅ **已關閉**(成立,危險方向,見上方因果鏈) |

**差異說明**:六項全部都測了(或如 #5 般查明白為何測不了),沒有增加也沒有減少項目——
派工單的清點與本次複驗範圍一致。**唯一的認知落差**是 #3:它看起來是六項之一,但實際上
是「已經被關過一次、只是 ADR 文件沒同步」,這點在派工單發出時沒有被指出,是本次搜尋
`prototypes/` 全部批次才發現的(遵照專案「多批探針並存時先確認搜尋範圍」的紀律)。

---

## 探針 #10 的設計(為何需要外部腳本,以及撞到的問題)

`NOTIFICATION_APPLICATION_FOCUS_IN/_OUT` 是 OS 視窗管理器送給應用程式的通知,無法從
Godot 腳本內部呼叫 `notification()` 自己模擬——那樣量到的只是自己寫的程式碼,不是引擎
行為。因此設計了一個外部 PowerShell 腳本(`focus_steal_probe10_v2.ps1`,已複製存檔於
`logs/focus_steal_script_used.ps1`):啟動 Godot(非 headless、輸出導向 log 檔)、等待
3 秒、開一個記事本視窗搶走焦點(觸發 FOCUS_OUT)、等待、用
`(New-Object -ComObject WScript.Shell).AppActivate()` 切回 Godot 視窗(觸發 FOCUS_IN)、
重複一次、收尾。

### 撞到的問題:引擎預設不鎖 FPS,導致第一次嘗試只錄到一半資料

**第一次嘗試**(`logs/probe10_windowed_attempt1_uncapped_fps.txt`,保留為證據)只錄到
一個 `FOCUS_OUT`,完全沒有對應的 `FOCUS_IN`。追查後發現:專案沒有設定 `Engine.max_fps`,
Intel 內顯跑一個近乎空的場景時**實測跑到約 146 fps**(583 影格發生在約 4 秒內)——比
「假設 60fps」快超過兩倍。原本設計 `MAX_FRAMES = 720`(以為對應 12 秒)在真實環境下
只對應約 4.9 秒,**遠早於外部腳本走完「切回 Godot」那一步就已經跑滿逾時、自動 `quit()`**,
於是只錄到第一個 FOCUS_OUT,程式就已經結束。

**修法**:在 `probe10_main.gd` 的 `_ready()` 開頭加一行 `Engine.max_fps = 60` 鎖定幀率,
並把 `MAX_FRAMES` 從 720 提高到 900 留安全邊際。第二次嘗試(`logs/probe10_windowed.txt`)
乾淨錄到完整的兩個 OUT/IN 循環。

**這個坑值得記錄的原因**:如果只看第一次嘗試的結果(「沒有 FOCUS_IN」),很容易誤判成
「Godot 沒有正確送出 FOCUS_IN 通知」或「AppActivate 切換失敗」——但真正的原因是**測試
腳本自己的時間假設(「720 影格 ≈ 12 秒」)在未鎖幀率的環境下不成立**,是量測工具自己的
問題,不是被測對象的問題。

### 一個沒有影響結果、但值得記錄的怪異現象

PowerShell 的 `$wshell.AppActivate($npProc.Id)`(以記事本的 process ID 呼叫)兩次都回傳
`False`,而 `$wshell.AppActivate("AdrProbe10Window")`(以標題字串呼叫)兩次都回傳 `True`。
儘管如此,Godot 的 log **確實錄到了兩次完整的 FOCUS_OUT→FOCUS_IN 循環**——代表焦點切換
實際上是成功的,`AppActivate` 的回傳值語意與「用 PID 而非 `Exec()` 回傳的 Task ID」呼叫時
不完全可靠(這是 `WScript.Shell.AppActivate` 文件本身記載的已知限制:數字參數應該是
`Exec()` 方法回傳的 Task ID,不是任意的 Win32 Process ID)。**判定依據是 Godot 自己記錄
的通知,不是 PowerShell 的回傳值**——後者只用來輔助排錯,不是本次的證據來源。

---

## 逐項涵蓋範圍(做了什麼、沒做什麼)

| 項目 | 涵蓋 | 未涵蓋 |
|---|---|---|
| #2 | headless、6 次獨立注入、5 個 recorder 橫跨機制六全部實際優先序值、序列位置分析(不依賴時間戳) | 無真實渲染負載下的重測;無故意製造幀時間抖動/掉幀的壓力測試;只測了單一 action(`ui_up`/`KEY_UP`),未測手把輸入路徑 |
| #3 | `has_setting()` + `get_setting()` + `get_property_list()` 交叉核對(三種查詢方式,不只猜一種);與 2026-08-20 舊 spike 結果比對 | 未測該鍵在**不同作業系統**(macOS/Linux)下是否同名同值;只驗證鍵名與現值,未驗證「一幀=一個原子批次」的計時保證(ADR 標記為另一項獨立的 LIKELY-BUT-UNVERIFIED,本次未涉及) |
| #5 | 確認本機/本專案環境結構性缺三項先決條件(GodotSteam、App ID、Steam 客戶端登入),說明需要什麼才測得到 | 完全未執行任何測試——如實回報「做不到」,沒有用推測值填充 |
| #9 | 非 headless 真實視窗、`push_input()` 注入單一 `InputEventMouseMotion`、`is_hovered()`/`get_draw_mode()` 雙重驗證、前後對照 | 只測了單一事件注入,未測連續滑鼠移動下的 hover 進入/離開時序;只測了 `Button`,未測其他 Control 子類(`OptionButton`/`CheckBox` 等)是否有相同行為;未用真人操作滑鼠驗證(見上方「輸入模擬方式的差異揭露」) |
| #10 | 非 headless 真實視窗、真實 OS 焦點切換(PowerShell 自動化,非引擎內部模擬)、2 個完整 OUT/IN 循環、5 個 recorder 橫跨機制六全部實際優先序值 | 只在 Windows 11 測過(其他 OS 的視窗管理器行為未知);樣本數僅 2 循環(遠低於 #2 的 6 次);未測試「焦點切換發生在 `_process()` 執行**期間**」這種更極端的時間點(本次的切換都發生在正常的引擎迴圈之間,不是刻意卡在某個節點的 `_process()` 呼叫中途) |
| #13 | headless、三組事件(pressed+echo=false / pressed+echo=true / released 對照組)、直接查證 `InputMap.event_is_action()` 的行為 | 只測了鍵盤路徑(`InputEventKey`);未測手把類比搖桿是否有類似的「連續視為 NAVIGATION」機制(E1 缺陷原始證據是手把路徑,本次補的是鍵盤路徑,兩者未在同一次測試裡比較) |

---

## 已知簡化

- **#2、#10 的「recorder」節點都是拋棄式 helper,刻意不宣告 `class_name`**——只用
  `const X := preload(...)` 取得類別,避免這份 spike 要求先跑一次額外的 `--import` 才能用
  (`class_name` 全域註冊需要快取)。這對結論沒有影響,純粹是簡化建置步驟。
- **#2 的注入使用 `Input.parse_input_event()`,#9 使用 `Viewport.push_input()`**——兩者是
  不同的注入層級(全域 Input 單例 vs 特定 viewport 的 GUI 管線),各自對應被測問題的正確
  注入點,但**不能假設兩者對「真人實際操作」的還原度相同**。細節見各項判定內的「輸入模擬
  方式的差異揭露」小節。
- **#10 的兩個 OUT/IN 循環由固定秒數的 `Start-Sleep` 排程**(3-2-3-3-3-3-3 秒的節奏),
  不是事件驅動的等待(例如等 Godot log 出現某一行才繼續下一步)。這在本次穩定重現,但
  理論上若某次執行環境變慢(例如系統負載高導致視窗切換延遲),固定秒數排程可能撲空——
  這是本次選擇的簡化,換取腳本複雜度較低。
- **#5 沒有嘗試任何形式的 mock/模擬 Steam 通知**(例如手動呼叫
  `Node.notification(NOTIFICATION_APPLICATION_FOCUS_IN)` 假裝是疊加層造成的)——那樣做
  只會測到「Godot 收到這個通知時會發生什麼」,完全答不了「Steam 疊加層會不會送出這個
  通知」這個真正的問題,所以判定為不值得做,直接回報做不到。

---

## 檔案

```
prototypes/adr0005-engine-probes-2026-09-01/
├── project.godot                      # 800x600、flush_stdout_on_print=true(headless 輸出必需)
├── README.md                          # 本檔
├── scenes/
│   ├── Probe13And3.tscn               # #13 + #3,main_scene 預設值(F5 安全)
│   ├── Probe2InputOrder.tscn          # #2
│   ├── Probe9FocusNoneHover.tscn      # #9(需非 headless)
│   └── Probe10FocusTiming.tscn        # #10(需非 headless + 外部焦點切換腳本)
├── scripts/
│   ├── probe13_and_3.gd               # #13 echo 過濾 + #3 設定鍵真名,兩項合併(皆 headless 安全)
│   ├── probe2_main.gd                 # #2 場景根節點,建立 5 recorder + 1 injector,序列 log 分析
│   ├── probe2_recorder.gd             # #2 零件:_input()/_process() 記錄
│   ├── probe2_injector.gd             # #2 零件:Timer 驅動的 Input.parse_input_event() 注入
│   ├── probe9_focus_hover.gd          # #9:Button + FOCUS_NONE + push_input(MouseMotion)
│   ├── probe10_main.gd                # #10 場景根節點,建立 5 recorder,鎖 FPS,逾時分析
│   └── probe10_recorder.gd            # #10 零件:_notification()/_process() 記錄
└── logs/
    ├── import.txt                                     # 一次性 --import 輸出
    ├── probe13_and_3_headless.txt                     # #13 + #3 完整輸出
    ├── probe2_headless.txt                            # #2 完整輸出(含逐行 log + 分析)
    ├── probe9_windowed.txt                            # #9 完整輸出
    ├── probe10_windowed.txt                           # #10 完整輸出(修法後,乾淨的兩循環)
    ├── probe10_windowed_attempt1_uncapped_fps.txt     # #10 第一次嘗試(FPS 未鎖,只錄到半筆),保留為證據
    ├── probe10_windowed.err.txt                       # #10 stderr(空)
    ├── probe10_windowed_attempt1_uncapped_fps.err.txt # 同上,第一次嘗試的 stderr(空)
    └── focus_steal_script_used.ps1                    # #10 使用的外部 PowerShell 焦點切換腳本(存檔備查)
```

---

## 狀態

**已完成(2026-09-01)**。六項全數處理:五項關閉(#2、#3、#9、#10、#13 皆已查證成立),
一項因環境結構性缺口做不到(#5,已說明需要什麼才測得到)。**#13 的結果需要回寫進
ADR-0005(危險方向,但落在已凍結子機制範圍內,只登記不設計);#3 的結果需要回寫更新
過時措辭(不影響決策)。** 這兩項回寫屬決策/文件內容,不在本 spike 動,由 ADR 的
下一次修訂處理。
