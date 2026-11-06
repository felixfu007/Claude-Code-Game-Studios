# 教學關 S4 好感度連線顯示檢查(2026-11-06)

> 作者:game-designer。性質:**人工推算,未經引擎執行**(我沒有 Bash、不能跑引擎)。
> 因此本檔所有數字**不是 (A) 級**,最高只能算 (B)/(C):規則是我讀原始碼抄來的,不是引擎替我算的。
> 對應規格:`design/ux/affinity-line-display.md` 第 6 節兩件待辦。

## 1. 教學關各段開場有沒有線

### 1.1 教學關實際使用的檔案(來源:`assets/data/levels/tutorial_sequence.txt`)

| 段 | 地形 | 名冊 | 好感度連線表 |
|---|---|---|---|
| S1 | `tut01_terrain.txt` | `tut01_roster.txt` | `tutorial_no_links.txt`(零條) |
| S2 | `tut02_terrain.txt` | `tut02_roster.txt` | `tutorial_no_links.txt`(零條) |
| S3 | `tut03_terrain.txt` | `tut03_roster.txt` | `tutorial_no_links.txt`(零條) |
| S4 | `tut04_terrain.txt` | `tut04_roster.txt` | `tut04_affinity_links.txt`(一條) |

序列檔只有這 4 列;`tutorial-level.md` 的 S5 小考與 S6 尚未做(該檔第 8 節 Q3),所以**S4 之後沒有任何有連線的段落**。

### 1.2 我採用的規則(逐條可核對)

| # | 規則 | 來源檔 + 符號 |
|---|---|---|
| R-a | 距離 = 曼哈頓距離 `abs(dx)+abs(dy)` | `src/gameplay/affinity/affinity_rules.gd` 的 `AffinityRules.manhattan_distance()` |
| R-b | 整盤的線 = 連線表中兩端都在棋盤上的每一條 | 同檔 `AffinityRules.board_lines()` |
| R-c | 正向線:距離 1 → delta = `delta_positive_adjacent`;距離 2 → `delta_neutral`;距離 ≥3 → `delta_positive_far`,再乘 `amp` | 同檔 `AffinityRules.delta()`,門檻常數 `DISTANCE_ADJACENT=1`、`DISTANCE_FAR=3` |
| R-d | 數值:`delta_positive_adjacent=3`、`delta_positive_far=-1`、`delta_negative_adjacent=-1`、`delta_negative_far=2`、`delta_neutral=0` | `assets/data/tuning/tuning_knobs.txt` 的 `affinity,*` 各列(與 `affinity_rules.gd` 預設常數一致) |
| R-e | 效果:delta>0 加成、<0 懲罰、=0 無(棋盤不畫線) | 規格 `design/ux/affinity-line-display.md` R2、R3(**我沒有逐行讀 `AffinityLineStatus.state` 的判定程式**,delta 與 state 的對應是照規格推的,未驗證) |
| R-f | 連線表檔案格式 `unit_a,unit_b,polarity,amp` | `assets/data/affinity/tut04_affinity_links.txt` 檔頭 |

刻意未計入:地形、視線、單位是否被擊倒(`board_lines` 以「在 positions 裡」為準;開場全員存活)。

### 1.3 逐段結果

**S1、S2、S3:連線表是 `tutorial_no_links.txt`(只有註解、零條連線)。**
→ 「開場棋盤上零條線」成立,但**原因是資料裡根本沒有關係,不是距離落在 2**。
(S3 名冊有甲(0,2)、丙(0,4),距離 2,但沒有連線所以不相關。)
我**沒有讀 `tut01_roster.txt`、`tut02_roster.txt`**,結論只依賴「連線表為零條」這一點。零條表被解析成零條線,是檔頭註解與 `board_lines()` 迴圈的合理推論,未實際跑過(人工推算,未經引擎執行)。

**S4:有一條線,開場看得到。**
連線表唯一一列:`1,2,POSITIVE,1`(甲、乙,正向,amp 1)。
名冊起點(`tut04_roster.txt`):甲 id1 在 (0,2),乙 id2 在 (0,3)。

| 配對 | 距離(人工推算,未經引擎執行) | delta(人工推算,未經引擎執行) | 效果 | 棋盤是否畫線 |
|---|---|---|---|---|
| 甲(0,2)–乙(0,3) | |0-0|+|3-2| = **1** | 距離 1 → +3 × 1 = **+3** | 加成 | **畫**:實線、綠、中點「+」符號牌 |

**S4 開場結論:棋盤上有 1 條線(綠色實線 + 「+」牌),不是零條線。**
`tut04_roster.txt` 檔頭也寫「甲乙開局就上下相鄰」,與推算一致。

**S4 玩家動手之後(連動預覽用,同樣是人工推算)**:甲乙距離 2 → 線消失(R3);距離 ≥3 → delta -1,變成**紅色實線 + 「−」牌**。
也就是 S4 玩家**自己拆開兩人**時,會依序看到:綠+ → 無線 → 紅−。

### 1.4 與規格第 6 節「未驗證」那句的對照

