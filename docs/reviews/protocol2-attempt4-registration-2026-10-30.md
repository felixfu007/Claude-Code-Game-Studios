# 協議 2 attempt-4 登記(2026-10-30,qa-lead)

> 本檔被提交的 commit 即 **H4**。H4 之後本檔任何規則/數字不得改動。
> 護欄:撰寫時未執行任何對戰、未讀 attempt-4 任何數據;已讀規格修訂 `docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`(下稱「修訂 2」)與 H2、H3 登記及其判定。
> 裁決逐字(協調者轉述):「**騎牆+留一手(推薦)**」、「今天做到哪算哪,未完下次接(推薦)」。前置事實(協調者轉述,**我未重讀來源**):attempt-3 事後診斷戊 +2 生效 0/28(`prototypes/protocol2-diagnosis-attempt3-2026-10-30/README.md`);創意總監判騎牆+留一手為現行限制下最強形式、但仍屬數值抵扣(`docs/reviews/straddle-pillar4-review-2026-10-30.md`)。

## 1. 沿用與判斷

**沿用(一字不改,指過去不複述)**:門檻 H=`20e0854` 的 `docs/reviews/protocol2-threshold-locked-2026-10-30.md` 全部數字與判定規則;運用臂四步驟、忽視臂、K1/K2/K3 旋鈕、12 回合上限、瀕死定義、簽名驗收:沿用 H2(`docs/reviews/protocol2-attempt2-registration-2026-10-30.md` 第 3、4 節提交版文字)與 H3(`docs/reviews/protocol2-attempt3-registration-2026-10-30.md` 第 1 節)。本輪改的是**遊戲規則**,不是運用臂。

**遊戲規則凍結於 H4**(出處:修訂 2 第 1、2 節,疊在原規格與 amend1 之上):`lone_guard`:d_min=1 → −1;d_min=2 → +2;d_min≥3 或無存活隊友 → 0;**取消出手條件**(`lone_guard_effective` 一律回傳 `lone`);留一手:旗標單位(名冊 `lone_guard=1`)作為攻擊方、**攻擊當下所在格** d_min=2 時最終傷害 −1(`HOLD_BACK_DISTANCE=2`、`HOLD_BACK_PENALTY=1`,`hold_back ∈ {0,1}`,`damage = max(0, ATK − DEF + Φ_att − guard_total − hold_back)`);`guard(Φ)=sign(Φ)×ceil(|Φ|/2)`、`GUARD_MIN=-2`、`GUARD_MAX=+3` 沿用 amend1。**story-034 實作者與工具作者均不得改動任何數值或定義**;第 2 場驗證若顯示爆表,停下回報管理者,不得就地調整(調整 = 新一輪登記)。

**判斷一:運用臂步驟 3 的 `lone_guard_if_at(id, t, will_attack)` 求值,仍屬「定義既有步驟」,不是改運用臂。**
- 理由:(1) 步驟順序、步驟 2 的攻擊優先過濾、步驟 3 目標函數 `Φ(t)+guard_total(t)`、步驟 4 決勝**全部不變**;(2) 變的只是**被呼叫的正式函式在新規則下回傳什麼**(d=2 → +2、d≥3 → 0),與 attempt-3 同形(遊戲規則改變了函式輸出,策略公式照實求值);(3) 修訂 2 把 `will_attack` 保留為**被忽略的棄用參數**,H3 第 1 節「出手假設」取值規則因此**失效但無害**:V3 仍會傳入該參數,結果不受影響。H3 第 1 節那條取值規則在本輪**不再適用**(取消出手條件),以本節為準。
- 誠實附註:此求值**會改變戊的實際選位**(運用臂將偏好 d=2 的格,因該處 +2 減傷),但那是規則改變的直接後果,不是策略改動;與 attempt-3 的處理一致。

