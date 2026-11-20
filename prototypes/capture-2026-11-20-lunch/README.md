# capture-2026-11-20-lunch 午休截圖驅動(拋棄式)

狀態:in-progress(headless 已驗證每態走到截圖前一步;開窗截圖尚未執行)

## 假說
真實 `res://src/ui/battle/BattleScreen.tscn` + vs02 四個真實資料檔(override),可走到管理者要看的 6 種畫面 x 2 解析度(960x540、1920x1080)= 12 張。

## 開窗指令(協調者午休 12:00 後跑;預估約 30~60 秒,12 張,行程自行 quit)
```
cd C:/Users/felixfu007/Documents/Claude-Code-Game-Studios
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . res://prototypes/capture-2026-11-20-lunch/capture_driver.tscn --audio-driver Dummy
```
headless 版(已跑):加 `--headless`,存為 `run_output_headless.txt`。
載入順序:`instantiate()` -> 設 5 個 override(terrain/roster/affinity/cards/card_text = vs02)-> `get_tree().root.call_deferred("add_child")` -> 等 2 幀。主場景啟動(非 `-s`,理由同 020a)。
開窗後每張檢查 HOSTCHAIN 的 `window=` 是否等於目標尺寸;不等該張作廢。

## 圖檔對照(`out/<態>_<寬>x<高>.png`)
| 態 | 畫面 | 備註 |
|---|---|---|
| 1_confirm_panel | 出牌確認面板,單人付血 2 的卡 | 看 960 / 1920 面板內容有無截斷 |
| 2_relation_map_detail | 關係圖開啟 + 詳情浮出卡 | 寫入好感紀錄湊出 **11 列**(10 組 + 麥子健騎牆列)。headless 的 `diagnostic_relation_detail_rows().size()`=11 |
| 3_infocard_relation | 選取藍亭萱、游標停徐培恩(id 2)格 | 資訊卡關係行,headless 讀回 `與藍亭萱：好感` |
| 4_infocard_straddle | 游標停麥子健(id 5)格 | headless 讀回 `騎牆：有效` |
| 5_hand_unplayable_reason | 手牌展開,游標在「藍亭萱血量不足」卡 | 該卡為驅動自造 HP 卡(vs02 無法保證出現不可打卡);原因行 headless 讀回 `藍亭萱血量不足` |
| 6_hand_card22_long_face | 手牌展開,游標在 vs02 真實 card_22【交叉火力】 | 牌面文字來自 vs02_card_text;原因行 headless 讀回 `射程內沒有敵人`(本身也是不可打) |

## headless 實測 HOSTCHAIN(原始輸出 `run_output_headless.txt`,12 行 + `DONE`,exit 0)
- 960x540:`WVC.pos=(0,0) size=(960,540) stretch_shrink=2 WV.size=(480,270)`
- 1920x1080:`WVC.pos=(0,0) size=(1920,1080) stretch_shrink=4 WV.size=(480,270)`
- 12 態皆 `window=` 等於目標;態 1 `confirming=true`;態 2 `minimap_visible=true`。

## 做不到 / 限制
- 無「做不到」的態;但 card_22 在手牌用的是 `CardDeck.new([自造HP卡, card_22])` 的 2 張牌組,**不是**遊戲真實開局洗牌結果(牌組內容為驅動所設)。
- 好感紀錄用 `_affinity_pool.append_record` 寫入以湊多列,屬注入的情境,非 vs02 真實開場數值。
- 61 行 `ERROR: hand_bar_slot_kind_for: unmapped Card.Category 3/4`(COMBO_DAMAGE 等類別 Z1 形狀未對映)出現在 headless log,**未驗證**是否為已知待辦或實際缺陷;驅動不受影響(屬 src/,依指示未動)。
- headless 無像素(`get_image()` 為 null),故 PNG 內容與版面溢出情況**未驗證**,需開窗人眼確認(Check 5)。

## 截圖分類(依 coding-standards.md)
- 全部為全視窗尺寸 -> 非 C。
- 態 1:依 020a 先例,`CardConfirmPanel.panel_rect()` 面積 < 50% 視窗才是 **B**,否則 A;本驅動未印 panel_rect,**未驗證**,協調者需自行判。
- 態 2~6:**A**(整個戰場畫面;態 2 的關係圖浮層與手牌展開都是疊在世界層上,未達 B 的 rect 函式判準)。
- Check 4 世界層:世界層內容無縮放節點時寫 N/A,不得寫通過(未量測)。Check 5 人眼為必做。
