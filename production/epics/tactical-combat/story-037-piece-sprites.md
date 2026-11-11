# Story 037:棋子圖(32×40)接進戰鬥棋盤,取代現行佔位棋子畫法

> **Status**: Blocked(未決點 1、2、3 —— 詳見最後一節;**程式部分可先用佔位圖做完,不必等素材,但未決點 1 會決定敵方那一側的範圍**)
> ✅ **2026-11-11 加註(管理者核准「現在開工,先用佔位圖(推薦)」)**:Status 改為 **Ready**。未決點 1、3、4 由 art-director 答覆 `docs/reviews/piece-sprites-art-answers-2026-11-11.md`:①敵方維持現行佔位圖,本張不做敵方圖;③正式圖路徑定案 `assets/art/characters/pieces/char_<jia|yi|bing|ding|wu>_piece_idle_01.png`;④對齊確認不改 `_piece_anchor`,另要求「下方格位的棋子畫在上方棋子前面」(現況未查,實作者確認)。未決點 2:程式先做、素材到再放檔,最終畫面驗收在家。原句保留。
> **Type**: UI / Visual(含少量 Logic:貼圖路徑解析與缺檔退回,可單元測試)
> **Epic**: tactical-combat(M4 世界層呈現)
> **指派建議**: `godot-gdscript-specialist`(.gd);像素量測與截圖驗收在家驗收,見 AC
> **素材依賴**: 家用端 35 號正式化 5 張(`docs/ai-art-service-handoff/35-request-draft-2026-11-10.md`)尚未交回。**本工單設計成「先用現有佔位圖做完程式,素材到了只換檔」**。

## 一句話目標

讓棋盤上我方 5 人改畫成正式的 32×40 棋子圖(`char_<jia|yi|bing|ding|wu>_piece_idle_01.png`);**正式圖檔不存在時,安靜退回現行佔位圖**,所以程式與素材可以分開交付。

## 擁有者判斷與理由

- **Epic 歸 tactical-combat**:`production/epics/tactical-combat/EPIC.md` 的 M4「世界層呈現(`src/ui/battle/board_view.gd`)」就是棋盤繪製的擁有者(當場查:`grep -n "M4 — 世界層呈現" production/epics/tactical-combat/EPIC.md`)。`card-play-interface` 的 U-013 也動過 `board_view.gd`,但那是「選目標高亮」,不是棋子本體。
- **編號 037**:`production/epics/tactical-combat/` 現有最大為 `story-036-vs03-vs04-roster-adjust.md`,無 037(當場查:`ls production/epics/tactical-combat | grep story-03`)。
- **指派**:`.gd` 依 `technical-preferences.md` 的副檔名路由交 `godot-gdscript-specialist`;`.tscn` 若需動交 `godot-specialist`(本工單預期不動場景)。

## 現行棋子怎麼畫(查證,原始行)

檔案 `src/ui/battle/board_view.gd`:

| 項目 | 符號 | 現況 |
|---|---|---|
| 我方貼圖表 | `const ALLY_SPRITE_PATHS: Array[String]` | 5 個 `res://assets/art/placeholder/piece_ally_01.png` ~ `_05.png`,以 `sprite_index`(0~4)索引 |
| 敵方貼圖 | `const ENEMY_SPRITE_PATH: String` | **單一** `res://assets/art/placeholder/piece_enemy_01.png`,註解自述「placeholder set only has one;沒有 per-enemy 區分」 |
| 繪製 | `render_pieces(pieces: Array[Dictionary])` | 迴圈內:`var path: String = ENEMY_SPRITE_PATH`;`if faction == "PLAYER":` 以 `clampi(sprite_index, 0, ALLY_SPRITE_PATHS.size() - 1)` 取我方路徑;然後 `sprite.texture = load(path)`、`sprite.centered = true`、`sprite.position = _piece_anchor(cell)`、加進 `_pieces_layer` |
| 錨點 | `_piece_anchor(cell)` / `const PIECE_SPRITE_HEIGHT: int = 40` | `Vector2(格中心 x, 格底緣 y − 40×0.5)`:**精靈底邊貼格底緣、多出的 8px 往上超出格上緣**(函式上方註解與 `PIECE_SPRITE_HEIGHT` 註解明文) |
| 資料來源 | `src/ui/battle/battle_screen.gd`(`pieces.append({...})` 兩處) | 我方 `"sprite_index": clampi(unit.id - 1, 0, 4)`(名冊 id 1~5 = 甲~戊,註解「Roster ids 1-5 are exactly the five player units in order」);敵方 `"sprite_index": 0` |
| 名冊對應 | `assets/data/units/vs0[1-5]_roster.txt` | 五場各恰 5 名 `PLAYER`;id 1=甲、2=乙(`vs01_roster.txt` 前幾行可證) |

