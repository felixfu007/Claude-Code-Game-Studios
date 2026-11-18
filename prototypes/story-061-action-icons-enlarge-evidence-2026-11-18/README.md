# story-061 鞋/劍圖示放大(格內右側 + 襯底)開窗證據驅動(2026-11-18)

- 假設:放大到 9×10 / 7×10 並移進格內加襯底後,(1) 角色右半身不被襯底遮得難受;(2) 縱列四人四種狀態可在約 3 秒內答對;
  (3) 圖例「已移動/已攻擊」兩列顯示同一組新圖示。以上都只能人眼判,本目錄只負責產出可看的圖與宿主鏈量測值。
- 狀態:**concluded(2026-11-18)**。開窗兩輪(14:35 舊劍、15:10 劍改亮),`run_output_windowed.txt` / `_r2.txt`。
- 結論:管理者判遮擋可接受、960/1920 皆 3 秒可辨(受測者知情,強度較低);art 判新劍通過;游標停留圖未畫進游標 → 未驗證。全文見 `production/qa/evidence/story-061/README.md`。
- 檔案:`driver.gd`(開窗驅動)、`probe_cursor_outline.gd`(游標白框量測,headless 已跑,log 見下)。

## 指令(開窗,一行;由協調者擇時執行,公司環境須不在最上層、靜音)

```
timeout 150 "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/story-061-action-icons-enlarge-evidence-2026-11-18/driver.gd -- 960x540 1920x1080 > prototypes/story-061-action-icons-enlarge-evidence-2026-11-18/run_output_windowed.txt 2>&1
```

## 預期輸出(開窗)

- `DISPLAY_SERVER=` 非 headless。
- 每個尺寸一行 `HOST [WxH] root.size=... WVC position=... size=... stretch_shrink=... WorldViewport.size=(480, 270)`
  (**這行是 (A) 級物證:這些值由真實 `world_viewport_scaler.gd` 算出;沒有這行,證據降為 (C)**)。
- 5 行 `SHOT closeup_char{0..4}_WxH.png`、1 行 `SHOT column_WxH.png`、
  2 行 `LEGEND-ROW`(已移動/已攻擊的圖示外框全域座標)+ 對應 `SHOT legend_kind*_WxH.png`、1 行 `SHOT legend_full_WxH.png`;
  每行 `save=0`(OK)。截圖在 `out/`,人眼確認後搬進 `production/qa/evidence/story-061/`。
- headless 下:各 `SHOT` 行為 `get_image() null`(正常,dummy rendering driver 限制),腳本仍跑到 `quit()`。

## 截圖判讀須知

- 類別:全視窗 -> Category A;裁切圖(特寫/縱列/圖例列)依 coding-standards 規則屬 Category C,不用盲取樣。
- Check 4:圖示/襯底為原生貼圖、無縮放 -> 寫「沒有可測對象(N/A)」,不得寫「通過」。
- Check 5:人開圖。五位各記「襯底遮右半身:可接受/難受」;任一位難受 -> 啟動 art 退路(襯底縮成只包圖示,須管理者重新確認)。
- 結論強度:受測者只有管理者本人且知道此設計,紀錄須寫「結論強度較低」;story-054 AC8 盲測併入此處。
- 另有一態「我方格游標停留」:`closeup_char0_cursor_hover_WxH.png`(兩者皆做 + 游標停在該格),供人眼確認游標 15% 白罩是否讓襯底/圖示泛白。
- 特寫裁切與棋子標籤字(`甲乙丙丁戊`)是驅動注入的假資料。
- 角色對應(**讀碼推得,未跑引擎驗證**):`battle_screen.gd` 以 `sprite_index = clampi(unit.id - 1, 0, 4)` 傳入;
  `assets/data/units/vs01_roster.txt` 的 id 1~5 = 甲乙丙丁戊;`assets/data/locales/strings.csv` 的 `character.name.1~5` =
  藍亭萱、徐培恩、董振豪、秦亦柔、麥子健。故 sprite_index 0~4 = char0 藍亭萱、char1 徐培恩、char2 董振豪、char3 秦亦柔、char4 麥子健
  (前提:id→姓名鍵與 sprite 序用同一個 id,未交叉查證 `Loc` 的使用端)。
- 游標白框量測:`probe_cursor_outline.gd`,log `C:/tmp/cursor_061.log` 重跑可得:白框 1px 不透明白(x=0 與 x=31),內部整格 alpha 0x26 白罩。
