# 場景載入可行性評估 —— 丙案(要求物證:量測腳本必須直接載入真實畫面檔)

**任務**:管理者已裁決丙案(第五十八批)。本檔不重新裁決,只回答「做不做得到、代價是什麼」。

**評估對象**:`res://src/ui/battle/BattleScreen.tscn`(專案的 `run/main_scene`)。

**引擎**:`C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`(4.7.1.stable.official.a13da4feb)

**探針**:`probe_load_real_scene.gd` + `ProbeLoadRealScene.tscn`(本目錄)。
原始輸出:`run_output_headless.txt`(headless)、`run_output_windowed.txt`(開窗,真實 GPU:Vulkan 1.4.325 / Intel Graphics)。
截圖:`root_windowed.png`(960×540 整窗)、`subviewport_windowed.png`(480×270,`WorldViewport` 原生緩衝區)。

---

## Q1 —— 能不能直接載入?

**能,但有一個坑,而且這個坑不是我這支腳本獨有的,是引擎主場景啟動序列的結構性事實。**

做法:`load("res://src/ui/battle/BattleScreen.tscn")` → `.instantiate()` → `get_tree().root.add_child(...)`。
`load()`/`instantiate()` 兩步在 headless 與開窗下皆成功(`run_output_headless.txt` 第 5-9 行、`run_output_windowed.txt` 第 5-10 行,`load() returned null? false` / `instantiate() returned null? false`)。

**但直接 `add_child()` 被引擎拒絕**,headless 與開窗兩邊逐字相同:

```
ERROR: Parent node is busy setting up children, `add_child()` failed. Consider using `add_child.call_deferred(child)` instead.
   at: add_child (scene/main/node.cpp:1721)
```

原因:探針腳本本身也是以「CLI 位置參數場景」方式啟動的(`godot --path . ProbeLoadRealScene.tscn`),當它自己的 `_ready()` 執行時,引擎主場景樹的建置流程還沒收尾,此時對 `get_tree().root` 呼叫非 deferred 的 `add_child()` 會被引擎當場拒絕 —— 不是我的腳本寫錯順序,是任何在 `_ready()` 裡直接組樹的驅動腳本都會撞到的時序。改成 `get_tree().root.call_deferred("add_child", battle)` 並等待 2 個 `process_frame` 後,`battle.is_inside_tree()` 才變 `true`(headless 第 17 行、windowed 第 18 行)。

**這件事必須寫進規則的實作指引,否則每個照著丙案寫驅動腳本的人都會重踩一次同樣的引擎錯誤** —— 這不是我的猜測,是這次探測**兩次獨立執行**(headless 一次、windowed 一次)逐字重現的同一個引擎錯誤。

**(A) 級來源**:`prototypes/godot-specialist-scene-load-feasibility-2026-09-23/probe_load_real_scene.gd`(第 43-64 行,`add_child` 重試邏輯),對應輸出 `run_output_headless.txt` 第 10-18 行 / `run_output_windowed.txt` 第 11-18 行。

---

## Q2 —— 載入之後,量測拿得到嗎?

**開窗:兩條路徑都拿得到,而且是真實像素。Headless:兩條路徑都拿不到,原因是引擎層級的,不是我的腳本寫錯。**

| | headless | 開窗 |
|---|---|---|
| 根視窗截圖 `get_viewport().get_texture().get_image()` | **`get_image()` 回傳 null**,伴隨引擎錯誤 `ERROR: Parameter "t" is null. at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)` | 成功,`960×540`,format=4,`is_empty()=false`,取樣 36 種相異色 |
| `SubViewport` 原生緩衝區 `get_texture().get_image()` | 同上,`get_image()` 回傳 null,同一則引擎錯誤 | 成功,`480×270`,取樣 15 種相異色 |
| 根視窗尺寸 | headless 下量到 `(64, 64)`(第一次失敗的 add_child 那次量到;修正後的乾淨那次執行沒有重新印這行,但 `root_vp.get_texture()` 物件本身非 null,只是取不出像素) | `(960, 540)`,與 `project.godot` 的 `window_width_override`/`window_height_override` 一致 |

