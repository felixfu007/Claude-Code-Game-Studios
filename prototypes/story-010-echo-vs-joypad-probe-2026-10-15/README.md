# Story-010 查證探針:方向鍵去抖收斂可行性

## 本 story 第一步要回答的問題

`battle_screen.gd` 的 `_direction_just_pressed()`(輪詢式,`Input.is_action_pressed()`)
與 `cursor_types.gd` 的 `classify_action()` echo 過濾(事件驅動,`InputEventKey`/`InputEventJoypadMotion`
直接處理)是否為「同一個去抖邏輯的兩份重複實作」,因而可以收斂成一份?

或者,兩者其實是**兩種不同的輸入模型**(輪詢 vs 事件驅動)各自需要自己的去抖/節流機制,
收斂在語意上不成立,正確結論應是「不收斂」+ 明確登記技術債?

## 查證結論(BLOCKING,工作單 Acceptance Criteria 第一步)

**答案是否定的 —— `InputEventKey.echo` 過濾結構上不可能涵蓋手把類比搖桿長按**,因為
`InputEventJoypadMotion` / `InputEventJoypadButton` 這兩個類別**根本沒有 `echo` 這個屬性**。
這不是「目前沒做」,是「這個屬性在這些類別的繼承鏈裡不存在」,無從過濾起。

### 探針一:`echo` 屬性是否存在(反射 + 靜態型別檢查雙重驗證)

腳本:`prototypes/story-010-echo-vs-joypad-probe-2026-10-15/probe_echo_property.gd`
指令:
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s prototypes/story-010-echo-vs-joypad-probe-2026-10-15/probe_echo_property.gd
```

**逐字原始輸出**(`run_output_echo_property.txt`):
```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

=== Probe: does InputEventJoypadMotion / InputEventJoypadButton have an 'echo' property? ===
InputEventKey has 'echo' in property list: true
InputEventKey.echo default value: false
InputEventJoypadMotion has 'echo' in property list: false
InputEventJoypadMotion.get('echo') (null if no such property): <null>
InputEventJoypadButton has 'echo' in property list: false
InputEventJoypadButton.get('echo') (null if no such property): <null>
=== Static-type compile check (already proven by prior parse-error run) ===
Prior run of this probe (same file, before this edit) failed to COMPILE with:
  'Expression is of type InputEventJoypadMotion so it can't be of type InputEventWithModifiers'
  'Expression is of type InputEventJoypadButton so it can't be of type InputEventWithModifiers'
This is the GDScript static type checker itself confirming, at parse time (not a runtime guess),
that InputEventJoypadMotion/InputEventJoypadButton do NOT inherit InputEventWithModifiers --
the class InputEventKey.echo is declared on. echo is structurally a keyboard-only concept.
```

🔴 **「parse-error 當證據」這個手法,為什麼比 `get()` 回 null 更強,值得單獨講清楚**:

這支探針第一次寫的版本裡,有兩行用靜態型別寫法去判斷
`motion_event is InputEventWithModifiers`,**結果整支腳本連編譯都過不了**:
```
SCRIPT ERROR: Parse Error: Expression is of type "InputEventJoypadMotion" so it can't be of type "InputEventWithModifiers".
SCRIPT ERROR: Parse Error: Expression is of type "InputEventJoypadButton" so it can't be of type "InputEventWithModifiers".
ERROR: Failed to load script ... with error "Parse error".
```
這不是我手寫的斷言、也不是我自己實作的規則去判斷「這兩個類別不是 `InputEventWithModifiers`
的子類別」—— **這是 GDScript 自己的靜態型別檢查器,在 parse 期,直接拒絕編譯這段程式碼**,
理由就是它自己認定這兩個型別之間不可能有 is-a 關係。依本專案
`.claude/docs/technical-preferences.md` 的 (A) 級證據定義(「這次量測,是執行了專案的程式碼,
還是重新實作了一份?」),這比執行期 `event.get("echo")` 回傳 `null`(這只是反射 API 回報
「找不到這個屬性名」,理論上還是可能因為反射 API 本身的行為被誤讀)更強一層 ——
**是引擎的型別系統本身在講話,不是我寫的反射迴圈在講話。** 兩種證據方向一致、互相印證,
但型別檢查器的拒絕編譯是結構性事實,不是我可以不小心寫錯的執行期判斷。

修正後的版本把這兩行改寫成只印出「上一次這樣寫會編譯失敗」這個事實本身(見
`probe_echo_property.gd` 現在的內容),而不是刪掉這個發現 —— **它本身就是證據的一部分**。

### 探針二:`Input.action_press()` / `is_action_pressed()` 在 headless 下是否照實反映

這支探針是為了解除派工單明確警告的一個陷阱(`Input.mouse_mode` 在 headless 下是
no-op 的已知前例)——**在依賴 `Input` 全域狀態寫正式測試之前,先確認它不是另一個
no-op 陷阱**。

腳本:`prototypes/story-010-echo-vs-joypad-probe-2026-10-15/probe_input_action_press_headless.gd`
指令:
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s prototypes/story-010-echo-vs-joypad-probe-2026-10-15/probe_input_action_press_headless.gd
```

