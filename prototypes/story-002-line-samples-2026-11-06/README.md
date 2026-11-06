# story-002 好感度連線樣張驅動腳本(2026-11-06)

**狀態:in-progress(腳本已寫成,只做過 headless 結構驗證;尚未開窗實拍,沒有任何圖檔)。**

## 要驗證什麼

`design/ux/affinity-line-display.md` 第 5 節樣張 A、C、D、E 的畫面是否達成美術兩份回答(`docs/reviews/polarity-line-art-answers-2026-11-06.md`、`...-answers-2-2026-11-06.md`)的判讀目標。參數(鋸齒振幅 ±2、半週期 4、牌 7×7 等)全是未驗證初值,**樣張由 `art-director` 看過才算定案**。

## 🔴 只准在私人時間、家裡開窗跑

本資料夾在上班時段只做過 `--headless` 驗證。**不要在辦公室螢幕上不帶 `--headless` 執行。** headless 下腳本會印出結構 log,然後明確拒絕寫圖並以 **exit 2** 結束。

## 怎麼跑(在家,一行)

```bash
GODOT_BIN="<你家的 Godot_v4.7.1 路徑>"
timeout 600 "$GODOT_BIN" --path . prototypes/story-002-line-samples-2026-11-06/SamplesDriver.tscn > prototypes/story-002-line-samples-2026-11-06/run_output_windowed.txt 2>&1; echo EXIT=$?
```

- 只跑部分:在命令尾端加 `-- --only=A_solid,E_minimap`(可用名稱見下表)。
- 預期 exit 0;任何一張驗證失敗 exit 1(該張不寫檔);headless/取不到像素 exit 2。
- 跑完 `tasklist | grep -i godot` 確認無殘留行程(腳本會呼叫 `quit()`,命令帶 `timeout` 作保險)。
- 🔴 **3840×2160 要求螢幕實際放得下該視窗**;放不下時作業系統會夾小視窗,腳本的「尺寸等於請求值」檢查會拒絕並 log 原因,**不會寫出尺寸錯的圖**。若在小螢幕上只想拍前兩種尺寸,可略過 E 的 4K 那張(目前沒有逐尺寸旗標,失敗只影響該張)。

## 會產生什麼

輸出在 `prototypes/story-002-line-samples-2026-11-06/out/`,檔名 `sample-<名稱>-<寬>x<高>.png`,標 `gray` 者另有 `-gray.png`(`Image.FORMAT_L8` 灰階)。

| 名稱 | 樣張 | 內容 | 視窗尺寸 | 灰階 |
|---|---|---|---|---|
| `A_solid` | A | 好感關係(實線),從同一中心單位 1 出發:水平、垂直、45°(格差 (3,3))、約 26.6°(格差 (2,1)) | 960×540、1920×1080 | 有 |
| `A_zigzag` | A | 同樣站位,惡感關係(鋸齒) | 同上 | 有 |
| `C_overlay` | C | 選定單位 2:移動區、威脅區、攻擊區高亮出現;線穿過單位 4(棋子) | 1920×1080 | 無 |
| `D_same_sign` | D | 兩線中點同點、同號(兩個 −)→ 只應有一塊牌 | 960×540、1920×1080 | 有 |
| `D_opposite_sign` | D | 兩線中點同點、一正一負 → 兩塊牌並排,`+` 在左 `−` 在右 | 同上 | 有 |
| `D_covered_by_piece_hp` | D | 垂直相鄰兩單位,游標在下方單位,顯示 HP 文字、棋子疊在牌邊 | 1920×1080 | 有 |
| `E_minimap` | E | 關係圖開啟,6 條關係含 2 條效果 0(只有線、無牌) | 960×540、1920×1080、3840×2160(N=2/4/8) | 無 |

## 每張要給 art-director 看什麼

取自兩份美術回答的判讀問題:

- **A**:45° 與 26.6° 斜線上,鋸齒是否糊成「一條稍粗略歪的實線」?(是 → 先加振幅/半週期,不要先加粗線寬。)灰階版:僅憑形狀能不能分出實線與鋸齒?
- **A/D 牌**:7×7 牌是否偏心?線進入牌的位置是否偏離中央一格?(是 → 取整規則改 `mid − (4,4)`。)
- **C**:鋸齒線穿過移動藍區、攻擊紅區、不透明棋子時的可讀性與吵度;底襯跟折線是否好讀。牌被半透明高亮染色後符號是否還看得清(看不清 → 才考慮升級為另開圖層,需請示)。
- **D**:同點同號只畫一塊、一正一負左正右負是否一眼分得出;牌被棋子或 HP 文字蓋住的程度是否可接受(美術回答:HP 優先、可接受);灰階版仍能分辨「好感/惡感 × 加成/懲罰」四種組合嗎(AC-P6)?
- **E**:關係圖鋸齒與棋盤是否同語彙;N=2/4/8 下牌與鋸齒大小是否合理;**效果 0 的淡色線(節點色 α0.6)是否讓管理者覺得「髒」或像節點延伸**(美術明講要由管理者本人看,不代判);舊虛線是否確實消失。

## 沒做的樣張與原因

