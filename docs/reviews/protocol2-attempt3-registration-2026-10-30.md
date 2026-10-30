# 協議 2 attempt-3 登記(2026-10-30,qa-lead)

> 本檔被提交的 commit 即 **H3**。H3 之後本檔任何規則/數字不得改動。
> 護欄:撰寫時未執行任何對戰,未讀 attempt-3 任何數據。已讀:規格修訂 `docs/reviews/affinity-core-redesign-spec-amend1-2026-10-30.md`(下稱「修訂規格」)、attempt-2 登記 H2 `1275bfa` 與其判定。
> 裁決逐字(協調者轉述):「**照建議補代價,重新登記重測(推薦)**」(被跳過:保住通過、登記邊緣待補 / 只補負向進位)。

## 1. 沿用與定義

**沿用(一字不改,指過去不複述)**:
- 門檻:H=`20e0854` 的 `docs/reviews/protocol2-threshold-locked-2026-10-30.md` 全部數字與判定規則。
- 運用臂四步驟、忽視臂、K1/K2/K3 旋鈕、12 回合上限、瀕死定義、變體編號與簽名驗收:全部沿用 H2(`docs/reviews/protocol2-attempt2-registration-2026-10-30.md` 第 3、4 節,**提交版文字**,含其中「步驟 1、2、4 兩臂皆適用,僅步驟 3 為運用臂獨有」的更正)。
- 本輪改的是**遊戲規則**(戊獨行改條件式、負向 Φ 進位),不是運用臂。

**遊戲規則數值/定義凍結於 H3**(出處:修訂規格第 1、2 節):`guard(Φ)=sign(Φ)×ceil(|Φ|/2)`(正負對稱);`GUARD_MIN=-2`、`GUARD_MAX=+3`;`lone_guard` 原值(d_min≥3→+2、=2→0、=1→-1、無隊友→+2)不變;`lone_guard_eff = 戊上個我方階段出過手 ? min(lone_guard, 0) : lone_guard`;「出手」= 戊於該我方階段作為攻擊方完成至少一次攻擊結算;旗標每個我方階段開始清除;敵方先手首階段視為未出手;貼隊友 −1 不條件化。**story-033 實作者與 V3 作者均不得改動任何數值或定義**;第 2 場驗證顯示爆表時,停下回報管理者,不得就地調整(調整 = 新一輪登記)。

**步驟 3 的 `guard_total(t)` 在新規則下的取值(定義,寫死)**:運用臂步驟 3 為戊計算 `guard_total(t)` 時,以「戊本回合是否會出手」作為正式查詢的輸入,**只用決策當下已知資訊**:
- 若步驟 2 的過濾**實際生效**(`can_attack` 為真且候選池內存在可攻擊格,池已縮成可攻擊格)⇒ 視為**會出手**(旗標=真)⇒ 獨行正向為 0,即 `lone_guard_eff = min(lone_guard, 0)`;
- 否則(`can_attack` 為假,或池內無任何可攻擊格,步驟 2 未過濾)⇒ 視為**不出手**(旗標=假)⇒ 完整值。
- 其他單位(甲乙丙丁)不受旗標影響;`guard(Φ)` 用修訂後的進位版正式函式。
- 🔴 **仍不得自行重刻公式**:story-033 必須提供公開查詢(例如 `lone_guard_if_at(unit_id, tile, will_attack: bool)`,簽名由 story-033 定)與修訂後的 `CombatRules.guard`;V3 只呼叫。若正式介面沒有「假設出手」參數,**停下回報**,不得在工具內自製替代。

