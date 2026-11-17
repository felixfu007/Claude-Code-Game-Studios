# 好感度位置鏈 公式五(及連帶條文)改文草稿(2026-11-17)

> 性質:**草稿,不是核准。** 目標檔 `design/gdd/affinity-position-chain.md` 本次一個字都沒動。
> 解鎖對象:`production/epics/skill-card-system/` 的 story-013、014(Blocked 條件「公式五須先修訂」)、016(依賴 013)。
> 依據:管理者 2026-11-12 裁決(任何兩人都可能變朋友或仇人;零點採冷淡區;騎牆 =「身上沒關係時有效,一有關係就失效」,只看場上存活者);`docs/reviews/affinity-zero-state-proposal-2026-11-12.md`;規格 `design/quick-specs/card-campfire-rework-v1-2026-11-12.md` 第 3、7 節;creative-director 清單 D2/D3(`active.md` grep「依「任何兩人」裁決須改的清單」)。
> 逐字引用的原文行號是 **2026-11-17 當下所查**,行號會漂,請以「錨點文字」為準,不以行號為準。
> 🔴 **本檔工具限制揭露**:本次我手上沒有 Bash,**無法執行 `git log` / `git show`**。因此第三節測試影響、第一節修訂次數都靠 Read/Grep,未跑引擎、未跑測試;標「未驗證」者即是。

## 一、修訂次數判斷(規則 4)

**git log 原始輸出:本次無法取得(無 Bash)。** 請協調者貼:`git log --oneline -- design/gdd/affinity-position-chain.md`。

可由檔案本身查證的下限證據(Read/Grep 原文):

1. 目標檔檔頭「2026-11-03 加註」逐字:`**第 5 次(含)以上修訂**,見 docs/reviews/affinity-core-gdd-diff4-2026-11-03.md 第 0 節`。
2. 該 diff4 檔第 0 節逐字:`規則 4:同一份文件不做第三次以上修訂。**四份目標檔全部已超過;規則 4 對這四份均無例外登記。**`(該檔自述「我沒有 git,依檔頭/修訂紀錄自述數」,是下限,未經 git 複驗。)
3. 該檔另自陳:`design/gdd/reviews/affinity-position-chain-review-log.md` 最近條目為 8/31 核准,未見 10/30 兩次修訂紀錄。

**結論:本次會是第 6 次(含)以上修訂,遠超規則 4 的上限(第 3 次)。** 規則 4 的要求是「要改第 3 次表示該重寫或該擱置,不是該再修」。目標檔現況也印證:同一個結論(戊的 Φ 與獨行)已被「已被取代/作廢/加註」疊了三層,讀者必須自己合成現行規則。另:該檔是規則 1(400 行)的明文例外檔,但規則 4 沒有任何例外登記。

### 替代方案(請管理者選,見第四節 Q1)

| 方案 | 做法 | 優點 | 缺點 |
|---|---|---|---|
| **A 新檔取代公式五(推薦)** | 公式五「騎牆有效判定」與下方第二節各處改文的**現行規則**,寫成新檔(例 `design/gdd/affinity-straddle-rule.md`,或升格規格 v1.0 第 3 節);目標檔只做**一處**指標性加註(第二節 C1,說「公式五以新檔為準」)。 | 不再往三層疊加註的檔裡塞第四層;單一出處;改動面最小。 | 目標檔仍被動第 6 次(一行指標),仍需管理者例外或明文「指標不計修訂」;舊文散落處(C3~C8)仍寫「戊 Φ 恆 0」,與新檔並存,**舊/新兩份說法會互相矛盾**(本專案最常見的失效形狀),須靠 C1 加註與 C3~C8 的最小修正壓住。 |
| **B 整份重寫** | 把 5 次修訂與本次裁決消化成一份乾淨 GDD,**零決策變更**(ADR-0001 2026-10-12 的做法)。 | 規則 4 指定的標準動作;一次還清舊債;第二節的逐字改文可原樣併入重寫稿。 | 約 670 行文件重寫、需逐條對帳表;成本最高,且會擋 013/014/016 更久。 |
| **C 不改目標檔,管理者明文宣告「公式五被規格 v1.0 取代」** | 工單 Blocked 條件改為「管理者已宣告」。 | 零改動。 | 目標檔留著「戊 Φ 恆 0、不加關係線」的現行語氣,讀 GDD 的人會寫出與 013/014 相反的程式;**我不推薦**。 |

