# 好感度核心重新設計:規格(2026-10-30,game-designer)

> 性質:規格草案,**待管理者/creative-director 確認後才生效**;未修改任何既有檔案。
> 管理者裁決(2026-10-30,逐字):「好感度減傷+戊獨行機制(推薦)」(選項原文「戈」指戊)。被跳過:只做 B / B+死 2 人才輸 / 只做 A。
> 標註:**(已查)** 讀過檔案;**(推估)** 我的算術,未驗證、未模擬、未跑引擎。來源格式:(檔案「節名」)。
> 前序提案:`docs/reviews/affinity-core-redesign-options-2026-10-30.md`。

## 1. 方案 B 規格:好感度減傷

### 1.1 現況(已查)
- 傷害 = `max(0, ATK − DEF + Φ)`(`src/gameplay/combat/combat_rules.gd` 的 `damage()`)。
- Φ 只算攻擊方;**敵方攻擊時 Φ 強制為 0**(`src/gameplay/battle/battle_state.gd` 的 `_attack_damage_breakdown()`、`battle_loop.gd` 的 `_compute_phi()`)。
- GDD 明文裁決「Φ 為攻擊方單向加成,玩家可以打得更痛,但無法挨得更少」(`design/gdd/affinity-position-chain.md`「交叉校準結果」,標【本次裁決:維持如此】)。🔴 **方案 B 推翻這條已裁決的立場**,管理者此次裁決視為授權,但該節與 OQ-5 須同批改寫,並更新 `docs/registry/architecture.yaml` 的 `phi_curve_enemy_advantage_cross_calibration` 條目(該節自己指定的耦合登記處)。

### 1.2 公式
```
guard(Φ_def) =  ceil(Φ_def / 2)        當 Φ_def > 0
             =  0                       當 Φ_def = 0
             = −floor(|Φ_def| / 2)     當 Φ_def < 0     (負值 = 額外受傷)

damage = max(0, ATK − DEF + Φ_att − guard_total)
guard_total = clamp(guard(Φ_def) + lone_guard, GUARD_MIN, GUARD_MAX)   # lone_guard 見第 2 節
```
- `Φ_def`:**防守方當下所在格**的 Φ(沿用既有夾限 [−4, +12],`src/gameplay/affinity/affinity_rules.gd` 的 `PHI_MIN`/`PHI_MAX`)。整數。
- `Φ_att`:攻擊方 Φ,現行規則不變。
- `GUARD_MIN = −2`、`GUARD_MAX = +3`(旋鈕,範圍:MIN −3~0、MAX 2~5;理由:避免 Φ_def 達 +12 時傷害歸零)。
- 範圍:只對 **PLAYER 防守方** 生效。**敵方沒有 Φ**(現行 `effective_phi` 對敵方攻擊歸零;敵方無關係線),故敵方防守 `guard = 0`。不新增任何敵方 Φ。
- 無 RNG。

### 1.3 Φ < 0 的處理(支柱四)
負 Φ 轉為**額外受傷**(`−floor(|Φ|/2)`):Φ=−1 → 0,Φ=−2 → 受傷 +1,Φ=−4 → 受傷 +2。理由:支柱四「雙向代價硬性約束」要求加成通道擴大時代價通道同步擴大(`game-concept.md`「支柱四:羈絆是雙面刃」);否則「靠近=更強更耐打」比以前更偏單向。
- ⚠️ 取捨:切片資料下負 Φ 最多 −1(正向對分開、負向對貼近),整數捨去後**實際為 0**,負側代價在 vs01 **幾乎不生效**。這與 R3 的 −1 本來就弱一致,但代價面實質仍在「站位受限」,是否足夠需 creative-director 判斷。
- R6(合作 +3、對立 +2 的 50% 差距):合作 guard 2、對立 guard 1,**差距變 100%**(`affinity-position-chain.md` Core Rules R6)。須重新裁決,我的提案:接受(合作路線更強是明文設計意圖)。