**判斷:這是「定義既有步驟」,不是「改運用臂」。** 理由:(1) 步驟順序、步驟 2 的攻擊優先過濾、步驟 3 的目標函數 `Φ(t)+guard_total(t)`、步驟 4 決勝,**全部不變**;(2) 新規則引入了 H2 當時不存在的輸入(出手旗標),H2 寫的是「正式函式對該單位站在 t 的結果」,沒有旗標可供取值,必須有一條取值規則才可執行,否則 ai-programmer 會得到裁量空間;(3) 取值只用當回合已知資訊、與遊戲判準一致,**沒有新增策略**(運用臂仍不為保住 +2 而放棄出手,修訂規格第 4 節明示那是新策略須另行登記);(4) 這是兩臂在新遊戲規則下同一函式的忠實求值,不是調整策略強度。誠實附註:此取值**會改變戊的實際選位**(不再追 +2),但那是遊戲規則改變的直接後果(H2 的字面做法在新規則下會對「不會發生的狀態」求值),不是策略改動。若協調者或管理者認為取值規則本身屬「運用臂改動」,交管理者裁決,在裁決前不得開工 V3。

## 2. 揭露(必須隨 attempt-3 結果一併呈現)
1. **兩個舊結論永久保留**:attempt-1「未通過」(`production/qa/protocol2/computer-attempt-1-20261030T0120Z/VERDICT.md`)、attempt-2「通過(壓線)」(`.../computer-attempt-2-20261030T0342Z/VERDICT.md`),檔案不得改寫。
2. **attempt-3 是因支柱審查而改規則,不是因數據**(`docs/reviews/lone-guard-pillar4-review-2026-10-30.md`)。
3. **attempt-3 若未通過,不得回頭採用 attempt-2 的結果。** 我**同意**此判讀。理由:attempt-2 的規則已被裁決為違反設計原則,以其為協議 2 判定等於選擇性採信對假說有利的一次;且停損約定(`production/milestones/one-year-plan.md` 第五節)要求判定可追溯到一組固定規則,不能事後換。attempt-2 之後僅作歷史紀錄。未通過時,停損判定依 attempt-3 呈管理者,**本輪不自動授權 attempt-4、不授權再改運用臂或遊戲規則重跑**,須新的管理者裁決。
4. **運用臂本輪仍是 H2 同一定義**;H2 第 2 節第 3 點(attempt-2 之後不得再改運用臂)**繼續有效**。
5. **戊的 +2 在本輪幾乎不會生效**:兩臂步驟 2 都「能打就打」(忽視臂亦然),戊多數回合會出手 ⇒ 獨行正向被關閉(設計師自述,修訂規格第 4 節)。本輪主要測的是甲乙丙丁的減傷與負向進位,戊條件式是兩臂共同承受的規則。**不得在結果解讀中宣稱「戊獨行機制被驗證」。**
6. 遊戲規則與 attempt-2 不同 ⇒ **attempt-3 與前兩輪不可直接對比**;「被打幾下倒」表在丙丁貼近兩列突破管理者先前「至少 4~5 下」要求(修訂規格第 3 節),為刻意代價,管理者已知。
7. 沿 H2 第 2 節與鎖定文件 2.4:電腦對照判定、8 變體非獨立樣本、Φ_avg 只作操作檢查(忽視臂 >+4 紅字揭露、不重新分組)。
8. 鎖定文件 2.3 的「基準無效重測最多 3 次」計數如何與本輪編號相處,**尚待協調者/管理者登記**(本檔不自行裁定);若本輪遇基準無效,先停下回報。