我的推薦:**A**(只改一行指標 + 新檔);若管理者不願讓目標檔再動第 6 次,則 **B**。決定權在管理者。**下方第二節的改文無論選 A 或 B 都可用**(A 只取 C1 寫入目標檔,其餘寫入新檔;B 全部併入重寫稿)。

## 二、逐處改動(共 12 處,C1~C12)

每處:錨點 → 原文(逐字)→ 改為(逐字)→ 理由/對應裁決。「加註」處一律**保留原文、在其後插入**(沿用目標檔「舊文保留加註」慣例);OQ-1 例外,見該處。

### 先定義新詞(供 C3~C12 引用,單一定義處 = C4)

`state_of(pair)` 與冷淡區 `k` 的定義權威在規格 v1.0 第 3 節/story-012,**本稿只引用,不複述其公式**。`straddle_active`(騎牆有效)的定義在 C4。

---

### C1 檔頭加註(位置:緊接「2026-11-03 加註」那一行之後插入)

- 錨點:`**第 5 次(含)以上修訂**,見 \`docs/reviews/affinity-core-gdd-diff4-2026-11-03.md\` 第 0 節。`
- 原文:無(插入)。
- 改為(逐字):

> **2026-11-17 加註(管理者 2026-11-12 裁決「任何兩人都可能變朋友或仇人」之文件同步)**:**公式五的前提改變** —— 戊(麥子健)不再「沒有任何關係線、Φ 恆為 0」。他與其餘四人各有一組好感度配對,同其他九組一樣由關係狀態 `S ∈ {NONE, POS, NEG}` 決定有無關係線。**騎牆(獨行減傷與留一手)只在他的 4 組 S 全為 NONE 時有效**,見公式五「騎牆有效判定」。本文件前文所有「戊沒有任何關係線」「戊 Φ 恆為 0」的敘述,**一律讀為「開場時如此,且僅在 4 組皆 NONE 時如此」**。本次為第 6 次(含)以上修訂,依規則 4 之處置見 `docs/reviews/affinity-position-chain-formula5-draft-2026-11-17.md` 第一節。

- 理由:避免讀者只讀到舊句就下結論;所有「恆 0」散句(C3、C5~C8)因此有一個統一的上位覆蓋。**方案 A 時這是目標檔唯一必改處。**

### C2 Overview 加註(位置:Overview 那段 `> 🔴 **2026-10-30 已被部分取代…` 引言塊之後)

- 錨點:`> 「唯一」二字的移除(2026-08-31)與上游 OQ-5 的同批限定義務**照舊有效**。`
- 原文(同塊第二行,逐字):`> 上方 ⚠️ 兩項中:②「只覆蓋輸出通道」**不再成立**(Φ>0 時承傷減少,Φ<0 時承傷增加);①「對戊完全不適用」**部分不再成立**:戊的 **Φ 仍恆為 0**(輸出通道不變),但他有**條件式獨行減傷**(承傷通道,公式五)。`
- 改為(在上述錨點行之後插入,逐字):

> 🔴 **2026-11-17 再取代**:上句「戊的 **Φ 仍恆為 0**」**不再無條件成立** —— 僅在戊的 4 組關係狀態全為 NONE 時成立;任一組為 POS/NEG 時,戊與其他單位一樣有關係線、有 Φ(公式一),同時**失去騎牆**(公式五)。

- 理由:Overview 是最先被讀到的地方,兩層舊句都寫「恆為 0」。

### C3 公式五首句

