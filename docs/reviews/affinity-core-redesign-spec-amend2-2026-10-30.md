# 規格修訂 2:戊「騎牆 + 留一手」(2026-10-30,game-designer)

> 依據:管理者裁決「騎牆+留一手(推薦)」,creative-director `docs/reviews/straddle-pillar4-review-2026-10-30.md` 第三節,我的 `docs/reviews/lone-wolf-redesign-options-2026-10-30.md` 候選 1。
> 只寫**相對 amend1 的修訂**;其餘以原規格 `affinity-core-redesign-spec-2026-10-30.md` 與 `...-amend1-...` 為準。不改既有檔;推估皆算術、未驗證。
> 已讀:`src/gameplay/combat/combat_rules.gd`、`battle_state.gd` 的 `lone_guard_if_at`(呼叫者:`battle_screen.gd` 傷害預覽、H2 電腦工具)。

## 1. lone_guard 新表(取代 amend1 第 1 節;取消出手條件)

```
d_min = 戊與最近存活隊友的曼哈頓距離(R2,不變)
d_min = 1               → lone_guard = −1      (不變)
d_min = 2               → lone_guard = +2      (原 0)
d_min ≥ 3 或無存活隊友  → lone_guard = 0       (原 +2)
```
- `CombatRules.lone_guard(d_min)` 改:`LONE_FAR_GUARD` 2 → 0;新增 `LONE_MID_DISTANCE = 2`、`LONE_MID_GUARD = +2`;`d_min=NO_ALLY` 走 0 分支。
- **介面去留(建議:保留介面、讓參數不再影響結果)**:`lone_guard_effective(lone, attacked)` 改為**一律回傳 `lone`**;`lone_guard_if_at(unit_id, tile, will_attack=false)` 簽章不變、`will_attack` 保留但**忽略**;`attacked_this_phase` 旗標寫入程式暫留、不被讀取。
  - 理由:UI 預覽與 H2 電腦工具已在呼叫這個簽章,移除會讓兩者編譯失敗,而 H2 規定電腦策略不得改(機械性改簽章也要避免被視為改策略)。
  - ⚠️ 風險:**「看似有用、實際無作用」的參數是陷阱**。必須(a)在三處 `##` 文件註解標「已棄用,忽略」;(b)加一條測試:同輸入下 `will_attack=true/false` 結果相同;(c)開一張後續工作單移除(UI 與工具都改完後)。

## 2. 留一手(新增)

- **規則**:戊**作為攻擊方**結算攻擊時,若**攻擊當下戊所在格**的 `d_min = 2`,該次攻擊最終傷害 **−1**(最小 0)。
- **公式**(進入唯一定義處的傷害式,不經 `Φ_att`):`damage = max(0, ATK − DEF + Φ_att − guard_total − hold_back)`,`hold_back ∈ {0, 1}`。
  - 選「最終傷害減 1」而非「減 ATK」:兩者數學等價(都在 `max(0,…)` 之前),但獨立一項便於預覽列示;**`Φ_att` 對戊仍恆 0**,「戊 Φ 恆為 0」這條既有性質**不必改**(creative-director 原本預期要改,此做法避開)。
- **`d` 取值**:攻擊當下戊的位置(預覽時用游標格 = 假設攻擊格)。只看與**存活隊友**的最近距離;無存活隊友 → 不適用。
- **只對旗標單位**:沿用名冊既有旗標欄(戊的第 12 欄 `lone_guard=1`),**不新增欄位**(避免動 9 份名冊與固定欄位測試)。語意改讀為「騎牆者」。
- **敵方不適用**(敵方無旗標);**我方他人不適用**。
- **數值**:`HOLD_BACK_DISTANCE = 2`、`HOLD_BACK_PENALTY = 1`,與 `LONE_*` 同放 `CombatRules` 常數(現行慣例;專案要求資料驅動,**沿用 `LONE_*` 既有做法,是否改外部資料檔交 gameplay-programmer 與 lead 決定**)。
- 純函式:`CombatRules.hold_back(is_straddler: bool, d_min: int) -> int`(is_straddler 且 d_min==2 → 1,否則 0)。無 RNG。

## 3. 預覽/畫面須同步

