# 好感度核心重設計 amend2(騎牆 + 留一手)—— GDD 同步 diff(第 4 份)2026-11-03

> 作者:game-designer。**本檔只是提案,未改動任何既有文件一字。** 套用由協調者做。
> 依據:管理者 2026-11-03 裁決逐字「現在同步,舊文保留加註(推薦)」。範圍:`docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md` 第 5 節第 1~6 項(第 7、8 項程式與重測已完成,不在範圍)。
> 慣例:舊文保留、就地加註、以插入為主。每個錨點已用 Grep 驗命中恰為 1(原始輸出見每處旁,過長者截斷)。
> 單一出處:公式與數字的唯一定義處仍在 `affinity-position-chain.md` 公式四/五;其他檔只指路,不複述。

## 0. 🔴 各目標檔修訂次數現況(下限;我沒有 git,依檔頭/修訂紀錄自述數)

規則 4:同一份文件不做第三次以上修訂。**四份目標檔全部已超過;規則 4 對這四份均無例外登記。** 協調者請複驗:`git log --oneline -- <path>`。

| 目標檔 | 已知修訂(下限) | 本次後 |
|---|---|---|
| `design/gdd/affinity-position-chain.md` | 8/31 第一輪 `/design-review` 修訂、8/31 第二輪、10/30 規格 1 加註(公式四/五)、10/30 amend1(diff3,條件式)= **≥ 4**;核准紀錄 8/31 另計不算 | **≥ 5** |
| `design/gdd/tactical-combat-system.md` | 檔頭自述:2026-08-18 前已四輪 `/design-review`、10/29 加註(Core Rules #2a)、10/30 公式一加註、10/30 amend1 加註 = **≥ 7** | **≥ 8**(該檔有規則 1 行數例外,規則 4 無) |
| `design/quick-specs/unit-stats-provisional.md` | 第二版、10/28 裁決、10/30 取代、10/30 amend1、11/02 丙射程加註(協調者所述)= **≥ 4**(暫行規格,非正式 GDD) | **≥ 5** |
| `docs/registry/architecture.yaml` | 本檔該列:8/31 round-2、10/30 取代、10/30 amend1 = **≥ 3**(登記表整檔次數不適用規則 4 的「一份文件」計法,**未查證**) | 該列 **≥ 4** |

本次只加註、一字不刪,且全部指路單一出處,淨增約 55 行(其中 `affinity-position-chain.md` 約 40 行)。我的建議沿用前例:知情接受並登記例外,而不是為此重寫;但這是對規則 4 的明文偏離,須管理者點頭。

## 1. 以現行程式與測試為準的數值核對

讀自 `src/gameplay/combat/combat_rules.gd`、`tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd`、`tests/unit/gameplay/combat/combat_rules_guard_test.gd`:

| 項目 | 現行程式 | amend2 | 一致? |
|---|---|---|---|
| `LONE_FAR_DISTANCE` / `LONE_FAR_GUARD` | 3 / **0** | d≥3 → 0 | 是 |
| `LONE_MID_DISTANCE` / `LONE_MID_GUARD` | 2 / **+2** | d=2 → +2 | 是 |
| `LONE_NEAR_DISTANCE` / `LONE_NEAR_GUARD` | 1 / **−1** | d=1 → −1 | 是 |
| 無隊友 | `NO_ALLY = -1`,走 FAR 分支 → 0 | 0 | 是 |
| `GUARD_MIN` / `GUARD_MAX` | −2 / +3 | 不變 | 是 |
| `HOLD_BACK_DISTANCE` / `HOLD_BACK_PENALTY` | 2 / 1 | 2 / 1 | 是 |
| `damage()` | `max(0, atk − def + phi − guard_total − hold_back_value)` | 同 | 是 |
| `lone_guard_effective(lone, _attacked)` | 一律回 `lone` | 同 | 是 |
| 測試 AC-L1 新值(ATK14、DEF8) | d=3/2/1 → **6 / 4 / 7**;無隊友 **6** | 6/4/7;L4 無隊友 6 | 是 |
| 測試留一手(ATK16 對 DEF6) | d=2 → **9**;d=1、3、5(遠)→ **10**;無隊友 **10**;非旗標/敵方不受影響 | 9 / 10 | 是 |

**不符處:無數值不符。** 只有三處「amend2 沒寫、測試多釘」,GDD 的 AC 應一併納入(見 2-D):
1. 測試釘了「戊攻擊後敵方回合承傷仍 4」(`test_attacking_no_longer_cancels_straddler_guard`),即出手條件取消的正面斷言。
2. 測試釘了「留一手不使傷害變負」(ATK 16 對 DEF 16 → 0)。
3. 測試釘了「結算傷害 = 預覽傷害 = 9」(單一來源,即 AC-G6 精神)與 breakdown 恆含 `hold_back` 鍵。

**未核對(誠實登記):** 現行測試檔中 AC-L2(只取最近)、L3(只計存活)、L5(非戊)、L7(距離一致)、L8(夾限單次)是否仍存在於別處、數字是否變動,我沒讀對應測試,GDD 的這五條保持不動、不加註。

**amend2 第 4 項的措辭差:** amend2 寫「AC-L1b、L9~L12 作廢」,GDD 原文的 L1b、L9、L10、L11、L12 全部依賴出手旗標,確屬作廢;L13 改寫(見 2-D)。程式的 `will_attack` 已忽略、`attacked_this_phase` 旗標「寫入暫留、不被讀取」(amend2 第 1 節原文,我未重驗寫入端)。

**移動預覽雙值顯示(`95559b2` 已移除):** 對 `design/` 全目錄 grep「雙值|兩種結果|若出手|出手會失去」,命中只有 `affinity-position-chain.md` 三處:公式五「預覽須同時列出…」、AC-L13、AC-GFEEL。**三處皆在本 diff 加註作廢**(2-A3、2-D3、2-D4)。`tactical-combat-system.md` 與 UX 規格無命中(`design/ux/` 在上述全目錄範圍內)。

## 2. 逐檔 diff

### 檔 1:`design/gdd/affinity-position-chain.md`(amend2 第 5 節第 1~4 項)

#### 2-A 公式五

**A0 檔頭 Last Updated。** 錨點(`grep -n "^> \*\*Last Updated\*\*: 2026-08-31$"`):
```
5:> **Last Updated**: 2026-08-31
```
命中 1。在該行之後插入:
```
> **2026-11-03 加註(管理者裁決「現在同步,舊文保留加註」)**:戊機制三「騎牆 + 留一手」(amend2)同步 —— 公式五、Edge Cases、Tuning Knobs、AC 皆就地加註,既有條文一字未動、衝突處以「加註取代」標明。**第 5 次(含)以上修訂**,見 `docs/reviews/affinity-core-gdd-diff4-2026-11-03.md` 第 0 節。
```

**A1 公式五 d 閾值行。** 錨點(`grep -n "^- \`d_min ≥ 3\`(或無存活隊友)→ \`lone_guard = +2\`"`):
```
320:- `d_min ≥ 3`(或無存活隊友)→ `lone_guard = +2`;`d_min = 2` → `0`;`d_min = 1` → `−1`。**取最近一位,不逐位加總**。
```
命中 1。在該行之後插入:
```
  🔴 **2026-11-03 已被取代(amend2 第 1 節,`docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`)**:新表 `d_min = 1` → **−1**(不變);`d_min = 2` → **+2**(原 0);`d_min ≥ 3` 或無存活隊友 → **0**(原 +2)。「騎牆」= 離隊友剛好 2 格才有減傷;貼身多受 1 點;落單沒有減傷。上一行數字與下方條件式整段保留為歷史。取最近一位的規則不變。現行常數:`LONE_FAR_GUARD=0`、`LONE_MID_DISTANCE=2`、`LONE_MID_GUARD=+2`、`LONE_NEAR_GUARD=−1`(`CombatRules`)。
  🔴 **上方「2026-10-30 條件式」整段(`lone_guard_eff`、不算出手、旗標生命週期、敵方先手、旗標屬戰棋狀態)自本日起作廢**:出手條件取消,`lone_guard_effective()` 一律回傳 `lone`,`will_attack` 參數保留但忽略;`lone_guard_if_at(unit_id, tile, will_attack)` 簽章不變。後續工作單移除該參數前,它是「看似有用、實際無作用」的陷阱,三處 `##` 註解已標「已棄用,忽略」,並有測試釘住 `will_attack=true/false` 結果相同。
```

**A2 公式五「只作用於承傷」行。** 錨點(`grep -n "^- 只作用於承傷(進入公式四的 \`guard_total\`)"`):
```
328:- 只作用於承傷(進入公式四的 `guard_total`),**不影響戊的攻擊**。戊 Φ 恆 0,[…]
```
命中 1。在該行之後插入:
```
  🔴 **2026-11-03 部分被取代(amend2)**:「只作用於承傷…不影響戊的攻擊」**不再成立** —— 新增「留一手」(見下):騎牆者**作為攻擊方**時,若攻擊當下所在格 `d_min = 2`,最終傷害 −1。**但 `Φ_att` 對戊仍恆為 0**,「戊 Φ 恆 0」這條既有性質**不變**(留一手不經 `Φ_att`,是獨立一項)。
  **留一手(本節為唯一定義處)**:`hold_back = 1` 當且僅當「攻擊方為旗標單位(名冊第 12 欄 `lone_guard=1`,語意改讀為騎牆者)且攻擊當下其所在格 `d_min = 2`」,否則 0;`d_min` 只計存活隊友,無存活隊友 → 不適用。敵方、我方他人皆不適用。純函式 `CombatRules.hold_back(is_straddler, d_min)`,無 RNG。
  傷害式(承接公式四的 `damage` 行):`damage = max(0, ATK − DEF + Φ_att − guard_total − hold_back)`,`hold_back ∈ {0, 1}`。`hold_back` 在 `max(0,…)` 之前,傷害不為負。預覽(`preview_damage_breakdown`)與結算走同一函式,細項含 `hold_back` 鍵(恆存在)。
  算例(算術):戊 ATK 16 攻擊 DEF 6 的敵人,從 `d_min=2` 格出手 = 16−6−1 = **9**;從 `d_min=1`、`d_min≥3` 或無隊友出手 = **10**。
```

**A3 公式五預覽行(雙值顯示作廢)。** 錨點(`grep -n "預覽須同時列出「若出手 / 若不出手」兩種受擊結果"`):
```
327:  - 預覽須同時列出「若出手 / 若不出手」兩種受擊結果。
```
命中 1。在該行之後插入:
```
    🔴 **2026-11-03 作廢(amend2 第 3 節;程式端 `95559b2` 已移除移動預覽雙值顯示)**:出手條件已取消,不再有「若出手 / 若不出手」兩種受擊結果。承傷預覽只列一個值,沿用既有「獨行 +2/−1」列,且**移除「出手會失去減傷」提示**。新增:戊從 `d_min=2` 格出手時,攻擊預覽顯示一列「留一手 −1」;從 `d=1` 或 `d≥3` 格出手時**不顯示該列**。UI 版面交 `/ux-design`;headless 取不到像素,須開窗驗證。
```

**A4 公式五「代價偏軟」回應(1-4)再加註。** 錨點(`grep -n "^- 未模擬:戊獨行 guard 2 是否足以撐過診斷中 R4 的集火,未驗證。$"`):
```
332:- 未模擬:戊獨行 guard 2 是否足以撐過診斷中 R4 的集火,未驗證。
```
命中 1。在該行之後插入:
```
- 🔴 **2026-11-03 加註(amend2 取代 amend1 的代價設計)**:上方「候選甲(出手二選一)」的非空間代價,改為**騎牆 + 留一手**(creative-director 裁決見 `docs/reviews/straddle-pillar4-review-2026-10-30.md`,選項來源 `docs/reviews/lone-wolf-redesign-options-2026-10-30.md` 候選 1)。新的代價結構:拿到 +2 減傷必須待在距隊友 **剛好 2 格**,而待在那裡出手要付 −1 傷害;想全力打就得貼上去(多受 1 點)或脫隊(失去減傷)。上方「代價偏軟」「已回應」兩條保留為歷史。
- 🔴 **2026-11-03 推估(算術,未驗證;戊 HP 30 / DEF 8,敵 ATK 14/13)**:被打幾下倒 —— `d=1`:7/6 → **5**;`d=2`:4/3 → **8~10**;`d≥3`:6/5 → **5~6**(不再有「落單未出手 8~10」)。輸出:對 vs01 敵 DEF 3~6 每下約 10~13,`d=2` 時約 −8~10%;以敵 HP(E1 23、E2 20、E3 18、E4 22、E5 24)算,**只有 E4(DEF 5、HP 22)由 2 下變 3 下**。對電腦對照:戊打得較輕、傾向拉長回合數;amend2 原文提醒 attempt-3 為壓線通過,**翻面風險高**。第四次重測已預先登記,第 1 場重測前不得用新數值跑。
```
(上方「d=2 時約 −8~10%」與擊殺下數為 amend2 第 4 節原文推估,**我未重算**。)

#### 2-B 公式四預覽行(加一個指路)

**B1** 錨點(`grep -n "^- 無 RNG;玩家預覽必須顯示「減傷 N」"`):
```
312:- 無 RNG;玩家預覽必須顯示「減傷 N」(Player Fantasy 反面感受「我不知道為什麼變強了」)。
```
命中 1。在該行之後插入:
```
  🔴 **2026-11-03 加註**:公式四的 `damage` 式現又多一項 `− hold_back`(騎牆者留一手,唯一定義在公式五);`hold_back = 0` 時與上方式相同。
```

#### 2-C Edge Cases

**C1 戊獨行旗標條目作廢。** 錨點(`grep -n "^- \*\*【新增】戊獨行旗標\*\*:屬戰棋狀態"`):
```
399:- **【新增】戊獨行旗標**:屬戰棋狀態;每我方階段開始清除;敵方先手首階段視為未出手;戊未行動視為未出手;只移動/待機/被用增益卡不算出手。
```
命中 1。在該行之後插入:
```
  🔴 **2026-11-03 作廢(amend2)**:出手條件已取消,本條(含「出手旗標」、敵方先手與戊未行動的特例)不再適用。上方 396 的「未出手時 `lone_guard=+2`,出手後 0」同樣作廢;無存活隊友現為 `lone_guard=0`(見公式五 2026-11-03 加註)。`attacked_this_phase` 旗標寫入暫留於程式但**不被讀取**,日後由後續工作單移除。
```

**C2 新增邊界條目。** 錨點(`grep -n "^- \*\*【新增】戊被日後加入關係線\*\*"`):
```
401:- **【新增】戊被日後加入關係線**:`guard(Φ_def)` 與 `lone_guard` 可同時非零,以 `GUARD_MAX` 夾限;是否保留獨行減傷須重新裁決。
```
命中 1。在該行之後插入:
```
- **【2026-11-03 新增】留一手:`d_min` 取值時點**:取**攻擊當下戊所在格**;預覽時用游標格(= 假設攻擊格)。只計存活隊友;無存活隊友 → 不適用(`hold_back=0`);隊友陣亡後 `d_min` 即時重算。
- **【2026-11-03 新增】留一手:傷害下限**:`hold_back` 在 `max(0,…)` 之前,ATK 不足時傷害維持 0,不為負、不回補生命(測試釘住:ATK 16 對 DEF 16 → 0)。
- **【2026-11-03 新增】留一手與卡牌**:不經 `Φ_att`,不吃卡牌修正;騎牆者被使用增益卡不影響 `hold_back`(它只由位置與旗標決定)。**以戊為攻擊方的卡牌觸發傷害是否也走同一函式扣留一手:未查證**,由實作與 `skill-card-system.md` 確認,不得默認。
- **【2026-11-03 新增】旗標語意**:名冊第 12 欄 `lone_guard=1` 改讀為「騎牆者」,**不新增欄位**(避免動 9 份名冊與固定欄位測試);戊的辨識仍是資料旗標,不得以「沒有關係線」推斷。
```

#### 2-D Tuning Knobs 與 AC

**D0 旋鈕。** 錨點(`grep -n "^- 存放處:外部資料(\`assets/data/\`),不得寫死。全部為曲線旋鈕"`):
```
473:- 存放處:外部資料(`assets/data/`),不得寫死。全部為曲線旋鈕;無 feel / gate 旋鈕。
```
命中 1。在該行之後插入:
```
🔴 **2026-11-03 加註(amend2)對上表的修訂,上表原列保留為歷史:**

| 旋鈕 | 現行值 | 安全範圍 | 類別 | 說明 |
|---|---|---|---|---|
| 「`lone_guard`(d_min ≥ 閾值,未出手)」列 | **作廢**,改為下列 `LONE_MID_GUARD` | — | — | 「未出手」條件已取消 |
| `LONE_MID_DISTANCE` / `LONE_MID_GUARD`(d_min = 2 的距離與減傷) | **2 / +2** | 距離固定 2;減傷 1~3 | 曲線 | 騎牆減傷;太高:戊守在 2 格近乎不死;`CombatRules` 常數 |
| `LONE_FAR_GUARD`(d_min ≥ 3 或無隊友) | **0**(原 +2) | 0~1 | 曲線 | >0 = 重新獎勵孤立 |
| 「獨行距離閾值」列 | 閾值語意變為:`LONE_FAR_DISTANCE = 3` 只表示「超過 2 格即失效」 | 固定 | 曲線 | 不再是 +2 的觸發線 |
| 相鄰懲罰(d=1) | **−1** 不變 | −2~0 | 曲線 | 同前 |
| `HOLD_BACK_DISTANCE`(留一手生效距離) | **2**(與 `LONE_MID_DISTANCE` 同值) | 2~3 | 曲線 | 兩者若分叉,「騎牆」的減傷與代價就不在同一格,須重新裁決 |
| `HOLD_BACK_PENALTY`(留一手傷害) | **1** | 1~2 | 曲線 | >2 時戊從 d=2 出手不值得,騎牆退化為「全程貼身或脫隊」 |
| 「出手條件(布林)」列 | **作廢**(程式已不讀) | — | — | 不再是旋鈕 |

存放:沿用 `LONE_*` 既有做法放 `CombatRules` 常數;**是否改外部資料檔,交 gameplay-programmer 與 lead-programmer 決定**(專案原則是資料驅動,現況是已登記的未決偏離,**未查證**是否已有登記)。
```

**D1 AC-L1 / L1b / L4 / L9~L12 作廢與改寫。** 錨點(`grep -n "^- \*\*AC-L13(預覽兩種結果)"`):
```
559:- **AC-L13(預覽兩種結果)**:戊出手前的預覽 API 對「出手 / 不出手」回報兩個不同的受擊傷害(`d_min≥3` 時 6 與 4);簽章以 S3 實作 `lone_guard_if_at(unit_id, tile, will_attack)` 為準。
```
命中 1。在該行之後插入:
```
🔴 **2026-11-03(amend2)對上方 AC-L1~L13 的修訂,上方原文保留為歷史;以現行測試 `tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd` 為準:**
- **AC-L1 改寫**:GIVEN 戊 `DEF=8`、敵 `ATK=14`,`d_min` 為 3、2、1,THEN 傷害 **6、4、7**(原 4、6、7)。與出手無關。
- **AC-L1b、AC-L9、AC-L10、AC-L11、AC-L12 作廢**(全部依賴已取消的出手旗標)。
- **AC-L4 改寫**:無存活隊友 → `lone_guard = 0`,傷害 **6**(原 4/6 兩種);不報錯。
- **AC-L13 作廢**(預覽雙值顯示已移除):改由 AC-H6 取代。
- **AC-L2、L3、L5、L6、L7、L8**:保留不動。⚠️ **AC-L6「不影響攻擊」措辭須讀為「`Φ_att` 對戊仍恆 0」**;傷害則受留一手影響(AC-H1~H3)。這些條目對應的現行測試我**未逐條重驗**。
- **新增 AC-H1~H6(BLOCKING,自動單元測試;敵/我數值為測試內常數)**:
  - **AC-H1**:GIVEN 戊 ATK 16、敵 DEF 6、`d_min=2` → 攻擊傷害 **9**,breakdown `hold_back = 1`。
  - **AC-H2**:同上但 `d_min = 1`、3、5 → 傷害 **10**,`hold_back = 0`。
  - **AC-H3**:無存活隊友 → 傷害 **10**,`hold_back = 0`。
  - **AC-H4**:敵方攻擊(`d` 任意)與非旗標我方單位(即使其最近隊友 `d=2`)→ `hold_back = 0`,傷害不受影響。
  - **AC-H5**:傷害下限 —— ATK 16 對 DEF 16 → **0**,不為負。
  - **AC-H6**:`will_attack` 忽略 —— 同一局面下 `lone_guard_if_at(id, tile, true)` 與 `(…, false)` 結果全等;`lone_guard_effective(2, true) == 2`;戊攻擊後敵方回合承傷仍為 4(`d=2`);結算傷害 = 預覽傷害 = 9(單一來源)。
- **敏感度證明:屬 A 類(斷言對象含 static 純函式,沒有繼承鏈可覆寫),無法做常駐間諜子類別。** 現行測試檔檔頭自述已改為手動注入兩次(拿掉留一手、`d=2` 減傷改錯)並還原,**原始紅燈行見該工作單回報,不在版本庫內 —— 依 `.claude/rules/test-standards.md`「手動注入不留痕」的規定,這一項屬可查證性弱**,GDD 不宣稱已證明。
```

**D2 AC-GFEEL 加註。** 錨點(`grep -n "^- \*\*AC-GFEEL\*\*:開窗試玩"`):
```
562:- **AC-GFEEL**:開窗試玩,玩家把甲乙貼近時,預覽能指出「減傷 N」來源;戊落單時預覽顯示獨行來源與「出手會失去減傷」。判準:試玩者能口述「為什麼這下比較不痛 / 比較痛」。
```
命中 1。在該行之後插入:
```
  🔴 **2026-11-03 改寫(amend2)**:「出手會失去減傷」提示作廢(出手條件已取消)。新判準:戊從 `d=2` 格出手時預覽出現「留一手 −1」一列、從其他格不出現,試玩者能口述「為什麼這下比較輕 / 為什麼他站那裡比較不痛」;承傷預覽顯示「獨行 +2/−1」來源。headless 取不到像素,須開窗驗證。
```

### 檔 2:`design/gdd/tactical-combat-system.md`(amend2 第 5 節第 5 項)

**T1** 錨點(`grep -n "旗標寫入須走戰棋既有的提交入口(ADR-0001)"`):
```
219:> 🔴 **2026-10-30(amend1)**:戊獨行減傷改為條件式。戰棋端持有「戊在本我方階段是否完成過攻擊結算」旗標[…]旗標寫入須走戰棋既有的提交入口(ADR-0001),具體時機由實作確認。
```
命中 1。在該行之後插入:
```
> 🔴 **2026-11-03(amend2,管理者裁決「現在同步,舊文保留加註」)**:① 上一條 amend1「戊出手旗標歸戰棋」**作廢** —— 出手條件已取消,戰棋端不再持有、不再讀取該旗標(程式暫留寫入,後續工作單移除),因而**不再有旗標寫入須走提交入口的義務**;ADR-0001 不受影響。② 傷害式新增一項:`max(0, ATK − DEF + Φ − guard_total − hold_back)`,`hold_back ∈ {0,1}`(騎牆者從 `d_min=2` 格出手 −1)。`hold_back` 與 `guard_total` 的**唯一定義**在 `affinity-position-chain.md` 公式五,本文件不複述;`hold_back = 0` 時與上方式相同。預覽與結算仍走同一函式。
```

### 檔 3:`design/quick-specs/unit-stats-provisional.md`(amend2 第 5 節第 6 項)

**U1** 錨點(`grep -n "上方原表「戊(獨行 d≥3) 8~10」須讀為「\*\*未出手時\*\*」。"`):
```
38:> 丙丁最佳佈局為分開(各 Φ=+2),3~4 下只在被迫貼近時出現;[…]上方原表「戊(獨行 d≥3) 8~10」須讀為「**未出手時**」。
```
命中 1。在該行之後插入:
```
> 🔴 **2026-11-03 再被取代(amend2 騎牆 + 留一手)**:戊的三列改為下表(算術,未驗證;戊 HP 30 / DEF 8,敵 ATK 14/13;其餘我方列不變)。上方 amend1 表的三列戊與「須讀為未出手時」一句同時作廢(出手條件已取消)。
>
> | 我方 | 狀況 | 新:每下(ATK 14/13) | 新:幾下倒 |
> |---|---|---|---|
> | 戊 | `d=2`(騎牆,guard +2) | 4 / 3 | **8~10** |
> | 戊 | `d≥3` 或無隊友(guard 0) | 6 / 5 | **5~6** |
> | 戊 | `d=1`(貼身,guard −1) | 7 / 6 | **5** |
>
> 另:戊從 `d=2` 格出手時輸出 −1(留一手),對 vs01 敵 DEF 3~6 每下約 10~13 → 9~12。以敵 HP(E1 23、E2 20、E3 18、E4 22、E5 24)算只有 E4 由 2 下變 3 下(amend2 第 4 節推估,**我未重算**)。唯一定義:`affinity-position-chain.md` 公式五。
```

### 檔 4:`docs/registry/architecture.yaml`(amend2 第 5 節第 6 項後半:AMENDED 再加一則)

**Y1** 錨點(`grep -n "remains outstanding\. Single definition: design/gdd/affinity-position-chain\.md formulas 4 and 5\."`):
```
779:      remains outstanding. Single definition: design/gdd/affinity-position-chain.md formulas 4 and 5.
```
命中 1。在該行之後插入(縮排 6 空白,與上下行同;**純 ASCII,避免此檔編碼差異**):
```
      AMENDED 2026-11-03 (amend2, docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md):
      the lone-guard of the flagged unit (戊) is now a "straddle" table by distance to the nearest
      living ally: d=1 -> -1, d=2 -> +2, d>=3 or no ally -> 0; the attack-condition of amend1 is
      CANCELLED (CombatRules.lone_guard_effective now always returns its input). NEW "hold back"
      term: a flagged attacker whose current cell has d=2 deals 1 less final damage
      (damage = max(0, ATK - DEF + Phi_att - guard_total - hold_back)); Phi_att for 戊 stays 0.
      Re-measurement of the cross-calibration remains outstanding (4th pre-registered retest
      not yet run). Single definition: design/gdd/affinity-position-chain.md formula 5.
```
注意:此為既有註解行內的 YAML 多行純量續寫,**套用者須確認該列是 block scalar(`|`/`>`)**;我只讀了 760~790 行,**未驗證**該鍵的標量型別,建議套用後跑一次 YAML 解析檢查。

## 3. 不在清單內但會變過時的敘述(只列,不寫 diff)

1. `affinity-position-chain.md` 的 Player Fantasy、Overview 若提到「戊落單減傷/出手二選一」:我只讀了 296~336、392~402、458~474、532~566 行,**未讀全檔,未查證**。請套用前 `grep -n "出手" design/gdd/affinity-position-chain.md` 複驗(公式五 321~327、396~399、AC-L1b/L9~L12 已涵蓋)。
2. `AC-G8`(資料驅動:注入 `lone_guard` 後重算 AC-L1)與 AC-G2 引用 AC-L1 的新舊值:AC-L1 已改為 6/4/7,AC-G8 的預期結果須讀新值,**我未改寫它**。
3. `design/gdd/reviews/affinity-position-chain-review-log.md`:最近條目為 8/31 核准,**未見 10/30 兩次修訂的紀錄**;本次是否補記由協調者決定。
4. 一年計畫與 `production/` 的重測登記:amend2 第 8 項已完成,不在範圍。

## 4. 實際讀過的檔案

- `docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`(全)
- `docs/reviews/skill-card-gdd-diff-named-target-2026-11-03.md`(全,取格式)
- `src/gameplay/combat/combat_rules.gd`(Grep 常數與函式 + 第 25~94 行)
- `tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd`(全)
- `tests/unit/gameplay/combat/combat_rules_guard_test.gd`(全)
- `design/gdd/affinity-position-chain.md`:第 296~336、392~402、458~474、532~566 行,另 Grep 關鍵字掃全檔並對每個錨點驗命中
- `design/gdd/tactical-combat-system.md`:僅 Grep 關鍵字命中行(含第 218~219 行),**未通讀**
- `design/quick-specs/unit-stats-provisional.md`:第 1~42 行,另 Grep 全檔「戊」
- `docs/registry/architecture.yaml`:第 760~790 行,另 Grep `AMENDED|lone_guard`
- `design/gdd/reviews/affinity-position-chain-review-log.md`:僅 Grep 標題行
- **未讀**:`battle_state.gd`、`battle_screen.gd`、`design/ux/*`(只靠全目錄 grep 判無雙值顯示)、各名冊資料檔、`design/gdd/skill-card-system.md`、`docs/reviews/straddle-pillar4-review-2026-10-30.md` 與 `lone-wolf-redesign-options-2026-10-30.md`(僅依 amend2 的引用);`unit-stats-provisional.md` 的丙射程 11-02 加註在第 42 行以後,**我未讀,也未重複**。
- 未能執行:`git log`(無 shell)。
