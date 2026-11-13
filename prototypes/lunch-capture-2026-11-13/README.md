# lunch-capture-2026-11-13

**目的**:午休開窗實機截圖,驗 story-044(高亮層級)、story-045(提示列五態)、story-041(血量數字/首字)。
**狀態**:in-progress(headless 流程已驗;開窗截圖尚未執行)。

## 開窗指令(一行;靜音、標題 x、150 秒保險)

先確認已匯入過(新 clone / 缺 `.ctex` 才需要):
`"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import`
(匯入會改動 tracked 的 `.import`,拍完 `git checkout -- '*.import'`;專案現已有一批未提交的 `.import` 改動,**先別還原**,改問協調者。)

```
timeout 150 "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/lunch-capture-2026-11-13/driver.gd > prototypes/lunch-capture-2026-11-13/run_output_windowed.txt 2>&1; echo ENGINE EXIT=$?
```

- 預設依序跑 1920x1080 -> 960x540 -> 1366x768(同一行程內切 `root.size`)。只跑指定尺寸:指令尾端加 `-- 1920x1080 960x540`(`--` 後為使用者參數)。
- `--resolution WxH` 也可加在引擎參數上設初始視窗;驅動自己會 `root.size=` 切換,log 的 `=== RESOLUTION requested=... actual root.size=... ===` 看實際值(螢幕太小會被截)。
- 內建 WATCHDOG 150 秒自動 `quit(2)`(log 有 `WATCHDOG fired`);`timeout 150` 是外層保險。**不要用 `--title x`(空格)**,會卡死。
- 截圖讀 `root.get_texture().get_image()`(只取遊戲視窗,不截桌面);輸入全是合成事件,不碰真滑鼠。
- 預估開窗秒數:每解析度 13 張、每張約 1 秒 + 6 次場景建立 + 敵方回合/戰敗等待,約 **25~35 秒/解析度,三個解析度合計約 75~110 秒**。
- 輸出 `out/NN_<寬>x<高>_<s044|s045|s041>_<狀態>.png`,共 39 張。log 的 `HOST [..]` 為第 5 點宿主物證,`STATE [..]` 為狀態物證。

## 每解析度 13 張

| tag | 狀態 | 要看什麼 |
|---|---|---|
| s044 | `unit_selected_attackable_and_los_blocked` | 選丙(4,3):E1(4,0) 可攻擊、E3(8,3) 視線被擋縮角章 |
| s044 | `cursor_on_los_blocked_enemy` / `cursor_on_attackable_enemy` | 游標分別停兩者 |
| s044 | `card_selecting_target` | 攻擊標記應隱藏、不可達標記補畫、琥珀括弧(檔名帶 `_NOT_REACHED` 表示沒進入選目標) |
| s045 | `hint_1_no_selection` / `hint_2_unit_selected` / `hint_3_hand_open` / `hint_4_enemy_phase` | 提示列四態 |
| s045 | `hint_5_finished_victory` / `hint_5_finished_defeat` | 結束態,提示列應為空(物證 `hint_text=''`) |
| s041 | `lowhp_overview_no_cursor` / `lowhp_cursor_on_player_unit2` / `lowhp_cursor_on_enemy_E3` | 乙 6/26、E3 3/18(注入 `take_damage`,不改資料檔) |

## 如實揭露
- 044 用**合成名冊** `fixture_roster_044.txt`(vs01 只改三列座標:丙、E1、E3)搭真實 vs01 地形;`test_fixture_terrain_los.txt` 只有 5x3,而 BattleScreen 要 13x6,故不用。真實 vs01 起手站位構不成「可攻擊+被擋」並存,未用引擎窮舉驗證。
- 勝/敗用 `test_fixture_*_duel/_doomed`(5x3 地形),log 會有 `Board.from_ascii` 與 `piece_label_text ... not E<number>` 的既有夾具雜訊 ERROR,棋盤畫面可能怪,只看提示列。這些 ERROR 不是新問題。
- 選牌:`battle_open_hand` + `battle_confirm` 選第一張牌;headless 實測進入 `card_selecting_target=true`(提示「請選擇目標」)。哪張牌、合法目標集合沒逐一核對。
- 游標:先合成滑鼠移動,不到位改 `CursorStateHost.set_target`;仍不到位檔名加 `_CURSOR_FAILED`。headless 全部由滑鼠移動到位,960 開窗是否需要 set_target 看 log 的 `CURSOR` 行。
- 提示列裝置字樣(滑鼠)取決於合成滑鼠事件,gamepad/鍵盤字樣未拍。

## headless 試跑(`run_output_headless.txt`)
`ENGINE EXIT = 0`;`TOTAL shots=39 states_done=39`;39 次 `get_image() is null` 為預期。87 行 ERROR 全屬既有雜訊(`Parameter "t" is null` 39 = 每張 headless 取像、夾具 from_ascii/piece_label 各 6/24),無 SCRIPT ERROR、無 WATCHDOG。
