# Story 004 測試證據品質覆核 — 2026-09-03

> **範圍聲明**:本報告只覆核測試證據撐不撐得起其宣稱的涵蓋範圍。引擎正確性(`classify()`/
> `classify_action()` 實作本身是否符合 ADR-0005 機制四/四之二)由另一份平行報告
> (`docs/reviews/story-004-engine-review-2026-09-03.md`)覆核,本報告不重複判定。
>
> 覆核對象:
> - `tests/unit/cursor/device_classification_test.gd`
> - `production/epics/cursor-highlight-state/story-004-device-classification.md`
> - `prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt`
> - `.claude/docs/coding-standards.md` Testing Standards 節、`.claude/rules/test-standards.md`
> - `src/ui/cursor/cursor_types.gd` 本次改動(僅為理解被測物件,不判定其正確性)
> - `src/ui/cursor/cursor_state_host.gd`、`tests/unit/cursor/state_host_test.gd`(查 Autoload 交互)
>
> 找不到獨立於測試檔本身的「Story 004 逐條 AC 自評」文件——`production/session-state/active.md`
> 未提及本 story 已完工,`production/epics/.../story-004-device-classification.md` 的
> Test Evidence 節仍寫「尚未建立」。**下方「自評」全部依據測試檔檔頭註解(1–38 行)與
> `cursor_types.gd` 新增區塊的 doc comment ——這是唯一找得到的物證。**

## 1. 8 條 AC 逐條核對

**已查核。**

| AC | 測試斷言了什麼 | 與 AC 原文的差距 | 自評歸屬是否成立 |
|---|---|---|---|
| AC-6 | `button_index=999`(不對應任何 action)→ `classify_action()` 回 `OTHER`(檔案 21-22 行,測試 255-266 行) | AC-6 的 THEN 子句是「裝置權威與游標目標皆不變」——那是 `CursorState`/Story 005 裁決層的行為,本 story 沒有該狀態可測。測試只驗到「分類正確判為 OTHER」這個**必要前提**,不是 AC 本身 | 成立。檔頭 27-28 行的籠統但書(「full arbitration/persistence behaviour is Story 005」)涵蓋了這一半缺口,雖未逐條寫「AC-6 的權威不變半句歸 Story 005」 |
| AC-7 | `classify()` 對 5 種 `.device` 值(含專案實測到的鍵盤 `device=16`,見 `project.godot` `battle_confirm` 節)回傳相同 `Authority`(測試 104-139 行) | AC-7 的 THEN 子句同樣是「裝置權威不因裝置 ID 改變而轉移或重置」——狀態層行為,本 story 未觸及。測試驗到的是**結構性前提**:`classify()` 確實不讀 `.device`,若它讀了,AC-7 在狀態層必然不成立 | 成立,理由同 AC-6 |
| AC-8 | 合成滑鼠事件(`InputEventMouseMotion`/`InputEventMouseButton`)在未綁定任何 `ui_*` action 時回 `OTHER`(測試 269-286 行) | 與 AC-6/7 同構——差距在「權威不轉移」是狀態層行為 | 成立 |
| AC-9 | 10,000 次重複呼叫同一 `NAVIGATION` 事件,斷言結果不漂移(測試 289-316 行) | AC-9 本體是「裝置權威在任意長時間後仍持續為 A,無逾時釋放」——這是 `CursorState` 欄位在 Story 002/005 的行為。`classify_action()` 是無狀態函式,不可能是逾時 bug 的來源,但測試本身**不是**在驗證 AC-9 陳述的現象 | **這是唯一有個別、具體歸屬說明的一條**(測試檔 289-301 行明講「supplementary only, not full AC-9 coverage… lives in Story 002/005」)。自評用語準確,誠實 |
| AC-34 | 對 `NAVIGATION_ACTIONS` 四個動作,各抓真實 `InputEventKey` 與 `InputEventJoypadButton`,兩種裝置皆須存在且分類為 `NAVIGATION`(測試 144-171 行) | 沒有差距——AC-34 的驗證標的(零門檻導覽分類,鍵盤/手把兩種裝置)在 `classify_action()` 這一層就是完整行為,不涉及狀態層 | 本條是全套裡覆蓋最扎實的一條 |
| AC-34b | 對 `NAVIGATION_ACTIONS` 四個動作,抓真實 `InputEventJoypadMotion`,斷言為 `NAVIGATION`(測試 174-193 行) | 同 AC-34,無差距 | 成立 |
| AC-35 | 對 `CONFIRM_ACTIONS`(`ui_accept`/`ui_cancel`)各取 `events[0]`,斷言為 `CONFIRM` 且不等於 `NAVIGATION`(測試 196-217 行) | **AC-35 原文明講「鍵盤或手把」兩種裝置**,但實測 `probe_output.txt` 第 95、97 行顯示這個引擎/專案的 `ui_accept`/`ui_cancel` 預設**只綁了 `InputEventKey`,沒有 `InputEventJoypadButton`**——`events[0]` 因此永遠只會抓到鍵盤事件。**手把觸發確認類動作的路徑在這套測試裡從未被真正執行過**,即使 AC 原文點名要驗兩種裝置 | **自評沒有標記這個缺口**——AC-35 在檔頭與 AC-34/34b 同樣被列為「已覆蓋」,沒有但書。這是本次覆核找到的**唯一一處自評未揭露的落差**(見下方判定) |
| AC-9 之外的 echo 過濾義務 | 見下方第 3 節 | — | — |