**判斷二:運用臂 score **不納入**留一手(`hold_back`)。** 理由:`hold_back` 是攻擊側扣減,不屬於 `Φ(t)` 也不屬於 `guard_total(t)`(H2 步驟 3 的 score 只含這兩項);把它加進 score 等於新增一個評分項 = **改策略**,H2 第 2 節第 3 點禁止。
- **後果必須揭露**:運用臂看不見留一手,可能為了 d=2 的 +2 減傷而站到 d=2 出手,**自己打得較輕卻不自知**(對運用臂不利、偏向假說不成立,屬保守方向)。忽視臂同樣不看,可能巧合站 d=2。兩臂的**引擎結算**皆照新規則(留一手由遊戲結算處理,不經策略)。若結果因此未通過,**不得**為此修改運用臂重跑,只能登記限制並交管理者裁決。
- 補充:`_focus_pick` 內以 `preview_damage(p.id, e.id, 0)` 估傷害,屬兩臂共用的正式函式,不是策略改動;其對戊以「當前站位」而非候選格估算的近似,兩臂相同,不另處理。

## 2. 揭露(必須隨 attempt-4 結果一併呈現)
1. **三個舊結論永久保留**:attempt-1「未通過」、attempt-2「通過(壓線)」、attempt-3「通過(壓線)」(各自 `production/qa/protocol2/computer-attempt-<N>-*/VERDICT.md`),檔案不改。
2. **attempt-4 未通過時,不得回頭採用 attempt-3(或 attempt-2)的結果**(管理者已被告知)。理由同 H3 揭露 3:停損判定須可追溯到一組固定規則,且 attempt-3 的戊規則已被事後診斷與創意總監審查認定為實質無效。未通過時,停損判定依 attempt-4 呈管理者,**本輪不自動授權 attempt-5、不授權再改運用臂或遊戲規則重跑**,須新的管理者裁決。
3. **attempt-4 為主動重設計,不是數據驅動**:起因是 attempt-3 事後診斷與創意總監審查,**我登記時未看任何 attempt-4 數據**。
4. 創意總監判「騎牆+留一手」為現行限制下最強形式,**但仍屬數值抵扣**(協調者轉述);本輪**不得**在結果解讀中宣稱「戊的支柱四問題已解決」。
5. 設計師自述風險:戊打得較輕,傾向拉長回合數;attempt-3 為壓線通過,**翻面風險高**(修訂 2 第 4 節)。此預期已在登記時寫明,結果不利時不得視為意外。
6. 遊戲規則與前三輪不同 ⇒ **不可直接對比**。attempt-2/3 都在 B1(b) 的 80=80、差=2 的刀口,兩次忽視臂 6 勝;沿鎖定文件 2.4:電腦對照判定、8 變體非獨立樣本、Φ_avg 只作操作檢查(忽視臂 >+4 紅字、不重新分組)。
7. 鎖定文件 2.3「基準無效重測最多 3 次」的計數歸屬仍待協調者/管理者登記;若本輪遇基準無效,先停下回報。

