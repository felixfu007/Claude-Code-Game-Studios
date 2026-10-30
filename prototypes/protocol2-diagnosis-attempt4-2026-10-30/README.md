# Protocol 2 attempt-4 事後診斷(2026-10-30)

不改判定、不改既有檔、未提交。只複製 V3 腳本並加純列印追蹤。

## 方法
- `p2_decision.gd`、`protocol2_runner.gd` = V3 複製(唯一差異:preload 路徑)。`protocol2_runner_traced.gd` = 上者 + 追蹤列印:
  - `HIT`:每次敵方決定攻擊我方 -> 攻擊者、受擊者、受擊者 hp、phi_def/guard_phi/lone_guard/guard/damage、是否致死(kills)、當下全體我方單位座標與 hp。
  - `WUATK`:每次戊(lone_guard 旗標)決策為攻擊 -> 預定出手格、到最近存活隊友距離 dmin、hold_back(以 CombatRules.hold_back 算)。
- 執行 S4 = 主工作樹(src 與 ace389b 無差異:`git diff --stat ace389b HEAD -- src assets` 空)。
- 對照 S3 `e7751fc`:乾淨 worktree `C:/tmp/p2diag_s3`(`git worktree add --detach`,已 `--import` exit 0),traced 版把 hold_back 呼叫換成常數 -9(S3 無該函式),故 S3 檔的 `hold_back=-9` 是佔位、不是數值。
- 輸出:`copy_untraced_stdout.txt`、`traced_stdout.txt`(S4)、`s3_traced_stdout.txt`(S3)。

## 發現(實測)
1. 複製不改行為:未追蹤版與追蹤版 ENGINE_EXIT=0,16 行 RESULT 與 `production/qa/protocol2/computer-attempt-4-20261030T0819Z/raw_stdout.txt` 逐字相同(diff 空,印 IDENTICAL x2);HIT=120=`GUARDSUM guard_events=120`。S3 追蹤版 16 行 RESULT 亦與 attempt-3 raw 逐字相同(S3_IDENTICAL)。
2. v0、v6 運用臂敗因 = **丙被集火倒下**(兩例都是丙;從 final_hp 少一個 id=3 推得「丙倒=敗」,未讀 BattleState 勝負條件原碼 —— 推論)。
   - v0 use:`HIT arm=use v=0 round=3 attacker=E5 target=3 name=丙 ... hp=5 ... guard=1 damage=6 kills=true`。丙被打:R1 一次(22->16)、R2 兩次(16->11->5)、R3 致死,共 4/7 次受擊。倒下當回合戊在(5,1),甲(8,1)、乙(7,0)遠在丙(0,3)之外(同行 players=[...])。
   - v6 use:`HIT arm=use v=6 round=3 attacker=E4 target=3 name=丙 ... hp=1 ... kills=true`;丙 5/7 次受擊,R2 全隊聚在 (0,1)(0,2)(1,1)(0,4)(0,5),丙在最前被 E1/E4 打、R3 倒。
   - 丙每次 guard 只有 1(`phi_def=2 guard_phi=1 lone_guard=0`);傷害 5~6/次。戊當時 d:v0 R3 戊 `lone_guard=0`(d≥3,`WUATK ... dmin=3 hold_back=0`),v6 R3 戊 `lone_guard=2` 被打 4。戊受擊都有、沒有「戊倒」。
3. 與 attempt-3 同變體比較(S3 `s3_traced_stdout.txt`):
   - **v0:S3 勝(use rounds=4)、S4 敗(rounds=3)—— 這是真實回歸。** 分歧從 R1 開始:S3 R1 戊在(1,0),E3、E4 都打丙(丙 22->16->11);S4 R1 戊在(4,5)被 E4 打(`HIT ... round=1 attacker=E4 target=5 name=戊 ... lone_guard=2 ... damage=3`),丙只被打一次。R2 S3 敵方分打乙/丁/甲(甲@(4,3)、丁@(4,5)在前),丙(0,4)沒被打;S4 R2 全隊擠上排 甲(3,0)乙(2,0)丁(1,0)戊(4,1),丙獨留(0,4),E4、E5 連打丙(16->11->5)。
   - **v6:S3 也是敗(rounds=4,`RESULT arm=use v=6 outcome=DEFEAT rounds=4`),不是「attempt-3 同變體贏」。** S4 只是更早(3 回合)敗。
4. 彙總(S4;戊受擊 = HIT name=戊;出手 = WUATK):

| 臂 | 戊受擊 | lone +2 | lone 0 | lone −1 | lone 淨值 | 戊出手(計畫) | 其中 hold_back=1(d=2) | 甲乙丙丁受擊 | guard_phi 非零 | guard_phi 總減傷 |
|---|---|---|---|---|---|---|---|---|---|---|
| ignore | 17 | 5 | 6 | 6 | +4 | 20 | 8 | 48 | 33 | −5 |
| use | 20 | 11 | 5 | 4 | +18 | 16 | 11 | 35 | 33 | +40 |

   - hold_back 總扣傷上限 = 次數 ×1(ignore ≤8、use ≤11);未逐筆核對是否被 max(0,…) 吞掉,也未核對計畫攻擊都有執行(WUATK 在決策時記錄)。
   - 對照 S3:戊 lone +2 兩臂皆 0 次(attempt-3 診斷同結論);S4 起變 5 / 11 次。
   - 重點:use 臂 S4 的甲乙丙丁 guard_phi 淨 +40(S3 use 為 +21),戊 lone +18 —— 減傷總量是增加的,但 v0/v6 的敗因不是減傷不夠,是**丙被孤立集火**。

## 推論(未直接驗證,需實驗確認)
- 運用臂的我方決策(`p2_decision.gd`,依 Φ/獨行格評分)在 S4 規則下把戊與隊伍移到不同格,隊形改變使丙落單;不是戊倒、也不是減傷歸零。S4 的 d=2 +2 / d=1 −1 改變了戊的最佳落點,連帶改變全隊走位 —— 因果鏈只由 R1 座標差(S3 戊(1,0) vs S4 戊(4,5))支持,沒做單一變因實驗(例如固定 戊 落點)。
- 敵方 AI(GreedyTacticalAI)偏向打 hp 低/可擊殺目標是推測,未讀其碼。

## 未驗證
- 勝負條件是否為「丙倒」(見 2)。
- worktree `C:/tmp/p2diag_s3` 仍在(未移除)。
