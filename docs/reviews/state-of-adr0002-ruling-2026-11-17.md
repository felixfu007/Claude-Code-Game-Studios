# `state_of(pair)` 與 ADR-0002 的關係:技術總監裁決建議(2026-11-17)

> **性質**:技術總監的判斷與建議,**不是管理者裁決**。第 3 節的登記表條目需由協調者呈管理者核准後才套用。
> **範圍**:只寫本檔。ADR-0002、`docs/registry/architecture.yaml`、story-012 一字未動。
> **問題來源**:`production/epics/skill-card-system/story-012-relation-state-of-pair.md` 的「派工前須先決定」第 1 題。
> **標記**:凡未當場讀原文或程式碼查證的,一律標「**未驗證**」。

---

## 0. 一句話結論

**只要 `state_of` 不放進 `AffinityDataPool`,就不碰 ADR-0002 契約、不需修訂 ADR,劑量規則 4 不會被觸發。**
推薦放在一個**新的小類別**(`AffinityRelation`),池與 `AffinityPhiProvider` 都不動;以一筆 `adr: none` 的 interface 條目登記到 `architecture.yaml`(與 2026-09-16 校準旋鈕條目同一形狀)。story-012 補一句即可開工。

---

## 1. 是否觸及 ADR-0002 契約

以下逐條引用 ADR 原文(檔案:`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`,當場讀過)。

### 1.1 決定性條文:Key Interfaces 開頭

> 「以下為本 ADR 定案的契約形狀。**具體命名與型別簽章可在實作時微調,但語意不得改變**;任何改變語意的調整須回頭修訂本 ADR。」

這條管的是**已列出的介面**的語意。`state_of` 只**呼叫** `combat_strength_read(pair)` 並解讀其回傳,不改變它的簽章、回傳形狀、拒絕碼或預設查詢時點 —— **對已列出的任何介面都沒有語意變更**。
→ **判定:放在池外時,不觸及。**

### 1.2 但若放「進池」,會觸及三處列舉性條文

ADR 有三處是**以完整清單寫成的**,在池上加一個公開方法會讓清單變得不完整:

| 條文 | 原文要點 | 加進池的後果 |
|---|---|---|
| Key Interfaces 的 `affinity_data_pool.gd` 方法清單 | 逐條列出池的全部公開方法(`append_record` … `import_state`) | 多一個未列出的公開方法 |
| 機制四之四「8 個帶 enum 參數的入口統一序數驗證」 | 「逐一針對 8 個帶 enum 參數的入口」;Validation Criteria 第 12 條以這 8 個為測試矩陣 | `state_of(pair: AffinityTypes.Pair)` 會是**第 9 個**帶 enum 參數的入口,本節與 VC#12 都變成漏列 |
| 機制四之二「兩條邊界規則」段 | 「它們把兩個原本隱含的性質升級為明文的…架構約束…**並指明未來新增介面時不得破壞**」 | 新增介面本身就是這段要求重新稽核的事件 |

另外,ADR 在機制四之二自己記載過一次同形狀的事故:2026-08-21 的修訂改了 `can_write()` 的簽章,而同 ADR 另一句仍逐字點名舊形狀 —— 「這是本專案『修法讓某個既有宣稱變得不成立』模式的第八次」。**把新方法加進池,就是在重開同一個面。**
→ **判定:放進池 = 觸及契約(三處清單需同步),必須修訂 ADR。**

### 1.3 職責邊界:池不擁有門檻,這有明文先例

