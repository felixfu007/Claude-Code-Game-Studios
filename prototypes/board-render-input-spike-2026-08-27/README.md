# Spike:世界層/介面層分層後,滑鼠螢幕座標怎麼換算成棋盤格座標?

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證,不是完整戰棋系統實作
> **日期**:2026-08-27
> **執行者**:godot-specialist,本機直接執行 Godot 4.7.1(有實體 GPU,可跑非 headless 視窗模式)

**要驗證的假設**:`technical-preferences.md` 記載一項尚未處理的跨文件矛盾——畫面分成世界層(`SubViewport`)與介面層(`CanvasLayer`)後,「同時存在兩套座標系,換算係數隨螢幕尺寸變動」,而 ADR-0005(游標/高亮狀態,1609 行,仍為草案)可能假設全螢幕只有一套座標系。本 spike 用實測數字回答:滑鼠螢幕座標要怎麼換算成棋盤格座標?這個換算隨視窗尺寸怎麼變?ADR-0005 那個假設成立嗎?

---

## 專案結構

```
prototypes/board-render-input-spike-2026-08-27/
├── project.godot                # 沿用主專案實測值:480x270 / canvas_items / keep / integer / Nearest
├── scenes/
│   └── GameRoot.tscn            # 照抄 src/ui/GameRoot.tscn 的節點形狀(見下方「重大發現」)
└── scripts/
    ├── board_coords.gd          # 純函式:格子<->像素換算,不碰場景樹,可獨立呼叫測試
    └── game_root.gd             # 場景根腳本:程式化組出地形/棋子/UI,並內建「印完自己關掉」的量測流程
```

地形、棋子都是在 `game_root.gd` 的 `_ready()` 用程式碼組出來的,`.tscn` 只保留 `WorldViewportContainer`/`WorldViewport`/`UILayer` 骨架——原因與 `cursor-reclaim-godot-spike-2026-08-05` 那份 spike 相同:手刻的節點樹只有一份程式碼可讀,不需要交叉比對 `.tscn` 和腳本兩份資料。

---

## 如何執行

1. **量測模式(預設,本 README 的數字全部來自這個模式)**——直接跑,**不要加 `--headless`**(理由見下方「彎路」),它會開一個視窗、跑完四種視窗尺寸的量測、印出結果、自己關掉:
   ```
   "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path .
   ```
2. **互動模式**(人眼看畫面、實際點擊測試高亮)——在編輯器裡打開 `GameRoot.tscn`,把根節點(`GameRoot`)Inspector 面板的 `Run Measurement On Ready` 勾掉,按 F6 執行。畫面應顯示 13×6 地形(`.`=空地/`,`=灌木/`#`=倒木)、我方五人+敵方五人的佔位圖,點任一格會顯示 `highlight_move` 疊圖,並在左上角文字顯示「Screen: ... -> Grid: ...」。**這個模式本 agent 沒有驗證過**(headless/自動關閉模式下引擎不送出 `InputEvent`,見 `.claude/docs/coding-standards.md`;而本 agent 也沒有真人可以坐在鍵盤前點滑鼠),只確認過程式碼路徑會被呼叫到、邏輯上會執行——不能取代下方「量測模式」的實測數字。

---

## 實測數字(2026-08-27,非 headless、真實 GPU、`Godot_v4.7.1.stable.official.a13da4feb`,Vulkan/Intel(R) Graphics)

四種視窗尺寸皆用 `DisplayServer.window_set_size()`(真正的原生 resize 路徑)驅動,每次 resize 後等 5 個 `process_frame` 才讀值。前三個是原始派工單指定的 16:9 尺寸(`aspect="keep"` 下不會產生黑邊);第四個(800×600,4:3)是額外加測的,專門用來實測黑邊。