- 錨點:`戊沒有任何關係線,Φ 恆為 0(人設:`
- 原文(逐字,該行全文):`戊沒有任何關係線,Φ 恆為 0(人設:\`design/narrative/characters.md\` 戊 條「絕不把籌碼押在同一邊」「算計過的自我保護」;**不加關係線**)。獨行減傷把這個人設做成玩法:`
- 改為(保留原行,在其後插入,逐字):

> 🔴 **2026-11-17 取代上一段的前提**:戊**可以**有關係線(管理者 2026-11-12 裁決:任何兩人都可能變朋友或仇人)。他的 4 組配對與其他九組用**同一個** `S` 判定、不看名字。「絕不把籌碼押在同一邊」這條人設改由**騎牆有效判定**落實:**身上沒有任何關係時,騎牆生效;一有關係(任一組 POS 或 NEG),騎牆失效、並肩加成取而代之**。獨行減傷與留一手因此變成「不押注」的可見獎勵,而非「天生沒有線」的副作用。

- 理由:原句把「沒有線」當前提,裁決推翻了前提,但人設意圖(不押注)保留 —— 這是 creative-director 清單 D1(`characters.md` 第三節)的文件同步義務,見 Q2。

### C4 公式五新增「騎牆有效判定」(**本稿核心,新單一定義處**;位置:C3 之後、`- \`d_min\` = 戊與…` 之前;方案 A 則寫入新檔)

- 原文:無(插入)。
- 改為(逐字):

> **騎牆有效判定(2026-11-17 裁決新增 —— 唯一定義處)**
>
> ```
> straddle_active = ALL over m in alive_allies(戊) : state_of(pair(戊, m)) == NONE
> lone_guard_eff  = straddle_active ? lone_guard(d_min) : 0
> hold_back_eff   = straddle_active ? hold_back(is_straddler, d_min) : 0
> ```
>
> | Symbol | Type | Range | Description |
> |---|---|---|---|
> | `alive_allies(戊)` | set of unit | 0~4 個單位 | 戊以外、場上**目前存活**的我方單位。**只看存活者**(管理者 2026-11-12 裁決);已陣亡者的配對不參與 |
> | `state_of(pair)` | enum | {NONE, POS, NEG} | 該配對的關係狀態,**每次查詢即時讀池、不快取**。定義見規格 v1.0 第 3 節 / story-012:`n==0` 或 `\|v\|≤k` → NONE;`v>k` → POS;`v<−k` → NEG。與配對名字無關 |
> | `straddle_active` | bool | {true, false} | 騎牆是否有效。**同一個布林同時驅動下面兩項,不得各算一次** |
> | `lone_guard(d_min)` | int | −1 / 0 / +2 | 既有公式五距離表(下方 `d_min` 條,含 2026-11-03 加註後的現行表) |
> | `hold_back(...)` | int | {0, 1} | 既有「留一手」定義(下方) |
> | `lone_guard_eff`、`hold_back_eff` | int | −1~+2 / {0,1} | 實際進入公式四 `guard_total` 與傷害式的值 |
>
> - **輸出範圍**:`straddle_active` 為布林;`lone_guard_eff`、`hold_back_eff` 為對應既有值或 0,不新增夾限(`guard_total` 仍只在公式四夾一次)。
> - **只選取使用者**:本判定只對名冊旗標 `lone_guard=1` 的我方單位(戊)計算;其他單位 `lone_guard_eff = 0`、`hold_back_eff = 0`(既有規則不變)。
> - **兩項同開同關**:`straddle_active = false` 時**兩項皆為 0**,包含 `d_min = 1` 的相鄰懲罰 −1(此點見 Q3,待管理者確認)。不得只關一項(否則騎牆半開)。
> - **`CombatRules` 不認識好感度池**:`straddle_active` 由戰棋狀態端(`BattleState`)向好感度側查完,以布林傳入 `CombatRules`;不得在 `CombatRules` 內另寫第二套門檻。
> - **無存活隊友**:`alive_allies` 為空 → 全稱式成立(`straddle_active = true`),但此時 `d_min` 無值、既有規則已規定 `lone_guard = 0`、`hold_back = 0`,故結果不變。
> - **由構造得到的互斥**:`lone_guard_eff ≠ 0` 或 `hold_back_eff ≠ 0` ⇒ 戊 4 組皆 NONE ⇒ 戊無任何關係線 ⇒ `Φ_def(戊)` 與 `Φ_att(戊)` 皆為 0。因此公式四的 `guard(Φ_def)` 與 `lone_guard_eff` **結構上不會同時非零**,既有「夾限 GUARD_MAX 預防日後戊被加線時疊加」不再是預防措施,而是不可達的保險。
>
> **算例**(戊 DEF 8,敵 ATK 14,戊站在離最近隊友 `d_min = 2` 格,`k` 取任意值,配對狀態為假設值):
>
> | 情境 | `straddle_active` | `lone_guard_eff` | `Φ_def` | `guard` | 傷害 = 14 − 8 + 0 − guard_total |
> |---|---|---|---|---|---|
> | 4 組全 NONE | true | +2 | 0 | 0 | 14−8−2 = **4** |
> | 戊×甲 POS,甲在距戊 2 格(距離 2 = 死區,貢獻 0) | false | 0 | 0 | 0 | 14−8−0 = **6** |
> | 戊×甲 POS,甲在戊旁 1 格(`d_min=1`) | false | 0(連 −1 一併關) | +3 | ceil(3/2)=2 | 14−8−2 = **4** |
> | 戊×甲 POS,但甲**已陣亡** | true(只看存活者,甲不參與) | +2 | 0 | 0 | **4** |
>
> 最後一列在實際戰鬥中不可達(任一我方陣亡即戰敗,`battle_state.gd` `outcome()`,數字與讀法取自規格 v1.0 第 3 節的協調者核實註記,本稿未重驗);列出是為了釘住函式語意,不得依賴該巧合。

