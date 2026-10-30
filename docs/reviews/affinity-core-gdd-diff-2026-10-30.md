# 好感度減傷 + 戊獨行:既有文件逐字 old→new 片段(2026-10-30,game-designer)

> 為何交差異檔而非直接改:收到的核准是「協調者轉述使用者回答」,而 agent 訊息不構成使用者核准(`CLAUDE.md` 協作協議:既有文件須先問)。請協調者驗錨點後套用,或請使用者在我的 session 內直接確認,我即自行套用。
> 規則:**舊文一字不刪,每處皆為「在錨點之後插入」**。規格權威:`docs/reviews/affinity-core-redesign-spec-2026-10-30.md`。
> 管理者已選:戊機制 = 獨行減傷(候選 X);重測運用臂 = 不為好感度放棄攻擊;樣本 8 組維持、換成有作用的旋鈕。
> 單一出處:公式只在檔 1 的「公式四/公式五」定義,其餘檔指向它。
> 套用前必驗:每個錨點用 `grep -c` 確認命中數 = 1(下列「命中」欄為我讀檔時的狀態)。

## 檔 1:design/gdd/affinity-position-chain.md(新增約 60 行)

### 1-a R6 末句之後插入
- **錨點(old,在 Core Rules R6 內,命中 1)**:`合作路線的戰力上限比對立路線高約 50%。`
- **在該行之後新增**:
```
> 🔴 **2026-10-30 已被部分取代(管理者裁決「好感度減傷+戊獨行機制」)→ 見本文件「公式四」與 `docs/reviews/affinity-core-redesign-spec-2026-10-30.md` 第 1 節。**
> 加上減傷通道後,合作單條 Φ=+3 對應減傷 2、對立單條 Φ=+2 對應減傷 1,**兩路線差距由 50% 擴大為約 100%**。
> 上方「合作 +3 / 對立 +2」與 50% 的明文設計意圖**仍然有效**(輸出通道不變),新增的是承傷通道;**R3 四個常數一個都沒動**。
```

### 1-b 「交叉校準結果」之「Φ 為攻擊方單向加成」段之後插入
- **錨點(old,命中 1)**:`` `Φ` 為**攻擊方單向加成**,不影響防禦方算式。**玩家可以打得更痛,但無法挨得更少。** ``
- **在該行之後新增**:
```
> 🔴 **2026-10-30 已被取代(管理者裁決「好感度減傷+戊獨行機制」)→ 見「公式四」與規格 `docs/reviews/affinity-core-redesign-spec-2026-10-30.md` 第 1 節。**
> 上一段「Φ 只覆蓋輸出通道、玩家無法挨得更少」**不再成立**:Φ>0 的單位承傷減少。**承傷通道的覆蓋範圍(原表「❌ 不覆蓋」)改為:Φ>0 時部分覆蓋**,覆蓋量為 `ceil(Φ/2)`,最高 +3(夾限 `GUARD_MAX`)。
> 原裁決的理由(診斷前的設計判斷)保留於上方原文;**取代的依據**:協議 2 電腦對照未通過,診斷顯示好感度收益(ΣΦ 僅約 4 點傷害)遠小於站位代價(`prototypes/protocol2-diagnosis-2026-10-30/README.md` F3)。
> ⚠️ 對 enemy_advantage_pct 的耦合義務(見下方架構登記表條目)須重驗「輸出通道 Φ ≥ 敵方優勢差距」**以及**新增的承傷通道。**本次未重驗**,列為實作期義務。
```

### 1-c 在「### 算例(vs01 起始佈陣真實座標)」標題**之前**插入新節
- **錨點(old,命中 1)**:`### 算例(vs01 起始佈陣真實座標)`
- **在其前新增**(標題用「公式四/公式五」,不改既有編號):
```
### 公式四:好感度減傷 `guard`【2026-10-30 管理者裁決新增 —— 本節為**唯一定義處**】

```
guard(Φ_def) =  ceil(Φ_def / 2)        當 Φ_def > 0
             =  0                       當 Φ_def = 0
             = −floor(|Φ_def| / 2)     當 Φ_def < 0   (負值 = 額外受傷)