規格寫「教學關出生佈陣是否落在距離 2(若是,S4 開場會看不到線)」。**答案:不是,S4 開場距離為 1,看得到線。**

### 1.5 一個會影響提示設計的事實

S4 **只有一條正向線,沒有負向線**(`tut04_affinity_links.txt` 檔頭明寫刻意不放丙丁)。
所以 S4 玩家**看不到「鋸齒線」**,「線有兩種樣子」這個指認在 S4 **指認不到**。S4 看得到的只有:一種線形(實線)、顏色與符號會隨距離變(綠+、紅−)。

## 2. S4 教學提示措辭候選

### 2.1 現況

`assets/data/locales/strings.csv` 以 tut/tutorial/hint/教學/提示 搜尋,只命中兩列:
- `battle.hud.controls_hint`(操作說明,與 S4 無關)
- `shell.title.skip_tutorial`,「略過教學」

**S4 的教學提示文字目前不存在,沒有現行鍵可換。**`tut04_roster.txt` 檔頭也寫「不放提示文字(管理者 2026-10-28 裁決)」。
所以下面是**新增**;若要新增,鍵名由實作者定(我不替它命名,免得被當成既有鍵)。另 `tutorial-level.md` N2(腳本化提示文字)是「需新功能」,是否做仍是 Q1 的裁決題。

### 2.2 候選句(不講因果、棋盤上不寫好感/惡感、只做指認)

| 候選 | 文字 | 優點 | 缺點 |
|---|---|---|---|
| A | 「兩名夥伴之間出現了一條連線。留意線的顏色,以及線中央的符號。」 | 純指認,不叫玩家做事,也不給方向;S4 開場看得到的東西(綠線、「+」牌)全都指得到;「夥伴」用詞與 SC-01 一致 | 沒有叫玩家動手,驗收第 4 條(玩家主動移動至少 1 次)要靠地形自然誘發 |
| B | 「連線的顏色與符號,會隨兩人的位置改變。」 | 指認「會變」這件事,促使玩家自己試 | 「隨位置改變」已經很接近因果(位置→線),可能削弱第 1 場探針;不建議 |
| C | 「線中央的符號有「+」與「−」兩種。」 | 最短、最中性 | S4 開場只看得到「+」,「−」要玩家拆開兩人才出現,開場指認不到;且與 S4 沒有負向線的設計不搭 |

**推薦 A。**理由:它是三句裡唯一不暗示因果、又全部指認得到的。
我刻意**沒有**用「線有兩種樣子」,因為 §1.5:S4 沒有鋸齒線。

## 3. 與新畫法的其他衝突(只列出,不裁決)

1. **S4 開場就看到「綠實線 + `+` 牌」本身就把「兩人站得近=好」畫出來了。**
   `tutorial-level.md` 驗收第 5 條(污染檢查:不得有人說出完整歸因)與 Q2 的切線(「只讓 Φ 數字自然出現,不刻意安排」)是在舊畫法(只有數字)下訂的;
   新畫法在 S4 多了一個玩家看得見的關係通道。新畫法是否仍符合 Q2 的原意,需要管理者看。
2. **`vertical-slice-level-01.md` 驗收第 3 條(自發歸因,第 202 行)**:規格第 6 節已保留並併入第 4 階段、標準屆時重訂。
   補充一點事實:該條判準是「玩家說出『因為感情好/不好』」,而新畫法 S4 只出現正向線,**第 1 場才是玩家第一次看到惡感(鋸齒)線**(`tutorial-level.md` 第 4 節:負向由第 1 場示範)。
   所以鋸齒線的「第一次見面」落在第 1 場,不在教學關,與探針位置重疊。
3. **介面上已有含「好感度」字樣的字串**,在教學關 S4 會不會顯示,我沒有查證(未驗證):
   `battle.hud.affinity_preview_format`「好感度 %+d→%+d」、`battle.hud.affinity_current_format`「好感度 %+d」、`battle.card_confirm.strength_label_format`「好感度：%s」、`battle.hud.relation_map_toggle`「關係圖 [R]」。
   規格 R7 說關係圖詳情區會寫「好感/惡感」文字。若 S4 玩家能按 R 開關係圖,則「教學提示不寫好感/惡感」的限制,在畫面上等於被別處的字破功。
   `tutorial-level.md` 第 8 節加註寫預覽框 Φ 欄只顯示符號「Φ」,但上面 `affinity_current_format` 等是另一組字串,誰在 S4 顯示未驗證。
4. **`shell.settings.hide_affinity_toggle`「隱藏好感度顯示」**:玩家若關掉,S4 連線是否一併隱藏,以及教學提示是否仍要出現,規格沒寫(未驗證)。

## 4. 未驗證項彙總

- 全部距離與 delta 為人工推算,未經引擎執行。
- `tut01_roster.txt`、`tut02_roster.txt` 未讀。
- 零條連線表被解析成零條線,是推論。
- `AffinityLineStatus.state` 的判定程式未讀。
- 第 3 節各字串在 S4 是否實際顯示,未查。