- 理由:規格第 3 節與 story-014 的規則。算例第 3 列說明「失效不等於戊變脆」:有並肩關係時由 `guard(Φ_def)` 接手。**第 3 列的 Φ=+3 取自既有 R3 曲線(正向相鄰 +3)與公式四 `ceil(Φ/2)`,算術推出,未跑程式。**

### C5 公式五距離表與「只作用於承傷」bullet 的加註

- 錨點 a:`- \`d_min\` = 戊與**所有存活隊友**(戊以外的我方存活單位)之**最短曼哈頓距離**`
  (**不改**;只在 C4 之後讓它成為「`straddle_active = true` 時才適用」。)
- 錨點 b(逐字原文):`- 只作用於承傷(進入公式四的 \`guard_total\`),**不影響戊的攻擊**。戊 Φ 恆 0,故與公式四的 \`guard(Φ_def)\` 不會同時非零;夾限 \`GUARD_MAX\` 預防日後戊被加線時疊加。`
- 改為(在錨點 b 該 bullet 及其既有 2026-11-03 加註之後插入,逐字):

> 🔴 **2026-11-17 加註**:上一條「戊 Φ 恆 0」與「預防日後戊被加線時疊加」**由騎牆有效判定取代** —— `lone_guard_eff` 與 `hold_back_eff` 只在 `straddle_active = true` 時非零,此時戊必無關係線,故兩者與 `guard(Φ_def)` 結構上不會同時非零(見上「騎牆有效判定」)。上方距離表(d=1 → −1、d=2 → +2、d≥3 或無隊友 → 0)與「留一手」定義**數值不變**,只是**前置條件**多了 `straddle_active = true`。`hold_back` 條件「攻擊方為旗標單位且攻擊當下所在格 `d_min = 2`」改為「…且 `straddle_active = true`」。

- 理由:距離表、留一手的數字沒有被任何裁決改動,只加前置條件,避免把已有測試釘住的數值再動一遍。

### C6 Edge Cases:「角色沒有任何關係線(如戊)」

- 錨點:`- **角色沒有任何關係線**(如戊):\`Φ\` **恆為 0,不論站哪**。`
- 原文(逐字):`- **角色沒有任何關係線**(如戊):\`Φ\` **恆為 0,不論站哪**。`
- 改為(在該條及其既有 2026-10-30 加註之後插入,逐字):