**結論**:headless 下 `get_texture()` 回傳的 `ViewportTexture` 物件本身不是 null,但呼叫 `.get_image()` 時引擎的 dummy rendering driver 直接回報「紋理是 null」並回傳空結果 —— 這是 headless 模式的 rendering driver 從根本上沒有真正光柵化任何東西的結果,不是場景載入方式的問題。**這與丙案要不要載入真實場景檔無關,是 headless 模式本身的限制**,任何量測方法(重建子樹或載入真實場景)在 headless 下都拿不到像素。

**(A) 級來源**:`run_output_headless.txt` 第 30-40 行(`ERROR: Parameter "t" is null.` ×2);`run_output_windowed.txt` 第 32-48 行(兩條路徑的完整輸出、尺寸、色彩取樣)。

---

## Q3 —— 驅動它需要什麼?

**幾乎不需要額外驅動 —— `BattleScreen._ready()` 會自己完成全部初始化,包含讀真實資料檔、蓋 `BattleController`、更新 UI 文字。這比我原本預期的成本低。**

`add_child()` 生效後(不論 headless 或開窗),等待 15 個 `process_frame` 後量到:

```
Q3: battle.get("_load_failed") = false
Q3: battle.get("_state") is null? false
Q3: battle.get("_controller") is null? false
Q3: UILayer/StatusLabel found? true text='第 1 回合．我方行動'
```

`StatusLabel` 的文字是**執行期真正跑過 `_update_status_label()`/`_ready()` 產生的在地化文字**,不是 `.tscn` 檔裡的預設佔位字串(`.tscn` 原始值是英文 `"Round 1 | PLAYER phase"`,見 `src/ui/battle/BattleScreen.tscn` 第 29 行)—— 這證明 `_ready()` 裡讀 `vs01_terrain.txt`/`vs01_roster.txt`/`vs01_affinity_links.txt`/`vs01_cards.txt`/`vs01_card_text.txt`、蓋 `BattleState`/`TurnOrder`/`BattleController`/`DeviceAuthority`、接線號誌的整條路徑**確實跑完了**,不是我誤讀了殘留的預設值。

`WorldViewportContainer`/`WorldViewport` 的佈局也是**自己算出來的**,不需要探針腳本手動套:

```
Q1/Q3: WorldViewportContainer.position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2
Q1/Q3: WorldViewport.size (should be 480x270 per WorldLayout.BASE_WIDTH/HEIGHT) = (480, 270)
```

`960×540` / `stretch_shrink=2` 正是 `window_width_override=960`/`window_height_override=540`(`project.godot`)搭配 `WorldLayout.compute_scale()` 算出的結果,`WorldViewport.size` 精確等於 `480×270`(`WorldLayout.BASE_WIDTH`/`BASE_HEIGHT`)—— `world_viewport_scaler.gd` 的 `_ready()` 自己接了 `get_window().size_changed` 並套用了正確的佈局,探針腳本一行都沒有手動介入。

**代價只有兩項,都很小**:①上面 Q1 的 `call_deferred` 時序;②等待足夠的 `process_frame`(這裡用 15 幀,足夠 `_ready()` 與後續幾幀 `_process()` 穩定下來)。**沒有觀察到需要額外注入假資料、額外呼叫額外方法、或繞過任何守衛的情況。**

**(A) 級來源**:`run_output_windowed.txt` 第 22-31 行;對照 `src/ui/battle/battle_screen.gd` 第 603-765 行(`_ready()` 本體,已讀)與 `src/ui/battle/BattleScreen.tscn` 第 29 行(`.tscn` 原始佔位字串)。

---

## Q4 —— 有沒有做不到的形狀?

**有一個具體、可從原始碼直接指出的例外,不是臆測:當量測目的需要「真實資料檔案不會自然產生的合成場景」時,載入完整 `BattleScreen.tscn` 做不到,只能組局部子樹。**

`battle_screen.gd` 的 `_ready()`(第 603-765 行,已讀)把三個資料路徑寫死成 `const`:

```gdscript
const TERRAIN_PATH: String = "res://assets/data/levels/vs01_terrain.txt"
const ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"
```

`_ready()` 無條件用這兩個真實檔案建構 `BattleState`,沒有任何參數或注入點可以換成合成資料。這代表:**任何需要「刻意安排的測試佈局」的量測都無法只靠載入 `BattleScreen.tscn` 達成** —— 例如 U-013 那支腳本要驗證的三態高亮(合法/不合法/無標記),需要三個**同兵種、同地形**的格子,以排除美術差異對量測的干擾。真實關卡資料(`vs01_terrain.txt`/`vs01_roster.txt`)不會自然長成這樣,也沒有理由為了配合一次性的視覺驗證去改動真實關卡資料。

這種情況下,**正確的做法不是完全放棄「跑真實程式碼」的原則,而是把「載入完整場景」降級為「組出與真實場景相同的宿主結構,只替換掉需要合成資料的那一層」**——這正是 `prototypes/u013-highlight-evidence-2026-09-22/evidence_driver.gd` 第 4 版(已由另一支 spike `prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/` 驗證過)實際做的事:它不 `load()` 整份 `BattleScreen.tscn`,但它組出來的 `SubViewportContainer`(掛真實 `world_viewport_scaler.gd`)→`SubViewport`→`BoardView`(`load()` 真實 `BoardView.tscn`)這條鏈,**節點型別與腳本全部是真實生產碼,一行都沒有重新實作** —— 只是省略了 `BattleScreen` 這一層(因為那一層正是綁死真實資料檔、無法餵合成資料的地方)。

**例外的形狀,講清楚給訂規則的人**:
> 當且僅當量測目的需要真實資料檔案無法產生的合成內容時,允許不 `load()` 完整真實畫面檔,改為組出「與真實畫面檔完全相同的宿主節點鏈(型別、腳本、屬性設定逐一比對一致)」,並只在**最靠近合成資料那一層**(而非任意層)省略真實場景、改為直接呼叫該層真實 API。省略的理由與省略的層級必須在腳本檔頭寫明,並附上與真實 `.tscn` 逐項比對的依據(不能只靠自述)。

這題不需要跑引擎,是讀 `battle_screen.gd` 原始碼得到的判斷 —— 已讀範圍是第 1-988 行(共 2068 行的前半),見下方「我沒查的清單」。

---

## 那 1071 是什麼(協調者追問項)

**我知道的**:

- 探針對開窗截圖(960×540)做了兩次 Check4 式整數格檢查:
  - **不排除任何區域**:`4563 / 129600` 格違規(`run_output_windowed.txt` 第 41 行)。
  - **排除 3 個 HUD 矩形後**:`1071 / 112490` 格違規(第 43 行)。
- 排除的 3 個矩形,**逐一對應 `HudLayout`(`src/ui/battle/hud_layout.gd`)的哪個真實函式,不是我猜的座標**:
  - `HudLayout.status_label_rect(window_size)` → `[P: (48, 27), S: (259, 33)]`
  - `HudLayout.info_label_rect(window_size)` → `[P: (329, 27), S: (582, 33)]`
  - `HudLayout.controls_hint_bg_rect(window_size)` → `[P: (48, 469), S: (864, 44)]`
  - **刻意沒有排除** `HudLayout.load_error_label_rect()`(=整個 `safe_rect()`,幾乎蓋滿全窗)與 `result_label_offset_rect()`:因為 `Q3` 已量到 `LoadErrorLabel.visible=false`,`ResultLabel` 依 `BattleScreen.tscn` 第 42 行場景預設也是 `visible=false`(此戰鬥開局既未載入失敗也未結束),兩者都沒有畫出任何像素,排除它們只會讓檢查失去意義(我在中途確實犯過這個錯:第一次連 `LoadErrorLabel` 一起排除,排除掉 105408 / 129600 格,只剩 24192 格可查,量到 `0` —— 這個 `0` 沒有意義,已捨棄,不寫進結論)。

**我不知道、沒有查的**:

- **扣掉那 3 個 HUD 矩形之後,剩下的 112490 格範圍裡,世界層(`BoardView`,畫在 `SubViewport` 內)自己有沒有畫任何反鋸齒文字或內容**(例如棋子血量數字、血條文字面板 —— `u013-highlight-evidence-2026-09-22/evidence_driver.gd` 的檔頭註解提到 `board_view.gd` 有「StatsLayer(HP bar + HP text panel)」,且該腳本專門為此排除過 HP 文字面板的矩形)。**我這次的探針完全沒有做這個排除**,因為我沒有讀 `board_view.gd` 的繪製邏輯,也沒有確認這次真實載入的 `BattleScreen` 有沒有實際渲染出任何棋子(`_ready()` 呼叫了 `_board_view.render_terrain(terrain_rows)` 和 `_refresh_view()`,但 `_refresh_view()` 的內容在 `battle_screen.gd` 第 988 行之後,是我**沒有讀到**的部分)。
- 因此 **1071 有可能就是 BoardView 自己畫的反鋸齒 HP 文字或其他真實世界層內容,也有可能是別的原因** —— 兩種我都沒有排除,不下結論。
- 唯一能排除的是「這 1071 是不是三個 HUD Label 造成的」:**不是**,因為它們已經被排除掉了還剩 1071。
- `SUBVIEWPORT-windowed` 那次取樣(480×270 原生緩衝區)只用了 12×6=1800 個點的粗網格,**取樣密度遠不足以偵測反鋸齒邊緣這種只佔少數幾個像素的訊號**,不能拿它來佐證或排除「世界層有沒有反鋸齒內容」這個問題。

⚠️ 昨天(2026-09-22)才因為一份腳本的誠實自述被直接當結論用、差點改錯正確程式碼 —— 我不重複那個錯誤,所以上面就寫到「不知道」為止,不繼續往下推。

---

## 規則可行性判定

**丙案能寫成一條可執行的規則,但規則文字需要涵蓋三件事,否則會重演「規則存在但接不住實際狀況」的老問題。**

**1. headless 對規則範圍的影響 —— 規則對「像素量測」實質上只能約束開窗環境,但規則本身不必只寫給開窗。**
Q2 證明 headless 下 `get_texture().get_image()` 恆為 null,是 dummy rendering driver 的引擎限制,與載入哪個場景檔無關。**這代表任何「畫面像不像」的視覺驗證原本就只能在開窗環境做**(這不是丙案新增的限制,是既有事實 —— `u007`/`u011`/`u013` 之前的證據腳本全部也都是開窗跑的)。但 headless 仍然對**結構性**驗證有用且丙案應該覆蓋到:Q3 證明 headless 下一樣能量到 `WorldViewportContainer` 的真實 `position`/`size`/`stretch_shrink`、`_state`/`_controller` 是否為 null、`StatusLabel` 文字是否為真實在地化字串 —— 這些不需要像素也能證明「真的跑了 production 的初始化路徑」。**規則的形狀應該分兩段**:凡涉及像素比對(Check1-4 那種)→ 必須開窗執行,丙案在此段等於「開窗量測腳本必須 `load()` 真實場景檔」;凡涉及結構/狀態斷言(場景樹形狀、屬性值、旗標)→ headless 亦可執行,丙案在此段等於「headless 結構探針也必須 `load()` 真實場景檔,不得重新組一份自稱等價的替身」。

**2. `add_child` 要 `call_deferred` 這個坑 —— 應該寫進規則的實作指引,理由是它會重演,不是我這次偶然踩到的。**
Q1 的錯誤在 headless 與開窗兩次獨立執行中**逐字相同**,而且是引擎主場景啟動序列的時序問題(驅動腳本自己也是用 CLI 位置參數啟動的場景,`_ready()` 觸發時根節點還在忙),不是我這支腳本寫錯順序才發生的巧合。**任何人只要照丙案的字面意思寫「在 `_ready()` 裡 `load()`+`instantiate()`+`add_child()` 真實場景」,都會在第一次執行時撞到同一則引擎錯誤**,而且錯誤訊息本身其實已經給出正確答案(`Consider using add_child.call_deferred(child) instead`)—— 但如果沒人事先寫下來,下一個人一樣要自己撞一次才會發現。**這屬於「不寫下來就會重演」的類別,應該進規則的配套文件**(不一定要進規則本文的條文,但至少要進 `technical-director` 決定放置的某份配套指引,例如 `coding-standards.md` 那種「已知陷阱」小節的形狀)。