| 視窗尺寸 | `WorldViewportContainer.size` | `WorldViewport.size` | 一格 32px 的螢幕像素邊長 | 棋盤左上角螢幕座標 | `get_final_transform()`(基準畫布→視窗像素) |
|---|---|---|---|---|---|
| 480×270 | (480, 270) | (480, 270) | 32.000 px | (32.0, 39.0) | scale=1, offset=(0,0) |
| 960×540 | (480, 270) | (480, 270) | 64.000 px | (64.0, 78.0) | scale=2, offset=(0,0) |
| 1440×810 | (480, 270) | (480, 270) | 96.000 px | (96.0, 117.0) | scale=3, offset=(0,0) |
| 800×600(4:3,黑邊測試) | (480, 270) | (480, 270) | 32.000 px | (192.0, 204.0) | scale=1, offset=(160.0, 165.0) |

**來回換算自洽性**(棋盤格 → 螢幕座標 → 反向換算回棋盤格,四角+中央共 5 格 × 4 種尺寸 = 20 次):**20/20 全部 `OK`**,無一次 MISMATCH。原始 log 逐行紀錄在 `scratchpad`,以下摘一組(480×270,scale=1)供對照:

```
round-trip top_left     cell=(0, 0) -> window=(48.0, 55.0) -> cell=(0, 0)  OK
round-trip top_right    cell=(12, 0) -> window=(432.0, 55.0) -> cell=(12, 0)  OK
round-trip bottom_left  cell=(0, 5) -> window=(48.0, 215.0) -> cell=(0, 5)  OK
round-trip bottom_right cell=(12, 5) -> window=(432.0, 215.0) -> cell=(12, 5)  OK
round-trip center       cell=(6, 3) -> window=(240.0, 151.0) -> cell=(6, 3)  OK
```

**黑邊探測**(800×600,4:3,`aspect="keep"` 產生上下各 165px、左右各 160px 的黑邊):點在視窗物理座標 `(0,0)`(左上角,落在黑邊裡)換算結果:

```
window (0,0) -> base-canvas=(-160.0, -165.0) -> grid=(-6, -7)  in_bounds=false
```

基準畫布座標是負值(超出 0..480 / 0..270 範圍),`is_in_bounds()` 正確判定為 `false`——黑邊上的點會被正確地換算到「棋盤格座標系之外」,不會誤判成某個真實格子。

---

## 換算怎麼寫的(可獨立呼叫的純函式,`scripts/board_coords.gd`)

```gdscript
static func window_to_grid(window_pos: Vector2, window_to_canvas: Transform2D, world_viewport_canvas_origin: Vector2) -> Vector2i:
	var canvas_pos: Vector2 = window_to_canvas * window_pos
	var local_pos: Vector2 = canvas_pos - world_viewport_canvas_origin
	return local_to_grid(local_pos)
```

`window_to_canvas` 是 `Window.get_final_transform().affine_inverse()`,在每次要用之前即時向引擎要——**不是自己重算 `stretch`/`keep`/`integer` 的公式**。這是刻意的取捨:引擎內部這套換算(`content_scale_mode`/`aspect`/`stretch` 三個 enum 交叉組合)的精確公式沒有記載在 `docs/engine-reference/godot/` 任何一份文件裡,本 agent 的訓練資料對這三個 enum 的實際 4.7.1 行為沒有足夠信心,手刻的版本一旦跟引擎內部算法有一絲偏差,在非 16:9 視窗這種邊界情況就會悄悄算錯而不會報錯。直接問引擎要 `get_final_transform()`,對就是對,不需要自己驗證公式對不對。

`world_viewport_canvas_origin`(即 `WorldViewportContainer.global_position`)在四種尺寸下全部量到 `(0.0, 0.0)`——這是下一節的關鍵。

---

## 對 ADR-0005「全螢幕只有一套座標系」假設的判定:**條件成立**

不是「成立」,也不是「不成立」,是**條件成立**——條件就是實測到的這兩件事同時滿足:

1. **`WorldViewportContainer` 用 `anchors_preset=15`(滿版)貼齊整個 480×270 基準畫布,起點固定在 `(0,0)`,沒有自己的獨立位移。** 因為滿版貼齊,`WorldViewport` 的本地座標系原點,在基準畫布座標系裡永遠是 `(0,0)`——兩個座標系之間**沒有第二個會變動的縮放係數**,只差一個固定的、由棋盤置中算出來的常數位移 `BOARD_ORIGIN = (32, 39)`。
2. **換算全程呼叫引擎自己的 `get_final_transform()`,不手刻 `stretch`/`keep`/`integer` 公式。** 只要做到這點,`canvas_items` + `keep` + `integer` 三個設定共同產生的縮放/黑邊,對呼叫端來說是**單一個仿射變換 + 一個固定位移**,可以用同一組純函式一次處理完,不需要為「世界層」和「介面層」分別維護兩套換算邏輯。