### 1.4 算例(推估,敵 ATK 與我方 DEF 取自 `assets/data/units/vs01_roster.txt`)
1. 甲(DEF 8,Φ_def=+3)被 E1(ATK 14)打:14−8+0−2 = **4**(舊 6)。
2. 丙(DEF 7,Φ_def=+2 遠離丁)被 E2(ATK 13)打:13−7−1 = **5**(舊 6)。
3. 丁(DEF 6,Φ_def=−1 貼近丙)被 E4(ATK 13)打:13−6−0 = **7**(舊 7,−1 的 floor 為 0)。

### 1.5 必須同步的點(實作義務)
- 防守方 Φ 的取得:現行 `phi_provider.call(attacker_id, target_id)` 只回攻擊方 Φ(已查);**是否能以反向呼叫或需新增 `phi_of(unit_id)` 未查證**(讀 `affinity_phi_provider.gd`)。這是實作第一件事。
- `BattleState._attack_damage_breakdown()` 要加 `guard`、`phi_def` 欄位;`preview_damage()`、`preview_damage_breakdown()`、`resolve_attack()` 三處共用,改一處即可(已查:三者共用此 helper)。
- AI 傷害預估(`src/ai/` 的 `GreedyTacticalAI`)若自行算傷害須改走同一 helper;UI 傷害預覽(`attack_confirm_panel`、`battle_info_panel`)須顯示「減傷 N」,否則違反 Player Fantasy「我不知道為什麼變強了」(`affinity-position-chain.md`「Player Fantasy」反面感受)。
- 敵方**行動結算**路徑 `BattleLoop` 的 `_compute_phi` 維持敵方 0,但**傷害公式的 guard 項必須在敵方攻擊時也計算**(防守方是玩家)——這是與舊規則最容易漏的一點。

## 2. 戊獨行機制規格

### 2.1 設計依據
- 戊沒有任何關係線(診斷 F2:`vs01_affinity_links.txt` 只有 1-2 正、3-4 負;`prototypes/protocol2-diagnosis-2026-10-30/README.md`)。方案 B 對 Φ=0 的他無效。
- 人設:戊「信奉絕不把籌碼押在同一邊」「中立是算計過的自我保護」「誰都不深交、誰都不得罪」(`design/narrative/characters.md` 戊 條與「戊中立」段)。所以**不加關係線**(中立是核心人設),把「自我保護」做成機制:獨自一人時他最安全。
- 距離定義沿用曼哈頓距離,**不重新定義**:`affinity-position-chain.md` Core Rules R2;實作用 `AffinityRules.manhattan_distance()`(已查)。

### 2.2 候選 X(推薦):獨行減傷,只防不攻
- 觸發:取戊與**所有存活隊友**的最短曼哈頓距離 `d_min`(隊友 = 戊以外的我方存活單位)。
- 效果(只加到 `lone_guard`,不動 Φ_att):
  - `d_min ≥ 3` → `lone_guard = +2`
  - `d_min = 2` → `0`(死區,與 R3 同形)
  - `d_min = 1` → `−1`(取「最近一位」,**不逐位加總**,避免全隊擠在身邊時重罰)
  - 無存活隊友 → `+2`
- 與方案 B 疊加:是。`guard_total = clamp(guard(Φ_def=0)=0 + lone_guard, −2, +3)`;戊 Φ 恆 0,所以兩者實際不會同時非零,**不存在 +2 與 +2 相乘**。若日後戊被加關係線才會疊加,夾限 `GUARD_MAX` 已預防。
- 為何符合人設:他的好處來自「不靠任何人」,貼著隊友反而不自在(算計過的自我保護)。
- **代價(支柱四)**:d_min=1 時承傷 +1;獨行時雖耐打,但**離隊友 ≥3 格無人互相掩護、也拿不到任何關係線 Φ**(他本來就沒有,所以此代價是「位置上的孤立」而非數值損失)。⚠️ 誠實:獨行側的代價比較軟,**需 creative-director 判斷是否構成「不得無代價純正向」**;我的看法是「被圍攻時無人支援」是真實戰術代價,但可被玩家忽略。

