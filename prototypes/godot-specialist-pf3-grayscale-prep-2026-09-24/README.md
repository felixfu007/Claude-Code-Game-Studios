# P-F3 灰階複驗準備(2026-09-24)

管理者裁決:今天不開窗。本目錄只完成「開窗以外」的部分,開窗那一步等管理者喊。

🔴 **本輪撞到 20 回合上限,提前被協調者叫停過一次;之後在協調者提供兩個卡點的實測結果後
繼續完成了 (二)(三) 的程式碼與 (二) 的實際執行。** 下面四節已於 2026-09-24 全部改寫為
現況——**這份文件曾經有一版寫著「(二)(三) 未動筆,零行程式碼」,那一版已經過時,
被本次改寫取代,不要沿用那個說法。**

## 🔴 第六十三批更新(2026-09-24):修了開窗前置查核抓到的三個缺陷

管理者裁決「三項都先修再開窗」。三個缺陷、修法、與驗證狀態:

1. **缺陷一(拍照前沒等畫面畫出來)** —— `extract_pf3_states.gd` 的 `_render_state()`
   與 `_attempt_capture()` 之間原本零等待。已依本專案唯一成功從視窗拍到真實像素的前例
   (`prototypes/godot-specialist-hidden-window-feasibility-2026-09-24/probe_main.gd:40-42,91`)
   加上等待,但改成【有上限】的版本(見 `_await_render_settle()`):固定等 2 個
   `process_frame`,再連上 `RenderingServer.frame_post_draw` 訊號、最多再等 10 個
   frame 就放棄。**這是刻意偏離前例的工程判斷,不是否定前例**——原因見下方「已知未驗證
   事項」。已 headless 重跑確認 `EXIT=0` 不受影響(見更新後的 `run_output_headless.txt`),
   但**這只證明不會懸掛,不證明開窗時真的等到了有效畫面**。
2. **缺陷二(取樣座標算錯,全部落在圖片外)** —— 選了「比對那一側改」,不改擷取那一側。
   `diff_pf3_grayscale.gd` 原本把擷取到的原生 480×270 圖當成合成後的 960×540 視窗,多乘了
   一個不該乘的 2 倍,導致取樣 y 座標(206~224 → 412~448)全部超出圖高 270,每一點都被
   `push_error` + `continue` 跳過,最終印出看似正常的 `0 ok, 0 flagged`。修法是拿掉那個
   乘法,並新增一道尺寸防呆(PNG 尺寸與 `world_viewport_size` 對不上就 `push_error` +
   `quit(1)`),避免同類漂移再次靜默發生。詳見該檔「座標系轉換」段落。
3. **缺陷三(灰階腳本沒有掛載場景,跑不起來)** —— 新增 `DiffPf3Grayscale.tscn`。

**自測(硬性交件要求)已完成**:新增 `self_test_diff_pf3_grayscale.gd` +
`SelfTestDiffPf3Grayscale.tscn`,用合成假影像(檔名 `self_test_synthetic_*`,刻意不叫
`legal_state.png` / `illegal_state.png`)把 `diff_pf3_grayscale.gd` 完整跑過一次,headless
`EXIT=0`,`8 ok, 4 flagged` —— pass 分支與 fail 分支都真的被觸發到,不是只證明沒當掉。
原始輸出見 `run_output_self_test_SYNTHETIC_IMAGES_NOT_GAMEPLAY.txt`。
⚠️ **這支自測本身第一次執行時因為兩個 typo(`_write_synthetic_geometry()` /
`_write_synthetic_image()` 宣告 `-> bool` 但函式本體沒有在每條路徑都 `return` 一個
布林值)導致 GDScript 解析失敗,而解析失敗的那次執行卡在主迴圈裡沒有呼叫任何
`quit()`,行程懸掛,由協調者事後用 `tasklist` 發現兩個殘留的 `Godot_v4.7.1-stable_win64`
行程並手動 `taskkill //F //T` 清掉。** 修好 typo 之後重跑,乾淨結束。這與 (二) 檔頭記載的
「`-s` 寫法導致 `CursorStateHost` 編譯期失敗、行程懸掛」是同一種失效模式的第三次重演
(壞掉的地方不同,共同點是「腳本在 `quit()` 之前就出錯,而出錯路徑沒有人替它呼叫
`quit()`」)——記在這裡供下一個人參考,不是自我批評用的裝飾。