**圖層與周邊**:HP 條/血量字在 `_stats_layer`、行動旗標在 `_action_flag_layer`,與棋子精靈各自獨立;**錨點是以格子而非以精靈算的**,所以換貼圖只要新圖也是 32×40 就不動它們。`PiecesLayer` 的繪製順序有測試鎖(見「會受影響的既有測試」)。

**目前載入方式**:直接 `load(path)`,**沒有存在性檢查** —— 路徑不存在時引擎會印錯誤並回 null。本工單的「素材缺席安靜退回」必須在這裡補(見 AC)。

## 美術規格來源與對齊

- `design/art/art-direction.md` 尺寸表「棋子(場上)」列:**32×40(比格子高,露出站姿)**;「棋盤單格 32×32」。
- **「比格子高 8px 怎麼對齊」**:art-direction 只寫「比格子高,露出站姿」,**沒寫錨點規則**。35 號第三節第 2 步寫「人物腳底貼畫布下緣,水平置中」。**現行程式的錨點(精靈底邊 = 格底緣、超出的 8px 在上方)與此一致**,所以**預期不必改 `_piece_anchor`**。這是「兩份文件都沒明文要求、但彼此相容」,**不是美術文件的明文裁決** —— 見未決點 4(低風險,列為確認項)。
- 待機幀:art-direction 寫 2~4 幀待機,2026-10-29 加註「暫定做法 A:第 1 幀 AI 圖、第 2~4 幀後製位移 1px」。**35 號只交 `idle_01` 一幀靜態圖。本工單只做靜態單幀,待機動畫不在範圍內**(要做是新工單,且要先有 2~4 幀素材)。受擊閃爍依加註「改由遊戲程式處理」,**也不在本工單範圍**。
- 審定與風險來源:`docs/ai-art-service-handoff/34-art-director-review-2026-11-10.md`。其中「32×40 縮後甲與丁主色接近」是美術面風險,**由 art-director 在看過成品並排圖後處理,不是本工單的程式問題**;但它意味著**素材可能還會換**,故路徑與命名必須穩定、程式不得綁死任何一張圖的內容。
- **紋理濾波**:`.claude/docs/technical-preferences.md` 規定 Nearest。實況:`project.godot` 的 `rendering/textures/canvas_textures/default_texture_filter=0`(Nearest),`src/ui/battle/BattleScreen.tscn` 的 `WorldViewportContainer` 設 `texture_filter = 1`。新增的 `Sprite2D` 不覆寫 `texture_filter`(維持 Inherit)即吃專案預設 Nearest。**不得對棋子精靈設 Linear;也不得為了「保險」寫死覆寫**,以免日後改全域設定時漏掉這裡。

## 素材路徑與 .import 慣例

- 現有素材只有 `assets/art/placeholder/`(`git ls-files assets/art` 可證),**美術規格沒有規定正式棋子的放置目錄**(`art-direction.md` 全文搜不到 `assets/art/` 子路徑規定)。**建議** `assets/art/characters/pieces/char_<jia|yi|bing|ding|wu>_piece_idle_01.png`,**列為未決點 3,請 art-director / 管理者確認**;程式端以單一常數表示該目錄前綴,日後改目錄只改一處。
- **`.import` 伴隨檔進版控**(`.gitignore` 刻意未啟用 `*.import` 排除規則,`assets/art/placeholder/*.png.import` 皆已追蹤)。素材放入後需跑一次 `godot --headless --path . --import` 產生 `.import` 並**一併提交**。
- **資料表不得用 `.csv`**(`coding-standards.md`:Godot 會把 `.csv` 當翻譯匯入)。**本工單不新增任何資料表**;角色→檔名的對應直接用「我方名冊 id → 角色代號」的常數陣列即可(`["jia","yi","bing","ding","wu"]`,與現行 `ALLY_SPRITE_PATHS` 同一個索引語意),不需要資料檔。
- **佔位圖保留不刪**:`assets/art/placeholder/piece_ally_*.png` 與 `piece_enemy_01.png` 是缺檔時的退回來源,且敵方在未決點 1 裁決前仍須使用它。

