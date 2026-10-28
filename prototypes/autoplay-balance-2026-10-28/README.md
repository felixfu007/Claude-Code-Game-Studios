# 自動對戰量測(5 場關卡,2026-10-28)

狀態:concluded(第一版)。管理者 2026-10-28 裁決「做自動對戰量測」。

## 目的
第一版數據:vs01~vs05 打不打得贏、幾回合、誰先倒。

## 怎麼跑
`Godot --headless --path . --import` 一次,再
`Godot --headless --path . -s res://prototypes/autoplay-balance-2026-10-28/autoplay.gd`
原始輸出:`run_output.txt`(引擎 exit 0)。

## 方法
- 讀 `assets/data/levels/campaign_sequence.txt` 的 5 列,載入各場真實 terrain/roster。
- 正式 `BattleState.create` + `TurnOrder.new` + `BattleLoop.run(30)`,敵方一律正式 `GreedyTacticalAI.decide`。
- 我方 A 貪婪:原樣 `GreedyTacticalAI.decide`。我方 B 謹慎(只在本目錄 autoplay.gd):
  1. 候選格 = 原地 + `BattleState.legal_moves(id)`(與 A 同)。
  2. 每格預估威脅 = 對每個存活敵人,若其「原地或 `legal_moves(敵)` 任一格」滿足 `BattleState.is_attack_reachable(敵, 該格, 候選格)`,就加上 `BattleState.preview_damage(敵, 我方單位, 0).damage`(每敵只算一次)。
  3. 排除 威脅 >= 該單位目前 HP 的格;全排除則只留威脅最小的格。
  4. 剩餘格用 A 自己的排序/選目標:`GreedyTacticalAI._attackable_from`、`_distance_to_nearest`、`_is_better_tile`、`_best_target`(src/ai/greedy_tactical_ai.gd,私有靜態函式被直接呼叫,未重寫)。
  - 傷害公式未自寫,全來自 `BattleState.preview_damage`(battle_state.gd)。

## 重新實作的規則(逐條)
- 地形列解析 `_rows()`:複製 `BattleScreen._parse_terrain_rows`(src/ui/battle/battle_screen.gd)的 8 行邏輯(按 \n 拆、去 \r、丟空行)。原因:該函式所在腳本引用 Autoload `CursorStateHost`,`-s` 模式下編譯失敗。非 (A) 級完整宿主鏈,見下。
- 其餘規則零重寫。

## 刻意未計入
- 卡牌(BattleLoop 無牌組)、好感度:`BattleLoop._process_unit` 對 `resolve_attack` 固定傳 phi=0,所以好感度加成在本量測中**從未生效**(未量,結構上為 0);真實遊戲我方有好感度加成,實際會比此數字略好。
- 人類行為:集火、卡位、利用視線/地形、重整隊形、用卡。
- B 的威脅估計忽略:我方單位移動後佔位對敵方 `legal_moves` 的改變;敵方移動順序;友軍擋格。
- 宿主:未載入 BattleScreen.tscn(不跑 UI/Autoload),只跑 BattleLoop 邏輯鏈。不是第 5 點意義下的 (A) 級畫面證據,是邏輯層量測。
- 結果表中「first_down」的括號內是**最後一擊**那行,不一定是唯一傷害來源。

## 結果(原始行見 run_output.txt 第 3~22 行,`grep -n "RESULT" run_output.txt`)
| 場 | 打法 | 結果 | 回合 | 我方攻擊 | 首倒 | 結束時我方 | 結束時敵方傷害 |
|---|---|---|---|---|---|---|---|
| vs01 | A | 敗 | 1 | 0 | 丙 R1 | 4 人 | 無損 |
| vs01 | B | 敗 | 2 | 2 | 甲 R2 | 乙12/26 | E1 -4, E4 -12 |
| vs02 | A | 敗 | 2 | 4 | 甲 R2 | 其餘全滿 | E1 12/36 |
| vs02 | B | 敗 | 3 | 5 | 乙 R3 | 甲11/30 | E1 8/36, E5 -3 |
| vs03 | A | 敗 | 2 | 5 | 乙 R2 | 丙6/22 | E1 -6, E5 21/41 |
| vs03 | B | 敗 | 2 | 2 | 甲 R2 | 乙3/26 | E5 31/41 |
| vs04 | A | 敗 | 1 | 0 | 甲 R1 | 全滿 | 無損 |
| vs04 | B | 敗 | 1 | 0 | 甲 R1 | 全滿 | 無損 |
| vs05 | A | 敗 | 2 | 3 | 丁 R2 | 乙12/26 | E2 21, E4 26, E1 30 |
| vs05 | B | 敗 | 3 | 2 | 甲 R3 | 全滿 | E2 8/28 |
五場兩種打法**全部戰敗,無一勝利、無一達回合上限**。

