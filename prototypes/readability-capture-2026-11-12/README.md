# readability-capture-2026-11-12

**假設/目的**:用真實 `BattleScreen.tscn` 開窗拍一組截圖,實機確認或推翻
`docs/reviews/screen-readability-audit-2026-11-11.md` 的推論(專家兩位都沒看過實機畫面)。
**狀態**:in-progress(headless 流程已驗;開窗截圖尚未執行)。

## 開窗指令(中午在公司執行,一行,靜音、視窗標題為 "x")

先匯入一次(新 clone / 棋子圖 `.ctex` 缺失會刷一大堆 ERROR 且棋子不畫;匯入會改動數個 tracked 的 `.import` 檔,拍完用 `git checkout -- '*.import'` 還原即可):

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

開窗拍攝:

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --audio-driver Dummy --title x --position 0,0 --path . -s res://prototypes/readability-capture-2026-11-12/driver.gd
```

- 解析度由腳本內 `root.size = ...` 依序切 960x540 → 1440x810 → 1920x1080(同一個行程連跑);
  想改:在指令尾端加 `-- 960x540 1920x1080`。log 會印實際 `root.size`(視窗被螢幕截斷時看這行)。
- 截圖讀 `root.get_texture().get_image()`(只拍遊戲視窗自己的畫面,不截整個桌面);輸入用合成事件,**不碰真滑鼠、不 warp**。
- 預期總耗時:約 40~60 秒(30 張,每張 ~1 秒,加敵方回合兩段等待);視窗會閃現一下,結束自動 `quit()`。
- 建議用 `> run_output_windowed.txt 2>&1` 把 log 導出,物證在其中(`HOST [...]` 行)。

## 輸出
`out/`(腳本自動建立)下共 **30 張**:`NN_<寬>x<高>_<狀態>.png`,每個解析度 10 張:

| 狀態 | 檔名片段 | 對應稽核項 |
|---|---|---|
| 戰鬥開場 | `01_open` | A4、B2、B3 |
| 選中丙,顯示移動/攻擊範圍 | `02_selected_ranges` | A2、V1、V5 |
| 游標停在「射程內但被倒木擋視線」的敵兵 E3 | `03_cursor_on_los_blocked_enemy` | A1、V2 |
| 取消選取後游標停在空格 | `04_cursor_on_empty_tile` | A3 |
| 手牌展開 | `05_hand_open` | B5、V2 |
| 戰鬥選單 | `06_battle_menu` | B5、V6 |
| 敵方回合 +15 幀 / +55 幀 | `07_enemy_phase_a` / `_b` | B2 |
| 勝利 | `08_victory` | A4 |
| 戰敗 | `09_defeat` | A4 |

每張截圖前,log 會印 `HOST [狀態] root.size=… WorldViewportContainer position/size/stretch_shrink … WorldViewport.size=…`(第 5 點物證)。

## 資料來源與如實揭露
- 場景:`res://src/ui/battle/BattleScreen.tscn`,走 `instantiate → 設 *_path_override → call_deferred add_child → 等幀`。
- 戰鬥場景:真實 vs01 地形/好感度/卡牌 + **合成名冊** `fixture_roster_los.txt`(vs01 名冊只改兩列:
  丙 (1,3)→(4,3)、E3 (9,4)→(8,3))。**原因**:真實 vs01 起始站位沒有「射程內但被倒木擋視線」的位置
  (倒木在 (5,2)(6,2)(5,3)(6,3);丙起點 (1,3) 射程 6,到最近敵兵 E4 (7,5) 曼哈頓距離 8,走不到;
  我只做了這一段推算,**沒有**用引擎窮舉實際可走位置,所以「真實玩法中完全不會出現」未驗證)。
  結論:03 號截圖是**合成站位**,只證明畫面怎麼標示,不代表第一場開局會遇到。
- 勝/敗:沿用整合測試的合成夾具(`test_fixture_terrain_duel.txt` + `test_fixture_roster_duel.txt` / `_doomed.txt`),
  不傳好感度/卡牌路徑(與 `battle_screen_battle_outcome_test.gd` 相同)。勝利靠合成滑鼠點擊 (0,0)→(1,0) 真實觸發;
  戰敗靠 `_end_faction_phase_pressed()`。⚠️ 該夾具地形是 5×3,而棋盤程式預期 13×6,log 會出現
  `Board.from_ascii: expected 6 rows, got 3` 的 ERROR(既有夾具的已知雜訊,headless 與測試都有);
  **勝/敗截圖的棋盤部分可能畫得怪,只看結果文字與面板。** 戰敗在 `_end_faction_phase_pressed()` 返回前就已 DEFEAT(waited 0 frames)。
- 游標移到 E3:先送合成滑鼠移動;若游標沒跟(滑鼠裝置權威讀真實指標位置),腳本會印 `LOS NOTE ... FORCING` 並直接設 `_cursor_cell`(私有欄位)。headless 下游標有跟上,開窗時看 log 有無 FORCING。
- 選單/手牌用真實輸入動作事件(`battle_menu`、`battle_open_hand`)。

## 找不到/未涵蓋的狀態
- 「戰鬥中可再叫出的勝利條件」、圖例、空格地形資訊卡:現行遊戲沒有這些畫面,截不到(正是稽核要驗的缺口)。
- 已行動變暗(B1):需要先行動完一個單位,本驅動未做;要的話下一版加(選中→移動→結束單位回合)。
- 1366×768 等筆電尺寸、2K/超寬(V10 棋盤外圍底色):未列入;可用 `-- 1366x768 2560x1440 3440x1440` 另跑。
- 敵方回合只抓兩個時間點,不等它結束。

## headless 試跑(ENGINE EXIT = 0;30 次 `get_image()` 為 null 為預期)
指令:`... --headless --audio-driver Dummy --path . -s res://prototypes/readability-capture-2026-11-12/driver.gd`
狀態切換實測(log):選取 `last_click=selected`、游標 `cell=(8, 3) active=true`、手牌 `hand_selecting=true`、
敵方回合 `phase=1`、勝利 `outcome=1`、戰敗 `outcome=2`;三個解析度皆 `root.size` 如要求;`TOTAL shots=30`。
原始輸出最後 20 行(已截 200 字寬):

```
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] from_ascii (res://src/gameplay/board/board.gd:136)
       [1] create (res://src/gameplay/battle/battle_state.gd:236)
       [2] _ready (res://src/ui/battle/battle_screen.gd:1939)
ERROR: Board.from_ascii: row 2 has length 5, expected 13
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] from_ascii (res://src/gameplay/board/board.gd:136)
       [1] create (res://src/gameplay/battle/battle_state.gd:236)
       [2] _ready (res://src/ui/battle/battle_screen.gd:1939)
DEFEAT state (waited 0 frames): phase=2 outcome=2 last_click=
HOST [09_defeat] root.size=(1920, 1080) WorldViewportContainer position=(0.0, 0.0) size=(1920.0, 1080.0) stretch_shrink=4 WorldViewport.size=(480, 270)
ERROR: Parameter "t" is null.
   at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)
   GDScript backtrace (most recent call first):
       [0] _shot (res://prototypes/readability-capture-2026-11-12/driver.gd:56)
       [1] _frames (res://prototypes/readability-capture-2026-11-12/driver.gd:28)
SHOT 29_1920x1080_09_defeat.png -> get_image() is null (expected under headless; skipped)
TOTAL shots=30
```
