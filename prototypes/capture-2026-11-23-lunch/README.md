# capture-2026-11-23-lunch 午休截圖驅動(拋棄式)

狀態:in-progress(headless 已驗證 16 態皆走到截圖前一步,exit 0;開窗截圖尚未執行)
範本:`prototypes/capture-2026-11-20-lunch/`(含 11-20 修正:游標用 `CursorStateHost.set_target`、手牌展開等 0.5s)。範本檔未動。

## 假說
真實 `res://src/ui/battle/BattleScreen.tscn` + vs02 五個真實資料檔(override),可拍到 6 個舊態 + 2 個新態(story-030 四種縮圖形狀;story-029 長牌面)x 960x540、1920x1080 = 16 張。

## 開窗指令(僅午休 12:00~13:00;預估 約 40~80 秒,16 張,行程自行 quit)
```
cd C:/Users/felixfu007/Documents/Claude-Code-Game-Studios
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . res://prototypes/capture-2026-11-23-lunch/capture_driver.tscn --audio-driver Dummy
```
- 前提:`.godot` 類別快取須是新的。本次 headless 第一次跑因快取舊報 `SupportConversationBufferedWritePort` 找不到,先跑 `--headless --import` 後正常。開窗前若有新 class_name 進來,先跑一次 import。
- headless 實測 16 態約 16 秒(含 0.5s 等待 x16);開窗含存 PNG,估 40~80 秒(估算,未驗證)。
- 載入順序:`instantiate()` -> 設 5 個 override(terrain/roster/affinity/cards/card_text = vs02)-> `get_tree().root.call_deferred("add_child")` -> 等 2 幀(「第 5 點」)。
- 開窗後每張檢查 HOSTCHAIN 的 `window=` 是否等於目標尺寸;不等該張作廢。

## 圖檔對照(`out/<態>_<寬>x<高>.png`)
態 1~6 同 11-20 範本(確認面板 / 關係圖詳情 / 資訊卡關係 / 騎牆 / 手牌不可打原因 / card_22 長牌面)。新增:

| 態 | 畫面 | 注入內容 |
|---|---|---|
| 7_hand_collapsed_four_shapes | 手牌**收合**,Z1 縮圖並排 | 5 張 vs02 真實卡,見下表 |
| 8_hand_expanded_four_shapes | 同態 7 但**展開**,游標在 card_22(Z3 長牌面,story-029) | 同上;headless 讀回 Z3 文字 `董振豪×秦亦柔\|交叉火力\|董振豪與秦亦柔各對同一敵人造成 6 點固定傷害；須兩人都打得到` |

### 手牌卡類別/形狀(headless 逐張印出,960 與 1920 皆同)
| 卡 id | Card.Category | SlotKind | IconShape |
|---|---|---|---|
| card_15 | TEMPORARY_STAT_MODIFIER(加成) | TEMPORARY_MODIFIER | SQUARE 正方 |
| card_07 | PERMANENT_AFFINITY_WRITE(改關係) | PERMANENT_WRITE | DIAMOND 菱形 |
| card_11 | DIRECT_DAMAGE(直傷) | DAMAGE | TRIANGLE 三角 |
| card_22 | COMBO_DAMAGE(合擊) | DAMAGE | TRIANGLE 三角(與直傷共形) |
| card_14 | HEAL(補血) | HEAL | CROSS 十字 |

手牌順序每次不同(牌組洗牌),所以圖上要用形狀指認而非位置;log 內每態有該次實際順序。

## headless 實測(`run_output_headless.txt`,16 行 HOSTCHAIN + DONE,exit 0)
- 960x540:`WVC.size=(960,540) stretch_shrink=2 WV.size=(480,270)`;1920x1080:`size=(1920,1080) stretch_shrink=4 WV.size=(480,270)`。
- 16 態 `window=` 皆等於目標。log 無 `unmapped Card.Category`(story-030 AC3 在此驅動的路徑上成立)。
- 結尾 `ObjectDB instances were leaked` / `resources still in use at exit` 為 headless 退出警告(驅動 `quit()` 時節點仍在),屬拋棄式驅動,未深究。

## 哪些是注入的、不是真實開局
- 態 7/8 的牌組是 `CardDeck.new([5 張])` + `CardPlaySession` 注入,**不是**真實開局洗牌結果;卡本身是 vs02 真實卡 id 與真實牌面文字。
- 態 5/6 沿用範本:含驅動自造 HP 卡 `cap_hp` 與受傷付費者。態 2/3 以 `_affinity_pool.append_record` 注入好感紀錄。
- 態 7/8 **沒有**「暗化(不可打)」那張(story-030 AC4 要求手牌含四種 + 一張暗化)。態 5 的手牌展開含不可打卡,但不含四形。若要暗化+四形同張圖,需另加態(未做)。

## 截圖分類(依 coding-standards.md)
- 全部為全視窗尺寸 -> 非 C。AC4 要求的是手牌列局部圖(C);本驅動拍全窗,要 C 級需事後以 `HandBar.slot_bar_rect()` 之類真實矩形函式裁切(未做)。
- 態 7:**A**(全戰場畫面,手牌列為疊在上方的介面,無 rect 函式證明 <50% 的遮罩)。
- 態 8:**A**(展開手牌疊在世界層上,同態 2~6 判斷)。
- 態 1:同範本,是否 B 需 `CardConfirmPanel.panel_rect()` 面積 < 50%,**未驗證**。
- Check 4:世界層無縮放節點 -> 寫「沒有可測對象(N/A)」,不得寫通過。Check 5 人眼(art-director 指認四形)必做。
- headless 取不到像素,PNG 內容與十字/正方在 N=2 能否分辨**未驗證**。