- GDD `design/gdd/affinity-data-pool.md`(當場 grep):戰鬥強度讀取的回傳是「帶正負號的『目前極性與強度』」;**解讀它的是讀取方**(「好感度—位置連鎖系統…取得指定配對的當前極性與強度以計算位置加成/懲罰」)。
- 同 GDD 對 `absent_confirmed`:「門檻判定(`M` 的具體數值)不在本系統決定,留給…系統的 GDD 依實際 playtest 校準」。
- **最直接的先例** —— `architecture.yaml` 的 `affinity_calibration_knobs_constructor_injected`(2026-09-16 技術總監裁決)notes 原文:
  > 「`n_gate_min` is deliberately EXCLUDED: the pool never reads it; the `n(p) >= n_gate_min` comparison is performed by the narrative-unlock-and-endings system (#13), and the pool only returns `n_pair`.」

`k`(冷淡區半寬)與 `n_gate_min` 是**同一種東西**:套在池回傳值上的消費端門檻。先例已裁定這類門檻**不進池**。

### 1.4 放在池外時,`state_of` 必須遵守的 ADR 既有義務(不是修訂,是遵守)

| ADR 條文 | 對 `state_of` 的要求 |
|---|---|
| 機制五之二:「**必須先確認 `result.rejection == ReadRejection.NONE`,才可讀取任何其他欄位**」 | 先查 `rejection`;非 `NONE` → `push_error` + 回傳 `NONE`(story-012 規則已寫,一致) |
| 機制五之二:拒絕時 `value` 為 `NAN` 而非 `0.0` | 不可依賴「NaN 比較恰好都為 false 所以落到 NONE」—— 必須是**明確分支**,否則敏感度測試證明不了它 |
| 機制五:`combat_strength_read` 預設查詢時點為「若 `t_death(pair) != null` 則 `t_death(pair)`,否則 `_t_now`」 | `state_of` 對陣亡配對回傳的是**凍結在陣亡時刻**的狀態。戰鬥內不會發生(管理者 2026-11-12 已確認任一我方陣亡即戰敗,協調者已核 `battle_state.gd` `outcome()`,見 `active.md`);**營火/戰後情境是否也如此:未驗證** |
| Key Interfaces「記憶化契約的兩種快取形狀」:快取是**呼叫方義務**的形狀描述 | story-012 AC4「不快取」與此**不衝突** —— 該段描述「若快取,鍵要長什麼樣」,不強制快取 |
| Key Interfaces「同檔強制規則」:裸引用 `ReadRejection` 等巢狀列舉的型別必須與池同檔 | 新類別一律寫 `AffinityDataPool.ReadRejection.NONE`(加前綴),即**不受**同檔規則約束 —— 現行 `affinity_phi_provider.gd` 就是這樣寫的(已讀) |
| 機制一:依賴注入,非 Autoload | 池以參數傳入,不得做成 Autoload 或全域單例 |

### 1.5 若仍要放進池:劑量規則 4 怎麼辦

- ADR-0002 已修訂多次(Status 節自載「2026-08-21 第四次修訂」,其後 2026-08-24、2026-08-25 各一次);2026-09-16 的登記表條目原文:「Dosage rules 3 and 4 … both point away from a sixth ADR-0002 revision」。**再修一次就違反規則 4。**
- 規則 4 的明文出路只有兩個:**重寫或擱置**(`technical-preferences.md`:「要改第 3 次表示該重寫或該擱置,不是該再修」)。ADR-0001 在 2026-10-12 走過「整份重寫、零決策變更」這條路。
- 對 ADR-0002 而言,重寫是一份 1211 行文件的整份重寫 —— **為了加一個有其他放法、且放進去還違反職責先例的函式,代價不成比例。**
- ⚠️ 規則 4 另有一句「只往後生效,不追改已完成的 5 份 ADR」。這句是否意味著 ADR-0002 的修訂計數從 2026-08-25 起歸零重算 —— **條文沒有明說,本檔不自行解釋**;但 2026-09-16 的先例是按「再修就是第六次」處理的。無論怎麼解釋,第 2 節的推薦都讓這個問題**不需要被回答**。

---

## 2. 放置位置:三個選項

### 選項 A:放進池(`affinity_data_pool.gd`)

- **後果**:觸及契約(第 1.2 節三處清單)→ 必須修訂 ADR-0002 → 撞劑量規則 4 → 只能整份重寫或擱置。`k` 也得進池:要嘛塞進建構期注入的 `AffinityCalibration`(改動另一條已登記 interface 的 `signal_signature`),要嘛讓 Foundation 層的池去讀 `TuningKnobs`。
- **違反先例**:`n_gate_min` 已裁定不進池(第 1.3 節)。
- **唯一好處**:呼叫端只要拿到池就能用。
- **不推薦。**

### 選項 B:放進 `AffinityPhiProvider`

- **後果**:`AffinityPhiProvider._init(state: BattleState, pool: AffinityDataPool)`(已讀程式碼)—— 它**綁定一場戰鬥**。
  - 營火在戰鬥外,沒有 `BattleState` 可給它。v1.0 規格(`design/quick-specs/card-campfire-rework-v1-2026-11-12.md` 第 149 行)明列營火要讀 `state_of`。營火若要用,只能硬造一個假 `BattleState`,或另寫第二份 —— 後者正是冷淡區提案第三節明文禁止的「另寫第二套門檻」。
  - story-014(騎牆)要在 `BattleState` 內呼叫它,而 provider 本身持有 `BattleState`:`BattleState` → provider → `BattleState`,兩者皆 `RefCounted`(已讀兩檔的 `extends`)。**是否形成實際的參照循環取決於 014 怎麼接,未驗證**;現行 `_defense_phi_provider` 是用 `Callable` 掛載(已讀 `battle_state.gd`),同法可迴避,但那是把問題推給 014。
  - 職責混雜:這個類別的檔頭自述是「滿足 `BattleController.phi_provider` 契約的轉接器」,判定關係三態不是 Φ。
- **好處**:改動最少,story-013 改第 3 分支時就在同檔。
- **不推薦**(營火會被迫複製)。

### 選項 C(推薦):新類別 `AffinityRelation`,池與 provider 都不動

- **形狀(建議,實作者可微調命名,不可改語意)**:
  - 新檔 `src/gameplay/affinity/affinity_relation.gd`,`class_name AffinityRelation extends RefCounted`(當場 grep 確認目前無同名 `class_name`)。
  - `enum RelationState { NONE = 0, POS = 1, NEG = 2 }` 巢狀於此類別 —— 第 0 值為最安全預設(與 story-012 規則一致)。
  - `static func state_of(pool: AffinityDataPool, pair: AffinityTypes.Pair, neutral_band: float) -> RelationState`
    —— 純函式:每次呼叫即時 `pool.combat_strength_read(pair)`,無狀態、無快取、不寫池。
  - `k` 的來源:建議放進既有的 `AffinityTuning`(`src/gameplay/tuning/affinity_tuning.gd`,已讀:`SECTION = "affinity"`,正好對上鍵名 `affinity,neutral_band_centi`),呼叫端從同一個 `AffinityTuning` 取值後傳入。**`AffinityTuning` 加欄位的實際載入路徑:未驗證,實作者當場讀 `tuning_knobs.gd` 確認。**
  - (可選)把純判定拆成 `static func classify(n_pair: int, value: float, neutral_band: float) -> RelationState`,`state_of` 只負責查池與處理拒絕。好處:AC1 的四條判定與邊界不需要建池就能測。
- **後果**:
  - ADR-0002 零接觸 —— 只用它已列出的 `combat_strength_read` 與 `AffinityReadResult.n_pair`/`.value`/`.rejection`(已讀 `affinity_data_pool.gd`:`var value: float`、`var n_pair: int`,拒絕時 `value = NAN`)。
  - 戰鬥(013、014、015、016)、UI(021)、營火都呼叫**同一個**函式,與名字無關的保證只需在一處守住。
  - 符合冷淡區提案第四節原本的建議(提案原文例:「`AffinityRelation.state_of(pair)`」)。
- **代價**:多一個檔案;`neutral_band` 由呼叫端傳入,理論上兩個呼叫端可能傳不同值。緩解:登記表條目明文規定「`neutral_band` 一律取自 `AffinityTuning`,不得在呼叫端寫死或另讀」(見第 3 節);AC7 第 ⑥ 條的「k 寫死 50」mutant 也覆蓋這一點的一部分。
  - ⚠️ 若希望**結構上**防止傳錯值,替代形狀是做成實例類別 `AffinityRelation.new(pool, tuning)` 由一處建構後共用。代價是又一個要保持存活、要注入的物件。**我推薦靜態版**(更簡單、可測),以登記表紀律換掉結構保證 —— 這是取捨,不是免費的。

### 推薦

**選項 C,靜態函式版。** 理由依序:不碰已核准契約(可逆性最高、不觸發規則 4)、有直接先例(`n_gate_min`)、唯一一個營火能直接用而不必複製的選項。

---

## 3. 是否登記 `architecture.yaml`

**需要。** 理由:

1. 這是**跨系統契約** —— 消費者至少有位置連鎖(013)、戰鬥騎牆(014)、卡牌代價(015/016)、介面三態顯示(021)、營火(v1.0 規格第 149 行)。劑量規則 3:ADR 只在跨系統契約時才寫;本專案對「跨系統契約但上游 ADR 已核准」的既定做法是**以登記表條目取代新 ADR**(`affinity_pairing_data_per_query_refetch`、`affinity_calibration_knobs_constructor_injected` 兩條皆 `adr: none`,已讀)。
2. 不登記的話,「單一判定、不得另寫門檻」只存在於一份提案與一張工單裡 —— 工單 Done 之後就沒人會讀。

### 逐字建議條目(放在 `interfaces:` 節末尾,`api_decisions:` 之前)

協調者呈管理者核准後套用。⚠️ 本機無 YAML 解析器(登記表檔頭自載),套用後請比照前例做縮排/鍵層級掃描與 `git diff` 純新增檢查。

```yaml
  - contract: affinity_relation_state_single_judgment
    status: active
    pattern: method_call
    producer: affinity-position-linkage    # 判定住在 src/gameplay/affinity/,不在池裡
    consumers:
      - affinity-position-linkage   # story-013:_link_for_pair 改讀 RelationState
      - tactical-combat-system      # story-014:騎牆 lone_guard/hold_back 的「身上沒關係」閘門
      - skill-card-system           # story-015/016:PAIR 代價依打牌當下的 RelationState
      - affinity-visual-ui          # story-021:友好/冷淡/敵對三態顯示
      - campfire                    # 營火(v1.0 規格),戰鬥外呼叫
    adr: none                       # 技術總監 2026-11-17 建議(docs/reviews/state-of-adr0002-ruling-2026-11-17.md)。
                                    # 刻意【不】修訂 ADR-0002:本契約只呼叫其已列出的
                                    # combat_strength_read(),不改任何簽章或語意;放進池會讓
                                    # ADR 的方法清單、機制四之四的 8 入口清單與 VC#12 同時漏列,
                                    # 且劑量規則 3/4 都指向不再修訂 ADR-0002。
    signal_signature: "AffinityRelation.state_of(pool: AffinityDataPool, pair: AffinityTypes.Pair, neutral_band: float) -> AffinityRelation.RelationState  # enum { NONE = 0, POS = 1, NEG = 2 }"
    notes: >
      ONE JUDGMENT, ONE PLACE. Every system that needs "do these two have a relationship,
      and which sign" calls AffinityRelation.state_of(). Rule: NONE if n_pair == 0 or
      |value| <= k; POS if value > k; NEG if value < -k. Ten pairs, one formula — no branch
      may test which characters a pair contains.
      k (neutral band) comes ONLY from AffinityTuning (data key affinity,neutral_band_centi,
      integer / 100). Callers must not hardcode it, read it from anywhere else, or apply a
      second threshold of their own (e.g. inside CombatRules) — that is exactly the
      "two implementations that merely agree today" shape this project has registered before.
      k = 0 MUST reproduce the pre-2026-11-17 behaviour of AffinityPhiProvider._link_for_pair
      bit-for-bit (story-012 AC3).
      The pool deliberately does NOT own k — same reasoning as n_gate_min in
      affinity_calibration_knobs_constructor_injected: the pool returns a signed value and
      n_pair; thresholds on that value are consumer policy.
      Obligations inherited from ADR-0002 (not new rules): check result.rejection first; on
      any rejection return NONE with push_error (value is NAN on rejection, so the branch must
      be explicit, not an accident of NaN comparisons); never cache; never write the pool.
      Dead pairs: combat_strength_read defaults t_query to t_death, so a dead pair's state is
      frozen at death. Unreachable in battle (any PLAYER death = DEFEAT); for campfire /
      post-battle contexts this was NOT verified as of 2026-11-17.
      No lint, hook or gate checks any of this — compliance is unobservable; this entry buys
      a written rule a reviewer can check against, not enforcement.
    referenced_by:
      - production/epics/skill-card-system/story-012-relation-state-of-pair.md
      - docs/reviews/affinity-zero-state-proposal-2026-11-12.md
      - design/quick-specs/card-campfire-rework-v1-2026-11-12.md
    added: 2026-11-17
```

**未驗證項(套用前由協調者或實作者確認)**:
- `consumers:` 的系統代號 `tactical-combat-system`、`skill-card-system`、`affinity-visual-ui`、`affinity-position-linkage` 皆在本登記表其他條目出現過(當場 grep);**`campfire` 這個代號在本表中是否已有既定寫法:未驗證**,請以現有條目或 `design/gdd/systems-index.md` 的名稱為準替換。
- 若採選項 C 的實例版而非靜態版,`signal_signature` 需改寫。
- 檔頭 `last_updated` 行是否要比照前例加一段紀錄:依前例應加,本檔不代擬(該行已極長,怎麼寫屬套用者判斷)。

**是否另加一條 forbidden pattern**(例:`second_relation_threshold_outside_affinity_relation`):我**不建議現在加**。上面條目 notes 已寫明禁令,而那條禁令目前沒有任何違反者可以擋;本專案前瞻性禁令的先例(`abstract_func_with_body`、`affinity_line_suppression_or_asymmetric_contribution`)都是「已經真的出過事」才立的。等 013/014 落地後若真出現第二套門檻,再立不遲。

---

## 4. 結論:story-012 可否照現狀開工

**可以開工,但要先在工單補一句** —— 因為現行 `Affected Files` 只列「`affinity_phi_provider.gd` 或 `affinity_data_pool.gd`」,並寫「超出此清單先問」;推薦方案用的是**新檔**,照現狀開工會撞上工單自己的閘門。

### 建議補進 story-012 的句子(逐字;story 檔是既有文件,需協調者依 2026-10-05 規則先問再改)

放在「派工前須先決定」第 1 題下方:

> **✅ 2026-11-17 技術總監建議(`docs/reviews/state-of-adr0002-ruling-2026-11-17.md`)**:不放池、不放 `AffinityPhiProvider`;新增 `src/gameplay/affinity/affinity_relation.gd`(`AffinityRelation.state_of(pool, pair, neutral_band) -> RelationState`,靜態純函式),`k` 經 `AffinityTuning` 載入。**不觸及 ADR-0002 契約,不修訂 ADR。** 本單不改 `affinity_phi_provider.gd` 與 `affinity_data_pool.gd`(第 3 分支改讀 `state_of` 屬 story-013)。

並把 `Affected Files` 第一條改為:

> - `src/gameplay/affinity/affinity_relation.gd`(新檔)
> - `src/gameplay/tuning/affinity_tuning.gd`、`src/gameplay/tuning/tuning_knobs.gd`(加 `neutral_band_centi`,當場確認載入路徑)

### 順帶回答「派工前須先決定」第 2 題

`n` 的讀取來源:**`combat_strength_read(pair)` 回傳的 `AffinityReadResult.n_pair`**(已讀 `affinity_data_pool.gd` 的 inner class 宣告,現行 `_link_for_pair` 也正是讀 `result.n_pair == 0`)。不需要新的讀取介面。

### 開工前不需要等的事

- 管理者核准第 3 節的登記表條目 —— **不擋開工**。條目是在記錄這個決定,不是這個決定的前提;但應在 story-012 Done 之前套用,否則 013/014 的實作者讀不到它。
- `k` 的正式值 —— 不擋,story-012 已明定以 `k=0` 先行。

### 我不確定、需要人判斷的一處

v1.0 規格第 75 行把營火的「寫入入口許可」列為未驗證、交 lead-programmer。那是**寫入**側,與本檔處理的**讀取**判定無關,本檔沒有查證它是否觸及 ADR-0002;**不要把本檔的「不觸及契約」結論延伸到營火寫入入口上。**
