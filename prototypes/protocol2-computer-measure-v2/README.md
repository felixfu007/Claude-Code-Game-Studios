# protocol2-computer-measure-v2 (attempt-2 工具)

Status: TOOL READY(vs01 未執行;`--level=1` 另需 `--r2=yes`,預設關卡為 2)
規格:`docs/reviews/protocol2-attempt2-registration-2026-10-30.md`(H2 `1275bfa`,含協調者提交前更正:步驟 1、2、4 兩臂皆適用,僅步驟 3 為運用臂獨有)。
規則程式:S `908708a`;S' `b3a7aa7`(新增公開 `BattleState.lone_guard_if_at(unit_id, tile)`)。
原型,不進 `src/`。

## 一、檔案清單
- `p2_decision.gd`:決策函式(安全池 -> 攻擊優先過濾 -> [僅運用臂]最大化 Φ(t)+guard_total(t) -> 決勝)。
- `protocol2_runner.gd`:runner(複製自舊目錄後修改)。
- `guard_check.gd` + `guard_check_output.txt`:guard 單點檢查(vs02 真實資料)。
- `k3_boundary_fixture_output.txt`:K3「第 1 回合」邊界的夾具實測(含 `--trace=yes` 逐單位紀錄)。
- 驗證輸出:`production/qa/protocol2/knob-verify-vs02-20261030T0338Z/raw_stdout.txt`。

執行:
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://prototypes/protocol2-computer-measure-v2/protocol2_runner.gd -- --level=2 > out.txt 2>&1; echo ENGINE_EXIT=$?
```
參數:`--level=` `--arms=` `--variants=` `--max-rounds=`(預設 12)`--terrain/--roster/--affinity=`(夾具除錯)`--trace=yes`。
輸出:`HEADER`、16 行 `RESULT`(新增 `final_hp= first_round= guard_events= guard_nonzero=`)、`SIGSUM`(每臂不同簽名數)、`GUARDSUM`、`DONE`。
所有局 guard_nonzero 合計為 0 時印 `FATAL guard never applied` 並 `quit(3)`(夾具上因無好感度,此 FATAL 屬預期)。

## 二、實作與揭露
- 防守方減傷:每局兩臂皆 `state.attach_defense_phi_provider(Callable(prov, "phi_of"))`(未接會靜默為 0)。
- 運用臂 guard_total(t) = `CombatRules.guard_total(CombatRules.guard(Φ(t)), state.lone_guard_if_at(id, t))`,Φ(t) = `AffinityRules.bonus_for_at`(移動前站位快照)。無任何重刻公式。
- 旋鈕:K1 同前;K2 = `TurnOrder.new(pids, eids)` 的 pids 遞增/遞減(先 sort);K3=1 時第 1 回合我方單位 `can_move` 傳 false(不移動,原地能打則打);池順序固定 (y,x) 遞增;集火平手鍵固定為低 id。
- 決勝解讀:集火目標 F 由「步驟 2 保留格可攻擊敵人的聯集」計算(在好感度最大化之前);之後在最高分並列格內優先「能攻擊 F」者,再 `_is_better_tile`,再池順序。攻擊目標:選定格能打 F 則 F,否則 `_best_target`。
- `guard_events` / `guard_nonzero` 的計法(揭露其近似):敵方單位每次決定攻擊我方目標時,記下 `preview_damage_breakdown` 的 guard 與 damage;下一次掃描時若目標 HP 確實下降(或預估傷害為 0)才計為一次受擊。是「決策時快照」,不是引擎內部鉤子。
- 簽名 = `outcome|rounds|neardeath|最終存活我方單位 HP 依 id 排序`(陣亡單位不列,故向量長度可變)。

## 三、guard 單點檢查(vs02 起始盤面,甲(0,1)與乙(0,2)相鄰、正關係 => Φ(甲)=+3,E1(id6)打甲)
原始行(`guard_check_output.txt`,ENGINE_EXIT=0):
```
GUARDCHECK before attach: { "atk": 14, "def": 8, "phi": 0, "phi_input": 0, "phi_def": 0, "guard_phi": 0, "lone_guard": 0, "guard": 0, "damage": 6, "target_hp_after": 24 }
GUARDCHECK after attach : { "atk": 14, "def": 8, "phi": 0, "phi_input": 0, "phi_def": 3, "guard_phi": 2, "lone_guard": 0, "guard": 2, "damage": 4, "target_hp_after": 26 }
GUARDCHECK phi_of(1)=3 expected_phi_def=3 guard=2 expected_guard=2 -> OK
```
(未接 provider 時 guard=0、傷害 6;接上後 guard=2、傷害 4。)

## 四、K3「第 1 回合」邊界(夾具 5x3 補成 13x6,`k3_boundary_fixture_output.txt`)
- runner 閉包取 `TurnOrder.round_number()`:第一個我方決策時即為 **1**(`first_round=1`)。
- K3=1 時:round=1 的我方決策 `cm2=false`、`move_to=<null>`;round=2 起 `cm2=true` 恢復移動。對照 K3=0 同單位在 round=1 即移動 (0,0)->(1,0)。
- 即「第 1 回合」= `round_number()==1` 的整個我方階段;K3 僅一個回合(未延長,備援 R1 未啟用)。

## 五、vs02 旋鈕差異驗證(登記 4.1)
原始輸出:`production/qa/protocol2/knob-verify-vs02-20261030T0338Z/raw_stdout.txt`(`ENGINE EXIT = 0`,16 行 RESULT,`DONE`)。
簽名統計行:
```
SIGSUM arm=ignore distinct=8 of 8
SIGSUM arm=use distinct=8 of 8
GUARDSUM guard_events=135 guard_nonzero=77
```
每臂 8 種 >= 4,達標。**不需替換旋鈕**(R1/R2/R3 皆未使用)。HEADER build_commit = `b3a7aa7`(含本目錄未提交檔案時的工作樹)。
本節不對兩臂差距作任何評論。

## 六、旋鈕替換紀錄
無。