### 2.3 候選 Y:獨行加攻加防(走 Φ 通道)
- 同樣觸發距離,但把結果寫成戊的 Φ:`d_min ≥3 → Φ_戊=+2`;`=1 → −1`;`=2 → 0`,經 B 的公式自然得到攻擊 +2 與 guard 1。
- 優:不另開通道,UI 現有 Φ 預覽、AI 分數、關係小地圖全部沿用;戊會更願意打。
- 缺:戊獨行最強 = 他前衝得更猛,**加深了診斷裡「戊被甩出陣型」這個現象**;guard 只有 1(Φ=+2),耐打度不足以解決集火(推估:見 3 節);且「獨行=攻擊加成」較不像「自我保護」。
- 支柱:代價同 X。

### 2.4 推薦
**X。** 一句話:戊落單時變成「難打的前鋒」(承傷 −2),貼著隊友則稍脆弱(+1),性格就是玩法,且不改敘事、不加關係線。數值 `lone_guard` 為旋鈕:+2 範圍 1~3,d_min 閾值 3 範圍 2~4。**未模擬。**

## 3. 「被打幾下倒」新舊對照(推估,算術)

單下傷害 = 敵 ATK − 我 DEF − guard。敵 ATK 為 13 或 14;我方 HP/DEF 取自 vs01 名冊(已查)。Φ 取各人最佳佈局(甲乙相鄰=+3;丙丁相距 ≥3=+2);戊獨行 guard=+2。

| 我方 | HP/DEF | 舊:每下 | 舊:幾下倒 | 新 guard | 新:每下 | 新:幾下倒 |
|---|---|---|---|---|---|---|
| 甲 | 30/8 | 5~6 | 5~6 | 2(Φ+3) | 3~4 | **8~10** |
| 乙 | 26/6 | 7~8 | 4 | 2(Φ+3) | 5~6 | **5~6** |
| 丙 | 22/7 | 6~7 | 4 | 1(Φ+2) | 5~6 | **4~5** |
| 丁 | 26/6 | 7~8 | 4 | 1(Φ+2) | 6~7 | **4~5** |
| 戊(獨行) | 30/8 | 5~6 | 5~6 | 2(獨行) | 3~4 | **8~10** |
| 戊(貼隊友 d=1) | 30/8 | 5~6 | 5~6 | −1 | 6~7 | **5**(30÷7=4.3→5;30÷6=5) |

- 舊值與 `unit-stats-provisional.md` 開頭的「甲、戊 5~6 下;乙、丁 4 下;丙 4 下」一致(已查)。
- 管理者先前要求「至少 4~5 下才會死」:新表全部 ≥4,**並未因此過頭**。⚠️ 但 Φ 只在站對位置時才有,站錯就回到舊值;診斷顯示運用臂的實際站位未必是最佳,故上表是上限而非平均。
- 診斷中戊被打 6 下倒(30→0,F2)。獨行 guard 2 後約需 8~10 下,**是否足夠撐過 R4 仍未知**(推估:延後約 1~2 個敵方回合)。

## 4. 會動到的既有文件與程式/測試範圍

**文件(須先問再改,本提案不動)**
- `design/gdd/affinity-position-chain.md`:Overview、Player Fantasy 反面感受、Core Rules R6、「公式」(新增公式四:減傷)、「交叉校準結果」、Edge Cases、Tuning Knobs、Acceptance Criteria、OQ-5。⚠️ 該文件已為規則 1 的三份例外之一,行數無上限約束。
- `design/gdd/tactical-combat-system.md`:傷害公式、Core Rules #7(敵方優勢兩條通道的描述)、AC 中釘傷害預覽者;**跨系統**,註記 ADR-0001 的原子性不受影響(只加純函式項,未查證其細節)。
- `design/quick-specs/unit-stats-provisional.md`:「被打幾下倒」表、第 5 節對局長度(已自標過時)。
- `design/gdd/vertical-slice-level-01.md`:「預期回合數」、AC 涉及承傷者。
- `design/gdd/game-concept.md`:支柱四(僅在 creative-director 認為戊代價不足時)。
- `design/narrative/characters.md`:不改(僅被引用)。
- `docs/registry/architecture.yaml`:`phi_curve_enemy_advantage_cross_calibration` 條目;視需要 `design/registry/entities.yaml` 的 guard 數值。

