# 卡牌工單 010~025 答案回寫逐字 diff(2026-11-17)

> **性質**:給協調者機械套用的逐字替換清單。本檔不修改任何工單檔。
> **套用規則**:每個 ```` ```old ```` 區塊必須在對應檔案中恰好命中 1 次(整段子字串比對,單行);不是恰好 1 次就跳過並回報。old 區塊刻意都是單行子字串,new 區塊可多行。
> **依據**:
> - 答案檔 = `docs/reviews/card-combat-design-answers-2026-11-17.md`(下稱「答案檔」,題號 = 其題號)
> - TD 裁決 = `docs/reviews/state-of-adr0002-ruling-2026-11-17.md`(第 4 節逐字補句)
> - 騎牆/k 推薦 = `docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md`
> - 管理者 2026-11-17 約 10:30 裁決:「全部核准(推薦)」、騎牆失效三項一起歸零、冷淡區量測前先設 0、位置系統文件整份重寫(裁決 B,進行中)、023 本批不做、012 補兩句。紀錄 `production/session-state/active.md`(`grep -n "文件包 =" production/session-state/active.md`)。
> **誠實標示**:答案檔未回答的題(例:015 第 1 題「`BattleScreen` 切關是否重建 `BattleState`」)不寫成「已決」,只標「實作者第一步查證」。「三項」= 騎牆推薦檔 Q3 所指:`lone_guard` 貼身 d=1 的 −1、d=2 的 +2、`hold_back`(留一手);該檔把 d=1/d=2 歸入 `lone_guard` 減傷表是其自述,**實作者第一步須對照 `combat_rules.gd` 確認三項的實際名稱**。

## 新狀態一覽

| 工單 | 新 Status | 仍卡什麼 |
|---|---|---|
| 010 | Ready(不改) | 無 |
| 011 | Ready | 無(三題皆已決) |
| 012 | Ready | 無(TD 已判;k=0 先行) |
| 013 | Blocked | 等 `affinity-position-chain.md` 整份重寫(裁決 B);另依賴 012 |
| 014 | Blocked | 同上;另依賴 012、013 |
| 015 | Ready(依序 010、011、012 完成後才可派工) | 無裁決;第 1 題為實作者第一步查證 |
| 016 | Blocked | 等整份重寫;另依賴 012、013、015 |
| 017 | Ready(依序 010、011、015 完成後才可派工) | 無裁決;三題皆為實作者第一步查證 |
| 018 | Ready(依序 010、011、015 完成後才可派工) | 無(F7、反擊皆已決) |
| 019 | Ready(依序 015、018 完成後才可派工) | 無(c12 細節已決) |
| 020 | Blocked(不改) | `ux-designer` 規格尚未存在 |
| 021 | Blocked(不改) | `ux-designer` 規格尚未存在 |
| 022 | Blocked | 三題皆已決;仍卡依賴 011、015、017、018、019,及牌名/牌面文字須 `narrative-director` 交付(是否已交付:未驗證) |
| 023 | Deferred(管理者 11-17:本批不做) | 不做 |
| 024 | Blocked | 依賴 013、014(兩者仍 Blocked) |
| 025 | Blocked | 依賴 012、016、019、022;k 量測前先設 0 已決 |

---

### story-010 story-010-card-confirm-through-commit-entry.md

無需改動(「派工前須先決定:無」,Status 已為 Ready)。

---

### story-011 story-011-card-data-model-16-fields.md

```old
> **Status**: Blocked —— 卡在三題裁決:
```
```new
> **Status**: Ready(2026-11-17 三題皆已決,見「派工前須先決定」;下列為原卡點,留作紀錄)—— 原:卡在三題裁決:
```

```old
**設計師 + lead-programmer 裁決**;若改為獨立第 17 欄,本單欄數與 AC 全變。
```
```new
**設計師 + lead-programmer 裁決**;若改為獨立第 17 欄,本單欄數與 AC 全變。
   - **已決:不加第 17 欄,欄數集合維持 {8,9,10,16}。** `named_unit_id` 一律 = 付款人(凡 `cost_type ≠ NONE` 的卡),`named_mode` 對這類卡無作用(填 `ONLY`,載入器不驗)。付款人集合由 `cost_type` + 卡類別導出(**屬 015 的純函式,不在本單**):`PAIR` 且雙人加成(c09~c11)/合擊(c12)→ `named` 與 `partner` 兩人皆付;`PAIR` 且補血(c13/c14)→ 只有 `named` 付、`partner` 是承受者。(答案檔題 1;v0.3 第 3 節規則 1;設計師直接定,日後出現例外卡再升級為第 17 欄。)