**3. Q3 的自我初始化結果對成本的影響 —— 讓丙案比預期便宜,但只在「真實資料檔案能表達你要驗證的場景」這個前提下成立;一旦踩到 Q4 那個例外,成本會反過來變貴。**
`BattleScreen._ready()` 自己讀真實資料檔、蓋真實 `BattleController`、算真實佈局,驅動腳本除了 `call_deferred` 那個坑和等待幾幀之外**幾乎不用做任何事** —— 這比「重建一份對照的子樹再手動餵資料」(u013 前三版的做法)省事得多,因為不用自己組節點、不用自己接腳本、不用自己算 transform。**但這個低成本只在你想驗證的東西剛好是「真實關卡資料本身長出來的樣子」時成立**。Q4 已指出:一旦量測需要合成場景(刻意安排的、資料檔案不會自然產生的佈局),完整載入這條路完全走不通,必須退回組局部子樹 —— 而且組出來的子樹還要自己重新確保與真實宿主結構一致(如 u013 第 4 版所做的比對),這部分工作量丙案並不會替你省下來。**規則若只強調「載入真實場景檔比較省事」,會誤導人以為丙案總是更便宜 —— 正確的表述是「丙案在資料層與真實檔案一致時最省事,在需要合成資料時完全不適用,必須改走 Q4 的例外形狀」。**

---

## 我沒查的清單

- **`battle_screen.gd` 只讀了第 1-988 行(共 2068 行)**,`_refresh_view()`、`render_pieces()` 呼叫點、卡牌互動、目標選取等後半段邏輯完全沒讀。因此我不知道這次真實載入的戰鬥畫面實際上有沒有渲染出任何棋子/血量文字/游標高亮,只知道 `_ready()` 讀檔與建構物件都成功了。
- **完全沒有讀 `board_view.gd`**,不知道它的繪製邏輯裡有哪些內容是向量繪製(理論上應為像素完美)、哪些是走 `Label`/`draw_string` 這類會反鋸齒的路徑。這直接導致上面「1071 是什麼」答不出來。
- **`SUBVIEWPORT-windowed` 的取樣密度不足**(僅 1800 點粗網格),沒有辦法用它確認或排除世界層本身有沒有反鋸齒內容。
- **沒有嘗試在 headless 下用非 dummy 的 rendering driver**(例如是否能強制指定 `--rendering-driver` 之類的旗標繞過 dummy texture storage)—— 沒有查證這條路是否存在或是否被本專案其他文件記載過,只確認了「預設 `--headless` 的路徑」拿不到像素。
- **沒有檢查 headless 下 `root viewport size = (64, 64)`(第一次失敗執行量到的)這個尺寸的來源**是引擎的 headless 預設值還是別的東西造成的 —— 這不影響本次任務結論(反正 headless 拿不到像素),但沒有深究。
- **沒有嘗試把丙案套用到除了 `battle_screen.gd`/`board_view.gd` 以外的其他既有證據腳本**(例如 `u007`/`u011`)去看規則的影響範圍多大 —— 本次只驗證了 `BattleScreen.tscn` 這一個場景檔、`u013` 這一個對照案例。
- **沒有重新執行 `u013-highlight-evidence-2026-09-22/evidence_driver.gd` 本身**去比對「改成載入 `BattleScreen.tscn`」是否得到不同數字 —— 派工單 Q5 有提到「若有餘裕就跑一次比對」,我沒有跑;上面 Q4/規則判定的推論完全基於閱讀該腳本原始碼與其檔頭記載的既有結果(`0/229440`),不是我重新執行得到的。