## 第二版(2026-10-28 下午)

管理者裁決:「改善自動對戰(開好感度、教它集火)再量一次」。腳本 `autoplay_v2.gd`,原始輸出 `run_output_v2.txt`(引擎 exit 0;第一版 `autoplay.gd` / `run_output.txt` 未動)。
跑法同第一版,腳本改 `autoplay_v2.gd`。
status:concluded(第二版)。結論:**改善後仍 5 場 × 全部打法全敗**。

### vs04 B 診斷(實測 + 推論,分開標)
- 實測(拋棄式診斷腳本,輸出已貼於此,腳本已刪):第 1 回合甲被 B 移到 (5,2);B 估該格威脅 = 26 < 甲 HP 30,故判安全。實際敵方 R1:E1 移 (6,2) 打甲 12、E2 移 (7,2) 打甲 7、E3 移 (8,2) 打甲 13,合計 32 ≥ 30,甲死。B 的估計中 E2、E3 對 (5,2) 的 `is_attack_reachable` 皆為空(只算到 E1 12 + E5 14 = 26)。
- 實測:v1 的 `legal_moves(敵)` 回傳 E3 最小可達 x=10、E2 最小 x=7(原位 (11,2)/(10,1))——但實際 E2 走到 (7,2)、E3 走到 (8,2)。
- 推論(**未逐格驗證**):成因是 `legal_moves(敵)` 把「同陣營單位目前佔的格」當阻擋,而敵方是逐個行動、前面的敵人(E1/E5)讓出格子後後面的敵人才能穿過;快照時的可走集合因此低估。第一版「刻意未計入」已列「友軍擋格/敵方移動順序」,此即其後果最大的一例。
- 修正(只用正式查詢):敵方可走集合改用 `BattleState.legal_moves_relaxed(敵, ignore_occupancy=true, false)`。修後 vs04 B 第 1 回合不再死甲,第 2 回合倒乙(5 場 B 皆仍敗)。A 與第一版逐字相同(A 未動)。

### 打法 C(只在 autoplay_v2.gd;B 的安全規則 + 兩條)
自訂規則逐條與其呼叫的正式函式:
1. 安全格:同修正後 B(`legal_moves`、`legal_moves_relaxed`、`is_attack_reachable`、`preview_damage`;威脅 < 當前 HP,全不安全取威脅最小)。
2. 集火:可攻擊目標集合 = 安全格池內各格 `GreedyTacticalAI._attackable_from` 的聯集。優先序:「本回合我方合力可擊倒」(Σ `preview_damage(我方,敵,0)`,對象為任何 `legal_moves`+原地任一格滿足 `is_attack_reachable` 的存活我方單位 ≥ 敵方 HP)優先,其次血量低,其次 id 小。只保留能打到該目標的格。
3. 好感度站位:同等攻擊能力的格中,偏好 `AffinityRules.bonus_for_at(id, 格, positions, links)` 較大者(`links`、`positions` 來自 `AffinityPhiProvider.links()` / `.positions()`)。正負關係判定全在 `AffinityRules`,未自寫。
4. 其餘排序/選格沿用 `GreedyTacticalAI._is_better_tile` / `_distance_to_nearest`。
- 自訂規則的簡化(誠實揭露):擊倒估計未計入「已行動過的我方單位其實不能再打」(會高估)、未計入好感度加成(`preview_damage` 傳 phi=0,會低估)、未計移動後佔位互擋。

### 好感度(phi)狀態
- `grep -n "phi_provider" src/gameplay/battle/battle_loop.gd` 有命中(建構子參數與第 332 行),`BattleLoop.new(state, order, decide, null, Callable(), phi_cb)` 可用。**注意該檔於本次量測時為工作樹未提交修改狀態**(另一位 gameplay-programmer 的 story-021 進行中)。
- 各場用該場 `vsNN_affinity_links.txt` 起始關係(±`AffinityLink.AMP_EXPECTED`,`Source.STORY_EVENT`,與 BattleScreen 非戰役路徑灌法一致)建 `AffinityDataPool`,餵 `AffinityPhiProvider`。**簡化揭露:正式遊戲第 2 場起改用累積記錄,量測各場一律用該場起始關係。**
- 生效證據(原始行,`grep -n PHI_RAW run_output_v2.txt`):`PHI_RAW vs04 C_focus_affinity attacker=1 target=6 phi=3`、`PHI_RAW vs03 A_greedy attacker=1 target=6 phi=3`;A/B 也有負值行(例 `vs02 A_greedy ... phi=-1`:貪婪打法隨機站到負向關係者附近被扣)。
- 對照組 `C_focus_phi0`(同 C,phi 不開)用來分離好感度的效果。