## 建議的實作形狀(僅供實作者參考,不是限制)

1. 新增一個小的純函式(可 `new()` 或 `static`,放 `board_view.gd` 內或旁邊的 `RefCounted` 皆可,由實作者與 godot-gdscript-specialist 定),輸入「陣營、`sprite_index`」,輸出該用的貼圖路徑:**正式路徑存在(`ResourceLoader.exists`)就用正式,否則用佔位**。這樣缺檔退回邏輯能在不開窗的單元測試裡驗。
2. `render_pieces()` 改呼叫它,取代內嵌的 `path` 選擇與直接 `load(path)`。**不得因缺檔呼叫 `push_error`**,也不得讓 `load()` 對不存在路徑印錯。
3. 不動 `_piece_anchor`、`PIECE_SPRITE_HEIGHT`、圖層順序、HP/旗標圖層。
4. 貼圖尺寸防呆(選做,實作者判斷):正式圖若不是 32×40,是否警告?**預設不加行為**,只在 AC-5 的在家驗收裡量。

## Affected Files

| 檔案 | 動作 | 備註 |
|---|---|---|
| `src/ui/battle/board_view.gd` | 修改 | `render_pieces()` 選圖路徑、新增路徑解析函式與正式素材目錄常數;**不動** `_piece_anchor` |
| `tests/unit/ui/board_view_piece_sprite_path_test.gd` | 新增 | 路徑解析(正式存在/缺席退回/越界索引/敵方),不開窗、不碰檔案系統寫入 |
| `assets/art/<目錄見未決點 3>/char_*_piece_idle_01.png`(+ `.import`) | 新增(**素材到了才有**) | 5 張;本工單程式部分不依賴它們存在 |
| `src/ui/battle/battle_screen.gd` | **預計不動** | 敵方 `sprite_index` 目前恆為 0;**若未決點 1 裁決為「敵方也要多款圖」才會動**,屆時另行補列 |
| `tests/unit/ui/battle_screen_scene_test.gd` | **預計不動**,但需確認(見下節) | 註解引用 `piece_enemy_01.png` 全色塊事實 |

## Acceptance Criteria

**AC-1(缺檔退回,可自動測)** 正式路徑不存在時,我方 `sprite_index` 0~4 解析出的路徑仍是對應的 `piece_ally_0N.png` 佔位圖;`render_pieces()` 照常加入 sprite,`sprite.texture` 非 null,**不 `push_error`、不崩潰、引擎無「Failed loading resource」輸出**。
**AC-2(正式圖優先,可自動測)** 正式路徑存在時解析出正式路徑。**測試不得寫檔進 `assets/`**(單元測試禁寫檔系統)——以「路徑存在性判定函式可注入」或「素材到位後在真實檔上讀」二擇一處理,實作者選定並在測試檔頭宣告;**若選後者,該測項在素材到位前須明確標為待素材,不得用假檔讓它變綠**。
**AC-3(越界/不明索引,可自動測)** `sprite_index` 越界仍 clamp 到 0~4,不崩潰(維持現行 `clampi` 語意)。
**AC-4(敵方不退步,可自動測)** 敵方單位的取圖結果與現行一致(`ENEMY_SPRITE_PATH`),直到未決點 1 另有裁決。
**AC-5(對齊,**在家驗收**、只能開窗)** 以真實 `BattleScreen.tscn`(依 `technical-preferences.md`「第 5 點」:`load()` → `instantiate()` → `call_deferred("add_child")` → 等幀;**不得自組替身節點鏈**)渲染,**原始 log 須留真實宿主鏈算出的量測值**(`WorldViewportContainer` 的 `position`/`size`/`stretch_shrink` 與 `WorldViewport.size`),否則不得標 (A) 級。驗:① 棋子腳底落在格底緣、頭頂超出格上緣 8px;② 不與 HP 條/旗標標記錯位;③ 五種世界層解析度下最近鄰、無糊邊。
**AC-6(像素格線,在家驗收)** Check 4 依 `coding-standards.md`「Check 4 世界層量法變更(2026-09-23)」執行:直接讀 `WorldViewport.get_texture().get_image()`,`_scale` 取被測內容應有的整數倍率(**不得預設 1**),量測前先確認被測精靈位置對齊該倍率的倍數;**若被測範圍無被縮放內容,證據寫「沒有可測對象(N/A)」,不得寫「通過」**。headless 取不到像素,此項**只能在家開窗做**。
**AC-7(人眼,在家驗收,強制)** 人實際開圖確認五人棋子顯示正確、與立繪辨得出同一人(coding-standards Check 5)。Category A 全畫面截圖依該文件「Screenshot classification」分類後套檢查。
**AC-8(全套測試)** 交付前跑全套(`GODOT_BIN=<引擎> ./tools/build/run_tests_with_import.sh`),回報貼出引擎自己的 `ENGINE EXIT` 與 `Overall Summary` 原始三行;協調者自行重跑複驗。