## 狀態總覽

- [x] (一) 可行性查證 —— 結論「可行」。**混合等級**:單位 5(戊)無配對這件事有
      讀碼推論、有已讀取的真實資料檔內容、也有既有引擎測試(未在本輪重跑);
      `vs01_cards.txt` 的 8 張卡類別分佈已親自 `cat` 核實。逐條標明見下方。
- [x] (二) 擷取腳本 —— **已寫、已跑,headless `EXIT=0`。** 選路 B(不是路 A),
      證明範圍已縮小,見該節。**第六十三批已修缺陷一(拍照前等待),見上方更新節。**
- [x] (三) 灰階比對腳本 —— **已寫,且已用合成假影像 headless 完整跑過一次
      (`8 ok, 4 flagged`)。仍未對真的兩張 legal_state.png / illegal_state.png 執行過**
      ——那兩個檔案只有開窗才會產生。通過門檻(`diff < 0.08`)仍是自己編的佔位數字,
      未經真實畫面驗證。**第六十三批已修缺陷二(座標乘錯倍率)與缺陷三(缺場景檔)。**
- [x] 給管理者 —— 可以給出完整指令;時間只有「確定小於 60 秒」這個粗略上界,
      沒有精確量測。

## (一) 可行性查證:真實資料檔能否擺出「同一顆棋子、同一格、合法/不合法」兩態

**結論:可行。** 逐條標明查證等級,不要整節當成同一個等級讀:

### 已讀到的原始碼(推論鏈,未執行——這幾條是讀碼推論,不是引擎輸出)

1. `src/gameplay/cards/permanent_affinity_write_rules.gd:75-80` `legal_pairs()`——
   結果完全由傳入的 `links` 陣列推導,從不憑空生成配對。**結構性推論**:一個從未
   出現在 `links` 裡的單位,不論存活與否,永遠不會出現在 `legal_pairs()` 的輸出。
2. `src/gameplay/cards/card_play_session.gd:352-362` `_s2p_legal_first_targets()`——
   丙類卡的 `legal_targets()` 直接回傳 `legal_pairs()` 蒐集到的單位 id 集合。同檔
   `:339-343` `_alive_player_unit_ids()`——甲類卡的 `legal_targets()` 回傳全體存活
   我方單位,不查 affinity 連結。
3. `src/ui/battle/battle_screen.gd:1977-1999`——`card_target_illegal` 旗標
   = `_card_selecting_target and not card_target_legal_set.has(unit.id)`。

### 已用 `cat` 直接讀取的真實資料檔內容(非讀碼推論,已實測)

4. `assets/data/units/vs01_roster.txt`——單位 5(戊)是 `PLAYER` 陣營,起始座標
   `(0,5)`,開局預設存活。
5. `assets/data/affinity/vs01_affinity_links.txt`——全檔僅兩條線:
   `1,2,POSITIVE,1` 與 `3,4,NEGATIVE,1`。檔案頭部註解逐字寫明「戊(麥子健)沒有
   任何配對,這是刻意的,不是漏寫」。
6. ✅ **`assets/data/cards/vs01_cards.txt`——本輪已親自 `cat` 核實
   (先前一版報告寫「沒有親自開過,是轉引另一支測試檔的註解」,現已補上)。**
   真實內容:8 張卡。`card_01`~`card_06` 皆 `TEMPORARY_STAT_MODIFIER`(甲類)。
   `card_07,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,2`(丙類,配對 1-2、+2)。
   `card_08,PERMANENT_AFFINITY_WRITE,0,0,0,3,4,-2`(丙類,配對 3-4、-2)。