**逐字原始輸出**(`run_output_input_action_press_headless.txt`):
```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

=== Probe: does Input.action_press() / is_action_pressed() round-trip headless? ===
Input.is_action_pressed(ui_up) BEFORE action_press = false
Input.is_action_pressed(ui_up) AFTER action_press  = true
Input.is_action_pressed(ui_up) AFTER action_release = false
```
**結論:不是 no-op 陷阱**——`Input.action_press()`/`action_release()` 在 headless 下會
正確反映到 `Input.is_action_pressed()` 的回傳值,`tests/unit/ui/direction_key_debounce_test.gd`
可以安全依賴這個機制驅動測試。

## 我選的路:不收斂,登記技術債(工作單 AC 第二步,第二分支)

**完全不收斂**——不只是「鍵盤收斂、手把維持」這種折衷,而是連 `battle_screen.gd` 的
Dictionary 去抖機制整體都不動。零行正式程式碼變更(`src/` 底下零改動)。理由:

1. **第一步查證已經是否定答案**:`echo` 過濾結構上涵蓋不了手把,工作單 AC 第二步的
   第二分支本來就明文規定「不得收掉 Dictionary 去抖這條路徑」。
2. **`_handle_hand_navigation()`(手牌列 S1 瀏覽游標)的去抖是主動且必要的**,而且它
   根本不經過 `classify_action()` —— 它完全忽略傳入的 `_event: InputEvent` 參數,直接
   輪詢 `Input.is_action_pressed()`。這不是「同一個邏輯兩份實作」,是一個完全獨立於
   ADR-0005/`CursorStateHost` 權威系統之外的輸入機制,服務一個 ADR-0005 完全不管轄的
   游標(手牌列游標,不是棋盤游標)。要收斂,代表要讓這個函式開始解析它目前丟棄的
   `event` 參數、檢查 `event is InputEventKey and not event.echo`,然後手把分支仍然
   必須保留現有的 Dictionary 輪詢 —— 這是在一個函式裡混用兩種時間語意(事件瞬時旗標
   vs 跨呼叫持續輪詢狀態),見下一節的回答。

## 協調者問題的回答:「只收斂鍵盤那一半」會讓程式變簡單還是變複雜?

**會變複雜,兩個呼叫端都是,而且其中一個完全沒有好處可言。**

- **`_handle_directional()`(棋盤游標)**:這個迴圈本體現在不管哪個分支都是 `pass`
  (見下方第 5 點的詳細分析)——棋盤游標的實際移動完全由 `CursorStateHost` 自己的
  `apply_buffered_navigation()` 管線處理,與這個函式的回傳值毫無關係。在一個兩個分支
  都已經是空動作的迴圈裡,為了「看起來有照 EPIC 收斂」而加一個
  `if event is InputEventKey` 分支,是**在一段已經不做任何事的程式碼裡,新增一條
  不做任何事的分岔**——純粹的負收益:多一行要讀、多一個要理解的分支,換不到任何
  行為上的差異。
- **`_handle_hand_navigation()`(手牌列游標)**:這裡是活的,拆分的代價是真實的。
  現有寫法用單一機制(輪詢 `Input.is_action_pressed()`)同時、一致地處理鍵盤與手把,
  不在乎是哪個裝置觸發了這次 `_input()` 呼叫。拆分之後,鍵盤分支要看「這一個事件實例
  自己的 `echo` 旗標」(事件驅動、瞬時),手把分支還是要看「這個動作橫跨多次呼叫、
  持續到現在是否仍按著」(輪詢、跨呼叫)——**同一個函式裡並存兩種完全不同的時間
  語意**,比現在「一種機制、兩種裝置都適用」更難讀、更難驗證、也更容易在其中一條
  分支漏改而不自覺(本專案這類「兩份實作、今天剛好答案一致」的教訓已有登記案例)。

**結論:不只是「可以不拆」,是拆了會讓程式更難維護,沒有對應的好處。** 這進一步支持
「完全不收斂」而不是某種鍵盤/手把各走一半的折衷方案。

## 誠實列出沒驗到的東西