**程式(估計,未動工)**
- 新增 guard 計算(純函式,建議放 `src/gameplay/combat/combat_rules.gd` 旁)、`_attack_damage_breakdown()`、防守方 Φ 取得、戊獨行 `d_min`、UI 預覽顯示。約 5~7 個檔案。
- 測試:`combat_rules` 相關新增約 15~20 條;既有受影響約 20~35 條(傷害預覽 `attack_confirm_panel_test`、`battle_info_panel_attack_preview_test`、`greedy_tactical_ai_test`、`battle_state_test`、`affinity_phi_provider_test`;推估,由先前 grep 的檔案數 23 個含 Φ 者縮小)。headless 取不到像素,UI 預覽顯示須另開窗驗證。

## 5. 重測預先登記草案

沿用已鎖定門檻(H `20e0854`,數字全不動;`docs/reviews/protocol2-threshold-locked-2026-10-30.md`)。**改的是遊戲規則,不是門檻。**

1. **V 工具要改,不能原樣沿用。** 理由:attempt-1 的運用臂把好感度排在「能否攻擊」之前(VERDICT「判讀限制 4(1)」),診斷 F4 又證明純平手鍵無作用;兩種讀法都不是我們要測的「划算地運用」。依鎖定文件,改策略 = **新一輪登記**,新文件另立(例:`protocol2-threshold-locked` 之後的 attempt-2 登記,不得改寫舊檔)。
2. **運用臂提案(須在看任何新數據前寫死)**:
   - 步驟一:先保留「本回合能攻擊」的候選格;
   - 步驟二:在其中選「Φ_att + guard_total 最大」者(含戊獨行 guard);
   - 步驟三:無可攻擊格才選「Φ_att + guard_total」最大;
   - 之後才用既有集火/距離/座標決勝。
   核心原則:**好感度不得讓單位放棄本回合的攻擊。** 這是第三種讀法(非強硬、非純平手鍵),所以必須明文。
3. **忽視臂**:不變(只看戰術,不看 Φ 與 guard)。但遊戲規則兩臂都含 Φ/guard/獨行,故忽視臂也會偶然受益;Φ_avg 分臂有效性規則沿用鎖定文件。
4. **K1~K3 變體**:診斷 F5 證明 K2/K3 在 vs01 零作用、8 變體實為 2 種。建議 attempt-2 **刪去 K2/K3,只保留 K1**,避免假樣本。此為對 V 的修改,同樣須寫入新登記。
5. **揭露**:運用臂的定義**無法完全獨立於 attempt-1 的失敗**(我讀過診斷才寫);登記時須寫明這是「失敗後重設計」,**只有一次機會,不得在重測後再改運用臂**。
6. **第 1 場保留**:重測前不得以任何新數值(guard、獨行)跑第 1 場;調試只能在第 2~5 場,且只看是否爆表(見 options 文件第 4 節)。新數值先進版控提交,再跑第 1 場。
7. 沒有自動檢查,靠紀律與時間戳。

## 6. 管理者白話摘要

1. 「減傷」:站對好感度位置的角色,不只打得更痛,**挨打也更輕**。甲乙靠在一起每下少受 2 點,丙丁分開各少 1 點。
2. 站錯位置(負好感度的人貼太近)會多挨一點,但在目前這關幾乎不會發生。
3. 戊沒有好感度關係,不加,維持他「誰都不依靠」的個性。
4. 戊的機制請你二選一:
   - **A(推薦)獨行減傷**:戊離所有隊友 ≥3 格時,每下少受 2 點(落單變耐打);緊貼隊友時反而多受 1 點。只防不攻,貼合「算計過的自我保護」。
   - **B 獨行加攻加防**:同樣的距離條件,但戊落單時也多打 2 點。更猛,但減傷較少,也更像鼓勵他獨自衝出去。
5. 算下來我方每人約能多挨 1~4 下才倒(甲約 5~6 變 8~10 下),都沒超過你要求的範圍。這些全是算術,沒有實測。
6. 重測要改電腦的「用好感度」做法(不再為好感度放棄攻擊),新做法在看到結果前寫死,而且只有一次機會。
7. 門檻數字完全不動;第 1 場關卡在重測前一次都不跑。
8. 需要你拍板:戊機制選 A 或 B;接受「推翻 Φ 只能攻不能守」這條舊裁決;是否要 creative-director 先看戊獨行的代價夠不夠。