### 既有、但本輪未重跑的引擎測試(存在即證據,但不是這輪的新輸出)

7. `tests/unit/gameplay/affinity/affinity_link_test.gd:157-165`
   `test_links_from_text_vs01_file_gives_unit_five_no_links`——直接讀取真實
   `vs01_affinity_links.txt`(`FileAccess.get_file_as_string`),斷言解析出的每一條
   link 都不涉及單位 5。**這條測試存在,但本輪沒有重新執行 GdUnit4 去確認它現在
   仍是綠燈**——下一個人如果要把它升級成「這輪驗證過」,需要實際跑一次測試套件。

### 尚未查證的缺口(路 A 才需要,路 B 不需要——見下方 (二) 的路線裁決)

8. `show_hp_text` 在真實流程裡怎麼被設成 true,游標系統(`CursorStateHost`)怎麼
   定位到單位 5 的格子——沒有走通。
9. `_card_selecting_target`(卡玩流程)與 `selected`(棋子移動選取)兩套狀態會不會
   互相排斥或衝突——沒有查證。

## (二) 擷取腳本

**已寫、已跑。** 檔案:`extract_pf3_states.gd`(場景腳本,`extends Node`)+
`ExtractPf3States.tscn`(掛載場景,執行入口)。

### 🔴 路線裁決:選了路 B,不是路 A——這段決定證據的範圍,必須讀

有兩條路可以把畫面擺成「合法/不合法」兩態:

- **路 A —— 走完整遊戲路徑**:真實卡牌流程(甲類卡選中 → 單位 5 合法;丙類卡選中
  → 單位 5 不合法),讓 `battle_screen.gd:1996-2010` **自己算出**兩個旗標。
- **路 B —— 直接呼叫 `render_pieces()` / `set_card_target_highlights()`**,由腳本
  自己把 `card_target_illegal` 設 true/false。

**本腳本走路 B。** 選路 B 的理由:路 A 需要先解決 (一) 第 8、9 點兩個缺口(游標定位、
卡玩流程真正入口 + 丙類卡未必在手牌的重試邏輯),在「不准再讀檔案先確認」的限制下,
這兩項本輪解不了;選路 B 讓腳本能在本輪真的寫出來、真的跑起來。

🔴 **這張證據因此證明什麼**:`board_view.gd` 的 `render_pieces()` /
`set_card_target_highlights()` / `_build_hp_text()` / `_build_card_target_illegal_mark()`
這幾個真實 production 函式,在 `card_target_illegal` 為 true / false 兩種輸入下,
真的畫出兩種不同的東西(HP 襯底顏色不同、有無 X 記號)——這正是 P-F3 要驗的「渲染」
問題本身。兩態使用的棋盤、地形、名冊、單位位置全部來自真實 vs01 資料檔(透過真實
`BattleScreen.tscn` 的 `_ready()` 正常載入,沒有覆寫任何 `*_path_override`),不是
合成資料。

🔴 **這張證據明確不證明什麼**:**不證明「遊戲會在正確的時機把 `card_target_illegal`
設成 true」**——那是 `card_play_session.gd` + `battle_screen.gd` 的職責,本腳本繞過了
它們,兩個旗標是腳本自己指定的,不是遊戲邏輯算出來的。要證明「觸發時機正確」需要路 A,
本輪未做。讀這份 README 的人如果只看畫面截圖,不會知道這一點——**旗標是誰決定的,
畫面本身看不出來。**

⚠️ **路 B 的一個刻意簡化,不是遺漏**:pieces 字典裡除了單位 5 以外的其他單位一律
`show_hp_text=false`。這與真實遊戲邏輯不同(真實邏輯是「選中的單位」或「游標指向的
單位」才顯示血量數字,可能不只一個)。**只看產出的 PNG 畫面的人,會看到棋盤上其他
單位完全沒有血量數字——這是路 B 的裁決,不是 bug。**