**AC-35 補充說明(為何我不判定為嚴重)**:`classify_action()` 對 `CONFIRM_ACTIONS` 的判斷路徑是
`for action in CONFIRM_ACTIONS: if InputMap.event_is_action(event, action)`——**沒有像
echo 過濾那樣針對某個裝置類別的特殊分支**。也就是說,鍵盤路徑與手把路徑在程式碼裡走的是
**同一行邏輯**,不像「echo 過濾只對 `InputEventKey` 生效」那樣有裝置特定的分岔會被漏測。
因此雖然測試沒有真的驗到手把觸發確認類動作,**目前程式碼結構下沒有一個「只有手把會走到、
鍵盤測試驗不到」的分支**——這不是藉口,只是判斷嚴重度的依據:漏測的是「引擎目前沒提供
可測資料」的情境,不是「程式碼有特殊路徑沒人測過」。

**判定**:AC-6/7/8/9/34/34b — **ADEQUATE**(在本 story 分類層的範圍內,歸屬說明大致誠實,
AC-9 的個別但書最精確)。AC-35 — **INCOMPLETE,嚴重度 S3(低)**:自評未揭露「手把觸發確認類
動作」這一半從未被真正執行過的真實 `InputEventJoypadButton`;建議在測試檔頭或 story 文件補一句
揭露(不需要新增測試,因為引擎現況下手把根本沒有可用的真實確認類事件可抓)。

## 2. AC-9 的 10,000 次迴圈是否有偵測力

**已查核。判定:偵測力接近於零,但不到「假造涵蓋外觀」的程度——它有誠實的自我揭露。**

- `classify_action()`(`src/ui/cursor/cursor_types.gd` 116-131 行)是純靜態函式:沒有成員變數、
  沒有 `Timer`、沒有 frame counter、沒有任何以呼叫次數或經過時間為條件的分支。對**同一個輸入**
  呼叫 10,000 次,唯一能讓結果漂移的情境是記憶體損毀或引擎本身的非決定性——這兩者都不是
  這條測試設計要抓的東西,也不是這條測試「跑一次」與「跑一萬次」在偵測力上有任何差異的理由。
- 換句話說:**這條測試第 2 次呼叫起就不再提供任何超越第 1 次呼叫的資訊。** 10,000 這個數字
  來自 AC-9 原文自己给的「操作化下限」建議(工作單 63 行:「建議以模擬至少 10,000 個影格…
  作為操作化下限」),但 AC-9 那句話講的是**要驗證『狀態欄位』不逾時釋放**的情境模擬長度,
  用在一個**沒有狀態欄位可驗**的純函式上,這個下限沒有對應的意義——它是在借用一個為
  別的驗證目的定的數字。
- **好的部分**:測試檔 289-301 行的類別註解**沒有假裝**這條測試驗到了 AC-9 本體,而是誠實寫
  「supplementary only」並解釋清楚它實際證明的是什麼(無狀態、結構性不可能是逾時 bug 來源)
  ——這正是 AC-9 原文建議的「優先以程式碼審查確認」那條路徑的書面版本。**問題不是誠信,
  是這條測試本身的存在對涵蓋範圍沒有加分,卻會讓「27 條斷言」的敘事顯得比實際扎實**
  (雖然「27」數的是原始碼中 `assert_` 呼叫點數量,不是執行期斷言次數,所以這個數字本身
  沒有被灌水——見下方第 3 節說明)。

