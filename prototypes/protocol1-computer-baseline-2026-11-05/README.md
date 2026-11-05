# 協議 1 替代量測(電腦半)—— 結果

狀態:已執行一次(兩次同指令用於決定性驗證)。依 `docs/reviews/protocol1-computer-half-lock-plan-2026-11-05.md`(鎖定提交 6dc9a82;第 1~5 節未改)。

## 通用限制(計畫第 4 節要求寫在第一段)
1. 本結果**不是**協議 1 的證據,也不使協議 1 達成;只代表電腦在鎖定資訊集下的準確率。
2. 全為決定性全枚舉,非統計樣本;各關僅 1~2 條連線,局面空間小。
3. 只對下列資料快照成立;vs03/vs04 後續調整後須重跑。
4. 無「通過/未通過」,只有診斷結論。
5. 好感度 delta 由站位/連線/調校表決定,不含敵方數值;真人半與 80% 門檻重新校準仍須在劣勢條件下做。
6. 偏離揭露:主要集不含 vs01(新玩家第一場不在樣本內),計畫已載明。

## 執行
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://prototypes/protocol1-computer-baseline-2026-11-05/protocol1_runner.gd
```
- 執行時 HEAD:`0469d3c10c01fdae5514946538435199a6c86370`(為 6dc9a82 的後代,`git merge-base --is-ancestor` 為真)。`src/ assets/ tests/` 無未提交改動。
- ENGINE EXIT:兩次皆 0(`exit_codes.txt`)。`cmp run_output_1.txt run_output_2.txt` -> **逐位元相同**(CMP_IDENTICAL)。
- 原始輸出:`run_output_1.txt`、`run_output_2.txt`。腳本:`protocol1_runner.gd`(單檔,含驅動與 P0/P1/P2)。
- 關卡檔 `git hash-object`(terrain / roster / affinity_links):
  - tut04 `6447477c…e1` / `314590a1…70` / `72a799c7…94`;完整值見下
  - tut04: 6447477c998bedb2e36392372c4e367db4cdb2e1 314590a1ec9f8de2d4b8f20bfa85cf0bdd31a470 72a799c7720634ec0a7adc7f5b70b9460f3f5094
  - vs02: 7c2f96630d01219be1cff72202f583d5836475dc 9a886642eb6bca8d1545fbb2f894c15640322075 6c619fb45c16186c0c35a94e4a63bbfdd0c83d36
  - vs03: 7bdbceaaa7a9c1e13b6ad1c20566c72ea156a3ed ea4469791f7b8efc6ffd8df2d2dd804cf8df3762 e814a3d0d54761e442fc9d5428b27bf9fa490a52
  - vs04: eb7857dcf4376d53184ab5af4de23f97a12280a5 0b1b98d879e10b1b6d78b21cffcbc85ae7c389a0 d541fad29f5349d4b2e1158dc97490ebff5faf05
  - vs05: 974ed7969058bccf5e6306ce466ec6c11565071f 3a39168428a82e15e2ccbeef436221281f93b379 e47ed89b112bf608d2a24a416719c4ea9bd2fcc5
  - tutorial_cards.txt 8084740fe76f160d72fcdf749aa2e87e54f966e6;tuning_knobs.txt 838d2c9160cb6ad5dc74f75464e94238f45f0536

## 真實管線與物證
`load()` 真實 `BattleScreen.tscn` -> `instantiate()` -> 設 terrain/roster/affinity/cards/card_text 五個 override -> `root.call_deferred("add_child")` -> 等 2 幀;正解呼叫 `_guess_delta_for_cell()` 再 `EffectGuessTracker.classify_delta`。候選格 = `BattleController.select_unit(u)` 後的 `move_targets().cells`(全部,未挑選)。log 內有宿主鏈值(如 `HOSTCHAIN tut04: WorldViewportContainer.position=(0.0, 0.0) size=(960.0, 540.0) stretch_shrink=2 WorldViewport.size=(480, 270)`)、調校值、連線表、單位位置、候選格數。

## 結果(單位:%;原始行見 run_output_1.txt 的 `REPORT` / `RECALL` 行)
| 關 | N_d | N_c | 排除單位 | 正解 正/負/無 | P0-無 | P0-正 | P0-負 | P0-輪替 | **P0** | P1 | P2-strict | P2-tie | U(格) | P2可決定答錯 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| tut04 | 2 | 53 | 0 | 0/92.45/7.55 | 7.55 | 0 | 92.45 | 33.96 | **92.45** | 100 | 100 | 100 | 0 | 0 |
| vs02 | 4 | 68 | 1 | 36.76/55.88/7.35 | 7.35 | 36.76 | 55.88 | 29.41 | **55.88** | 100 | 100 | 100 | 0 | 0 |
| vs03 | 4 | 52 | 1 | 36.54/53.85/9.62 | 9.62 | 36.54 | 53.85 | 36.54 | **53.85** | 100 | 100 | 100 | 0 | 0 |
| vs04(次) | 4 | 74 | 1 | 33.78/59.46/6.76 | 6.76 | 33.78 | 59.46 | 29.73 | **59.46** | 100 | 100 | 100 | 0 | 0 |
| vs05(次) | 4 | 43 | 1 | 34.88/53.49/11.63 | 11.63 | 34.88 | 53.49 | 32.56 | **53.49** | 100 | 100 | 100 | 0 | 0 |

未加權平均:主要集 P0=67.39 P1=100 P2s=100 P2t=100 U=0;次要集 P0=56.47 P1=100 P2s=100 P2t=100 U=0。
U(決策層級,有任何不可決定格的決策比例)亦為 0。分類別召回見 `RECALL` 行(例:tut04 P0-負 負 49/49、無 0/4;P1 負 49/49、無 4/4)。排除單位 = 戊(5 號,無連線),各 vs 關 1 個;tut04 名冊為 1、2 號。N_c 為同決策內高度相關的格數,非獨立樣本。

## 診斷結論(依寫死判讀表,逐字取自 log 的 `DIAG` 行)
- tut04:P0=92.45 >= 80 -> **80% 門檻無鑑別力(不讀畫面也過線)**;發現,非失敗。
- vs02 / vs03(及次要 vs04 / vs05):P0 介於 53.49~59.46,< 70 -> 門檻在這些關有鑑別空間。
- 所有關:P2-strict=100 且 U=0 <= 20 -> 畫面資訊邏輯上足以達 80%(僅上限,不代表人類做得到)。
- 所有關:P1=100 >= 80 -> 天真讀法已過線,80% 對略讀者可能偏易(非人類證據)。
- U > 20 與 P1 < P0+5 兩條**未觸發**;P2 − P1 >= 20 **未觸發**(P2-strict 與 P2-tie 兩種讀法皆未觸發,計畫未指定用哪個,兩者都評估)。
- P2 可決定部分答錯 = 0,無停止解讀條件。

## 觀察(非計畫判讀,僅供下一個人;未驗證成因)
P1/P2 各關皆 100% 且 U=0:開場佈陣下所有連線的目前距離皆非 2,故符號唯一對應極性(未逐局面檢查距離,屬推測);又 P1 的「走近朋友」啟發式恰好與 delta 表一致。這代表開場局面集 A 對 P1 沒有鑑別力,不是 P1 真的完美。

## 計畫標「未查證」項目的處理
- `enemy_advantage_pct`:在 `src/`(僅 `combat_rules.gd` 的 `enemy_stat()` 參數)與 `assets/data` 無旋鈕;好感度 delta 路徑不經過它,故 log 無讀到值。tuning 實際用的 `AffinityTuning` 值已逐關留在 `TUNING` 行(delta 表 +3/-1/-1/+2/0、phi -4~12)。
- 局面集 B:**未做**(未查證逐階段站位可否在不改 src 下輸出,看結果前決定不做)。旁證掃描 S:**未做**。
- 無重新實作任何規則:delta/夾限/距離/可移動範圍均呼叫真實 `AffinityRules`/`BattleController`。腳本只自寫:P1 的符號×距離變化投票邏輯(計畫定義)、候選格排序、計分聚合;P2 的極性枚舉用 `AffinityLink.new()` 組假設連線後交 `AffinityRules` 計算。
- 偏離/注意:tut04 載入時引擎警告 `tutorial_cards.txt parsed to zero cards`(空牌庫,與好感度量測無關)。`P2-tie` 平手一律選「無效果」;U 以格數計,另附決策層級。腳本內有一段被後續覆寫的冗餘 tie 迴圈(無影響,結果取自覆寫後)。
- 未 commit。