> 🔴 **2026-11-17 加註**:「如戊」不再成立。**任何單位**在其所有配對 `S` 皆為 NONE 時 `Φ` 為 0(不論站哪)。戊與其他單位無差別;差別只在戊另有騎牆(公式五)。

### C7 Edge Cases:「戊被日後加入關係線」與新增邊界

- 錨點:`- **【新增】戊被日後加入關係線**:\`guard(Φ_def)\` 與 \`lone_guard\` 可同時非零,以 \`GUARD_MAX\` 夾限;是否保留獨行減傷須重新裁決。`
- 原文:同錨點行全文。
- 改為(在原行之後插入,逐字):

> 🔴 **2026-11-17 已裁決,取代上一條**:戊的關係線由 `S` 決定,**不是「被加入」**。任一組 `S ≠ NONE` → 騎牆失效 → `lone_guard_eff = hold_back_eff = 0`,`guard(Φ_def)` 照常。兩者**不會同時非零**(見公式五「由構造得到的互斥」)。
> - **【2026-11-17 新增】戰鬥中 `S` 翻轉**(例:丙類寫池,`skill-card-system.md` 卡 07/08):`straddle_active` **每次查詢即時重算、不快取**。翻轉後的**下一次**查詢(預覽、結算)立即反映。⚠️ 與 Interactions ② 的「`Φ` 在結算中為快照」並存:**單次結算內,`straddle_active` 與 `Φ` 取同一個快照**(結算步驟①取值);此處「快照範圍是否涵蓋 `straddle_active`」屬戰棋系統契約,見第四節技術確認項 T1,**未驗證**。
> - **【2026-11-17 新增】預覽與結算同一函式**:`straddle_active` 的取得路徑,預覽(`lone_guard_if_at(unit_id, tile)`)與結算(`_lone_guard_of`、`_hold_back_of`)必須是**同一個**(沿用 UI Requirements 第二條)。
> - **【2026-11-17 新增】`k = 0` 的實際後果**:`k = 0` 時任何 `n>0` 且 `v≠0` 的配對即為非 NONE,戊只要與任何人有過一次非抵銷的互動,騎牆即永久失效(冷淡區提案對方案 (a) 的自述缺點)。`k` 的正式值待 story-025 量測;**不得以占位值 50 上線**(story-012)。見 Q4。

### C8 UI Requirements:「無關係線的角色(戊)」

- 錨點:`- **無關係線的角色**(戊)須明確呈現「本系統對他不適用」,而非顯示一個空的 0 ——`
- 原文(兩行,逐字):`- **無關係線的角色**(戊)須明確呈現「本系統對他不適用」,而非顯示一個空的 0 ——` / `  兩者對玩家的意義完全不同。`
- 改為(在該條之後插入,逐字):

> 🔴 **2026-11-17 取代上一條對象**:不再依「角色是不是戊」決定,改依狀態:**戊 4 組皆 NONE 時**呈現「騎牆:有效」(並顯示當下獨行減傷或留一手來源);**任一組非 NONE 時**呈現其關係線(同其他單位)並明示「騎牆:失效(原因:與○○有關係)」。三態(友好/冷淡/敵對)的顯示版面見 story-021;**UI 版面交 `/ux-design`,須開窗驗證(headless 取不到像素)**。

### C9 Tuning Knobs:校準段「無關係線者(戊)」加註與新旋鈕指路

- 錨點:`加大 \`Φ\` 會讓「無關係線者」(戊)與「加成無感者」(丙)的落差**反而擴大**。`
- 原文:同錨點行。
- 改為(在該行之後插入,逐字):