### 結果(原始行:`grep -n RESULT run_output_v2.txt`;每場列:結果/回合/我方攻擊次數/首倒)
| 場 | A 貪婪(phi 開) | B 謹慎(修正,phi 開) | C 集火+好感度 | C(phi=0) |
|---|---|---|---|---|
| vs01 | 敗 R1 0擊 丙倒 | 敗 R2 2擊 甲倒 | 敗 R2 2擊 甲倒 | 敗 R2 2擊 甲倒 |
| vs02 | 敗 R2 4擊 甲倒 | 敗 R3 4擊 **E2 倒**(我方先擊倒一敵),之後我方有人倒 | 敗 R3 3擊 乙倒 | 敗 R3 3擊 乙倒 |
| vs03 | 敗 R2 5擊 乙倒 | 敗 R2 2擊 甲倒 | 敗 R2 1擊 甲倒 | 敗 R2 1擊 甲倒 |
| vs04 | 敗 R1 0擊 甲倒 | 敗 R2 2擊 乙倒 | 敗 R2 1擊 乙倒 | 敗 R2 1擊 乙倒 |
| vs05 | 敗 R2 3擊 丁倒 | 敗 R3 2擊 丙倒 | 敗 R3 2擊 丙倒 | 敗 R3 2擊 丙倒 |
20 局全敗,無勝、無達回合上限。唯一擊倒敵人的是 vs02 B(1 個)。

### 讀法與限制
- 戰敗判定是「任一我方單位死亡即 DEFEAT」(`BattleState.outcome()`),所以 2~3 回合內有人被敵方 5 人合擊就結束,我方攻擊機會只有 0~5 次。這是「任一人死即敗」+ 敵方開局即有人進射程的結構,不是單一打法能補的(此為推論,未對關卡本身做更多量測)。
- C 的集火在這些局面幾乎沒有發揮空間:我方攻擊次數(1~3)反而比 A 少,因為安全規則把前進/出手的格排除了。C 與 C(phi=0) 在 5 場裡結果與首倒逐字相同,好感度站位偏好在這 5 場沒改變結局(phi 實際有算入傷害:見 PHI_RAW,但 `END` 血量差距 ≤ 1~3 點)。
- 未計入:卡牌、人類利用地形/視線、重整隊形;好感度累積記錄(見上)。
- 未驗證:vs04 診斷的「友軍擋格」因果(僅上述實測結果間接支持);C 的集火規則是否優於「單純 B」無統計意義(每場每打法 1 局、決定性,不是樣本)。

## 第三版:數值敏感度掃描(2026-10-28,管理者裁決「試驗區試調數值+數值設計師分析,不改正式資料」)

腳本 `autoplay_v3_sweep.gd`(複製自 v2,打法 C 邏輯逐字沿用,好感度開),原始輸出 `run_output_v3.txt`(`grep -n "^SWEEP" run_output_v3.txt`)。不改任何 assets/、src/、tests/。

### 調整方式(載入真實 vs01~vs05 名冊、`BattleState.create` 之後於記憶體中進行)
- 敵方 ATK:`Unit.atk` 屬性 setter(受寫入窗守衛,故包在 `BattleState.commit_authoritative_change(...)` 內),`roundi(原 ATK × 係數)`(四捨五入,.5 進位遠離零)。DEF/HP/MP/射程不動。
- 我方 HP:`Unit.hp_max` 是無守衛的一般欄位(直接賦值)、`Unit.hp` 屬性 setter(同上包在 commit 內);兩者皆設 `roundi(原 hp_max × 係數)`,即當前 HP = 新上限。
- 敵方少一人:**名冊文字層**刪掉 faction=ENEMY 且 id 最大的那一列(`_drop_last_enemy`),再 `BattleState.create`。這是對輸入資料的變動,不是重寫規則;`TurnOrder` 的敵方 id 列表隨之少一人。vs01~vs05 各被移除的是各自名冊最後一個敵人(id 最大)。
- 組合:敵方 ATK ×0.8 + 我方 HP ×1.3,同上兩條。
- 戰敗規則未改(仍是任一我方死亡即 DEFEAT);「我方全滅才敗」只記錄結束時我方存活人數。
- 揭露:每格每場決定性一局(非統計樣本);好感度每場用該場起始關係(同第二版)。基準列與第二版 C 的結果/首倒逐字相符(vs01 甲、vs02 乙、vs03 甲、vs04 乙、vs05 丙),可視為腳本沒搞壞。