- **真實手把硬體上長推類比搖桿,實際上多久送一次 `InputEventJoypadMotion`**
  (每格都送、還是只在數值變化時送)——這件事本機的 headless 環境測不到,需要真實
  手把裝置 + windowed 執行。`tests/integration/ui/battle_cursor_navigation_convergence_test.gd`
  檔頭(finding #3)已將此登記為「候選的 ADR-0005 層級缺口,owner 未指派」,本次查證
  沒有新增任何進展,也沒有嘗試用合成輸入去模擬這件事(合成事件只能證明
  `classify_action()`/`apply_buffered_navigation()` 這端的程式邏輯怎麼反應,無法證明
  真實硬體的輸送頻率)。
- **本次查證完全沒有涉及滑鼠奪回權威(`threshold_mouse_reclaim_policy.gd` 的
  E1 已知缺陷)的任何修補**——那是另一份被凍結的子機制,本 story 沒有碰,也不應該碰。
- **`_handle_directional()` 的死碼是否真的可以安全刪除,本次沒有動手驗證**
  (例如刪除後跑一次全套測試看會不會紅)——只做了靜態分析(讀程式碼 + grep 確認
  `_direction_was_pressed` 沒有其他讀者),沒有實際刪除再跑測試驗證,原因見下一節。

## `_handle_directional()` 死碼問題:我的建議(只寫建議,未動手)

**現狀**(協調者已獨立複驗):`_handle_directional()` 的迴圈本體自 Story 009 起恆為
`pass`,它呼叫 `_direction_just_pressed(action, _direction_was_pressed)` 算出的布林值
被完全丟棄;`_direction_was_pressed` 這個 Dictionary 除了 `_direction_just_pressed()`
自己讀寫之外,全專案沒有任何其他讀者。**棋盤游標那一半的去抖是完整的死碼,手牌列
那一半(`_hand_direction_was_pressed` / `_handle_hand_navigation()`)還活著、而且是
`_hand_bar.move_cursor()` 的真實前置條件。**

**重新讀 2026-10-13 那次管理者裁決後,我認為有一個關鍵落差值得指出**:那次裁決的
措辭是「保留債券式去抖,因為它在 gate 事件是否進入 host 的管線」("gating whether the
event reaches the host's pipeline")。但實際讀 `_handle_directional()` 現在的程式碼,
它**從來沒有 gate 過任何東西**——它只是計算一個值然後丟掉(`pass`)。`CursorStateHost`
的 `apply_buffered_navigation()` 是透過**完全獨立的另一個 `_input()` 接收端**
(同一顆事件,送到兩個不同節點,見 ADR-0005「dispatch order is TREE order」),不經過
`_handle_directional()`、也不讀它算出的任何東西。**也就是說:棋盤游標這一側,
"手把搖桿長按讓游標在棋盤上狂奔" 這個已登記的真實風險(E1 / finding #3),不管
`_handle_directional()` 的 Dictionary 去抖留不留著,都同樣存在或同樣不存在**——
那個風險完全活在 `CursorStateHost` 自己的管線裡,`_handle_directional()` 的死碼
從未、也不能保護它。

**基於這個落差,我的建議是:可以刪除 `_handle_directional()` 這部分死碼
(迴圈本體 + `_direction_was_pressed` 欄位),因為它現在提供的保護是零**——
保留它唯一的「好處」是避免動到我剛寫的 §3 迴歸鎖測試,但那不是刪不刪的理由,
那只是刪除時要一併處理的連帶工作。

**但我同時要誠實標出不確定的地方**:2026-10-13 那次裁決是管理者在知情狀況下做的
決定,我不確定當時的完整考量是否只是我上面讀到的這個(gate 事件進入管線),還是
另有我沒看到的脈絡(例如:未來打算讓 `battle_screen.gd` 層級自己承擔某種過濾職責,
把 `_handle_directional()` 的 debounce 當成預留的掛勾)。**我沒有把握排除後者**,
所以不建議直接動手刪除,只建議下一次要做這個決定的人,把上面這個「它從未 gate 過
任何東西」的具體程式碼事實一併納入考量。

**連帶工作,若決定要刪**:本次新增的
`tests/unit/ui/direction_key_debounce_test.gd` 裡的
`test_board_and_hand_direction_trackers_do_not_cross_contaminate`(§3)直接依賴
`_direction_was_pressed` 這個欄位存在、而且會在棋盤側按鍵時被寫入 —— 它驗證的是
「兩個 tracker 彼此獨立」。如果棋盤側那個 tracker 整個被刪掉,「獨立」這個斷言會
變成空洞的真(沒有第二個 tracker 可以拿來污染),**這條測試需要一併改寫或退場**,
不能放著不動(放著不動它會變成一條永遠綠燈、但不再驗證任何有意義行為的測試 ——
本專案已經為「測試顯示綠燈但沒有真正把關」這類情況付過代價,登記在
`.claude/rules/test-standards.md` 的敏感度證明門檻那一節)。**換句話說:這不是
一次零成本的清理,決定要刪的人請一併排進這條測試的處置。**