## 會受影響的既有測試(grep 結果)

- `tests/unit/ui/battle_screen_scene_test.gd`:**只在註解引用** `piece_enemy_01.png` 為單色色塊事實(用來說明為何 Attack/Threat 層必須在 `PiecesLayer` 之上),**斷言的是圖層 index 順序,不是貼圖內容**。預期不受影響。⚠️ **但該註解的前提(佔位棋子完全不透明)在換成正式棋子後不再成立**(正式圖含透明像素)—— 圖層順序的規則本身仍成立、測試不必改,**實作者需確認註解是否補一句「正式圖已非全不透明,順序規則維持不變」**(註解類修改,可順手做)。
- `tests/integration/ui/action_flag_impassable_terrain_test.gd`、`tests/integration/ui/card_target_selection_test.gd`:呼叫 `render_pieces()`,**以 `sprite_index` 為資料餵入、斷言的是旗標/HP 讀出,不是貼圖路徑**(grep `piece_ally|piece_enemy|ALLY_SPRITE|ENEMY_SPRITE` 於 `tests/` 只命中 `battle_screen_scene_test.gd` 一處註解)。預期不受影響,但這兩支會實際跑到新的選圖路徑,**全套必須實跑確認**。
- 🔴 這些「預期」是靜態讀碼的推論,**不是量測**;以 AC-8 的全套結果為準。

## 範圍外(明列,免得被順手帶進來)

待機多幀動畫、受擊閃爍、敵方多款圖(待未決點 1)、立繪、對話畫面、素材本身的製作與審定(家用端/art-director)、`art-direction.md` 任何修改。

## 未決點(需裁決後才能解除 Blocked;1~3 擋工單,4 為確認項)

1. **敵方棋子畫什麼?(需 art-director,可能升到管理者)** 35 號只有我方 5 人,敵方現在是全部共用一張單色佔位圖。選項:(a) 敵方維持佔位圖不動(本工單範圍最小,但棋盤上會是「精緻我方 vs 單色方塊敵方」);(b) 另開工單做敵方正式棋子,本工單敵方不動;(c) 先做一張臨時的通用敵方圖。**本工單預設 (a)/(b) 等價 —— 敵方不動**,但請確認可接受這個視覺落差到何時。
2. **素材何時到、以哪一版為準?(需協調者/家用端)** 35 號尚未交回,且 34 號審定明說「定案要等 32×40 成品我看過」、甲丁主色可能分不開而要重做配色。**程式可先做完,但「驗收」(AC-5~7)與工單最終 Done 必須等 art-director 審過成品。** 請確認:程式先行、素材後換,是否是你要的節奏。
3. **正式棋子圖放哪個資料夾?** 美術文件沒規定。建議 `assets/art/characters/pieces/`;請 art-director 或管理者確認(影響檔案進版控的位置,事後搬動要同時搬 `.import`)。
4. **(確認項)「比格子高 8px 往上超出」是否就是美術要的對齊?** 現行程式與 35 號「腳底貼下緣」相容,`art-direction.md` 只寫「比格子高,露出站姿」。請 art-director 一句話確認「底邊貼格底緣、頭部向上超出 8px」即定案;若要別的(例如腳底略超出格底),`_piece_anchor` 需改,AC-5 數字會變。