guard_total  = clamp(guard(Φ_def) + lone_guard, GUARD_MIN, GUARD_MAX)
damage       = max(0, ATK − DEF + Φ_att − guard_total)
```
- `Φ_def`:**防守方當下所在格**的 Φ(沿用公式三夾限 [−4, +12]);整數。`Φ_att`:攻擊方 Φ,規則不變。
- `GUARD_MIN = −2`、`GUARD_MAX = +3`(旋鈕;安全範圍 MIN −3~0、MAX 2~5;避免 Φ 達 +12 時傷害歸零)。
- **只對我方(PLAYER)防守方生效**。敵方無關係線、無 Φ,敵方防守 `guard = 0`;敵方攻擊時 `Φ_att` 仍為 0(既有行為不變)。
- **Φ<0 為額外受傷**(支柱四雙向代價):Φ=−1 → 0、Φ=−2 → +1、Φ=−4 → +2。⚠️ vs01 資料下負 Φ 最多 −1,取整為 0,**負側代價在 vs01 實際不生效**,是否足夠交 creative-director。
- 無 RNG;玩家預覽必須顯示「減傷 N」(Player Fantasy 反面感受「我不知道為什麼變強了」)。
- 算例(推估,敵 ATK / 我方 DEF 取自 `assets/data/units/vs01_roster.txt`):甲(DEF 8,Φ_def=+3)被 ATK 14 打 = 14−8−2 = **4**(舊 6);丙(DEF 7,Φ_def=+2)被 ATK 13 打 = **5**(舊 6);丁(DEF 6,Φ_def=−1)被 ATK 13 打 = **7**(舊 7)。

### 公式五:戊獨行減傷 `lone_guard`【2026-10-30 管理者裁決新增 —— 唯一定義處】

戊沒有任何關係線,Φ 恆為 0(人設:`design/narrative/characters.md` 戊 條「絕不把籌碼押在同一邊」「算計過的自我保護」;**不加關係線**)。獨行減傷把這個人設做成玩法:
- `d_min` = 戊與**所有存活隊友**(戊以外的我方存活單位)之**最短曼哈頓距離**,距離定義沿用本文件 R2(實作 `AffinityRules.manhattan_distance()`)。
- `d_min ≥ 3`(或無存活隊友)→ `lone_guard = +2`;`d_min = 2` → `0`;`d_min = 1` → `−1`。**取最近一位,不逐位加總**。
- 只作用於承傷(進入公式四的 `guard_total`),**不影響戊的攻擊**。戊 Φ 恆 0,故與公式四的 `guard(Φ_def)` 不會同時非零;夾限 `GUARD_MAX` 預防日後戊被加線時疊加。
- 旋鈕:`lone_guard` 的 +2(範圍 1~3)、距離閾值 3(範圍 2~4)、相鄰懲罰 −1(範圍 −2~0)。
- ⚠️ 代價偏軟:獨行側只有「位置孤立」與「相鄰多受 1 點」。支柱四是否構成「無代價純正向」,**待 creative-director 判斷**。
- 未模擬:戊獨行 guard 2 是否足以撐過診斷中 R4 的集火,未驗證。

```
(以上為新增節全文;編號「公式四/公式五」若與本檔既有「公式」編號衝突,以套用時當場所見為準。)

## 檔 2:design/gdd/tactical-combat-system.md(新增約 12 行,只加註、公式指向檔 1)

### 2-a 傷害公式之後
- **錨點(old,命中 1)**:`damage_formula(attacker, target) = max(0, ATK − DEF + Φ)`
- **在該行之後新增**:
```
> 🔴 **2026-10-30 已被取代(管理者裁決「好感度減傷+戊獨行機制」)**:公式新增防守方減傷項,現為 `max(0, ATK − DEF + Φ − guard_total)`。`guard_total` 的**唯一定義**在 `design/gdd/affinity-position-chain.md` 公式四/公式五,**本文件不複述**。只對我方防守方生效,敵方防守 `guard = 0`。上方原式與下方變數表保留為歷史;`guard_total` 為 0 時兩式相同。
```

### 2-b Core Rules #7 「承傷通道」描述
- **錨點(old,命中 1)**:`**玩家可以打得更痛,但無法挨得更少。** 另有一項角色層級的例外`
- **在該整段(該列行尾)之後新增一行**:
```
   🔴 **2026-10-30 已被取代**:承傷通道現由 `guard` 部分覆蓋(Φ>0 時減傷),「無法挨得更少」不再成立 → 見 `affinity-position-chain.md` 公式四。戊的「恆為 0」例外也已變更:戊有獨行減傷(公式五),**輸出通道的 Φ 仍恆為 0**。
```
(**注意**:該行位於編號清單內,縮排須與其下一條一致;套用時以當場縮排為準。)