> 🔴 **2026-11-17 加註**:上句「無關係線者」改讀為「**4 組皆 NONE 的戊**」。另新增旋鈕 `affinity,neutral_band_centi`(冷淡區半寬 `k` 的百分之一單位整數編碼;**定義與安全範圍的唯一出處在規格 v1.0 第 8 節與 story-012,本文件不複述**)。它同時決定「一對配對何時算有關係線」與「戊何時失去騎牆」,**不得為騎牆另設第二個門檻**。`k` 初值待量測(story-025);調它須同步重驗:輸出通道 `Φ` 校準(既有義務)與戊騎牆的實際持續度。

### C10 Acceptance Criteria:新增 AC-S1~AC-S6,並標註既有 AC-L 的前提

- 錨點:`### 【2026-10-30 新增】減傷與獨行減傷(BLOCKING,自動單元測試` 節末(`AC-H6` 之後)插入。
- 改為(逐字):

> 🔴 **2026-11-17(騎牆有效判定)**:AC-L1~L13、AC-H1~H6 的測試夾具**前提皆為「戊 4 組 S 全為 NONE」**(池空),此前提現須明寫於各測試的 GIVEN。
> - **AC-S1(全 NONE → 兩項皆開)**:GIVEN 戊 `d_min=2`、4 組 NONE,THEN `lone_guard_eff = +2` 且 `hold_back_eff = 1`。
> - **AC-S2(任一非 NONE → 兩項皆關)**:GIVEN 同上但 4 組中恰 1 組 POS(再測 1 組 NEG),**逐組各一條(共 8 條)**,THEN `lone_guard_eff = 0` 且 `hold_back_eff = 0`,並各自斷言**可觀察結果**(受擊傷害 6、攻擊傷害不含 −1),不只斷言布林。
> - **AC-S3(相鄰懲罰一併關閉)**:GIVEN 戊與有 POS 關係者 `d_min=1`,THEN `lone_guard_eff = 0`(不是 −1)。**取決於 Q3 的裁決;裁決前此條不得寫成測試。**
> - **AC-S4(只看存活者)**:GIVEN 戊×甲 POS 且甲陣亡(測試夾具直接標死,不經戰敗流程),THEN `straddle_active = true`。
> - **AC-S5(即時)**:GIVEN 戰鬥中池被寫入使戊×乙由 NONE 變 POS,THEN 下一次傷害/預覽查詢 `lone_guard_eff = 0`;再寫回 NONE → 恢復 +2(冷淡區可逆)。
> - **AC-S6(互斥)**:GIVEN 任意佈局,`lone_guard_eff ≠ 0` 與 `guard(Φ_def) ≠ 0` **不同時成立**(窮舉 4 組 S 的 3⁴ = 81 種組合,各取一個 `d_min`)。
> - **AC-S7(`CombatRules` 無池知識)**:`combat_rules.gd` 內無任何好感度池 / `state_of` 引用(搜尋指令不得寫進被搜尋檔,見 story-014 AC3)。

- 理由:對應 story-014 AC1~AC5、規格第 9 節 (6);AC-S6 是本稿由構造推出的不變量,值得常駐測試守著(未驗證,屬新增宣稱)。

### C11 Open Questions:OQ-1 列