**換句話說:表面上是「兩層」,實測後數學上收斂成「一個變換鏈」**——`window_to_canvas`(引擎給)接 `- world_viewport_canvas_origin`(常數)。ADR-0005 若假設「一套座標系」指的是「呼叫端只需要一條轉換公式,不必為世界層/介面層分別分支處理」,這個假設在本專案目前的分層方式下**成立**,20/20 來回換算自洽是支撐這個判定的實測證據。

**條件不滿足時會怎樣**:如果 `WorldViewportContainer` 以後被改成不貼滿整個畫布(例如非滿版、留邊、或本身還有動畫位移),`world_viewport_canvas_origin` 就不會恆為 `(0,0)`,屆時「單一套座標系」的簡化說法就不再準確——但即使那樣,`board_coords.gd` 現有的函式簽章(`world_viewport_canvas_origin` 是參數,不是寫死的常數)已經預留了這個變數,呼叫端只需要在每次換算前重新讀 `WorldViewportContainer.global_position`,不需要改寫算法本身。這是本 spike 特意把它做成參數而不是內部寫死的原因。

---

## 重大發現(超出原始問題範圍,但擋在「世界層畫得出來」前面):`WorldViewportContainer` 的錨點在 `Node2D` 底下永遠不會生效

這不是本 spike 原本要驗證的問題,是建構過程中撞到的——**而且它直接關係到 `src/ui/GameRoot.tscn` 這個正式檔案是否真的能用**,不能不報。

### 現象

`GameRoot.tscn` 完全照抄 `src/ui/GameRoot.tscn` 的節點形狀:`GameRoot`(`Node2D`)→ `WorldViewportContainer`(`SubViewportContainer`,`anchors_preset=15`、`stretch=true`)→ `WorldViewport`。用正常的引擎啟動流程(`--path .` 讀 `run/main_scene`,**非 headless、有真實 GPU**,不是手動 `new()` 組節點樹)跑起來後:

```
WorldViewportContainer.size: (0.0, 0.0)
WorldViewport.size: (2, 2)
```

**無論視窗尺寸怎麼變、等多少個 `process_frame`,這兩個數字永遠不會變。** `WorldViewport` 卡在引擎給 `SubViewport` 的預設最小尺寸(2×2px),不會跟著容器的滿版錨點跑到 480×270。這代表:如果不處理,世界層實際渲染出來的內容會被硬擠進一張 2×2px 的材質,再整個拉伸貼回螢幕——棋盤會整片糊成一塊顏色,不是「稍微模糊」,是「完全看不出形狀」。

### 這不是 headless 造成的假象

先前一輪用 `-s` 腳本手動 `new()` 節點樹測試也量到一樣的 `(0,0)`/`(2,2)`,但那條路徑被主 session 判定「不是正常流程,不可信」而中止——這輪改用 `--path .` 正常載入 `.tscn`、**真的開一個視窗、有 `Vulkan 1.4.325 - Forward+ - Using Device #0: Intel(R) Graphics` 這行 log 佐證確實跑了真實 GPU 路徑**,結果完全一樣。用同一份程式碼另外隔離測試(`Node`/`Control`/`CanvasLayer` 當 `SubViewportContainer` 的父節點)發現:**只要父節點不是 `Node2D`,四種測試(`Node`/`Control`/`CanvasLayer`/直接掛在 `Window` 底下)全部正常解出 `(480, 270)`;唯獨父節點是 `Node2D` 時,錨點永遠不生效。** 這把變因鎖定在「`Node2D` 這一層本身不轉發子 `Control` 需要的 resize 通知」,不是 headless 或某次測試的偶發雜訊。

### 已驗證可行的暫行解法