**建議(供主 session 參考,不代表已裁決)**:把這條測試的迴圈次數大幅降低(例如 2-3 次
即可證明「呼叫兩次結果一致」,循環次數本身不影響能不能抓到 bug),把 10,000 這個數字的說明
移到 doc comment 裡引用 AC-9 原文,而不是真的執行一萬次——目前的寫法會讓每次跑測試都浪費
時間卻不換來額外的偵測力。**若要真正驗證 AC-9,程式碼審查（確認 `CursorState` 沒有計時器
欄位)是唯一有意義的方法,這件事應該記在 Story 002/005 的證據裡,而不是靠這裡的迴圈次數
充數。**

## 3. 迴歸偵測力

**已查核。**

### 3a. echo 過濾測試是否必然變紅

`test_classify_action_filters_out_echoed_key_events`(測試 219-252 行)。若把
`cursor_types.gd` 127 行的 `if event is InputEventKey and (event as InputEventKey).echo:
return ActionClass.OTHER` 拿掉:

- `echo_event`(237-243 行複製自真實 `ui_up` 綁定,`echo=true`)會落入 129-133 行的
  `for action in NAVIGATION_ACTIONS: if InputMap.event_is_action(event, action): return
  ActionClass.NAVIGATION` 迴圈。已由本專案自己的探針
  (`prototypes/adr0005-engine-probes-2026-09-01/logs/probe13_and_3_headless.txt`,
  `story-004-device-classification.md` 40 行引用)證實 `InputMap.event_is_action()`
  **不區分** `echo=true`/`false`——因此拿掉過濾後 `echo_event` 會被判為 `NAVIGATION`。
- 測試斷言 `is_not_equal(NAVIGATION)` 與 `is_equal(OTHER)`(249-252 行)——兩者都會失敗。
- **結論:這條測試必然變紅,不是「他自述變紅」這件事本身沒有物證,而是我獨立從程式碼推導
  出同樣結論,兩者互相印證。** 判定:**ADEQUATE**,這是本套測試裡最扎實的迴歸偵測。

### 3b. 其餘 14 條裡有沒有「不可能失敗」的測試

沒有找到嚴格意義上「不管實作怎麼改都不會變紅」的測試。但找到一個**性質相關但不同**的問題,
比「不可能失敗」更隱蔽:

🔴 **三條測試在特定情境下會靜默通過(執行零次斷言而不是斷言成立)**:
`test_classify_action_returns_navigation_for_keyboard_and_gamepad_button_nav_actions`
(144-171 行)、`test_classify_action_returns_navigation_for_joypad_motion_nav_action`
(174-193 行)、`test_classify_action_returns_confirm_not_navigation_for_confirm_actions`
(196-217 行)——三條都是 `for action in CursorTypes.NAVIGATION_ACTIONS`(或
`CONFIRM_ACTIONS`)包住全部斷言。**若有人把 `cursor_types.gd` 的
`NAVIGATION_ACTIONS`/`CONFIRM_ACTIONS` 改成空陣列 `[]`,這三條測試函式會執行、迴圈零次、
不觸發任何 `assert_`、GdUnit4 視為通過(綠燈)。** 我查了 `addons/gdUnit4/src` 底下有沒有
「零斷言即失敗/警告」的機制(搜尋 `assert.*count`、`no assertion` 等關鍵字)——**沒有找到
這樣的機制**,故此風險是真實的,不是我的臆測。
**這與「不可能失敗」不同,更難發現**:表面上看起來是三條在跑迴圈、驗四個動作的扎實測試,
實際涵蓋度完全綁在 production 常數目前的內容上,**測試本身不驗證這份白名單「有沒有被
意外清空/縮小」**。這正好是 `NAVIGATION_ACTIONS`/`CONFIRM_ACTIONS` 這兩個常數（本 story
新增的產出物之一）唯一會被意外破壞的方式,卻沒有任何一條測試釘住「這兩個陣列必須恰好等於
`[ui_up, ui_down, ui_left, ui_right]` / `[ui_accept, ui_cancel]`,不多不少」。
**判定:INCOMPLETE,嚴重度 S2(建議在本 story 內補,不是推給 Story 006)**——Story 006 的
「載入期完整性驗證器」驗的是「引擎有的 `ui_*` action 有沒有被分類過」(白名單擴張方向的漏項),
跟這裡「本 story 自己定義的常數被意外縮減」是不同方向的風險,不能互相取代。補法很簡單:
加一條 `assert_array(CursorTypes.NAVIGATION_ACTIONS).contains_exactly([&"ui_up", &"ui_down",
&"ui_left", &"ui_right"])`(`CONFIRM_ACTIONS` 同理),成本低、能直接堵住這個洞。

