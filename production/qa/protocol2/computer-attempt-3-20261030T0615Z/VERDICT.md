# 協議 2 attempt-3 判定(qa-lead,2026-10-30)

> 依據:鎖定文件(H `20e0854`,現文 2.3)與 `docs/reviews/protocol2-attempt3-registration-2026-10-30.md`(H3 `286a313`)。原始資料:同目錄 `raw_stdout.txt`、`RUN-INFO.md`。本判定未修改任何規則。

## 0. 鎖定鏈與執行有效性(自行重跑)

| 檢查 | 結果 |
|---|---|
| 鎖定文件最後提交 = H | `20e0854d5c30...` ✅ |
| H3 檔最後提交 = H3 | `286a31346b16...` ✅ |
| 祖先鏈(皆 exit 0) | H→H3、H3→S3(`e7751fc`)、H3→V3(`47465aa`)、S3→V3、V3→R3(`136f600`)全部 ok ✅ |
| 結果檔首次提交 | `git log --diff-filter=A -- production/qa/protocol2/computer-attempt-3-*` → `136f600`(= R3)✅ |
| V3→R3 / V3→HEAD 無變動 | `git diff --stat 47465aa 136f600 -- prototypes/protocol2-computer-measure-v3/ src/ <H3檔>` 空;V3→HEAD 的 prototypes 與 `src/` 亦空 ✅ |
| 鎖定文件、H2 檔無變動 | `git diff --stat 20e0854 136f600 -- <鎖定文件>`、`1275bfa 136f600 -- <H2檔>` 皆空 ✅ |
| 引擎/完整性 | `RUN-INFO.md`:ENGINE EXIT=0;raw:16 筆 RESULT、`DONE`、無 `FATAL`;HEADER `tool=protocol2-computer-measure-v3 build_commit=47465aac...`(= V3)`level=1 vs01 max_rounds=12` ✅ |
| V3 相對 V2 的改動(H3 3 節:只允許三類) | `git diff --no-index` 對 `p2_decision.gd`、`protocol2_runner.gd`:共 4 處有意義改動 —— 宣告 `will_attack`、步驟 2 縮池生效時設為 true、步驟 3 把 `will_attack` 傳入 `lone_guard_if_at(id, t, will_attack)`、runner 的 preload 路徑與 HEADER 加 `tool=`。皆落在 (a)(b)(c) 內,無其他邏輯改動 ✅(v2 舊 `k3_boundary_fixture_output.txt` 未帶入 v3、新增 `smoke_fixture_output.txt`,屬輸出檔) |
| 旋鈕再驗(H3 3 節) | `production/qa/protocol2/knob-verify-vs02-v3-20261030T0615Z/raw_stdout.txt`:level=2、`build_commit=47465aac`(= V3)、16 筆 RESULT、`SIGSUM arm=ignore distinct=8 of 8`、`SIGSUM arm=use distinct=8 of 8`、`DONE`;首次提交 `b8ac352` 為 V3 的後代 ✅(吸取 attempt-2「驗證時工具未提交」的弱點,本次已改正) |
| 結構審查 | v3 `p2_decision.gd` 的好感度/guard 讀取仍只在 `if use_affinity:` 區塊內(第 121 行為其中之一;區塊位置同 v2,diff 無新增區塊外讀取)✅;未逐行重讀整檔,以 diff 為證 |

結論:鎖定鏈成立、本次執行有效,可判定。

## 1. 步驟 A 基準有效性(忽視臂通關數須在 2~6)
raw 忽視臂(第 4、6、8、10、12、14、16、18 行):
```
ignore v=0 VICTORY rounds=5 neardeath=2   ignore v=4 DEFEAT  rounds=3 neardeath=5
ignore v=1 VICTORY rounds=5 neardeath=1   ignore v=5 DEFEAT  rounds=4 neardeath=5
ignore v=2 VICTORY rounds=5 neardeath=1   ignore v=6 VICTORY rounds=5 neardeath=0
ignore v=3 VICTORY rounds=5 neardeath=0   ignore v=7 VICTORY rounds=7 neardeath=1
```
忽視臂通關 = v0,1,2,3,6,7 = **6** ∈ [2, 6] ⇒ **基準有效**(⚠️ 又是上緣)。

## 2. 步驟 B
運用臂(第 5、7、9、11、13、15、17、19 行):
```
use v=0 VICTORY rounds=4 neardeath=0   use v=4 VICTORY rounds=4 neardeath=0
use v=1 VICTORY rounds=4 neardeath=1   use v=5 VICTORY rounds=5 neardeath=0
use v=2 VICTORY rounds=4 neardeath=0   use v=6 DEFEAT  rounds=4 neardeath=5
use v=3 VICTORY rounds=4 neardeath=0   use v=7 VICTORY rounds=5 neardeath=0
```
運用臂通關 = 7(僅 v6 戰敗)。

