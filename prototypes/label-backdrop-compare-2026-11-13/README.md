# 棋子首字襯底並排比較(2026-11-13)

規格:`docs/reviews/art-addendum-icons-contrast-salience-2026-11-13.md` 第 2、5 節。管理者裁決「先做並排截圖,看圖再決定」。

## 開窗指令(協調者在允許時段執行;公司規定須靜音、不得在最上層)
```
cd /c/Users/felixfu007/Documents/Claude-Code-Game-Studios
timeout 150 "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/label-backdrop-compare-2026-11-13/driver.gd > prototypes/label-backdrop-compare-2026-11-13/run_output_windowed.txt 2>&1; echo ENGINE EXIT=$?
```
預估開窗 **約 20~30 秒**(2 解析度 × 場景建立 + 16 張 × 約 1 秒;headless 全程 7 秒)。內建 WATCHDOG 150 秒。
輸出 `out/<寬>x<高>_<1overview|2cursor_xu>_<0current|A_alpha072|B_alpha050|C_xu_only_alpha072>.png`,共 16 張。

## 變體
| 檔名片段 | 內容 |
|---|---|
| 0current | 現行,不加底 |
| A_alpha072 | 我方首字襯底 #0E0F14 α0.72,敵方不加 |
| B_alpha050 | 同 A,α0.50 |
| C_xu_only_alpha072 | 只徐培恩(格 (0,3))一人加底 α0.72,作參照 |

狀態:①總覽無游標(先把合成滑鼠移到視窗外,使滑鼠權威且格出界,log 物證 `PRE-OVERVIEW cursor_active=false` 與每張 HOST 行 `cursor_active=false`);②游標停徐培恩(log `CURSOR (0, 3) ...`,960 若滑鼠沒到位會改 `CursorStateHost.set_target`,仍失敗檔名帶 `_CURSOR_FAILED`)。解析度 960×540、1920×1080。

## 做法
- `load()` 真實 `BattleScreen.tscn` 並注入 vs01 真實資料路徑(第 5 點);log 的 `HOST [...]` 行為宿主鏈物證(`WorldViewportContainer`/`WorldViewport.size`)。
- 進樹後在 `BoardView._piece_label_layer`(首字 Label 的同一父節點)內,對每個可見首字 Label 於其正前方(=繪製在其下)插入 ColorRect。矩形呼叫 `BoardView.piece_label_rect_in_cell()` 取得,未自算座標;由 Label 位置只反推「是哪一格」。log `BACKDROP` 行列出每塊的 pos/size/節點索引。
- 變體切換只改 alpha/visible,後等 3 幀再拍。

## 如實揭露
- 這是**驅動疊上去的模擬**,不是正式實作。正式實作的圖層順序(規格寫「Label 之下、棋子貼圖之上,StatsLayer 同層或其下均可」)若與此不同會有差異:本驅動襯底與 Label 同在 `PieceLabelLayer`(該層位於 `_stats_layer` 之上),所以**襯底會蓋住 HP 文字條/被擋章以外、位於同一層之下的所有東西**,包含 StatsLayer 內與首字框重疊的元素(首字框 y8~22 與 HP 文字條 y0~8、血條 y26~ 不相交,規格亦如此);但若將來襯底放 StatsLayer 之下,可能被 StatsLayer 內容蓋住,外觀會略有不同。
- 敵方判斷用「首字文字為整數」(敵方為 1~5 數字編號,我方為漢字);徐培恩判斷用格 (0,3)(vs01_roster id2 乙,`character.name.2`=徐培恩)。
- 游標在狀態②重繪後襯底會被重插(驅動先清舊的再插新的);log 的 BACKDROP 行會出現兩輪。
- 本驅動只在 headless 驗過流程:`get_image()` 為 null 屬預期,**像素內容尚未人眼驗證**,須開窗後人看圖(Check 5)。
- log 的 16 行 `ERROR: Parameter "t" is null.` 是 headless 取像的既有雜訊(與午休截圖驅動相同,每次取像一行)。

## headless 試跑(`run_output_headless.txt`)
`ENGINE EXIT=0`;`TOTAL shots=16`;16 次 `get_image() is null`;ERROR 僅上述 16 行,無 SCRIPT ERROR、無 WATCHDOG。