## 3. 執行順序與防污染
順序:**H3 → story-033 提交 S3 → V3 → 第 2 場旋鈕再驗 → 第 1 場 R3**。
- **V3**:放新目錄 `prototypes/protocol2-computer-measure-v3/`(複製自 v2,不改舊檔)。只允許的改動:(a) 步驟 3 為戊傳入「會出手」假設(第 1 節規則);(b) 為配合 story-033 新介面所需的呼叫簽名/provider 掛接;(c) HEADER 標籤。README 逐項列出改動理由;**diff 須可審**,審查者以下列指令確認沒有其他改動:`git diff --no-index --stat prototypes/protocol2-computer-measure-v2 prototypes/protocol2-computer-measure-v3`。V3 之前不得在 vs01 執行。
- **第 2 場旋鈕再驗**:只在 vs02,兩臂各 8 組,標準與失敗處置**沿用 H2 4.1**(簽名 ≥4 種;不足依 R1→R2→R3 固定順序替換 K3,最多 3 次;全用盡仍不足則照跑並列「有效不同變體數 = n」)。attempt-2 未使用任何備援,**備援額度對 V3 視為重新起算**。輸出存 `production/qa/protocol2/knob-verify-vs02-<UTC>/raw_stdout.txt`(含 `ENGINE EXIT`、`DONE`、16 行 RESULT、`SIGSUM`)。驗證在工具已提交之後做(避免 attempt-2 那種「驗證時工作樹未提交」的弱點);若發生旋鈕替換,`<V3>` 取最後一次替換後的提交並在 RUN-INFO 列全部提交。
- **第 1 場**:R3 之前任何人不得以新規則(新 guard 進位、戊條件式、V3)執行 vs01,含試跑;除錯只准夾具與 vs02。
- 結果放 `production/qa/protocol2/computer-attempt-3-<UTC>/`(原始 stdout 全文 + `RUN-INFO.md`,記 H3、S3、V3、build commit、引擎版本、指令、`ENGINE EXIT`、RESULT 行數、`DONE`;exit 非 0 或缺 `DONE` = 作廢並登記,見 `.claude/docs/coding-standards.md` CI 節 exit 105)。重跑僅限工具故障,原 log 保留。判定由 qa-lead 依鎖定文件與本檔做,再交管理者。

可貼指令(`<H3>`、`<S3>`、`<V3>`、`<R3>` 以實際 hash 取代;須 exit 0 或指定輸出):
```bash
git log -1 --format=%H -- docs/reviews/protocol2-attempt3-registration-2026-10-30.md   # 必須等於 <H3>
git merge-base --is-ancestor <H3> <S3> && echo ok-H3-S3
git merge-base --is-ancestor <H3> <V3> && echo ok-H3-V3
git merge-base --is-ancestor <S3> <V3> && echo ok-S3-V3
git merge-base --is-ancestor <V3> <R3> && echo ok-V3-R3
git log --diff-filter=A --format='%h %cI' -- production/qa/protocol2/computer-attempt-3-*   # 首次提交 = <R3>
git diff --stat <V3> <R3> -- prototypes/protocol2-computer-measure-v3/ src/ docs/reviews/protocol2-attempt3-registration-2026-10-30.md   # 必須為空
git diff --stat 20e0854 <R3> -- docs/reviews/protocol2-threshold-locked-2026-10-30.md                                                  # 必須為空
git diff --stat 1275bfa <R3> -- docs/reviews/protocol2-attempt2-registration-2026-10-30.md                                             # 必須為空
```
旋鈕再驗輸出的首次提交須為 `<V3>` 的後代(`git log --diff-filter=A -- production/qa/protocol2/knob-verify-vs02-*` 取最新者,再 `merge-base --is-ancestor <V3> <該提交>`)。
⚠️ 沒有任何自動檢查會替你跑這些指令;它們只讓「規則早於數據」成為第三方可自行查證的事實。

## 4. 給管理者的白話
1. 這是第三次電腦對照:不是因為數據,而是因為「戊落單減傷」被判定太便宜,所以規則改成「戊出手了就沒有」,感情差的人貼近也真的會多挨打。
2. 過關標準、電腦的打法、8 組變化全部不動;只有遊戲規則改了,所以前兩次結果都留著但不能直接比。
3. 這次若沒過,不能回頭用上次的「通過」;上次那條規則已被判違反設計原則。
4. 電腦是「能打就打」,所以戊的新代價這次幾乎測不到,主要測另外四人的減傷。
5. 一件請你知道的事:我判斷「電腦怎麼估戊會不會出手」只是在新規則下把原步驟照實算,不算改打法;你若不同意要先說,否則不開工。