- 錨點:`| ~~OQ-1~~ | ✅ **已裁決,自待決清單移除(2026-08-31)**。戊沒有任何關係線是**角色設定的既定裁決**`
- 原文(逐字至錨點後):該列全文(含「⚠️ 本輪有專家提議重新檢討,經 \`creative-director\` 判定為把定案送回重審而擋下。**要改先改 \`characters.md\`。**」)。
- 改為:**不刪原列**,在其後插入新列(逐字):

> | OQ-1b | 🔴 **2026-11-17 重新開啟,由管理者 2026-11-12 裁決推翻**:「戊沒有任何關係線」不再是定案。**依 OQ-1 原列自己的規定「要改先改 `characters.md`」,`design/narrative/characters.md` 第三節須先(或同批)改為「開場時的關係」**(規格 v1.0 第 7 節、creative-director 清單 D1)。 | 阻擋本文件 C3~C8 轉為「現行」;**不阻擋**第二節 C4 之外的 story-012 | 管理者(`characters.md` 為既有檔,須逐檔核准) |

- 理由:OQ-1 原列把「定案」與「要改先改 characters.md」綁在一起。若本稿先改 GDD 而 `characters.md` 沒動,兩份文件對同一件事說相反的話。見 Q2。

### C12 Dependencies:好感度數值池列加註

- 錨點:`| 好感度數值池(#1,Accepted) | 上游 | **硬** | 呼叫戰鬥強度讀取函數取得**極性與強度**;另取互動次數以區分「久未互動」與「從未互動」 |`
- 原文:同錨點行。
- 改為(在表後 `⚠️ **陣亡通知不經本系統轉發**` 之前插入,逐字):

> 🔴 **2026-11-17 加註**:另取**關係狀態** `S(pair)`(`state_of`,規格 v1.0 第 3 節 / story-012;與 `n` 判定合併,**不是**第二個資料來源)。`state_of` 的放置位置(池 vs `AffinityPhiProvider`)是否構成 ADR-0002 契約變更**未驗證**,由 lead-programmer 先對照 ADR-0002 與 `docs/registry/architecture.yaml` interfaces 節回答(story-012「派工前須先決定」第 1 題)。
> 戰棋移動與交戰(#4)列:新增被讀的輸入——戰棋端須向好感度側查 `straddle_active`(布林)並傳入 `CombatRules`。

## 三、改後對已實作程式/測試的影響

**證據等級全部 = 讀原文 + Grep,未跑引擎、未跑測試。**

### 3.1 程式(已讀原文)

| 位置 | 現況(已讀) | 被改動的行為 |
|---|---|---|
| `src/gameplay/battle/battle_state.gd` `_lone_guard_of` / `_hold_back_of` / `lone_guard_if_at` | 只判 `faction == PLAYER` 與 `unit.lone_guard` 旗標,**完全不看好感度池**(已讀) | 須在三處加同一個 `straddle_active` 閘門;`_hold_back_of` 另有一條路徑,不得漏(AC-S1/S2 逐一釘住) |
| `src/gameplay/affinity/affinity_phi_provider.gd` `_link_for_pair` | 第 3 分支 `value == 0.0` 才 `return null`;其餘依 `value>0/<0` 定極性;`links()` 已全掃 10 對(已讀) | story-013:改讀 `state_of`;`_diagnostic_zero_value_pair_count` 語意須順改(冷淡區併入) |
| `src/gameplay/cards/permanent_affinity_write_rules.gd` `legal_pairs()` | 未讀,僅 grep 得函式存在 | creative-director 清單 C1;本稿範圍外,**未驗證** |

### 3.2 測試(僅檔名與命中數,斷言內容未逐條讀)

下列檔案含 `lone_guard`/`hold_back`,**預期**會受 C4/C5 影響(需先在 GIVEN 明寫「4 組 NONE」,或在測試用 BattleState 沒有關係提供者時預設 `straddle_active = true` 以維持回歸)—— **哪幾條會紅:未驗證**:

- `tests/unit/gameplay/battle/battle_state_straddle_hold_back_test.gd`(23 命中)
- `tests/unit/gameplay/battle/battle_state_lone_guard_if_at_test.gd`(23)
- `tests/unit/gameplay/battle/battle_state_lone_guard_conditional_test.gd`(6)
- `tests/unit/gameplay/battle/battle_state_guard_test.gd`(10)
- `tests/unit/gameplay/combat/combat_rules_guard_test.gd`(2;`CombatRules` 無池知識,**預期不受影響**,為 AC-S7 的對照)
- `tests/integration/ui/battle/battle_screen_guard_display_test.gd`(20)、`battle_screen_guard_line_test.gd`(1)、`battle_screen_combat_tuning_wiring_test.gd`(4)
- `tests/unit/gameplay/tuning/combat_tuning_test.gd`(29;旋鈕載入,**預期不受影響**,除非新增旋鈕缺鍵走既有失敗路徑)

好感度端:

- `tests/unit/gameplay/affinity/affinity_phi_provider_test.gd`:含 `_diagnostic_zero_value_pair_count` 2 處命中、`AffinityPhiProvider` 14 處。story-013 改 `_link_for_pair` 第 3 分支後,**至少這 2 處斷言須對照 `k=0` 回歸確認**(story-013 AC1 要求斷言不改,故預期 `k=0` 時仍綠;**未驗證**)。
- `AffinityPhiProvider` 另被 `tests/integration/ui/battle/` 的 `battle_screen_campaign_affinity_ledger_seeding_test.gd`、`battle_screen_affinity_tuning_wiring_test.gd`、`battle_screen_battle_outcome_test.gd`、`battle_screen_relation_minimap_test.gd`、`battle_screen_real_level_battle_test.gd`、`tests/perf/affinity_query_perf_benchmark.gd` 引用(各 1~7 處);**是否寫死「固定兩對」假設:未查**(story-024 範圍)。

**回歸關鍵設計(建議,非裁決)**:未掛載關係提供者時 `straddle_active` 預設 `true`(與 ADR-0001「守衛選擇性掛載、未掛載預設放行」同形),則所有現有戰棋測試不動即綠;只有新測試掛載後才進入新路徑。此為實作設計,屬 lead-programmer。

## 四、需裁決/確認的題目

### 管理者(4 題)

- **Q1 修訂路線**:A 新檔取代 + 目標檔一行指標(推薦)/ B 整份重寫 / C 不改目標檔、只宣告取代(不推薦)。依據第一節。
- **Q2 `characters.md` 第三節先後**:OQ-1 原列自己寫「要改先改 `characters.md`」。是否先(或同批)請 `narrative-director`/管理者核准該既有檔改為「開場時的關係」?未改前,C3~C8 與 `characters.md` 互相矛盾。
- **Q3 騎牆失效時,相鄰懲罰 −1 是否一併關閉**:規格字面「`lone_guard` 與 `hold_back` 同開同關」且 `lone_guard` 含 d=1 的 −1,所以我按字面寫成**一併關閉**(C4、AC-S3)。替代:只關 +2 與留一手,保留 −1(戊貼著有關係的人仍多受 1 點)。白話:戊跟有感情的人貼身站時,要不要因為「已經有人罩著他」而不再多受那 1 點?
- **Q4 `k` 量測前的騎牆行為**:story-012 先以 `k=0` 上線(占位值 50 禁上線),`k=0` 下戊只要和任何人有過一次非抵銷互動,騎牆就永久關閉(第二節 C7)。量測(story-025)前是否接受此行為?(這是冷淡區提案對方案 (a) 的自陳缺點;裁決已定要冷淡區,所以只問「量測前先這樣」是否可。)

### 技術確認(不需管理者,交 lead-programmer / technical-director)

- **T1**:單次結算內 `straddle_active` 是否與 `Φ` 同取結算步驟①快照(Interactions ② 契約是否涵蓋新增的布林)。**未驗證**。
- **T2**:`state_of` 放位置與 ADR-0002 契約關係(story-012 派工前第 1 題,已列)。

## 五、本稿未涵蓋(誠實揭露)

- 未讀 `skill-card-system.md`、`characters.md`、`affinity-data-pool.md`、`legal_pairs()`、`affinity_rules.gd`;對它們的連帶修訂(creative-director 清單 D1/D4/D7/D8、C1/C2/C6)不在本稿。
- 未檢查 `design/gdd/affinity-position-chain.md` 的 Player Fantasy、States and Transitions、Visual/Audio 節是否另有「戊恆無線/恆 0」散句(只 Grep 到上列處);請套用前以 `grep -n "戊" design/gdd/affinity-position-chain.md` 當場複驗(搜尋指令寫在本檔,不在目標檔,不會自命中)。
- 目標檔 AC-G8、AC-G2 引用 AC-L1 的新舊值之歷史問題(diff4 檔第 3 節第 2 點)本稿不處理。
- 若選 A,第二節 C2~C12 的改文需移進新檔;若選 B,併入重寫稿。兩者皆需重新校對錨點。