### 已實測的物證(`run_output_headless.txt`,headless,`EXIT=0`)

```
SANITY: WorldViewportContainer.position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2
SANITY: WorldViewport.size = (480, 270)
SANITY: BoardView.global_position = (0.0, 0.0)
SANITY: BoardView.global_transform = [X: (1.0, 0.0), Y: (0.0, 1.0), O: (0.0, 0.0)]
REAL DATA: unit 5 (戊) real cell from vs01_roster.txt = (0, 5)
--- STATE A: legal (card_target_illegal = false) ---
  (highlight layer child count = 1, Line2D count = 0)
  CAPTURE[legal]: get_image() is null (expected under --headless ...)
--- STATE B: illegal (card_target_illegal = true) ---
  MARK_LINE points (real, engine-computed) = [(39.0, 206.0), (57.0, 224.0)]
  MARK_LINE points (real, engine-computed) = [(57.0, 206.0), (39.0, 224.0)]
  (highlight layer child count = 2, Line2D count = 2)
  CAPTURE[illegal]: get_image() is null (expected under --headless ...)
WROTE: res://prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/real_geometry.json
=== done ===
```

物證意義:`WorldViewportContainer`/`WorldViewport` 的尺寸與縮放是**真實宿主鏈自己算出來
的**,不是腳本決定的;`MARK_LINE points` 是 `_build_card_target_illegal_mark()` 真實建出
的 `Line2D.points`,不是腳本自己重算叉的兩條對角線端點;state A 沒有任何 `Line2D`
(child count=1,只有外框、沒有 X),state B 有 2 條(外框+X 的兩條對角線)——兩態
確實不同,且不同的方式與 `board_view.gd` 的真實邏輯一致。

⚠️ **一個先前文件沒有逐字記過的觀察**:嘗試讀取像素之前,引擎會先印一行
```
ERROR: Parameter "t" is null.
   at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)
```
再印出 `get_image() is null`。**2026-09-23 的既有文件只記了「`get_image()` is null」這個
結果,沒有記這行前置引擎錯誤。** 本輪沒有查證這是本專案已知現象的新增細節、還是我漏看了
既有記錄——照實列為未查證。不影響結論(image 確實是 null,符合預期),但下一個人如果看到
這行 `ERROR` 不要誤以為腳本壞了。

### 執行安全性(2026-09-24,必須留在這裡,不能只留在對話報告裡)

`extract_pf3_states.gd` 最初寫成 `extends SceneTree`、用
`godot --headless --path . -s extract_pf3_states.gd` 執行。**這個寫法會讓
`battle_screen.gd` 編譯期報錯 `Identifier not found: CursorStateHost`**(`-s` 自訂
MainLoop 腳本似乎繞過了引擎正常的「先掛 Autoload、再跑主場景」開機順序,重跑三次逐字
重現,含中間重新 `--import` 一次)。這個編譯錯誤發生在腳本自己的 `quit()` 呼叫之前,
導致該次執行沒有任何路徑會呼叫 `quit()`,行程卡在主迴圈裡永遠不退出——這正是造成兩個
headless Godot 行程從背景卡住、後來由協調者手動 `taskkill` 清掉的成因。

**現在磁碟上的版本已經不是那個寫法。** `extract_pf3_states.gd` 已改成 `extends Node`,
搭配同目錄 `ExtractPf3States.tscn` 當一般場景執行(`godot --headless --path .
prototypes/.../ExtractPf3States.tscn`,不是 `-s`),`CursorStateHost` 正常解析,腳本在
`_ready()` 的每一個提前返回分支與最終正常路徑都呼叫了 `get_tree().quit(...)`——已實測
`EXIT=0`,不會再卡住。**下一個人如果要重跑,必須用 `.tscn` 這個跑法,不要用 `-s` 直接跑
`extract_pf3_states.gd`**,否則會重演同一個「編譯期就死、`quit()` 永遠不會被呼叫」的
懸掛行程問題。