手動把 `WorldViewportContainer.size` 同步成 `get_tree().root.get_visible_rect().size`(見 `game_root.gd` 的 `_sync_container_size_workaround()`),在 `_ready()` 呼叫一次、再接上 `root.size_changed` 訊號每次 resize 都重呼叫一次——套用後四種視窗尺寸下 `WorldViewportContainer.size`/`WorldViewport.size` 全部正確變成 `(480, 270)`(見上方數字表格,已是套用暫行解法後的結果)。

⚠️ 這個賦值會觸發引擎自己印出的警告(不是本 agent 編的,是實測 log 逐字):
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
   at: _set_size (scene/gui/control.cpp:1519)
```
但在本 spike 觀測的所有 frame 範圍內,`size` **從未真的被覆寫回去過**——四次 resize、每次都停留在賦值後的 `(480, 270)`,不是「賦值生效、下一格被搶回去」。這代表警告描述的「覆寫」情境在 `Node2D` 父節點下大概率根本不會觸發(因為觸發覆寫本身也需要同一套錨點通知鏈,而那條鏈已經證實不會傳到這裡)——但本 spike 只觀測了資源有限的少數 frame,**不能保證長時間執行、或不同的 resize 時序下永遠不會被覆寫**,這點沒有窮舉測試。

### 建議

`src/ui/GameRoot.tscn` 是正式檔案,不在本 spike 授權修改範圍內(`prototypes/**` 規則明文只能動 `prototypes/` 底下的檔案),**這裡只回報發現,不動手改**。兩個可能修法,留給正式檔案的維護者裁決:

1. **重新掛父節點**——把 `WorldViewportContainer` 移到不經過 `Node2D` 的路徑下(例如直接掛在根 `Node`/`CanvasLayer` 底下,`GameRoot` 若不需要 `Node2D` 的 position/rotation/scale,也可以直接把根節點型別改成 `Node`)。這是治本的做法,不需要在腳本裡補一行同步邏輯。
2. **保留現有形狀,腳本裡補同步**——比照本 spike 的 `_sync_container_size_workaround()`,但這是治標,每一個用到這個 `GameRoot.tscn` 形狀的場景都要記得補這一段,容易漏。

---

## 已知簡化(相對於正式規格)

- 沒有依表面類型/地形類型分別套用不同的入場規則或視覺效果——三種地形只有貼圖不同,沒有機制意義。
- 高亮只做「點擊當下那一格」,沒有做移動範圍/攻擊範圍的多格高亮。
- 互動模式(人眼點擊測試)完全沒有真人驗證過,見上方「如何執行」第 2 點的揭露——量測模式的自動化數字才是本 spike 的實測依據。
- `UILayer` 目前只有一個 `Label`,沒有實作正式的游標/高亮狀態系統(那是 ADR-0005 的範圍,不是本 spike 要做的)。

## 建構過程中撞到的規格問題(如實記錄,不代表結論)

1. **原始派工單要求「用一支無視窗的數值驗證腳本」**,但實測發現:`-s` 腳本模式手動 `new()` 組節點樹,即使餵入正確的 `content_scale_*` 設定,`Control` 的錨點系統也不會正常解算(這是 `-s` 腳本模式繞過了正常視窗建立流程本身的限制,不是本 spike 原本要驗證的引擎行為)。主 session 已經實測複驗到同樣的現象,判定「兩種模式都量不到,問題在手動組節點樹這條路本身」,指示改用正常 `--path .` 載入 `.tscn` 的方式,本輪已照改。**這代表「無視窗」與「不透過正常場景載入流程」是兩件不同的事——本 spike 最終用的是「有視窗、但腳本自己在量完之後呼叫 `get_tree().quit()`」,不是原始要求的純 headless 腳本。**
2. **`Window.content_scale_*` 系列屬性/`get_final_transform()`/`get_screen_transform()`/`get_stretch_transform()` 這幾個 API 名稱,`docs/engine-reference/godot/` 底下沒有任何一份文件記載**——UI 模組文件(`modules/ui.md`)標注版本落後到 4.6、且完全沒提內容縮放這塊。本 agent 用一支拋棄式探測腳本(已刪除,不在最終交付物裡)直接向引擎的 `get_method_list()`/`get_property_list()` 查真實存在的 API 名稱,而不是憑訓練資料記憶硬寫——查到的 `get_final_transform()`/`content_scale_stretch` 等名稱與訓練資料的印象一致,但這件事本身沒有被任何本專案文件記載過,建議之後有人要用到這塊 API 時,把這份確認補進 `docs/engine-reference/godot/modules/ui.md`,現在那份文件在這塊完全是空白。
3. 見上方「重大發現」——`SubViewportContainer` 掛在 `Node2D` 底下錨點不生效這件事本身就是一個沒人預期到、原始派工單也沒有問到的規格問題。

---

## 狀態

**已完成(2026-08-27)**。四種視窗尺寸的座標換算數字已實測、20/20 來回換算自洽、黑邊探測已驗證正確判定越界。ADR-0005 單一座標系假設判定為**條件成立**(條件:世界層容器滿版貼齊 + 換算呼叫引擎即時 API,兩者本專案目前都成立)。額外發現一項需要人工裁決的正式檔案問題(`src/ui/GameRoot.tscn` 的 `SubViewportContainer` 錨點在 `Node2D` 下不生效),已回報但未修改正式檔案。

---

## 主 session 獨立複驗(2026-08-27,非本 spike 執行者)

**方法**:另建四個最小 `.tscn`(見 `_verify/`),各自只有「根節點 → `SubViewportContainer`(滿版錨點、`stretch=true`)→ `SubViewport`」三層,
根節點型別分別為 `Node2D` / `Node` / `Control` / `CanvasLayer`。以 `--path . res://_verify/root_X.tscn` 逐一啟動、
等三個 `process_frame` 後印出尺寸再自行 `quit()`。**未使用任何暫行解法,亦未手動 `new()` 組節點樹。**

實測逐字輸出:

```
VERIFY 父節點型別=Node2D       容器尺寸=(0.0, 0.0)      內部畫布尺寸=(2, 2)
VERIFY 父節點型別=Node         容器尺寸=(480.0, 270.0)  內部畫布尺寸=(480, 270)
VERIFY 父節點型別=Control      容器尺寸=(0.0, 0.0)      內部畫布尺寸=(2, 2)
VERIFY 父節點型別=CanvasLayer  容器尺寸=(480.0, 270.0)  內部畫布尺寸=(480, 270)
```

### 複驗結論

✅ **核心發現成立,`src/ui/GameRoot.tscn` 的形狀確實壞掉**:`Node2D` 當父節點時容器尺寸恆為 `(0,0)`、
內部畫布恆為 `(2,2)`,`Node` 與 `CanvasLayer` 則正常解出 `(480, 270)`。三項與上方報告一致。

🔴 **但上方「`Node`/`Control`/`CanvasLayer` **全部**正常解出」這句話太寬,`Control` 那一項不成立。**
本複驗的 `Control` 是**裸的**(自己沒有設錨點,因此自身尺寸為 0),其子容器同樣解出 `(0,0)`。
本 spike 執行者的隔離測試把 `Control` 父節點也設成了滿版錨點,兩邊條件不同,故兩份數字都對,
**但原句省略了「`Control` 自己必須先被撐開」這個前提** —— 照原句去改正式檔案(把根節點換成裸 `Control`)
**會得到跟現在一模一樣的壞結果**。

⚠️ **「`Control` 父節點自己錨定滿版時是否解得出來」本複驗未量測**(指令被權限攔下,未重試)。
**它是未查證項,不是已否證項** —— 要引用請先自己跑一次。

### 對正式檔案的建議(維護者決策用)

上方兩個修法中,**修法 1(改掛父節點型別)已被本複驗直接支撐**:`Node` 與 `CanvasLayer` 兩種
都是實測解得出來的,不需要任何腳本補償。**建議把 `src/ui/GameRoot.tscn` 的根節點由 `Node2D` 改為 `Node`** ——
該根節點目前不使用任何 `Node2D` 的 position/rotation/scale,改型別零功能損失。