**B1(a)**:7 − 6 = **+1** < +2 ⇒ **不成立**。
**B1(b)**(兩臂通關局 6、7,各 ≥4,可評估):
- 忽視臂通關局回合:5,5,5,5,5,7(v0,1,2,3,6,7)→ n=6,中間兩數 5、5 ⇒ `2M_忽視 = 10`。
- 運用臂通關局回合:4,4,4,4,4,5,5(v0,1,2,3,4,5,7)→ n=7,第 4 個 = 4 ⇒ `2M_運用 = 8`。
- `10 * 2M_運用 <= 8 * 2M_忽視`:10×8 = **80** ≤ 8×10 = **80** ⇒ 成立(恰等於,依「≥ 剛好等於算過」)。
- `2M_忽視 − 2M_運用 >= 2`:10 − 8 = **2** ⇒ 成立(恰少 1 回合)。
⇒ **B1(b) 成立 ⇒ B1 成立**。
**B2 瀕死總和**(戰敗局記 5):運用臂 = 0+1+0+0+0+0+5+0 = **6**;忽視臂 = 2+1+1+0+5+5+0+1 = **15**;6 ≤ 15 ⇒ **成立**。
A 有效、B1 成立、B2 成立 ⇒ 符合通過條件。

## 3. 揭露(H3 第 2 節全部)
1. **舊結論永久保留**:attempt-1「未通過」、attempt-2「通過(壓線)」,檔案不改。
2. **attempt-3 是因支柱審查而改規則,不是因數據。**
3. **「attempt-3 若未通過不得回頭採用 attempt-2」**:本次結果為通過,此條未被觸發;條文仍有效,不因本次結果而改變。
4. **運用臂本輪仍為 H2 同一定義**(只新增「戊會出手」假設的取值,H3 第 1 節判斷為定義既有步驟);H2「attempt-2 之後不得再改運用臂」繼續有效。
5. **戊的 +2 本輪幾乎不生效**(兩臂步驟 2 都「能打就打」)。**實際生效次數:不可得。** RESULT 只有全體合計的 `guard_events` / `guard_nonzero`(各局合計 116 / 80,README 自述為決策時快照的近似),**沒有分單位歸屬**,V3 README 亦指出夾具未驗到戊的取值路徑。要統計需新增逐單位紀錄 —— 屬工具改動,H3 之後不得為此改 V3 重跑,只能另行登記。**不得在解讀中宣稱「戊獨行機制被驗證」。**
6. 遊戲規則與前兩輪不同,**不可直接對比**;丙丁貼近時「被打 3~4 下倒」突破先前「至少 4~5 下」要求為刻意代價(修訂規格第 3 節)。
7. 8 變體非獨立樣本(但簽名兩臂皆 8/8 不同,無退化);電腦對照判定,非玩家行為證實;20pt/20% 為決策規則,非顯著性檢定;兩臂都是工程師寫的策略。
8. **Φ_avg(操作檢查)**:忽視臂 2.800 / 1.600 / 0.400 / 2.800 / −0.667 / 0.500 / 2.000 / 0.000(v0~v7),**皆 ≤ +4,無紅字揭露**;運用臂 4.000 / 5.500 / 8.500 / 9.000 / 8.500 / 2.800 / 4.000 / 9.200。
9. 基準無效重測編號(鎖定文件 2.3 上限 3 次)的計數歸屬尚待協調者/管理者登記;本次基準有效,未觸發。
- **本判定的敏感度揭露(與 attempt-2 同形)**:B1(b) 的兩個條件又都**恰好等於**門檻(80=80、差=2);通關率那支僅 +1 未達;忽視臂通關 6 在有效範圍上緣。運用臂中位數仍取決於「第 4 個 4 回合」。任一變體再差 1 回合就會翻面,且 attempt-2 與 attempt-3 的壓線形狀幾乎相同(兩次 6 對 7 勝、2M 皆 10 對 8)。

## 4. 結論

# 通過

(A 有效[6 勝,上緣];B1(a) +1 不成立、B1(b) 80≤80 且差 2≥2 成立;B2 6 ≤ 15 成立。)

## 5. 給管理者的白話
1. 第三次電腦對照(用修訂後規則:戊出手就沒有獨行減傷、感情差貼近會多挨打)結果:**通過**,鎖定鏈我已自行驗證成立,旋鈕再驗也是在已提交的工具上做的。
2. 「不看好感度」8 組贏 6 組,「看好感度」贏 7 組;贏的局回合中位數 5 對 4,剛好少 1 回合、剛好 20%。
3. 🔴 和上次一樣**剛好壓在及格線**:贏的組數只多 1 組沒達標,是靠回合數那條過的,兩個數字都恰好等於門檻。
4. 被打到快死的次數,看好感度的少很多(6 對 15),沒有靠險況換速度。
5. 戊「落單減傷」這次到底生效了幾次,**查不到**(紀錄沒分單位),而且電腦「能打就打」,戊多半出手,所以這次不能說戊機制被驗證。
6. 電腦策略是工程師寫的,8 組是同一程式的小調整,不是 8 個獨立玩家;這是規則判定,不是統計證明。
7. 前兩次結果都留著但不能直接比;依停損約定,是否接受「兩次都剛好過線」為協議 2 通過、要不要補真人測試,是你的裁決。