- 我方攻擊預覽(`preview_damage_breakdown` 與 `battle_screen.gd` 的預覽面板):細項新增 `hold_back` 欄;戊從 d=2 的格子攻擊時顯示一列「**留一手 −1**」;從 d=1/d≥3 的格子攻擊時**不顯示該列**。
- 承傷預覽沿用既有「獨行 +2/−1」列,現在與出手無關,**移除「出手會失去減傷」提示**(amend1 要求的兩種結果預覽作廢)。
- 傷害預覽與結算走同一函式(AC-G6 精神不變)。UI 版面交 `/ux-design`;headless 取不到像素,須開窗驗證。

## 4. 推估

- 戊被打幾下倒(HP 30/DEF 8,敵 ATK 14/13):d=1:7/6 → **5**;d=2:4/3 → **8~10**;d≥3:6/5 → **5~6**(不再有「落單未出手 8~10」)。
- 戊輸出(ATK 16 對 vs01 敵 DEF 3~6):每下約 10~13 → d=2 時 9~12,約 −8~10%。以敵 HP(E1 23、E2 20、E3 18、E4 22、E5 24)算,**只有 E4(DEF 5、HP 22)由 2 下變 3 下**,其餘擊殺下數不變(算術)。
- 對電腦對照:戊打得較輕,傾向拉長回合數;attempt-3 為壓線通過,翻面風險高(creative-director 已提醒)。

## 5. 對已套用 GDD 的影響(第四批差異清單,本檔不執行)

1. `affinity-position-chain.md` 公式五:觸發表(d≥3 的 +2 → 0、d=2 → +2)、「只作用於承傷…不影響戊的攻擊」一句**不再成立**(留一手影響攻擊)、amend1 條件式加註(diff3 的 1-3)與「代價偏軟」回應加註(1-4)須加註取代;旋鈕行(閾值 3 → 2 的意義)。
2. `affinity-position-chain.md` Edge Cases:戊獨行旗標條目(diff3 2-B2 的出手旗標 bullet)作廢;新增留一手 bullet。「戊 Φ 恆為 0」保留不動。
3. Tuning Knobs:`出手條件(布林)` 列作廢;`lone_guard` 說明改為 d=2;新增 `HOLD_BACK_DISTANCE`(固定 2;範圍 2~3)、`HOLD_BACK_PENALTY`(1;範圍 1~2,>2 時戊攻擊不值得)。
4. AC(diff3 2-D):AC-L1 改為 d=3/2/1 → **6 / 4 / 7**(ATK14、DEF8);AC-L1b、L9~L12 作廢;L4 無隊友 → 傷害 6;AC-L13 改為預覽 `hold_back` 列;**新增** AC-H1~H5:戊 d=2 攻擊(ATK16、敵 DEF6)→ **9**;d=1/d≥3 → **10**;無隊友 → 10;敵方攻擊不受影響;非旗標單位不受影響;`will_attack` 忽略測試。
5. `tactical-combat-system.md` 公式節加註:傷害式新增 `hold_back` 項;前批「戊出手旗標歸戰棋」加註作廢。
6. `unit-stats-provisional.md` 戊列(amend1 加註):改為上述第 4 節數字。`architecture.yaml` AMENDED 註記需再加一則。
7. 程式與測試(估計):`combat_rules.gd`、`battle_state.gd`、`battle_screen.gd` 約 3 檔;釘 story-031/033 條件式者約 10~20 條改寫;新增約 8~12 條。
8. 重測:第四次預先登記;運用臂 score 含 `lone_guard_if_at`(結果變,策略公式不變,請 qa-lead 確認);第 1 場重測前不得用新數值跑。

## 6. 白話

1. 麥子健離最近隊友剛好 2 格(不貼身也不走遠)時,挨打少 2 點;貼身仍多挨 1 點;落單沒有減傷。
2. 新增「留一手」:他站在那 2 格出手時,少打 1 點。想全力打就得貼上去或脫隊。
3. 以前「出手就失去減傷」的規則取消。
4. 推估:他只有打 E4 時要多 1 下,其餘不變;可能讓上次剛好過線的結果翻面。
5. 要第四次登記與重測;今天做不完的部分,下次接。