```

```old
2. **卡 id 命名**:`c01` 或沿用 `card_01`(game-designer)。
```
```new
2. **卡 id 命名**:`c01` 或沿用 `card_01`(game-designer)。
   - **已決:`card_11`~`card_24`**(c01 = `card_11`,依此類推 c14 = `card_24`);**不可**用 `card_01`~`card_08`(現行 `vs02_cards.txt` 已佔用,會撞 id)。`cNN` 只是閱讀簡稱。(答案檔題 2;v0.3 第 3 節規則 13。)
```

```old
**請設計師同時確認 c02 的射程是用現有單位射程還是卡面指定**(規格第 4 節 c02 原文本單撰寫時未重讀,**未驗證**)。
```
```new
**請設計師同時確認 c02 的射程是用現有單位射程還是卡面指定**(規格第 4 節 c02 原文本單撰寫時未重讀,**未驗證**)。
   - **已決:直傷尊重視線;c02 射程 = 施放者的單位射程(董振豪 2~6),不是卡面指定 → 不需要任何射程欄位,欄位集合不變。** 直傷卡 `target_range = -1`(不適用/用付款人攻擊射程)。(答案檔題 3;v0.3 第 3 節規則 2、7。)控制區對直傷無影響(設計師直接定,影響 018 不影響本單)。
```

```old
(沿用 data-format 2.1)。
```
```new
(沿用 data-format 2.1)。
   - **補充(答案檔題 5、題 12)**:卡表資料**只使用 `PAIR`**、不使用 `AFFINITY`(列舉保留該值——列舉只能尾端追加,不刪既有值;載入器遇 `AFFINITY` 的處置由實作者依 AC3 決定並於回報說明)。`effect_value` 維持「由建構者/載入器傳入、不寫死」(023 本批不做,營火批再追加覆寫入口,屬追加式小改)。
```

---

### story-012 story-012-relation-state-of-pair.md

```old
但 ⚠️ 見「派工前須先決定」第 1 題(ADR-0002 是否需補一行)
```
```new
第 1 題已由技術總監裁決(2026-11-17,`docs/reviews/state-of-adr0002-ruling-2026-11-17.md`:不修訂 ADR-0002,新檔 `AffinityRelation`);`k=0` 先行已由管理者 2026-11-17 裁決「冷淡區量測前先設 0」
```

```old
**lead-programmer 須先對照 ADR-0002 與 `docs/registry/architecture.yaml` 的 interfaces 節回答;若算契約變更 → 停下問技術總監,不自行改 ADR。**
```
```new
**lead-programmer 須先對照 ADR-0002 與 `docs/registry/architecture.yaml` 的 interfaces 節回答;若算契約變更 → 停下問技術總監,不自行改 ADR。**

   > **✅ 2026-11-17 技術總監建議(`docs/reviews/state-of-adr0002-ruling-2026-11-17.md`)**:不放池、不放 `AffinityPhiProvider`;新增 `src/gameplay/affinity/affinity_relation.gd`(`AffinityRelation.state_of(pool, pair, neutral_band) -> RelationState`,靜態純函式),`k` 經 `AffinityTuning` 載入。**不觸及 ADR-0002 契約,不修訂 ADR。** 本單不改 `affinity_phi_provider.gd` 與 `affinity_data_pool.gd`(第 3 分支改讀 `state_of` 屬 story-013)。
```

```old
規格 3 節標二手。實作者第一步當場查。
```
```new
規格 3 節標二手。實作者第一步當場查。
   - **已決(TD 裁決檔第 4 節末)**:`n` 取自 `combat_strength_read(pair)` 回傳的 `AffinityReadResult.n_pair`;不需要新的讀取介面。必須先確認 `result.rejection == AffinityDataPool.ReadRejection.NONE` 才讀其他欄位,拒絕時 `push_error` + 回傳 `NONE`(拒絕時 `value` 為 `NAN`,必須是明確分支)。