## 3. 執行順序與防污染
順序:**H4 → S4(story-034 規則程式提交)→ 工具確認(V4)→ vs02 旋鈕再驗 → 第 1 場 R4**。story-034 目前「進行中、未提交」:允許先寫,但**提交必須在 H4 之後**,且其數值須與第 1 節凍結值逐項一致(以測試證明);第 1 場在 R4 之前任何人不得以新規則執行,含試跑;除錯只准夾具與 vs02。
- **V4 的處置(寫死)**:預設 **V4 = V3 不變、只重跑**。理由:V3 對 `lone_guard_if_at(unit_id, tile, will_attack)` 的唯一呼叫簽章在修訂 2 中**保留不變**(`will_attack` 保留但被忽略),其餘改動(進位版 `CombatRules.guard`、`hold_back`)由正式函式在引擎內處理,工具未重刻。**條件**:S4 之後以 V3 在夾具與 vs02 能編譯、能跑。若不成立(編譯失敗或簽章改變)⇒ 停下回報;允許產生 **V4**,僅限修正呼叫簽章/掛接的最小改動,**diff 須可審**(`git diff --no-index --stat prototypes/protocol2-computer-measure-v3 prototypes/protocol2-computer-measure-v4`),且不得動策略;是否核准由管理者/協調者決定。
- **旋鈕再驗**(只在 vs02;標準與失敗處置沿用 H2 4.1:每臂簽名 ≥4 種;不足依 R1→R2→R3 固定順序替換 K3,最多 3 次;備援額度對本輪視為重新起算):必須在**已提交的工具(V3 或 V4)與 S4 之後、於乾淨 worktree** 執行,輸出存 `production/qa/protocol2/knob-verify-vs02-v4-<UTC>/raw_stdout.txt`(含 `ENGINE EXIT`、`DONE`、16 行 RESULT、`SIGSUM`),且 HEADER 的 `build_commit` 須為 S4 的後代。
- 結果放 `production/qa/protocol2/computer-attempt-4-<UTC>/`(原始 stdout + `RUN-INFO.md`,記 H4、S4、工具提交、build commit、引擎版本、指令、`ENGINE EXIT`、RESULT 行數、`DONE`;exit 非 0 或缺 `DONE` 作廢並登記,見 `.claude/docs/coding-standards.md` CI 節 exit 105)。判定由 qa-lead 依鎖定文件與本檔做,再交管理者。

可貼指令(`<H4>`、`<S4>`、`<T>`=工具提交 V3 `47465aa`(或 V4)、`<B4>`=執行時的提交、`<R4>`=結果檔首次提交;皆須 exit 0 或指定輸出):
```bash
git log -1 --format=%H -- docs/reviews/protocol2-attempt4-registration-2026-10-30.md   # 必須等於 <H4>
git merge-base --is-ancestor <H4> <S4> && echo ok-H4-S4
git merge-base --is-ancestor <S4> <B4> && echo ok-S4-B4
git merge-base --is-ancestor <T>  <B4> && echo ok-T-B4
git merge-base --is-ancestor <B4> <R4> && echo ok-B4-R4
git log --diff-filter=A --format='%h %cI' -- production/qa/protocol2/computer-attempt-4-*   # 首次提交 = <R4>
git diff --stat 47465aa <B4> -- prototypes/protocol2-computer-measure-v3/   # V4=V3 時必須為空
git diff --stat <B4> <R4> -- prototypes/ src/ docs/reviews/protocol2-attempt4-registration-2026-10-30.md   # 必須為空
git diff --stat 20e0854 <R4> -- docs/reviews/protocol2-threshold-locked-2026-10-30.md   # 必須為空
```
旋鈕再驗輸出的首次提交須為 `<B4>` 之前的祖先或同為其祖先鏈上、且早於 `<R4>`;其 HEADER `build_commit` 須能以 `git merge-base --is-ancestor <S4> <該 hash>` 通過。⚠️ 沒有任何自動檢查會替你跑這些指令。

## 4. 給管理者的白話
1. 第四次電腦對照:戊改成「離隊友剛好 2 格挨打少 2 點、貼身多挨 1 點、落單沒減傷」,而且在那 2 格出手時少打 1 點。過關標準、電腦打法、8 組變化全不動。
2. 電腦「用好感度」的打法**看不見**「少打 1 點」(加進去就等於改打法,不准),所以它可能為了少挨打而打得較輕;這對假說不利,也是這次可能翻成不通過的原因之一。
3. 這次若沒過,不能回頭用上次的「通過」;也不自動再開第五次,要你裁決。
4. 前三次結果都留著但不能直接比;就算這次又過,創意總監仍認為戊的代價只是「數值抵扣」。
5. 電腦工具預計不用改,只重跑(前提:規則程式完成後能照常執行);不成立就停下來問你。