**驗證一個 headless 執行有沒有真的結束,不能只看有沒有印出東西,要看外層 `echo $?` 的
結束碼**——本輪能發現「卡住」正是因為協調者去查了實際行程清單(`--headless` 命令列存在
但行程沒有退出),而不是看 log 內容判斷。

### 額外產出:`real_geometry.json`

每次執行(二)都會覆寫一份,內容包含真實宿主鏈尺寸、`BoardView.global_position`、
單位 5 的真實格子座標、以及不合法狀態下兩條對角線的真實 `Line2D.points`。(三) 的
灰階比對腳本讀這份檔案取樣座標,不重算幾何公式。

## (三) 灰階比對腳本

**已寫,且已用合成假影像 headless 完整跑過一次。** 檔案:`diff_pf3_grayscale.gd` +
`DiffPf3Grayscale.tscn`(第六十三批新增,修缺陷三)。**對真的兩張
legal_state.png / illegal_state.png 仍未執行過**——那兩個檔案只有開窗才會產生。

- 讀 `real_geometry.json` 取得 `illegal_mark_local_points`(真實對角線端點),在
  `y_local ∈ [206, 224]`(對應設計文件的格內相對 y ∈ [7, 25))這段範圍內用線性內插
  取 6 個樣本點,轉換成 `legal_state.png` / `illegal_state.png` 的像素座標。
  🔴 **第六十三批修缺陷二**:原本這裡還乘了 `world_container_size / world_viewport_size`
  (=2),把擷取腳本拍到的原生 480×270 圖誤當成合成後的 960×540 視窗,y 座標算出
  412~448、全部超出圖高 270,每個樣本都被跳過,最終印出看似正常的 `0 ok, 0 flagged`。
  現在已拿掉那個乘法(`pixel_point = board_offset + local_point`),並在讀完兩張 PNG
  後新增尺寸防呆:PNG 尺寸與 JSON 記的 `world_viewport_size` 對不上就 `push_error` +
  `quit(1)`,不會再靜默印出「看起來沒事」的空結果。詳見檔案開頭「座標系轉換」段落。
- 轉灰階(`Image.convert(Image.FORMAT_L8)`)後逐點比較兩張圖的灰階差,依設計文件
  (`design/art/hp-readout-contrast-fix.md` 第四節)分區:格內相對 y < 11 為
  「預期內差異小,可接受」,y ≥ 11 為「必須清楚可辨」。
- 🔴 **`diff < 0.08` 這個通過門檻是我自己編的佔位數字,不是從設計文件或任何量測來的。**
  設計文件只說「清楚可辨」/「幾乎看不見」這種質性描述,沒有給浮點數門檻。腳本自己的
  註解已寫明「第一次真的跑出兩張 PNG 之後必須人眼核對這個門檻抓不抓得到真實邊界,
  不能盲目相信這個數字」。**合成假影像的自測無法驗證這個門檻對不對**——它只能證明
  「diff 很大時判 ok、diff 接近 0 時判 flagged」這條邏輯有在執行,不能證明 0.08 這個
  數字在真實遊戲灰階值上抓得準不準。
