# 難度量測專用電腦代打(含撤退)2026-11-03

Status: CONCLUDED(結果:撤退規則在 vs02~vs05 共 32 局「零影響」,見下)。未改協議 2 任何正式工具、未改 src/ assets/ 與既有 prototypes;未跑 vs01、未讀 production/qa/protocol2/。

## 檔案
- `retreat_decision.gd` —— 複製自 `vs03-defeat-diagnosis-2026-11-03/p2_decision.gd`(即 v3 決策),只在「步驟 4 選定格子之後」插入一段 `RETREAT`。
- `retreat_runner.gd` —— 複製自診斷用 traced runner(含逐單位 TPACT/TPOS/TDEATH 紀錄);新增 `--retreat=on|off`(預設 off)與 `--radius=N`(診斷用)。
- `run_vs03_off.txt`、`run_vs0{2,3,4,5}_on.txt`、`run_vs03_on_radius99.txt` —— 原始輸出。

## 撤退規則與常數(`retreat_decision.gd` 頂端)
- `RETREAT_LETHAL_MARGIN = 0`:原決策選定的格子若 `預估受擊 + 0 >= 現有 HP` 即觸發撤退。
- `RETREAT_TEAM_RADIUS = 2`:候選格須與某個其他存活我方單位(曼哈頓距離)≤ 2;若無任何這種格,退而用全部可達格。
- 觸發且該單位可移動時:在候選格中選「預估受擊最少」;同分 → 優先「能攻擊且該格預估受擊 < HP」者 → 離最近敵人較遠者 → (y,x) 小者。只有嚴格比原選擇低才改選,否則維持原行為。
- 改選後若該格仍預估致命,則本回合不攻擊(「攻擊後仍安全才攻擊」)。
- 決定性:無亂數,平手一律 (y,x) 升序。
- **預估受擊用既有的 `_threat()`**(v3 原函式):對每個敵人,檢查「原地或可達格」是否 `is_attack_reachable` 到目標格,再加 `BattleState.preview_damage(...)`。**沒有自己重刻傷害公式。** 限制:`preview_damage` 以單位「當前所在格」的地形算防禦,不是候選格的地形;且假設所有敵人都會打同一個人、不扣除本回合我方會殺掉的敵人 —— 因此是偏悲觀上限。

## 驗證
命令(引擎 exit):
```
G="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
timeout 900 "$G" --headless --path . -s res://prototypes/difficulty-ai-retreat-2026-11-03/retreat_runner.gd -- --level=3 --arms=use --retreat=off > run_vs03_off.txt   -> ENGINE EXIT=0
diff <(grep ^RESULT run_vs03_off.txt) <(grep ^RESULT ../difficulty-check-2026-11-03/run_vs03.txt)   -> OFF_IDENTICAL(8 局逐字相同)
... --level=2|3|4|5 --arms=use --retreat=on > run_vs0N_on.txt   -> 四次 ENGINE EXIT=0,四次 DONE
```
① 關閉驗證通過。

## 量測表(use 臂,8 組旋鈕;原版 = `difficulty-check-2026-11-03`,撤退版 = 本目錄 on)
| 關卡 | 原版 勝/敗 | 撤退版 勝/敗 | 回合數 | 瀕死 | 誰倒下 | 撤退觸發次數 |
|---|---|---|---|---|---|---|
| vs02 | 8/0 | 8/0 | 逐局相同 | 逐局相同 | 無 | 0 |
| vs03 | 6/2 | 6/2 | 逐局相同 | 逐局相同 | v1 丁、v5 丙(同原版) | 11 |
| vs04 | 8/0 | 8/0 | 逐局相同 | 逐局相同 | 無 | 0 |
| vs05 | 8/0 | 8/0 | 逐局相同 | 逐局相同 | 無 | 0 |
RESULT 行(含 final_hp)與原版逐局逐字相同(diff 無差異)。

## 為什麼沒有任何改變(vs03 觸發 11 次的軌跡,`grep RTRIG run_vs03_on.txt`)
- v1 R3 丁 HP10:原選格預估受擊 19,原地 26 —— 可達格全部 ≥ 19,**沒有更安全的格子**,所以規則不改選。丙 HP3(v5 R4):原選 19、原地 19,同理。
- 另放寬隊友半徑到 99(`run_vs03_on_radius99.txt`)結果仍逐局相同 → 不是「離隊友 2 格」限制擋住。
- 原因:v3 決策本來就有「無安全格 → 取預估受擊最小」的回退,等同一次撤退;敵人 5 人貼近時,一回合移動力內沒有任何格子逃得出所有敵人射程。真正的問題在「更早」(陣型展開、R2 踏進灌木帶、戊落單),不是「當回合沒撤」。

## 白話結論(證據強度:低~中,仍是電腦、只量 32 局、且規則沒生效)
- 在這種「較像真人的撤退」下,**vs02、vs04、vs05 仍全勝、vs03 仍 6/8**:四場結論與原量測相同,**未顯示任何一場偏難或偏易的新證據**。
- 這不代表真人也撤不掉:本規則只能「這一步移到更安全的格子」,而診斷的敗局在那一步時已無處可逃。若要讓代打更像真人,需要改**更早的決策**(例:受傷單位在 HP 還高時就後撤、隊形先合攏、不在敵方先推進時才進灌木帶)—— 那是更大的改動且會連帶抬高 vs02/04/05 勝率,需要新的裁決,我沒有做。
- vs03 仍建議以真人實打判定;本結果等於再次確認「電腦的 2 敗不是少了一步撤退」。

## 限制
- 只跑 use 臂、各 8 組。撤退只影響 v3 步驟 4 之後的選格;未改敵方 AI、未改攻擊目標選擇、Phi 步驟在撤退選格時被繞過(但本次無任何改選發生)。
- `_threat` 為悲觀上限估計(見上),門檻 MARGIN=0 / RADIUS=2 只試了這一組(外加 RADIUS=99 於 vs03);未掃描 MARGIN > 0(只會更常觸發,但受同一個「無更安全格」限制)。
