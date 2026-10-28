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