## 4. 決定性

**已查核。判定:ADEQUATE,無亂數種子、無時間相依、無執行順序相依。**

- 全檔搜尋沒有 `randi`/`randf`/`Time.`/`OS.get_ticks_*` 等呼叫。
- 每個測試函式內部自己 `new()` 建構所需的 `InputEvent`,或用 `.duplicate()` 複製
  `InputMap` 回傳的事件後才修改(237、241、309 行)——**沒有任何一處直接修改
  `InputMap` 本身回傳的物件**,故測試之間、與 `InputMap` 全域狀態之間都不互相污染。
  這符合 `.claude/rules/test-standards.md`「Unit tests must not depend on external state」
  與「tests must not depend on execution order」。
- **Autoload 交互**:查了 `src/ui/cursor/cursor_state_host.gd`——`_ready()`
  (75-80 行)只建構 `CursorState.new(null, CursorSurfaceRegistry.new(), Callable(...))`,
  不觸碰 `InputMap`、不註冊任何全域設定、不啟動計時器。本測試檔本身也不建立任何節點、
  不呼叫 `CursorStateHost` 的任何方法(檔頭 5-8 行已自陳「no node, Input, or file-I/O
  dependency」,查證屬實)。**`CursorStateHost` 在每個測試場景啟動這件事,對本檔沒有
  已知的交互風險**——它與本檔測試的 `InputMap` 讀取路徑完全不相交。

## 5. 測試脆弱性

**已查核。除了實作者自己指出的一項(`project.godot` 輸入綁定變更會使某些測試失敗),
還找到兩項未被指出的:**

1. **依賴引擎版本釘死,而非只依賴本專案設定。** 這些測試讀的是 **Godot 4.7.1 的內建
   `ui_*` 預設值**,不是本專案 `project.godot` 自訂的東西(`project.godot` 的 `[input]`
   節只有 `battle_confirm`/`battle_end_phase` 兩個自訂項,已核對)。這代表:即使沒有人
   碰 `project.godot`,**未來若專案升級引擎版本、且該版本調整了任何一個 `ui_*` 動作的
   內建預設綁定**(例如未來版本把 `ui_accept` 也加上手把綁定,或調整死區判定),這些測試
   一樣會受影響,而這不在實作者自陳的「有人改 `project.godot`」這個風險描述範圍內——
   他的措辭把風險窄化成「本專案設定被改」,但實際依賴面更廣,涵蓋「引擎本身的預設值」。
   `docs/engine-reference/godot/VERSION.md` 已把此專案標為 4.7.1 釘死,短期風險低,但這是
   一個未被寫下來的假設,值得補一句。
2. **`ui_select`(`ACKNOWLEDGED_OTHER_ACTIONS`)在探針裡有 `InputEventJoypadButton`
   綁定,但完全沒有測試覆蓋它落在 `OTHER` 分支這件事**(它不在 `NAVIGATION_ACTIONS`
   也不在 `CONFIRM_ACTIONS`,理論上應該落到 `classify_action()` 的 `return
   ActionClass.OTHER` 尾端)。這不是 AC 明文要求的項目,但它是 `cursor_types.gd`
   新增的 `ACKNOWLEDGED_OTHER_ACTIONS` 清單裡少數**有真實手把綁定**的一項,如果未來
   有人不小心把它移進 `NAVIGATION_ACTIONS`(例如手滑複製貼上),沒有任何測試會抓到——
   屬於低嚴重度的補強建議,不是缺陷。

## 6. 邊界值與失敗態涵蓋

**已查核。** 工作單 80-81 行已自陳「AC 沒有列邊界值與失敗態」,以下是實際盤點:

