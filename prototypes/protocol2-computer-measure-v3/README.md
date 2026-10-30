# protocol2-computer-measure-v3 (attempt-3 工具)

Status: TOOL READY(未提交;vs01 未執行,預設關卡 2,`--level=1` 需 `--r2=yes`;vs02 旋鈕再驗尚未做,依 H3 須在 V3 提交之後)
規格:`docs/reviews/protocol2-attempt3-registration-2026-10-30.md`(H3 `286a313`);規則程式 S3 `e7751fc`
(`BattleState.lone_guard_if_at(unit_id, tile, will_attack: bool = false)`)。複製自 `../protocol2-computer-measure-v2/`,舊目錄未改。原型,不進 `src/`。
使用方式、參數、輸出格式與 v2 相同(見 v2 README);`guard_check.gd`、`guard_check_output.txt` 為 v3 重跑(甲 Φ=+3 => guard=2,exit 0)。

## 與 v2 的差異(H3 第 3 節允許的三類,逐項)
審查指令原始輸出見文末。stat 中 README、`*.uid`(引擎依路徑產生的雜湊)、`k3_boundary_fixture_output.txt`(v2 獨有)、`smoke_fixture_output.txt`(v3 新增)不是程式改動;**程式改動只有 `p2_decision.gd` 與 `protocol2_runner.gd` 兩列(各 4 行),逐行 diff 即下表。**

| 檔案 | 改動 | 類別 | 理由 |
|---|---|---|---|
| `p2_decision.gd` | 步驟 2 新增 `will_attack`,僅當過濾實際縮池時設 true(`can_attack` 且池內有可攻擊格) | (a) | H3 第 1 節「步驟 3 的 guard_total(t) 取值」:池縮減生效=會出手,否則不出手 |
| `p2_decision.gd` | 步驟 3 呼叫 `s.lone_guard_if_at(id, t, will_attack)`(S3 新簽名第三參數) | (a)(b) | 只呼叫正式函式;`CombatRules.guard`(進位版)由 S3 提供,工具未重刻。對甲乙丙丁 `lone_guard_if_at` 恆為 0,旗標無影響 |
| `protocol2_runner.gd` | `preload` 路徑 v2 -> v3 | (b) | 指向本目錄的決策檔 |
| `protocol2_runner.gd` | HEADER 增 `tool=protocol2-computer-measure-v3` | (c) | HEADER 標籤 |
其餘(忽視臂、K1/K2/K3、guard 接線 `attach_defense_phi_provider`、guard 全 0 => `FATAL guard never applied` exit 3、簽名/SIGSUM、`--r2=yes` 防呆)一字未動。
未動的運用臂其他三步驟(安全池、攻擊優先過濾、決勝)原文不變。

## 冒煙(夾具,僅確認能跑與 exit code)
- `guard_check.gd`:`GC_EXIT=0`,`GUARDCHECK phi_of(1)=3 ... guard=2 expected_guard=2 -> OK`。
- 夾具 `--variants=0,1 --max-rounds=4`(`smoke_fixture_output.txt`):`SMOKE_EXIT=3`(夾具無好感度,FATAL 為預期)、4 行 RESULT、`DONE`、無 SCRIPT ERROR/Parse Error。HEADER build_commit = `e7751fc`。
- 夾具與 guard_check 不含 `lone_guard` 單位,故 `will_attack` 路徑只驗到「能編譯、能執行」,未驗到戊的取值;依 H3 該取值於 vs02 再驗時才會被實際走到。

## diff 原始輸出
`git diff --no-index --stat prototypes/protocol2-computer-measure-v2 prototypes/protocol2-computer-measure-v3`:
```
 .../README.md                                      | 83 +++++++---------------
 .../guard_check.gd.uid                             |  2 +-
 .../k3_boundary_fixture_output.txt => /dev/null    | 40 -----------
 .../p2_decision.gd                                 |  4 +-
 .../p2_decision.gd.uid                             |  2 +-
 .../protocol2_runner.gd                            |  4 +-
 .../protocol2_runner.gd.uid                        |  2 +-
 .../smoke_fixture_output.txt                       | 12 ++++
 8 files changed, 47 insertions(+), 102 deletions(-)
```