### 結果(R=回合 atk=我方攻擊次數 kill=擊倒敵數/開局敵數 alive=結束時我方存活/開局我方;首倒 = 第一個倒下的單位)
| 設定 | vs01 | vs02 | vs03 | vs04 | vs05 |
|---|---|---|---|---|---|
| 基準 | 敗 R2 atk2 kill0/5 alive4/5 首倒甲 | 敗 R3 atk3 kill0/5 alive4/5 首倒乙 | 敗 R2 atk1 kill0/5 alive4/5 首倒甲 | 敗 R2 atk1 kill0/5 alive4/5 首倒乙 | 敗 R3 atk2 kill0/5 alive4/5 首倒丙 |
| 敵ATK×0.8 | 敗 R3 atk4 kill0/5 alive4/5 甲 | 敗 R4 atk4 kill0/5 alive4/5 丙 | 敗 R4 atk8 kill1/5 alive4/5 E2 | 敗 R2 atk0 kill0/5 alive4/5 乙 | 敗 R5 atk8 kill1/5 alive4/5 E2 |
| 敵ATK×0.7 | 敗 R3 atk9 kill1/5 alive4/5 E4 | 敗 R4 atk6 kill1/5 alive4/5 E2 | 敗 R4 atk10 kill1/5 alive4/5 E5 | 敗 R4 atk7 kill1/5 alive4/5 E1 | 敗 R6 atk15 kill2/5 alive4/5 E1 |
| 敵ATK×0.6 | 敗 R3 atk9 kill1/5 alive4/5 E4 | **勝 R9 atk23 kill5/5 alive5/5** | 敗 R6 atk22 kill4/5 alive4/5 E5 | 敗 R4 atk4 kill0/5 alive4/5 戊 | 敗 R6 atk20 kill4/5 alive4/5 E2 |
| 我方HP×1.3 | 敗 R2 atk1 kill0/5 alive4/5 甲 | 敗 R4 atk4 kill1/5 alive4/5 E2 | 敗 R4 atk8 kill1/5 alive4/5 E2 | 敗 R3 atk4 kill0/5 alive4/5 乙 | 敗 R5 atk9 kill2/5 alive4/5 E2 |
| 我方HP×1.5 | 敗 R3 atk5 kill0/5 alive4/5 甲 | 敗 R4 atk4 kill0/5 alive4/5 丙 | 敗 R4 atk8 kill1/5 alive4/5 E2 | 敗 R2 atk0 kill0/5 alive4/5 乙 | 敗 R4 atk7 kill1/5 alive4/5 E4 |
| 敵少一人 | 敗 R2 atk3 kill0/4 alive4/5 丙 | 敗 R3 atk2 kill0/4 alive4/5 戊 | 敗 R3 atk5 kill1/4 alive4/5 E2 | 敗 R3 atk5 kill0/4 alive4/5 乙 | 敗 R3 atk2 kill0/4 alive4/5 丙 |
| 敵ATK×0.8+我方HP×1.3 | 敗 R3 atk9 kill1/5 alive4/5 E4 | 敗 R4 atk6 kill1/5 alive4/5 E3 | 敗 R4 atk11 kill1/5 alive4/5 E5 | 敗 R2 atk1 kill0/5 alive4/5 甲 | 敗 R6 atk15 kill2/5 alive4/5 E1 |

(首倒為 E 開頭 = 我方先擊倒敵人;「敗」的局結束時我方一律 4/5 存活,因為戰敗規則是第一個我方單位倒下即結束。)

### 讀法
- 40 局中只有 1 局勝:**vs02 敵ATK×0.6**(R9,我方無人倒、全殲 5 敵)。其餘 39 局皆敗。
- 最先出現「勝」的方向:**敵方 ATK 下調**(×0.6,僅 vs02)。我方 HP ×1.3/×1.5、敵少一人、ATK×0.8+HP×1.3 組合皆 0 勝。
- 敵ATK下調對「我方先擊倒敵人」最有效:×0.7 起 vs01/02/03/04/05 全部 kill≥1;×0.6 時 vs03/vs05 擊倒 4/5 但仍敗(1 敵殘存),vs01 與 vs04 反而 kill1 / kill0(vs04 ×0.6 首倒戊,atk4)。
- 我方 HP ×1.3/×1.5 單獨效果有限:vs01、vs04 在 ×1.5 仍是 R2~R3 敗、kill0;vs04 ×1.5 atk0(與 ×0.8 同為 R2 atk0)。
- 「我方全滅才敗」假設:未改規則,故僅記錄。所有敗局結束時我方 4/5 存活;若規則改為全滅才敗,這些局當時皆仍會繼續(有 4 人活著)。繼續後結果:**未驗證**(未跑)。
- 未驗證:ATK 係數與勝負的單調性(只取 3 個係數點、每格一局決定性);ATK×0.6 在 vs02 以外 4 場仍敗的原因(僅有上表數字,未做因果診斷);結果對打法 C 以外打法是否成立;vs04 在調整下 atk=0 的成因。