- **B(色盲模擬)**:需要色彩轉換工具。做法:拿 `A_solid`/`A_zigzag` 的 PNG 丟進任一色覺模擬工具(紅綠色盲兩型 + 藍黃型),把結果附給 art-director。本專案目前沒有色盲模式,模擬只是看現行色值夠不夠分。
- **F(舊虛線對照)**:舊虛線畫法已刪,需要檢出舊版 `relation_minimap.gd`(story-002 第二段提交 `8bcbcea` 之前的版本)在拋棄式工作樹開窗實拍,再與 `E_minimap` 在 N=4 局部裁切並列。**本腳本不做。**
- 共線兩對線段像素重疊(誰在上)是美術標為「設計決定」的未決點,沒有合成局面。

## 規則遵守紀錄

- 載入真實 `res://src/ui/battle/BattleScreen.tscn`,順序 `instantiate()` → 設 `terrain_path_override`/`roster_path_override`/`affinity_path_override` → `call_deferred("add_child")` 到 root → 等 2 幀再多等 12 幀。沒有 `set_script()`、沒有替身節點鏈。
- 夾具:`fixtures/terrain_open.txt`(13×6)與各 `roster_*.txt`/`links_*.txt`。🔴 玩家 id 只能是 1~5(`AffinityRosterCharacterMapper` 限制,6~10 是敵人),所以 A 用「中心單位 1 輻射 4 條線」而非 4 對獨立的線。每張 log 印 `COMPAT` 行(單位起點在地形範圍內、不重疊、連線 id 都在名冊內)。
- 物證:每張 log 印 `EVIDENCE` 行(視窗尺寸、`WorldViewportContainer.position/size/stretch_shrink`、`WorldViewport.size`),由真實 `world_viewport_scaler.gd` 算出。
- 驗證後才寫檔(Category A 檢查 1~3):尺寸等於請求值;12 點取樣 ≥3 色;主色占比 ≤80%(**步距 5 的取樣近似,不是全像素**)。重試 5 次仍不過 → 不寫檔、計一次失敗。**第 5 項(人眼確認)由 art-director 做。**
- 只截遊戲視窗(root Window 的 viewport),不截全螢幕。
- Check 4:世界層目前沒有 `scale != (1,1)` 的節點,每張 log 寫「沒有可測對象(N/A)」,**不是「通過」**。鋸齒是否糊成實線看樣張 A,不靠 Check 4。
- 🔴 `C_overlay` 為 Category A 全窗畫面;`E_minimap` 面板占視窗面積小、但整窗並無「單色遮罩」,依分類測試歸 Category A。

## headless 驗證結果(2026-11-06,上班時段,未開窗)

指令:`"$GODOT_BIN" --headless --path . prototypes/story-002-line-samples-2026-11-06/SamplesDriver.tscn`,全文在 `run_output_headless.txt`。**exit 2**(預期:headless 取不到像素)。關鍵行:

```
COMPAT terrain=13x6 units=6 links=4 compatible=true            (A_solid / A_zigzag)
STRUCT A_solid line2d_nodes=8 zigzag_line2d=0 plaques=4 minimap_lines=4
STRUCT A_zigzag line2d_nodes=8 zigzag_line2d=8 plaques=4 minimap_lines=4
SETUP select_unit(2)=true cursor=(6, 2)
STRUCT C_overlay move_hl=58 threat_hl=46 attack_hl=1
STRUCT D_same_sign line2d_nodes=4 zigzag_line2d=2 plaques=1 minimap_lines=2
STRUCT D_opposite_sign line2d_nodes=4 zigzag_line2d=0 plaques=2 minimap_lines=2
SETUP relation minimap visible=true
STRUCT   minimap 1-2 state=2 shape=0 plaque=false              (E:效果 0 無牌)
STRUCT E_minimap line2d_nodes=8 zigzag_line2d=6 plaques=4 minimap_lines=6
EVIDENCE A_solid WorldViewportContainer.position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2
EVIDENCE A_solid WorldViewport.size=(480, 270)
EVIDENCE A_solid WorldViewportContainer.position=(0.0, 0.0) size=(1920.0, 1080.0) stretch_shrink=4
CAPTURE A_solid (960, 540): get_image() is null -- headless cannot read pixels; no image file written
RESULT: headless / no pixel access -- NO image file was written. Structure log above is the only output.
```

- headless 下 `window.size = ...` 有生效(`window.size`、`stretch_shrink` 隨之由 2 變 4),代表真實縮放鏈在尺寸改變時確實重算。
- headless 每次取像素前引擎印 `ERROR: Parameter "t" is null.`(`get_texture()` 在 dummy 渲染器下的行為),是預期現象,不影響結果。
- `out/` 資料夾不存在、沒有任何 PNG 被寫出。

## 尚未驗證(誠實登記)

- 開窗執行路徑中的 `_validate()`、`save_png()`、灰階轉換、視窗尺寸設定/夾小行為**從未跑過**(headless 走不到)。第一次開窗若有 SCRIPT ERROR,先修腳本再重拍。
- `C_overlay` 的「線穿過棋子」靠站位保證(單位 4 在單位 1、2 連線上),log 只證明高亮節點出現,沒有證明視覺上疊到。
- 主色占比 ≤80% 對這些稀疏局面是否成立未知;若被拒,log 會寫明原因,不會寫假圖。