- ✅ **第六十三批已用合成假影像完整跑過一次**(`self_test_diff_pf3_grayscale.gd` +
  `SelfTestDiffPf3Grayscale.tscn`,headless,`EXIT=0`)。透過 (三) 新增的三個
  `@export ..._override` 欄位把讀取路徑指向合成的 `self_test_synthetic_*.json/png`
  ——**刻意不使用 `legal_state.png` / `illegal_state.png` 這兩個保留檔名**,那兩個
  只留給開窗那次的真實證據。合成影像設計成兩條線各自的 CLEAR 區一大一小差異,結果
  `8 ok, 4 flagged`——證明 pass 分支與 fail 分支都真的被執行到,不是只證明「沒當掉」。
  原始輸出見同目錄 `run_output_self_test_SYNTHETIC_IMAGES_NOT_GAMEPLAY.txt`。
  ⚠️ 腳本裡用到的 `Image.load_from_file()`、`JSON.parse_string()`、`Image.FORMAT_L8`、
  `Image.create()`、`Image.fill_rect()`、`img.get_pixel(px,py).r`、
  `RenderingServer.frame_post_draw` 這幾個 API,**沒有對照
  `docs/engine-reference/godot/deprecated-apis.md` 或 `breaking-changes.md` 逐條核對過
  4.7.1 是否有變動**(已用 grep 確認這些字串未出現在該兩份文件裡,亦即沒有被列為
  已知變更項,但這不等於逐條核對過官方文件)——列為明確缺口,不是已完成項。這些都是
  自測與 headless 重跑實際執行成功的 API,行為已透過執行本身間接驗證,只是版本文件
  比對這一步沒有另外走一遍。

## 給管理者

**現在可以給出完整指令,但時間只有粗略上界,沒有精確量測。**

指令(windowed,注意去掉 `--headless`,場景路徑是 `.tscn` 不是 `-s` 腳本):
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . prototypes/godot-specialist-pf3-grayscale-prep-2026-09-24/ExtractPf3States.tscn
```
跑完會在同目錄產生 `legal_state.png` / `illegal_state.png`,並覆寫一份新的
`real_geometry.json`。

- **確定小於 60 秒**:headless 版本(邏輯與 windowed 完全相同,只差最後
  `get_image()` 那一步)在外層 `timeout 60` 限制下每次都乾淨結束(`EXIT=0`),
  沒有被 timeout 中止過。但沒有另外用 `time` 指令量過精確秒數,只能說「確定小於
  60 秒」,不是精確數字。
- **開窗額外開銷是類比估計,不是量測**:視窗建立/GPU 初始化通常會再加數秒到一分鐘量級
  的開銷,這個範圍是類比本專案其他 windowed 探針的經驗值,**不是針對這支腳本量出來的
  數字**。
- 拿到兩張 PNG 之後:(三) `diff_pf3_grayscale.gd` 不需要開窗(只讀 PNG+JSON),可以
  另外用 headless 跑;但如上一節所述,這支腳本本輪從未執行過,第一次跑很可能需要
  除錯,不要預期它一次就過。
- 拿到比對結果之後:**人工開圖確認仍是強制項,不可省略**(設計文件第四節步驟 4、
  `.claude/docs/coding-standards.md` Check 5)——尤其是「整條 X 是否仍讀得出是一個
  完整的叉」與「壓暗會不會被誤讀成其他狀態」這兩點,協調者與 `art-director` 的
  分歧就是留給這一步人眼判斷的。
  🔴 **`legal_state.png` / `illegal_state.png` 是原生 480×270 的小圖,一般看圖軟體
  用預設縮放開起來會很小、看不清楚。** `diff_pf3_grayscale.gd` 執行時會印一行
  `HUMAN REVIEW HINT`,給出建議的放大檢視像素範圍(依真實對角線端點算出的
  bounding box + 10px 邊界)——**開圖時請放大到 400% 以上,對準那個範圍看**,
  不要用預設縮放掃過整張小圖。
- ⚠️ **若開窗執行 (二) 時,log 印出
  `frame_post_draw did not fire within 10 extra frames after the base 2 -- proceeding
  anyway`,這行本身就是警訊,應該回報,不要略過。** 本輪 headless 重跑已確認這行
  在 headless 下必然出現(dummy rendering driver 不觸發這個訊號),但開窗執行走的是
  真實 GPU 路徑,理論上訊號應該準時觸發、這行不該出現。若開窗時仍然印出這行,代表
  「等 10 個 frame 都等不到一次真實渲染完成訊號」這件事在真實 GPU 環境下也發生了,
  意味著拍到的 PNG 有更高機率是「畫一半」或「上一態殘留」的畫面,不能直接信任——
  應該連同這行一起回報,而不是只看有沒有 EXIT=0。