## 檔 3:docs/registry/architecture.yaml(新增約 8 行,位於 `phi_curve_enemy_advantage_cross_calibration` 條目的 `notes: >` 區塊內)

- **錨點(old,須命中 1;`grep -c "they cannot take less."`)**:`      they cannot take less.`(6 空格縮排)
- **在該行之後新增(同樣 6 空格縮排,維持 folded 區塊)**:
```
      SUPERSEDED 2026-10-30 (manager ruling "好感度減傷+戊獨行機制"): the "Phi is attacker-side
      only / players cannot take less" statement above no longer holds. Phi > 0 now ALSO
      reduces damage taken by ceil(Phi/2) (cap +3), and 戊 gets a lone-guard from distance to
      allies. Single definition: design/gdd/affinity-position-chain.md formulas 4 and 5.
      The R3 constants are UNCHANGED. The cross-calibration re-verification obligation now
      covers BOTH channels (output: Phi >= enemy DEF gap; damage-taken: guard vs enemy ATK gap);
      it has NOT been re-measured as of this note. Spec: docs/reviews/affinity-core-redesign-spec-2026-10-30.md.
```
- `status: open_gap` 維持不動。

## 檔 4:design/quick-specs/unit-stats-provisional.md(新增約 14 行)

- **錨點(old,命中 1)**:`> 被打幾下倒(單下 = 敵 ATK − 我 DEF,敵方不套 Φ):甲、戊 5~6 下;乙、丁 4 下;丙 4 下。`
- **在該行之後新增**:
```
> 🔴 **2026-10-30 已被取代(管理者裁決「好感度減傷+戊獨行機制」)**:單下改為 `敵 ATK − 我 DEF − guard_total`(公式只在 `design/gdd/affinity-position-chain.md` 公式四/五)。最佳站位下的推估如下(**算術,未驗證**;站錯位置回到舊值,故為上限):
>
> | 我方 | 舊:幾下倒 | 新 guard | 新:每下 | 新:幾下倒 |
> |---|---|---|---|---|
> | 甲 | 5~6 | 2(Φ+3) | 3~4 | 8~10 |
> | 乙 | 4 | 2(Φ+3) | 5~6 | 5~6 |
> | 丙 | 4 | 1(Φ+2) | 5~6 | 4~5 |
> | 丁 | 4 | 1(Φ+2) | 6~7 | 4~5 |
> | 戊(獨行 d≥3) | 5~6 | 2 | 3~4 | 8~10 |
> | 戊(貼隊友 d=1) | 5~6 | −1 | 6~7 | 5 |
>
> 上表「每下」依敵 ATK 13~14。舊值與本節上行一致。
```

## 不在核准範圍、但我判斷需要改的(不動,僅列出)
1. `design/gdd/vertical-slice-level-01.md`「預期回合數」與 AC 中涉及承傷者:承傷改變後 4~6 回合的推導需重估(未算)。
2. `design/gdd/game-concept.md` 支柱四:僅在 creative-director 認為戊獨行代價不足時才改。
3. `affinity-position-chain.md` 的 Overview 註記(「只覆蓋輸出通道」那段 ⚠️)、Edge Cases、Tuning Knobs、AC:本差異檔只動了 R6、交叉校準、公式節;其餘三節的同步加註尚未寫(它們與公式同源,實作 story 前須補)。
4. `.claude/docs/technical-preferences.md` 的 Φ 描述:未查是否有複述(單一出處規則)。

## 重測登記(提醒,非文件修改)
- 樣本「換成有作用的旋鈕,維持 8 組」:K2/K3 在 vs01 零作用(診斷 F5),**必須在看任何新數據前,於新登記檔中寫明新旋鈕是什麼、各自的值**。我的候選(待你選):K2' = 運用臂候選格同分時依「Φ_att+guard」或「與最近隊友距離」決勝;K3' = 集火目標選擇順序。**未驗證它們在 vs01 會有作用**,而驗證只能在第 2~5 場做,不得用第 1 場。