| 邊界/失敗態 | 目前狀態 | 判定 |
|---|---|---|
| `InputMap` 缺少某個必要動作的綁定(例如 `ui_up` 被整個移除) | 有覆蓋——`assert_object(...).is_not_null()` 帶明確失敗訊息(144-171 行等),符合工作單 44 行「必須大聲失敗,不得默默降級」的要求 | 不必補 |
| `NAVIGATION_ACTIONS`/`CONFIRM_ACTIONS` 常數本身被意外清空或縮小 | **沒有覆蓋**(見第 3b 節) | **該補,已列為本節該補項** |
| 手把觸發的確認類(`CONFIRM`)動作 | **沒有覆蓋**(見第 1 節 AC-35 分析,現況下引擎沒有真實可抓的樣本) | 不必補測試,但該在文件揭露 |
| 觸控事件(`InputEventScreenTouch`/`InputEventScreenDrag`) | 沒有覆蓋,只測了 `InputEventAction` 作為「不屬於任一裝置家族」的代表 | 不必補——`technical-preferences.md` 明文本專案 **Touch Support: None** |
| 空/null 事件(`classify(null)`、`classify_action(null)`) | 沒有覆蓋 | **可以補,低優先**——GDScript 靜態型別下呼叫端傳入 `null` 給宣告為 `InputEvent` 參數的函式通常會在呼叫點就報型別錯誤而非進入函式體,但這是推測,沒有實測驗證,標記為「推測」而非結論 |
| `InputEventKey` 的 `echo=true` 但 `pressed=false`(放開鍵的 echo,理論上不該發生但未防禦) | 沒有覆蓋 | 不必補——echo 過濾條件只看 `.echo`,與 `.pressed` 無關,補這條不會增加偵測力 |
| 手把類比搖桿在死區邊界值(剛好等於/低於死區)是否觸發 `ui_*` action | 沒有覆蓋,且**這本來就是引擎 `InputMap.event_is_action()` 自己的職責**,不是 `classify_action()` 要驗的東西(AC-34b 條文本身也在 Open Questions 註記死區濾除不在本 AC 驗證範圍) | 不必補——正確地排除在本 story 範圍外 |

## 總體判定

**整體:ADEQUATE,但有 2 項該在本 story 內修正、1 項該補文件揭露、1 項建議簡化。**

| # | 項目 | 判定 | 嚴重度 | 歸屬 |
|---|---|---|---|---|
| 1 | AC-6/7/8/9/34/34b 覆蓋 | ADEQUATE(分類層範圍內) | — | 本 story 已達成 |
| 2 | AC-35 缺手把確認類動作真實樣本,自評未揭露此落差 | INCOMPLETE | S3(低,因無裝置特定分支) | **本 story**——補一句文件揭露即可,不需新測試 |
| 3 | AC-9 的 10,000 次迴圈偵測力趨近於零 | 建議簡化,非缺陷(自評誠實揭露) | 建議性 | **本 story**——供實作者裁量是否簡化 |
| 4 | `NAVIGATION_ACTIONS`/`CONFIRM_ACTIONS` 常數被意外清空時三條測試會靜默通過零斷言 | INCOMPLETE | **S2** | **本 story**——建議補一條 `contains_exactly` 斷言,成本低 |
| 5 | echo 過濾測試迴歸偵測力 | ADEQUATE,獨立驗證必然變紅 | — | 已達成 |
| 6 | 決定性、執行順序、Autoload 交互 | ADEQUATE | — | 已達成 |
| 7 | 引擎版本升級的隱性依賴、`ui_select` 未覆蓋 | 低嚴重度補強建議 | S4 | 不阻擋,供未來參考 |

**高報/低報總結**:沒有找到高報(宣稱驗到卻沒驗到的情形)。找到一處**低報候選**——AC-35
的手把路徑缺口沒有被指出,但這是「該揭露而未揭露」而非「明知故意推給別張工作單」,且程式碼
本身沒有裝置特定分支可能藏 bug,嚴重度低。**沒有發現實作者把本該屬於本 story 的東西刻意
推給 Story 002/005/006 的情形**——歸屬到那三張工作單的部分(權威轉移的狀態層行為、白名單
擴張方向的完整性驗證)在架構上確實不屬於本 story 產出的純函式,歸屬正確。