```

```old
正式值由 025 的 M9 量測後由管理者/數值設計師定。
```
```new
正式值由 025 的 M9 量測後由管理者/數值設計師定。
   - **已決:量測前先設 `k=0`**(管理者 2026-11-17 裁決「量測前先設 0(設計師推薦)」;`docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` Q4-A)。k=0 是唯一有回歸保證的值(與現行 `_link_for_pair` 逐位相同)。若試玩覺得麥子健太快失去騎牆,正確動作是提前做 025,不是塞暫定非零值。
```

```old
- `src/gameplay/affinity/affinity_phi_provider.gd` 或 `src/gameplay/affinity_pool/affinity_data_pool.gd`(依派工前第 1 題結論)
```
```new
- `src/gameplay/affinity/affinity_relation.gd`(新檔)
- `src/gameplay/tuning/affinity_tuning.gd`、`src/gameplay/tuning/tuning_knobs.gd`(加 `neutral_band_centi`,當場確認載入路徑)
```

---

### story-013 story-013-position-chain-reads-relation-state.md

```old
> **Status**: Blocked —— 卡在 **`design/gdd/affinity-position-chain.md` 的「公式五(麥子健恆無線)」須先修訂**(既有文件,須管理者逐檔核准;
```
```new
> **Status**: Blocked —— 等 `design/gdd/affinity-position-chain.md` **整份重寫完成**(管理者 2026-11-17 裁決 B:整份重寫,進行中;013/014/016 一併等它)。原卡點(已被取代,留作紀錄):**公式五「麥子健恆無線」須先修訂**(既有文件,須管理者逐檔核准;
```

```old
**本單開工條件 = 公式五已改完。** 不要自己改文件。
```
```new
**本單開工條件 = `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B,取代原「公式五已改完」)。** 不要自己改文件。
```

---

### story-014 story-014-lone-guard-follows-relation-state.md

```old
> **Status**: Blocked —— 卡在 `design/gdd/affinity-position-chain.md` 公式五(麥子健恆無線)須先修訂(同 story-013);另依賴 012、013。
```
```new
> **Status**: Blocked —— 等 `design/gdd/affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B,進行中;同 story-013);另依賴 012、013。原卡點「公式五須先修訂」已被此取代。
```

```old
1. 公式五文件先改(同 013)。
```
```new
1. `affinity-position-chain.md` 整份重寫完成(同 013;管理者 2026-11-17 裁決 B)。
   - **已決:騎牆失效時三項一起歸零**(管理者 2026-11-17 裁決「三項一起歸零(設計師推薦)」;`docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` Q3-A)。三項 = 獨行減傷表的貼身 d=1 的 −1、d=2 的 +2、`hold_back`(留一手)。**不得只關兩項、不得保留貼身 −1。** 實作者第一步須對照 `combat_rules.gd` 確認三項的實際符號名稱(該推薦檔自述 d=1/d=2 屬 `lone_guard` 減傷表,本單撰寫者未逐行驗證)。
   - **已決:k=0 先行**(管理者 2026-11-17):本單只讀 `state_of`、不含 k;AC4「池空、k=0 回歸」即以此為基準。
```

```old
**同一個布林同時驅動 `lone_guard` 與 `hold_back`**,不得各算一次。
```
```new
**同一個布林同時驅動 `lone_guard`(含貼身 d=1 的 −1、d=2 的 +2 兩列)與 `hold_back`,共三項同開同關**,不得各算一次、不得只關其中一部分(管理者 2026-11-17 裁決,Q3-A)。
```

```old
- [ ] **AC1 全 NONE → 兩項皆開**;任一組非 NONE → **兩項皆關**(各 1 條,斷言兩個行為各自的可觀察結果,不只斷言布林)。
```
```new
- [ ] **AC1 全 NONE → 三項皆開**(貼身 d=1 的 −1、d=2 的 +2、`hold_back`);任一組非 NONE → **三項皆歸零**(各 1 條,逐項斷言各自的可觀察結果,不只斷言布林;尤其須有一條斷言「騎牆失效時貼身 d=1 沒有額外 −1」)。
```

```old
①只關 `lone_guard`、`hold_back` 不關 → AC1 紅
```
```new
①只關 `lone_guard`、`hold_back` 不關 → AC1 紅(另一個 mutant:只關 +2 與 `hold_back`、保留貼身 −1 → AC1 紅;各自獨立執行)
```

---

### story-015 story-015-card-cost-settlement.md

```old
> **Status**: Blocked —— 依賴 010、011、012(尚未完成);另卡在派工前第 1、2 題裁決。
```
```new
> **Status**: Ready(依序:010、011、012 完成後才可派工)—— 派工前第 2、3 題已決(答案檔題 1、5);第 1 題不是設計裁決,為實作者第一步查證。
```

```old
lead-programmer 第一步查證;若不重建,停下問。
```
```new
lead-programmer 第一步查證;若不重建,停下問。
   - **非設計裁決,答案檔未涵蓋**:設計面只確認「折損不寫池、計數器放 `BattleState`」(答案檔題 5);`BattleScreen` 切關是否重建 `BattleState` 仍為**未驗證**,實作者第一步查,查到會重建才停下問。
```

```old
請設計師確認 `AFFINITY` 與 `PAIR` 的分工(規格 4.1 只定義了 PAIR;`AFFINITY` 是否仍用在單人卡:**未驗證**)。
```
```new
請設計師確認 `AFFINITY` 與 `PAIR` 的分工(規格 4.1 只定義了 PAIR;`AFFINITY` 是否仍用在單人卡:**未驗證**)。
   - **已決:卡表資料只用 `PAIR`;折損從不寫池、不呼叫 `AffinityWritePort`**(列舉仍保留 `AFFINITY` 值,不刪)。F6 的「好感度代價寫入 append-only 池」前提已被 v0.3 第 3 節規則 4 與 v1.0 第 3、5.2 節取代,只有「每場每配對一個計數器放 `BattleState`」仍有效。折損與血都在 `BattleState`/單位上、同一提交內,不再有寫池才有的不可逆風險,「先驗證後扣款」可適度簡化。(答案檔題 5,設計師直接定;管理者裁決 1「甲 代價只在這場戰鬥」亦同。)
```

```old
付款人欄來自 011 的 F1 裁決。
```
```new
付款人欄來自 011 的 F1 裁決。
   - **已決(答案檔題 1)**:`named_unit_id` 一律 = 付款人;付款人集合由 `cost_type` + 卡類別導出,寫成**一個純函式**:`PAIR` 且雙人加成(c09~c11)/合擊(c12)→ `named` 與 `partner` 兩人皆付;`PAIR` 且補血(c13/c14)→ 只有 `named` 付。NONE 時各付 `hp_cost_none`,條件 `hp>cost`(v1.0 4.1、6.1)。
```

---

### story-016 story-016-pair-cost-phi-deduction.md

```old
> **Status**: Blocked —— 依賴 012、013、015;`affinity-position-chain.md` 公式五修訂後(同 013)才能在文件一致的前提下實作。
```
```new
> **Status**: Blocked —— 依賴 012、013、015;另等 `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B,進行中;同 013)才能在文件一致的前提下實作。原寫「公式五修訂後」已被此取代。
```

---

### story-017 story-017-heal-and-two-target-buff-cards.md

```old
> **Status**: Blocked —— 依賴 010、011、015;另卡 F7「距離函式用哪一份」須先查(派工前第 1 題)。
```
```new
> **Status**: Ready(依序:010、011、015 完成後才可派工)—— 派工前三題皆為實作者第一步查證,不是待裁決;原寫「卡 F7 距離函式」是 lead-programmer 自問,不擋派工。
```

```old
有向卡(c13 徐→藍、c14 秦→董):付款人/承受者有向,但好感度配對無向(`AffinityTypes.pair_of`),有向只用於誰付/誰收。
```
```new
有向卡(c13 徐→藍、c14 秦→董):付款人/承受者有向,但好感度配對無向(`AffinityTypes.pair_of`),有向只用於誰付/誰收。
- **已決(答案檔題 1)**:補血卡 c13/c14 `named_unit_id` = 付款人、`partner_unit_id` = 承受者;NONE 時只有付款人付血(`hp>cost`);雙人加成 c09~c11 則兩人皆付(015 的純函式決定,本單只接收結果)。
```

---

### story-018 story-018-direct-damage-card-and-kill-chain.md

```old
> **Status**: Blocked —— 依賴 010、011、015;卡在 F7(直傷是否尊重視線)與「直傷擊殺是否有反擊」兩題裁決。
```
```new
> **Status**: Ready(依序:010、011、015 完成後才可派工)—— F7 與「直傷擊殺是否有反擊」兩題已於 2026-11-17 決定(答案檔題 3、4),見「派工前須先決定」第 1、2 題。
```

```old
**game-designer 裁決**,工單在回答前不得開工。
```
```new
**game-designer 裁決**,工單在回答前不得開工。
   - **已決:直傷尊重視線**(視線被擋的敵人不可選為目標;射程 = 施放者當前位置的單位攻擊射程 `min_range`~`max_range`)。(v0.3 第 3 節規則 7;答案檔題 3。)**控制區:直傷不受影響**(設計師直接定)。**必須沿用「一般攻擊的目標合法性」同一個函式,不得另寫第二份視線判斷**(格式審查 F7 的重點);實作者第一步確認該函式是哪一個並於回報說明。⚠️ 設計師只讀了 ZoC 邊界情況表、未讀其規則本文,「ZoC 另有影響攻擊的條款」為**未驗證**,實作者確認同一函式時順帶看。
```

```old
實作者第一步讀;若現行攻擊有反擊而直傷設計未定 → 停下問。
```
```new
實作者第一步讀;若現行攻擊有反擊而直傷設計未定 → 停下問。
   - **已決:現行沒有反擊,直傷(擊殺與否)不引發反擊。** 依據:`src/` grep `retaliat|counter_attack|反擊` 零命中;`design/gdd/tactical-combat-system.md` 第 173 行「現階段核心戰鬥規則不含任何防守方自動迎擊/反擊機制」(答案檔題 4,設計師直接定)。⚠️ 設計師沒逐行讀 `battle_controller.gd` 攻擊流程,「是否有未用『反擊』字樣的迎擊邏輯」為**未驗證**——實作者讀 `_apply_attack()` 時順手確認,發現有迎擊邏輯才停下問。
```

---

### story-019 story-019-combo-damage-card.md

```old
> **Status**: Blocked —— 依賴 018、015;卡在 018 的 F7/反擊裁決;另有派工前第 1 題(c12 規格細節)。
```
```new
> **Status**: Ready(依序:015、018 完成後才可派工)—— 018 的 F7/反擊裁決與 c12 細節皆已於 2026-11-17 決定(答案檔題 3、4、6)。
```

```old
規格 v1.0 第 3.8 與 v0.3 c12 兩處是否一致:**未驗證**。
```
```new
規格 v1.0 第 3.8 與 v0.3 c12 兩處是否一致:**未驗證**。
   - **已決(答案檔題 6;v0.3 第 3 節規則 10、第 4 節 c12)**:各自獨立兩擊(各 6,合 12),**不是**合併一次 12;兩人各自對**同一**敵人造成固定傷害 `min(effect_value, 該敵人現有 HP)`,無視 DEF 與 Φ。射程交集 = 該敵人須**同時**在兩人各自的射程與視線內(尊重視線,沿用 018 的同一函式);合擊另須兩人距離 ≤2(v0.3 第 3.8 節)。NONE 時兩人各付血 3,`hp>cost` 兩人都要成立。⚠️ 「v1.0 第 3.8 與 v0.3 c12 兩處是否逐字一致」設計師未重驗,實作者第一步讀兩處,不一致則停下回報。
```

```old
需規格定案(建議:第二擊作廢、不退款;**未裁決**)。
```
```new
需規格定案(建議:第二擊作廢、不退款;**未裁決**)。
   - **已決(答案檔題 6,設計師直接定,管理者可推翻)**:兩擊依序結算、同一次提交;**第一擊擊殺則第二擊略過**,代價不退;擊殺鏈只觸發一次。第二擊略過時不播第二次動畫(交 ux/art);確認面板建議提示「目標剩餘 HP 低時,第二擊可能落空」(ADVISORY)。
```

```old
(依派工前第 1 題:各自/合併)
```
```new
(已決:各自獨立兩擊、依序結算;不是合併一次)
```

---

### story-020 story-020-card-confirm-panel-cost-and-unplayable-reason.md

無需改動(仍 Blocked:`ux-designer` 規格尚未存在;答案檔未涵蓋 UI 題)。

---

### story-021 story-021-relation-state-display-three-state.md

無需改動(仍 Blocked:`ux-designer` 規格尚未存在;答案檔未涵蓋 UI 題)。

---

### story-022 story-022-card-table-migration-14-cards.md

```old
> **Status**: Blocked —— 依賴 011、015、017、018、019;卡在卡 id 命名與 10A-1(牌面敘事,預設甲案中性改名)、D4(舊 6 張甲類去留)。
```
```new
> **Status**: Blocked —— 派工前三題(卡 id、10A-1、D4)已於 2026-11-17 全部決定(答案檔題 2、7、8);**仍卡**:①依賴 011、015、017、018、019 尚未完成 ②14 張卡的牌名/牌面文字須由 `narrative-director`/`writer` 交付(是否已交付:**未驗證**,派工前須向其索取)。
```

```old
1. **卡 id 命名**(同 011 第 2 題):`c01`/`card_01`。
```
```new
1. **卡 id 命名**(同 011 第 2 題):`c01`/`card_01`。
   - **已決:`card_11`~`card_24`**(c01 → card_11 … c14 → card_24);現行 `vs02_cards.txt` 的 `card_01`~`card_08` 已佔用,`card_09`、`card_10` 空著。(答案檔題 2;v0.3 第 3 節規則 13。)營火產出卡的 id 規則規格未定,營火批再定。
```

```old
不由工程師自擬**。
```
```new
不由工程師自擬**。
   - **已決:牌面 = 中性改名(= 10A-1 甲案)**,管理者 2026-11-12 裁決(`production/session-state/active.md` 第 278 行:「牌面 =『中性改名(設計師與創意總監都推薦)』」)。(答案檔題 7。)文案仍由 `narrative-director` 提供,是否已交付:**未驗證**。
```

```old
保留則 14 張為新增。
```
```new
保留則 14 張為新增。
   - **已決:vs02~vs05 退役舊 6 張免費甲類卡(`card_01`~`card_06`),vs01 教學場保留現狀**(v0.3 第 4 節末、第 10 節表;答案檔題 8)。⚠️ 這是設計師定案、**非管理者裁決,管理者可推翻**(設計師找不到管理者針對 D4 的明確裁決原文)。連帶:v0.3 6B 預設牌組 = c01~c12 + card_07 + card_08(共 14 張);丙類 `card_07`/`card_08` 不退役;寫死 `card_01`~`card_06` 的測試須改指向保留 id 或內嵌字面值(`grep -rln "card_0[1-8]" tests` 當場確認)。
```

---

### story-023 story-023-card-effect-value-external-override-seam.md

```old
> **Status**: Blocked —— 依賴 011;且**範圍待確認**:
```
```new
> **Status**: Deferred(管理者 2026-11-17:本批不做;依據答案檔題 12)—— 011 的 `effect_value` 維持由建構者/載入器傳入、不寫死,營火批再追加覆寫入口(追加式小改)。原:依賴 011;且範圍待確認:
```

```old
若協調者判定「本批不做 seam」→ 本單撤銷。
```
```new
若協調者判定「本批不做 seam」→ 本單撤銷。
   - **已決:本批不做**(管理者 2026-11-17 裁決「023 本批不做」;設計角度本批不必要,答案檔題 12)。本單保留為 Deferred,不撤檔,營火批啟動時重新排程。
```

---

### story-024 story-024-affinity-tests-fixed-two-pairs-rewrite.md

```old
> **Status**: Blocked —— 依賴 013、014(行為改後才知道哪些斷言失效)。
```
```new
> **Status**: Blocked —— 依賴 013、014(行為改後才知道哪些斷言失效);兩者仍 Blocked,等 `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B)。
```

---

### story-025 story-025-measure-m9-relation-distribution-and-k.md

```old
依賴 012、016、019、022(要有完整卡牌戰鬥才量得到)。
```
```new
依賴 012、016、019、022(要有完整卡牌戰鬥才量得到);其中 016 仍等 `affinity-position-chain.md` 整份重寫完成(管理者 2026-11-17 裁決 B)。
```

```old
**無判準前不得下結論**,只輸出分布。
```
```new
**無判準前不得下結論**,只輸出分布。
   - **已決:量測前 `k=0` 上線**(管理者 2026-11-17 裁決「量測前先設 0(設計師推薦)」)。`k=0` 是 AC3 的必備基準,候選 `k` 僅並列比較、不暫定非零值;若試玩覺得麥子健太快失去騎牆,正確動作是提前做本單(不必等 12/11 檢查點)。(`docs/reviews/straddle-q3-q4-recommendation-2026-11-17.md` Q4-A。)
```
