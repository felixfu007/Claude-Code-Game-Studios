# Spike:單一游標/高亮狀態系統——滑鼠奪權子機制 Godot 4.7.1 引擎行為驗證

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證 harness,不是完整系統實作
> **問題**:`design/gdd/cursor-highlight-state.md`(第十輪 `/design-review`,滑鼠奪權子機制觸發止損政策、MAJOR REVISION、同 session 完成重新設計)登記了兩項待 spike 驗證的殘留風險,兩者都無法只靠讀文件/推理解決,必須在 Godot Editor 裡實際跑起來、用真實硬體測試:
> 1. **Control offset transform 是否影響命中測試**(Open Questions,godot-specialist 列,`docs/engine-reference/godot/current-best-practices.md`/`breaking-changes.md` 皆點名 hover feedback 為 Godot 4.7 offset transform 的旗艦用例)——若視覺變換與命中測試分離,GDD 本輪判定應回頭升級為 MAJOR REVISION。
> 2. **方向鍵/搖桿持續按住期間,重置觸發點 (d)(原 (e))是否可能造成滑鼠永久無法奪權**(Core Rules #3「累積起點的重置時機」明文登記為「已知殘留風險」,取決於未經驗證的引擎逐幀事件派發頻率)。
> **日期**:2026-08-05
> **執行者**:人類測試者於 Godot Editor 手動執行(本 agent 的環境沒有安裝 Godot,無法自行執行驗證)
>
> **第二輪補測(2026-08-11 新增,不更動上方原始框架文字)**:第十輪同日直接寫入的修法(否決資格限縮為「新按下」的那一影格 + 保險上限,AC-56/57)已於 2026-08-06 第十一輪對抗性審查判定該修法本身不成立並**撤回**(引用未測試 API、新增未登記隱藏狀態、三輸入來源一致性未驗證)。撤回是正確決定,但撤回後**沒有留下任何暫行防線**——缺陷(持續按住方向鍵/搖桿導致滑鼠奪權永久鎖死)本身維持 100% 可重現、未緩解,已登記於 `design/gdd/cursor-highlight-state.md` 的「Known Confirmed Defects」節,且該節明文規定「必須先經過至少一次完整對抗性審查才可寫入規則本體,不得重演同日修法的例外處理方式」。在提交下一輪對抗性審查之前,本輪先用這份 harness 讓真人測試者驗證 GDD 已登記的候選修法方向(依 `InputEventKey.echo`/`is_action_pressed(action, allow_echo=false)` 過濾同影格否決資格)在 D-pad、類比搖桿、鍵盤三種輸入來源上分別是否有效,不假設一致。詳見下方「Test 2 第二輪補測(2026-08-11)」章節(程序 B2-B5)。

---

## 這個 spike 是什麼、不是什麼

**是**:兩個獨立、最小化的 Godot 4.7.1 測試場景,各自針對上面一個開放問題做儀器化(instrumentation)——把引擎的原始行為攤開顯示在畫面上,讓人類測試者用眼睛和真實硬體判斷。

**不是**:`cursor-highlight-state.md` 的完整實作。沒有棋盤格、沒有關係圖迷你地圖、沒有下游系統、沒有依表面類型分表的門檻常數表——這些都留給正式的 `/create-architecture` 之後的實作。本 spike 只抽出兩個開放問題各自需要的最小骨架。

Test 2(滑鼠奪權 harness)刻意只實作 GDD **目前(第十輪重新設計後)的四項重置觸發清單**,不是第九輪以前的五項舊清單(已被使用者裁決移除的觸發點「滑鼠離開命中框後又返回」**沒有**被實作):

- **(a)** 裝置權威轉移(任一方向)
- **(b)** 目前高亮目標改變
- **(c)** 失焦全程不運算、復焦時重新播種起點
- **(d)** 同影格內滑鼠已達門檻,但被鍵盤/手把固定優先序否決

---

## 專案結構

```
prototypes/cursor-reclaim-godot-spike-2026-08-05/
├── project.godot                          # 最小 Godot 4.7.1 專案設定
├── scenes/
│   ├── OffsetTransformHoverTest.tscn       # Test 1
│   └── MouseReclaimHarness.tscn            # Test 2
└── scripts/
    ├── hover_target_box.gd                 # Test 1:單一懸停目標(translate/rotate/scale 三選一)
    ├── debug_overlay.gd                    # Test 1 專用:畫出 get_global_rect() 的即時外框
    ├── offset_transform_hover_test.gd      # Test 1 場景根腳本(程式化組出整個畫面)
    └── mouse_reclaim_harness.gd            # Test 2 場景根腳本(狀態機 + 除錯面板 + 事件記錄)
```

兩個場景的 UI 都是在根腳本的 `_ready()` 內用程式碼組出來的(沒有把 Label/Container 等節點手刻進 `.tscn`)。這是刻意的取捨:本 agent 沒有 Godot 可以打開驗證手刻的 `.tscn` 節點樹是否真的合法,把結構寫在單一腳本檔案裡,人類測試者只需讀一個檔案就能確認畫面上每個東西的來源,不需要交叉比對 `.tscn` 和腳本兩份資料。`debug_overlay.gd` **只給 Test 1 用**——Test 2 的所有面板、進度條、事件記錄都直接建在 `mouse_reclaim_harness.gd` 裡,`MouseReclaimHarness.tscn` 不需要、也沒有引用 `debug_overlay.gd`。

---

## 前置需求

1. **Godot 4.7.1**(必須是這個版本或非常接近——本專案釘選版本見 `docs/engine-reference/godot/VERSION.md`;用其他 4.x 版本測試,結果對本 spike 要驗證的問題可能沒有參考價值,因為兩個開放問題本身就是「這是不是 4.7 才有的行為變化」)。
2. Test 2 需要**真實滑鼠 + 真實手把**(Xbox/PlayStation/任何 Godot 能辨識的 XInput/標準手把皆可)。**沒有實體手把的話,可以先用鍵盤方向鍵代替跑一次流程,但無法回答開放問題 (a) 的手把半部分**——鍵盤的 OS 層級 key-repeat 機制與手把的事件派發機制不是同一套,兩者都要各自測過。
3. Test 1 只需要滑鼠。

---

## 如何開啟專案(兩個測試共用的步驟)

1. 開啟 Godot Engine 4.7.1(Project Manager 畫面)。
2. 點選 **Import**(或 **Scan** 後在清單中若已出現本專案則直接點兩下開啟)。
3. 瀏覽並選擇 `prototypes/cursor-reclaim-godot-spike-2026-08-05/project.godot`,點 **Import & Edit**。
4. 等待編輯器完成第一次匯入(本專案沒有外部美術資源,只有幾個 `.gd`/`.tscn` 檔案,應該幾秒內完成)。
5. 編輯器左下角 **FileSystem** dock 展開 `scenes/`,裡面應該看到 `OffsetTransformHoverTest.tscn` 與 `MouseReclaimHarness.tscn` 兩個場景檔案。
6. **在測試任一場景前**,建議先做一次 Input Map 健檢(見下方「開場健檢」),確認本專案沒有意外把滑鼠鍵綁到 `ui_*` 動作上——這是 GDD Core Rules #3「滑鼠奪權前提約束」的前提,若違反,Test 2 的所有結果都不可信。

### 開場健檢(建議每次測試前做一次,約 30 秒)

1. 選單 **Project → Project Settings...**
2. 切到 **Input Map** 分頁。
3. 找到 `ui_up` / `ui_down` / `ui_left` / `ui_right` / `ui_accept` / `ui_cancel` 六個動作。
4. 展開每一個,確認列出的綁定事件圖示都是鍵盤鍵(方向鍵/WASD 不會出現,除非你自己改過)或手把圖示(D-pad 按鈕、類比搖桿軸),**不應該出現滑鼠圖示**(滑鼠左鍵/右鍵/移動)。
5. 本專案的 `project.godot` **沒有**自訂 `[input]` 區塊——這六個動作用的是 Godot 引擎內建預設值。若你在步驟 4 看到滑鼠圖示,代表你本機的 Godot 安裝或某個 editor 設定被改過預設值,請先排除這個變因再繼續測試(見下方「建構過程中的發現」第 1 點,說明為什麼本 spike 選擇依賴引擎預設值而不是手刻 `[input]` 區塊)。

---

## Test 1:Control Offset Transform 與滑鼠懸停命中測試

**驗證的開放問題**:Godot 4.7 的 Control offset transform(translate/rotate/scale,不經過 Container 重新排版)套用在一個 Control 上時,`_gui_input` 的滑鼠路由與 `get_global_rect()` 是否跟著視覺變換一起動,還是仍然錨定在變換前的版面矩形上?

### 執行步驟

1. 在 FileSystem dock 點兩下開啟 `OffsetTransformHoverTest.tscn`。
2. 按 **F6**(或選單 **Scene → Run Current Scene**)只執行這個場景。
3. 畫面應該顯示:上方說明文字、中間一列三個方塊(標籤分別是 `TRANSLATE`、`ROTATE`、`SCALE`)、方塊下方一組即時 `get_global_rect()` 數值讀出、最下方一個持續捲動的事件記錄面板。
4. **對每一個方塊分別重複以下動作**(建議先測 `TRANSLATE`,再測 `ROTATE`,最後測 `SCALE`,三者的變換機制不同,行為可能不一致):
   a. 把滑鼠移到方塊**外面**、方塊完全沒有反應的地方。
   b. 慢慢把滑鼠往方塊**原始(未變換前)的邊緣**移動,觀察方塊何時開始出現**黃色 hover-flash 半透明疊色**(這個疊色只受 `mouse_entered`/`mouse_exited` 訊號控制,代表引擎認定「滑鼠現在在這個 Control 上面」)、何時開始播放位移/旋轉/放大動畫。
   c. 方塊完成動畫變換後(視覺上已經明顯位移/旋轉/放大),**把滑鼠移到「變換後的視覺範圍內、但變換前的原始範圍外」的區域**——例如 `SCALE` 方塊放大後,新增出來的外圈區域;`ROTATE` 方塊轉了角度後,原本矩形四個角落之外新蓋到的三角形區域;`TRANSLATE` 方塊往左上位移後,原本位置與新位置之間的走廊區域。
   d. 觀察這個「只有變換後才蓋到」的區域:黃色疊色**是否還亮著**?移到這個區域時,下方的事件記錄面板**有沒有繼續出現**該方塊的 `_gui_input` 紀錄?
   e. 同時看綠色外框——這是 `DebugOverlay` 每一影格用 `get_global_rect()` 即時畫出來的外框,`DebugOverlay` 本身沒有任何變換,所以這個外框畫的位置永遠等於引擎認為的「這個 Control 的碰撞矩形」。**綠色外框有沒有跟著方塊一起位移/放大?還是留在原地不動、或只變大變小了矩形尺寸但沒有跟著旋轉?**

### 判定標準

- **若證實視覺變換與命中測試脫節**(即:黃色疊色與綠色外框在整段動畫期間都停在方塊變換前的原始矩形,不論方塊視覺上轉到哪裡都不跟著動;或 `_gui_input` 只在原始矩形範圍內觸發,變換後新蓋到的區域完全沒有事件)——這**直接對應 GDD Open Questions 已經預告的最高風險結果**:「若證實視覺變換與命中測試分離,本文件本輪判定應回頭升級為 MAJOR REVISION,需新增設計層規則」。這代表 GDD 假設「滑鼠移動永遠正確被辨識」在關係圖迷你地圖等使用 offset transform 做 hover feedback 的表面上不成立,需要提交下一輪 `/design-review`。
- **若證實視覺變換與命中測試一致跟隨**(黃色疊色、綠色外框、`_gui_input` 事件都準確跟著方塊當下的視覺位置/旋轉/縮放走)——GDD 的假設在 4.7.1 下成立,這條開放問題可以關閉,不需要新增設計層規則。
- **若三種變換模式(translate/rotate/scale)結果不一致**(例如 translate 正確跟隨,但 rotate 不跟隨)——這本身就是一個需要記錄的發現,代表 GDD 需要針對「哪些視覺變換類型安全、哪些不安全」寫更細的規則,而不是一刀切的結論。
- 額外觀察(非本題核心,但值得記一筆):`TRANSLATE` 方塊的位移動畫過程中,方塊有沒有出現「跳一下/抖一下再繼續」的現象——這可能是 HBoxContainer 在動畫途中把 `position` 搶回去重新排版(即 4.7 changelog 提到的「fighting container re-layout」)的跡象。

---

## Test 2:滑鼠奪權混合輸入儀器化 Harness

**驗證的開放問題**:(a) 手把方向鍵/類比搖桿持續按住期間,是否真的每一個處理影格都會產生一次具權威資格的導覽類 `ui_*` 動作?(b) `reclaim_threshold_px`(奪權空間門檻)大概多少像素,混合滑鼠+手把操作時手感是對的?

### 執行步驟

1. 在 FileSystem dock 點兩下開啟 `MouseReclaimHarness.tscn`。
2. 按 **F6** 只執行這個場景。
3. 畫面應該顯示:上方說明文字、一列狀態文字(`device_authority` / `OS focus` / `accumulated_net_displacement_px` / `reclaim_progress`)、一行「Held state / event rate」文字、一條進度條、`reclaim_threshold_px` 校準用的數值輸入框與一個「Force reset to UNINITIALIZED」按鈕、中間一列 5 個灰色方塊(目前高亮的那一個會變黃)、最下方持續捲動的事件記錄面板。

#### 程序 A——權威交接基本檢查(建議每次測試 session 開場先跑一次,確認 harness 本身正常)

1. 用滑鼠點一下畫面中央任一灰色方塊。確認:狀態列 `device_authority` 變成 `MOUSE`,事件記錄出現一行 `AUTHORITY CHANGE: UNINITIALIZED -> MOUSE`。
2. 按手把 D-pad 任一方向(或鍵盤方向鍵)一下。確認:`device_authority` **立即**(零門檻)變成 `KEYBOARD_GAMEPAD`,黃色高亮方塊跟著移動一格,事件記錄出現 `AUTHORITY CHANGE: MOUSE -> KEYBOARD_GAMEPAD`。
3. 把滑鼠移動一小段距離(明顯小於目前 `reclaim_threshold_px` 顯示值,預設 80px)。確認:`accumulated_net_displacement_px` 與 `reclaim_progress` 開始跟著滑鼠移動距離上升,但 `device_authority` 還停在 `KEYBOARD_GAMEPAD`,進度條沒有跑滿。
4. 繼續往同一方向移動滑鼠,直到 `reclaim_progress` 顯示接近或等於 `1.00`,且過程中**不要**再碰手把/鍵盤。確認:一旦累積淨位移跨過門檻,`device_authority` 變回 `MOUSE`,事件記錄出現 `AUTHORITY CHANGE: KEYBOARD_GAMEPAD -> MOUSE (reclaim threshold met, no same-frame veto)`。

若以上四步都符合預期,harness 本身狀態機正常,可以繼續下面兩個開放問題的實測程序。若有任何一步不符,先記錄下來(可能是 harness 本身的 bug,而不是引擎行為的發現),再繼續。

#### 程序 B——開放問題 (a):持續按住方向鍵期間,滑鼠是否永久無法奪權

1. 先重複程序 A 步驟 1-2,讓 `device_authority = KEYBOARD_GAMEPAD`。
2. **用手把類比搖桿**,把左搖桿完全推到某個方向底(例如向右推到底)並**持續按住不放**至少 5-10 秒。
3. 在持續按住的同時,**用另一隻手把滑鼠一次性快速移動一段明顯超過 `reclaim_threshold_px` 的距離**(例如把滑鼠從畫面一角甩到另一角)。
4. 觀察並記錄:
   - `reclaim_progress` 有沒有出現「一直逼近 1.00 又被打回 0」的鋸齒狀變化?
   - 事件記錄裡有沒有反覆出現 `VETOED: mouse reached reclaim_threshold_px this frame but a keyboard/gamepad ui_* action also fired this frame` ?如果有,**數一數這些 VETOED 訊息之間間隔多短**(看訊息前綴的 `[Xms]` 時間戳)——間隔如果落在個位數~數十毫秒等級,代表搖桿持續按住確實在每個或近乎每個處理影格都產生了合格動作。
   - `device_authority` 在整段持續按住期間,有沒有**任何一刻**成功變回 `MOUSE`?如果 5-10 秒內完全沒有變回 `MOUSE` 過,即使滑鼠移動距離早已遠遠超過門檻——**這就是 GDD 已知殘留風險的直接重現**。
   - 同時看「Held state / event rate」那一行:`ui_right`(或你按的方向)的 `events/last1s=` 數字大約是多少?這個數字直接回答「搖桿持續按住,每秒實際產生幾次具權威資格的動作」——如果這個數字接近 60(等於每個 `_process` 影格一次),GDD 的殘留風險假設成立;如果數字遠低於 60(例如個位數,或只在剛按下的那一刻出現一次然後歸零),代表持續按住並不會每影格都重新產生合格動作,殘留風險不成立或影響很小。
5. 放開搖桿,確認 `reclaim_progress` 不再被卡住,滑鼠能正常拿回權威。
6. **换用手把 D-pad 按鈕**(不是類比搖桿)重複步驟 2-5——D-pad 是離散按鈕,搖桿是類比軸,兩者在 Godot 底層的事件派發機制不一定相同,必須分開測。
7. **换用鍵盤方向鍵**重複步驟 2-5——鍵盤有 OS 層級的 key-repeat(按住鍵盤按鍵,系統會用一個固定間隔持續送出新的按下事件,`InputEventKey.echo` 會是 `true`),這與手把是完全不同的機制,結果很可能不一樣。事件記錄裡每一行動作訊息都印出了 `is_echo=` 欄位,可以直接看出這次事件是不是鍵盤重複觸發的。

**這一題沒有「正確答案」讓你去對——這正是開放問題存在的原因。無論實測結果是「確實會鎖死」還是「不會鎖死」,把觀察到的現象、`events/last1s` 的實際數字、以及 D-pad/搖桿/鍵盤三者是否表現不同,如實記下來,交回 `/design-review` 下一輪處理。**

#### 開放問題 (a) 的判定標準

- **若「持續按住方向鍵/搖桿期間,滑鼠始終無法完成奪權」在三種輸入來源(D-pad / 搖桿 / 鍵盤)中至少一種上成立** → GDD 登記的殘留風險證實成立,需要提交下一輪 `/design-review`,可能需要新增一個「防止此類鎖死」的補充規則(例如豁免同一個持續按住的方向鍵不重複觸發否決)。
- **若三種輸入來源都不會鎖死**(例如按住期間只在第一次按下時觸發一次合格動作,之後 `Input.is_action_pressed()` 雖然持續回報 `true`,但沒有新的 `InputEvent` 產生,所以不會反覆觸發否決)→ 殘留風險不成立,可以在下一輪 `/design-review` 明確關閉這條 Open Question。
- **若三種輸入來源表現不一致**(這是最有可能的結果,基於 GDScript 已知 `InputEventKey.echo`/`InputEventJoypadButton`/`InputEventJoypadMotion` 是不同的事件類型)→ 記錄下具體是哪一種輸入來源有風險,GDD 的規則可能需要針對輸入來源類型做差異化處理,而不是一刀切。

#### 程序 C——開放問題 (b):`reclaim_threshold_px` 手感校準

1. 重複程序 A 讓 `device_authority = KEYBOARD_GAMEPAD`。
2. 用畫面上的 `reclaim_threshold_px` 數值輸入框,先設一個很小的值(例如 10),用滑鼠正常的日常手感(不刻意誇張)去試著奪回權威,記錄「感覺很容易誤觸/滑鼠隨便碰一下就搶權威」還是「感覺剛好」。
3. 逐步調大(例如 40、80、150、300),每個數值都用手把先取得權威、再用滑鼠正常移動嘗試奪權,記錄主觀感受:「感覺要花力氣特地去抓滑鼠才能搶回來」vs「感覺自然、不會不小心誤觸,也不會覺得要用力找滑鼠」。
4. 記下你覺得手感最自然的數值範圍(不需要精確到個位數,一個大致區間即可,例如「50-100px 之間感覺對」)。這個數字是**這個特定螢幕解析度/DPI/視窗大小下**的手感,不是最終校準值——正式校準留給垂直切片階段用真實美術資源與真實表面尺寸重新測。

#### 程序 D——重置觸發點 (c):失焦重新播種

1. 讓 `device_authority = KEYBOARD_GAMEPAD`,用滑鼠移動一小段距離讓 `reclaim_progress` 卡在中間值(例如 0.5 左右,但還沒完成奪權)。
2. Alt-Tab 切換到另一個視窗(或把 Godot 執行視窗縮到最小)。
3. 等 2-3 秒後,切回 Godot 執行視窗(或還原視窗)。
4. 確認:事件記錄立刻出現 `[FOCUS] Application FOCUS_IN` 與 `ACCUMULATOR RESET (c) refocus reseed`,且 `reclaim_progress` 顯示值在切回的當下就是 `0.00`,不是切走前殘留的中間值,也不是別的奇怪數字。

#### 程序 E——重置觸發點 (b):目標改變重置

1. 讓 `device_authority = KEYBOARD_GAMEPAD`,用滑鼠移動一小段距離讓 `reclaim_progress` 卡在中間值。
2. 按手把/鍵盤左右方向鍵移動黃色高亮方塊一格。
3. 確認:事件記錄出現 `ACCUMULATOR RESET (b) highlighted target changed`,`reclaim_progress` 立刻歸零。

---

### Test 2 第二輪補測(2026-08-11)——候選修法方向驗證

**背景**:第十輪同日修法(Edge Cases「同一影格雙裝置」否決資格限縮為「新按下」+ `mouse_reclaim_veto_max_consecutive_frames` 保險上限)已於第十一輪對抗性審查判定不成立並撤回。撤回本身是正確決定(引用的 `Input.is_action_just_pressed()` 從未被本 spike 實際測試、新增的保險上限計數器是未被 Core Rules #1/AC-1 承認的隱藏狀態欄位、三種輸入來源一致性假設未驗證),但撤回後**沒有留下任何暫行防線**——缺陷維持 100% 可重現。GDD `Known Confirmed Defects` 節登記的候選方向(未定案)是:改用本 harness 已記錄但第一輪未採用的 per-event 欄位(`InputEventKey.echo`,對應 `is_action_pressed(action, allow_echo=false)`),對齊本系統既有的緩衝架構(`_input` 收集離散事件,而非逐幀輪詢 `Input` 單例狀態)過濾同影格否決資格。這個方向**尚未經過對抗性審查**,也尚未用真實硬體測過。本輪在把它寫回 GDD 規則本體之前,先用這份 harness 驗證。

**harness 新增了什麼**:

- 一個可即時切換、不需重開場景的下拉選單「Same-frame veto eligibility」,搭配下方一行文字標籤(對應 `_veto_filter_mode_label`)顯示目前生效的模式:
  - **Mode 1(對照組,`CURRENT_BEHAVIOR`)**:重現目前 GDD 規則本體實際的行為——同影格內任何一個合格的鍵盤/手把 `ui_*` 動作都會否決滑鼠奪權,不論是不是 echo/重複觸發。這是第一輪 spike 已經測過、證實會鎖死的行為。
  - **Mode 2(候選修法,`ECHO_FILTERED_CANDIDATE`)**:只有 `is_action_pressed(action, allow_echo=false)` 判定為「非 echo/非重複」的事件才具否決資格。**注意**:Godot 的 echo 旗標只存在於 `InputEventKey`,`InputEventJoypadButton`/`InputEventJoypadMotion` 沒有這個概念——這代表 Mode 2 對 D-pad/類比搖桿是否真的改變行為,是程序 B4/B5 要驗證的問題,harness 本身**不預設答案**。
- 「Held state / event rate」那一行,現在依 `InputEvent` 子類別(`InputEventKey`/`InputEventJoypadButton`/`InputEventJoypadMotion`)拆開顯示各自的 `events/last1s`,不只是第一輪的合併總數——可以直接在畫面上看出三種輸入來源持續按住時的事件派發頻率差異,不需要只靠肉眼數 log 行數。

**執行前提**:每個程序開始前,先確認畫面上「Same-frame veto eligibility」下拉選單與其下方文字標籤顯示的模式正確,避免測錯模式導致結果誤判。

#### 程序 B2——Mode 1(對照組)下,D-pad 持續按住是否鎖死(補測第一輪承諾但未執行的部分)

第一輪程序 B 只實際測試了類比搖桿(步驟 6-7 的 D-pad/鍵盤留待補測,見 README 第一輪「發現」章節)。本程序先補齊 D-pad 在**現行行為(Mode 1)**下的結果,作為程序 B4 的比較基準。

1. 確認下拉選單停在 **Mode 1: current behavior (control group)**。
2. 重複程序 A 步驟 1-2,讓 `device_authority = KEYBOARD_GAMEPAD`。
3. 改用**手把 D-pad 按鈕**(不是類比搖桿),持續按住某一方向不放至少 5-10 秒。
4. 在持續按住的同時,把滑鼠一次性快速移動一段明顯超過 `reclaim_threshold_px` 的距離。
5. 觀察並記錄(比照第一輪程序 B 的觀察項目):`reclaim_progress` 是否鋸齒狀被打回、事件記錄裡 `VETOED` 訊息出現的頻率(看 `[Xms]` 時間戳間隔)、`device_authority` 在整段持續按住期間有沒有任何一刻變回 `MOUSE`、以及「Held state / event rate」該方向那一行的 `[D-pad=...]` 數字。

**判定標準**:
- 若 5-10 秒內 `device_authority` 完全沒有變回 `MOUSE` 過 → D-pad 持續按住同樣會造成完整鎖死,與第一輪已證實的類比搖桿結果一致。
- 若 `device_authority` 有變回 `MOUSE` 過(即使中間出現過幾次 VETOED)→ D-pad 與類比搖桿在 Mode 1 下表現不一致,這本身是需要記錄的發現,不要假設兩者相同。

#### 程序 B3——切到 Mode 2(候選修法),鍵盤持續按住的鎖死是否解除

1. 把下拉選單切到 **Mode 2: echo-filtered candidate fix**(不需要重開場景,確認下方文字標籤已更新為 Mode 2 的描述)。
2. 重複程序 A 步驟 1-2,讓 `device_authority = KEYBOARD_GAMEPAD`。
3. 用**鍵盤方向鍵**持續按住某一方向不放至少 5-10 秒。
4. 在持續按住的同時,把滑鼠一次性快速移動一段明顯超過 `reclaim_threshold_px` 的距離。
5. 觀察並記錄:`device_authority` 是否在按住期間的某一刻(理想上應該很快)變回 `MOUSE`;事件記錄裡鍵盤事件的 `is_echo=` 欄位是否如預期在第一次按下之後變成 `true`;「Held state / event rate」該方向那一行的 `[Key=...]` 數字與同樣測試在 Mode 1 下觀察到的數字是否不同(注意這個數字顯示的是「進入緩衝的合格事件數」,不是「具否決資格的事件數」,兩者在 Mode 2 下可能不同——實際是否解除鎖死,以事件記錄裡的 `VETOED`/`AUTHORITY CHANGE` 訊息為準,不要只看這個數字)。

**判定標準**:
- 若鍵盤持續按住期間,`device_authority` 能夠成功變回 `MOUSE`(奪權主張不再被逐幀否決)→ 候選修法對鍵盤這個輸入來源有效,鎖死解除。
- 若鍵盤持續按住期間仍然鎖死(`device_authority` 全程未變回 `MOUSE`)→ 候選修法對鍵盤無效,需要回頭重新檢討修法方向,不能只因為理論上 echo 過濾「應該」有效就直接寫回 GDD。

#### 程序 B4——切到 Mode 2,D-pad 持續按住行為是否改變

1. 確認下拉選單維持在 **Mode 2: echo-filtered candidate fix**。
2. 重複程序 B2 步驟 2-5,但這次用 D-pad,在 Mode 2 下測試。
3. 逐項比較這次(Mode 2)與程序 B2(Mode 1)的觀察結果:`device_authority` 有沒有變回 `MOUSE` 過、VETOED 頻率、「Held state / event rate」的 `[D-pad=...]` 數字。

**判定標準**:**這一題沒有預設答案**。GDD 已經指出 Godot 的 echo 旗標只存在於 `InputEventKey`,理論上 Mode 2 對 D-pad 應該是 no-op(行為與 Mode 1 相同,因為 D-pad 事件的 `pressed_no_echo` 預期恆為 `true`)。但「理論上應該 no-op」不等於「實測證實 no-op」——如實記錄 Mode 1/Mode 2 下 D-pad 的行為是否真的相同。若不同,這是需要進一步追查的意外發現,不要用理論推測取代實測結果。

#### 程序 B5——切到 Mode 2,類比搖桿持續按住行為是否改變

1. 確認下拉選單維持在 **Mode 2: echo-filtered candidate fix**。
2. 重複第一輪程序 B 步驟 2-5(類比搖桿版本),這次在 Mode 2 下測試。
3. 逐項比較這次(Mode 2)與第一輪程序 B(Mode 1,已證實鎖死、`events/last1s ≈ 60`)的觀察結果。

**判定標準**:同程序 B4——**不預設答案**。理論上類比搖桿事件同樣沒有 echo 概念,`pressed_no_echo` 預期恆為 `true`,Mode 2 對搖桿可能是 no-op(鎖死問題不會因為切到 Mode 2 而解除,甚至代表候選修法完全無法緩解最初證實鎖死的那個輸入來源),但**必須實測確認**,不能只憑這個推論就寫回 GDD 判定候選修法「對搖桿無效」。

**本節四個程序(B2-B5)都沒有「正確答案」讓你去對——這正是第二輪補測存在的原因**。無論結果是「候選修法對三種輸入來源都有效」「只對鍵盤有效、D-pad/搖桿不變」或其他組合,如實記錄下 Mode 1/Mode 2 在三種輸入來源上的實際差異,交回下一輪 `/design-review`,由完整對抗性審查決定候選修法是否可以正式寫回 GDD 規則本體、需要調整,或需要另尋方向——比照 `Known Confirmed Defects` 節的明文規定,不得再次略過對抗性審查直接寫入規則本體。

---

## 已知簡化(相對於 GDD 正式規格)

- **沒有依表面類型分表的門檻常數表**——GDD 的 `mouse_reclaim_threshold_px_by_surface_type` 是每個表面類型各自一個常數,本 harness 只有一個合成的「表面」,`reclaim_threshold_px` 是單一可即時調整的數值,用於程序 C 的粗略手感校準,不是最終每個表面各自的校準結果。
- **沒有實作「待重新解析」狀態**(Core Rules #2)——這個 harness 的「目前高亮目標」永遠有效,不會被外部呼叫方標記為失效,因為 harness 沒有任何會讓目標消失的遊戲邏輯(例如單位死亡)。
- **沒有實作漸進回饋的視覺載體形狀約束**(Core Rules #3「載體形狀約束」)——`reclaim_progress` 只用一條進度條數字顯示,不是原生滑鼠指標透明度或自繪替代游標圖形,因為載體選擇本身是留給 `/create-architecture`/`/art-bible` 的開放問題,不是本 spike 的驗證範圍。
- **沒有實作 Core Rules #7 的表面類型共用列舉**——harness 沒有多種表面類型可切換。
- **`_process` 用於「同一影格」的判定單位**,與 GDD Edge Cases 已定案的定義一致,但本 harness 沒有實作 Godot 的 Agile Event Flushing 專案設定檢查(見下方「建構過程中的發現」第 4 點)。

---

## 建構過程中的發現(尚未經人類驗證——僅為撰寫程式碼時的觀察,不能取代上面兩個測試的實際執行結果)

1. **「Control offset transform」在 Godot 4.7 究竟是不是一個全新的、有獨立名稱的 API,還是單純指既有的 `position`/`rotation`/`scale`/`pivot_offset` 屬性行為被強化,本 spike 沒有能力確認**。本 agent 的環境沒有 WebSearch 工具可用,`docs/engine-reference/godot/current-best-practices.md` 與 `breaking-changes.md` 都只用一句話功能性描述這個特性(「Controls can now be translated, rotated, or scaled visually without fighting container re-layout」),沒有點出具體屬性/方法名稱。`docs/engine-reference/godot/modules/ui.md`、`modules/input.md` 兩份文件檔頭標注「Last verified: 2026-02-12 | Engine: Godot 4.6」——比專案釘選的 4.7.1 舊一個版本,完全沒有涵蓋這個 4.7 專屬特性。因此 `hover_target_box.gd` 選擇直接對 `HoverTargetBox`(一個 `Control`)本身的 `position`/`rotation`/`scale`/`pivot_offset` 做 `Tween` 動畫——這是長期存在、文件穩定的標準 API,不是猜測的新屬性名稱。**如果人類測試者在 Godot 4.7.1 編輯器裡發現有一個明確命名的新屬性或新方法(例如 Inspector 面板裡多出一個「Offset Transform」分組),而不是沿用這四個舊屬性,請在測試筆記中記下來——這代表本 spike 測試的可能不是官方最推薦的 4.7 用法,只是行為上等價（或不等價）的替代做法**,需要一併回報。
2. **`InputEventJoypadButton` 是否存在類似 `InputEventKey.echo` 的重複觸發機制,本 agent 無法從現有引擎參考文件中確認**——這正是程序 B 存在的理由,不是本 agent 自行推斷出來寫死在程式碼或文件裡的結論。`mouse_reclaim_harness.gd` 對兩者一視同仁地用 `event.is_action_pressed(action, true)`(`allow_echo=true`)偵測,並把 `is_echo`(僅對 `InputEventKey` 有意義)與兩種 `is_action_pressed` 呼叫結果都記錄進事件記錄面板,讓人類測試者自己比對三種輸入來源(D-pad/搖桿/鍵盤)的實際差異,而不是預先假設某一種行為。
3. **本專案的 `project.godot` 刻意不寫自訂 `[input]` 區塊**,完全依賴 Godot 引擎內建的 `ui_up`/`ui_down`/`ui_left`/`ui_right`/`ui_accept`/`ui_cancel` 預設綁定。原因:Godot 專案設定檔裡自訂輸入動作的序列化格式,需要手刻巢狀的 `InputEventKey`/`InputEventJoypadButton`/`InputEventJoypadMotion` 資源區塊(包含 `physical_keycode`、`key_label`、`axis_value` 等多個欄位),本 agent 沒有 Godot 可以驗證手寫的格式是否完全正確——若欄位名稱或格式有誤,可能導致整個 `project.godot` 無法被引擎解析,讓專案完全打不開,這個風險遠高於「這六個 `ui_*` 動作用引擎預設值」的代價。引擎預設值本身已經不綁定任何滑鼠事件(這是 Godot 眾所皆知的內建行為),自然滿足 GDD Core Rules #3 的前提約束,因此判斷不需要為了「明文列出綁定」而冒手刻資源格式出錯的風險。見上方「開場健檢」章節,提供了一個不需要自訂 `[input]` 區塊也能驗證這個前提的步驟。
4. **AC-26 相關的 Open Question(2026-08-05 已由 godot-specialist 於文件內關閉,確認 `InputMap.get_actions()`/`InputMap.action_get_events()` 的引擎行為穩定)沒有在本 spike 內重新驗證**——本 spike 的兩個測試場景都不呼叫這兩個 API,不在本次驗證範圍內。
5. **Godot 專案設定「Input Devices → Buffering → Agile Event Flushing」本 spike 沒有主動關閉或鎖定**(GDD Open Questions 已登記此設定必須維持關閉,`project.godot` 沒有寫入相關設定鍵,代表沿用引擎預設值,預設應為關閉)。若人類測試者的本機 Godot 安裝或編輯器偏好設定曾經全域修改過這個設定,`mouse_reclaim_harness.gd` 仰賴的「`_input` 緩衝到 `_process` 一次性裁定」同一影格模型可能不成立,建議在程序 A 開始前,順手到 **Project → Project Settings → General → Input Devices → Buffering** 確認 **Agile Event Flushing** 是關閉狀態。

---

## 狀態

**已完成(2026-08-05,人類測試者於 Godot 4.7.1 Editor 執行)**——兩個測試皆已執行,結果已回報並寫回 `design/gdd/cursor-highlight-state.md` 與 review log。

**本輪(第二輪補測)部分完成(2026-08-11,非工程背景真人測試者以口語觀察方式執行)**——鍵盤路徑(Mode 1/Mode 2 各測一次)已完成,發現一個新的、原本測試計畫沒有預期到的現象(反方向零門檻豁免造成「搶到又立刻彈回」),詳見上方「Test 2 第二輪補測(2026-08-11)」章節結論。**D-pad(程序 B2/B4)、類比搖桿 Mode 2(程序 B5)因測試者手邊無任何手把硬體,完全未執行**,不是「測了沒事」,是「沒測」——待測試者取得手把後補測,見 Open Questions 新增列。

## 發現

### Test 1(Control offset transform 命中測試)—— 結論:**風險不成立**

三種變換模式(TRANSLATE/ROTATE/SCALE)分別測試,結果一致:
- 滑鼠移到「變換後才蓋到、變換前沒蓋到」的區域(走廊/新三角形/新外圈),黃色 hover 疊色**持續亮著**,事件記錄**持續出現** `_gui_input` 紀錄。
- `DebugOverlay` 畫出的即時 `get_global_rect()` 綠色外框**準確跟隨**方塊當下的位移/旋轉/縮放。

**判定**:視覺變換與命中測試沒有脫節,Godot 4.7.1 下 Control offset transform 驅動的 hover 命中測試行為正確可信賴。GDD 的假設(滑鼠移動永遠正確被辨識)成立,不需升級為 MAJOR REVISION,不需新增設計層規則。此發現已回填 GDD Open Questions 對應列,標記關閉。

### Test 2(滑鼠奪權混合輸入)—— 結論:**重新設計驗證通過,但發現一項新阻擋項**

- **程序 A(基本檢查)**:四步皆符合預期,harness 狀態機正常。
- **程序 B(持續按住方向鍵/搖桿是否鎖死)⚠️ 證實成立**:類比搖桿持續推底按住 5-10 秒期間,`device_authority` 全程鎖在 `KEYBOARD_GAMEPAD`,即使同時把滑鼠快速移動一大段遠超過 `reclaim_threshold_px` 的距離,仍完全無法完成奪權轉移。「Held state / event rate」顯示 `events/last1s ≈ 60`(接近每個 `_process` 影格皆派發一次合格動作)。**GDD 登記的已知殘留風險證實成立**,不是理論疑慮。D-pad 離散按鈕與鍵盤方向鍵尚未個別測試(留待第十一輪 `/design-review` 或實作階段補測),已測的類比搖桿路徑足以確認風險存在。
- **程序 C(門檻手感校準)**:約 50-100px 區間主觀手感自然(單一合成測試表面,非最終各表面類型分別校準值)。
- **程序 D(觸發點 (c) 失焦重新播種)**:符合預期,Alt-Tab 切回後立即歸零、正確重新播種。
- **程序 E(觸發點 (b) 目標改變重置)**:符合預期,高亮目標一換,累積進度立即歸零。

**判定**:第十輪重新設計的觸發點 (b)(c) 皆驗證通過。觸發點 (d)(同影格否決)與持續按住方向鍵/搖桿的交互證實會造成完整鎖死。

**追加:同日修法**——使用者考量已投入的時間成本,裁決簡化處理、不等第十一輪完整對抗性審查,同日直接採用建議修法:Edge Cases「同一影格雙裝置」固定優先序規則的否決資格限縮為「新按下」的那一影格(對應 `Input.is_action_just_pressed()`/類比搖桿軸值剛跨越死區),持續按住不再具否決資格;另加 `mouse_reclaim_veto_max_consecutive_frames` 保險上限,新增 AC-56/57。**此修法尚未經對抗性審查**,且尚未驗證 D-pad/鍵盤的「新按下」判定是否與本 spike 已測試的類比搖桿表現一致——若要更嚴謹地收尾這個 spike,下一步應該是**用同一份 harness 補測 D-pad 與鍵盤方向鍵**,確認修法後三種輸入來源皆不再鎖死。

**回填位置**:`design/gdd/cursor-highlight-state.md` Open Questions、Core Rules #3、Edge Cases、Tuning Knobs、Acceptance Criteria(AC-56/57);`design/gdd/reviews/cursor-highlight-state-review-log.md`「Spike 結果回報」章節。

### Test 2 第二輪補測(2026-08-11)—— 結論:**鍵盤路徑部分完成(非正式測試);D-pad/類比搖桿因硬體不可得,完全未測**

**測試條件的誠實揭露**:本輪由真人測試者(非工程背景,不具備逐行讀 log 的能力)在 Godot Editor 中執行,採用**憑肉眼觀察、口語描述**的方式回報結果,不是像 2026-08-05 第一輪那樣逐行核對時間戳與事件記錄。以下結論的精確度低於第一輪,但現象本身清楚、可重現,足以作為下一輪 `/design-review` 的輸入。**測試者手邊沒有任何手把(候借、PS/Xbox 控制器、Steam 控制器皆無)**,程序 B2(D-pad + Mode 1)、B4(D-pad + Mode 2)、B5(搖桿 + Mode 2)三項**完全未執行**,不是「測了沒發現問題」,是「沒有硬體可以測」——下方 Open Questions 已新增一列明確登記這個缺口,待測試者取得手把後補測,不得被後續讀者誤讀為「已驗證 D-pad 沒問題」。

**已完成的測試(鍵盤,對應程序 B3 的變體 + Mode 1 對照)**:

1. **Mode 1(對照組)+ 持續按住鍵盤方向鍵 + 甩滑鼠**:黃色高亮方塊「抖動一下」,過程中方塊確實移動了一格(證實滑鼠瞬間搶到過控制權),但**緊接著又立刻跳回去跟著鍵盤方向鍵**——不是像第一輪測到的類比搖桿那樣完全鎖死 5-10 秒動彈不得,鍵盤持續按住並沒有讓滑鼠完全無法插手。
2. **Mode 2(候選修法:echo 過濾)+ 同樣操作**:測試者回報「跟測試 A 一樣」——肉眼看不出差異,同樣是「抖動一下、移動一格、又立刻彈回鍵盤方向」。

**判定與新發現(比原本要驗證的問題更進一步)**:

- 鍵盤路徑**不會**重現類比搖桿那種完全鎖死——這點與第 0 節 godot-specialist 查證報告的技術推論吻合(OS 層級 key-repeat 送出事件的間隔,比類比搖桿逐影格連續送出事件要疏,中間有空隙讓滑鼠有機會插入)。
- 但鍵盤路徑存在**另一個未被登記過的問題**:滑鼠即使成功瞬間搶到控制權(方塊確實移動了一格),**下一瞬間又被鍵盤秒搶回去**——這不是本輪原本要驗證的觸發點 (d) 同影格否決造成的,而是 Core Rules #3「滑鼠→鍵盤/手把反方向零門檻豁免」這條規則本身的必然結果:只要玩家手指還按著方向鍵不放,鍵盤/手把的每一次重複觸發訊號,都會用零門檻立即把控制權從滑鼠手上搶回去。**Mode 1/Mode 2 表現一致這件事本身就是關鍵證據**——這證實了問題不是出在本輪測試的「同影格否決過濾邏輯」上,候選修法(echo 過濾)對這個新問題**沒有作用**,因為它從未觸及反方向零門檻豁免這條規則。
- 從玩家角度描述這個現象:滑鼠移動看起來像是「搶到了,但又立刻被彈開」,不是「完全沒反應」——但體感上兩者可能一樣令人挫折,都是「滑鼠感覺不聽使喚」。這是否要算進「持續按住鎖死」這個已知缺陷的範圍內,或是一個需要獨立登記的新缺陷,留給下一輪 `/design-review` 裁決。

**未完成/待補**:D-pad(Mode 1、Mode 2)、類比搖桿(Mode 2)——全部因無手把硬體而未執行,見上方「測試條件的誠實揭露」。第一輪已確認的類比搖桿 Mode 1(現行行為)結果(完全鎖死)維持不變、不需重測。

**回填位置**:`design/gdd/cursor-highlight-state.md` 的 `Known Confirmed Defects` 節與 Open Questions——見下一節。
