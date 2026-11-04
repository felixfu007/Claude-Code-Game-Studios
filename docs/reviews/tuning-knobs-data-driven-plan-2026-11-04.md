# 調整旋鈕資料驅動化規劃(2026-11-04)

> 擁有者:lead-programmer。依據:技術債「遊戲數值寫死在程式裡」屬程式碼層架構決策。
> **本檔只是規劃,沒有改任何 `src/` 或 `tests/`。**
> 凡未親自驗證者逐字標「未驗證」。本檔引用的 grep 皆為本次當場重跑,輸出節錄於各節。
> 📌 **此事不是新發現**:2026-10-12 第八十批已登記為技術債(`docs/tech-debt-register.md`,
> 搜 `約 17 個遊戲平衡數值硬編碼`),管理者當時裁決「登記為債,現在不搬」,**並寫明真正的
> 觸發時機是「遊戲第一次可以完整試玩、開始有試玩數據要回饋到數值時」**。本檔是為那個時機準備的。

## 1. 盤點

**掃描範圍與方法**:`grep -rn "^const [A-Z_0-9]*" src --include=*.gd`(全 `src/`,不只 gameplay)。
協調者給的 `grep ... src/gameplay`(只抓 `: int|float =`)會漏 `Dictionary` 型常數(`TERRAIN_TABLE`),
我另補了。`src/ai/` 內**沒有任何 `const`**,只有哨兵 `-1` 與迴圈索引(原始 grep 輸出為空,
`greedy_tactical_ai.gd` 的數字字面值只有 `-1`/`0`/`1`)—— 該檔的「打誰、走哪」是比較規則,
不含平衡數字,不需搬。

### 1.1 調整旋鈕(應搬)—— 4 個系統、26 個常數

| 檔案 | 常數 | 為什麼是旋鈕 |
|---|---|---|
| `combat/combat_rules.gd` | `GUARD_MIN`(-2)`GUARD_MAX`(3) | 檔內註解自稱「Tunable knobs」;夾限直接決定傷害減免上下界 |
| 同上 | `LONE_FAR_DISTANCE`(3)`LONE_FAR_GUARD`(0)`LONE_NEAR_DISTANCE`(1)`LONE_NEAR_GUARD`(-1)`LONE_MID_GUARD`(2) | 「騎牆」減傷表,amend2 規格明列為 knobs |
| 同上 | `HOLD_BACK_DISTANCE`(2)`HOLD_BACK_PENALTY`(1) | 「留一手」,檔內註解自稱 knobs |
| `affinity/affinity_rules.gd` | `DELTA_POSITIVE_ADJACENT`(3)`DELTA_POSITIVE_FAR`(-1)`DELTA_NEGATIVE_ADJACENT`(-1)`DELTA_NEGATIVE_FAR`(2)`DELTA_NEUTRAL`(0) | 好感度距離到加成的曲線;技術債登記即列為旋鈕 |
| 同上 | `PHI_MIN`(-4)`PHI_MAX`(12) | 旋鈕,**但是承重的**,見 §2 第 3 項 |
| `cards/card_deck.gd` | `OPENING_HAND_SIZE`(5)`HAND_SIZE_LIMIT`(5)`CARDS_DRAWN_PER_TURN`(1) | 檔內註解明寫「A Tuning Knob」;GDD 警告調成 2 會反轉設計決定 |
| `cards/card_modifier_rules.gd` | `ATK_DELTA_MIN/MAX`(-4/6)`DEF_DELTA_MIN/MAX`(-3/4) | 卡牌加成的夾限 |

### 1.2 結構常數(不搬)

| 常數 | 理由 |
|---|---|
| 各檔 `FIELD_COUNT*`(unit/card/affinity_link/campaign_sequence/card_text/support_*)、`SPEAKER_MIN/MAX` | CSV 欄位數與格式驗證,資料檔格式的一部分,不是平衡 |
| `NO_OCCUPANT`、`MOVE_COST_UNKNOWN_TERRAIN`、`NO_ALLY`、`UNRESTRICTED_TARGET`、`NO_GUESS`、`NOT_REVIEWING`、`AMP_EXPECTED` | 哨兵值/語意標記 |
| `FIRST_INDEX`、`FIRST_MISSION_INDEX`、`ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET`、`_PAIR_MEMBERS`、`_TRANSITIONS`、`_DIRECTION_VECTORS`、`_HAND_DIRECTION_DELTAS`、`TARGET_*` | 索引/對照表/狀態機,改了是改邏輯不是調平衡 |
| `*_PATH`、`_LOG_*_FORMAT`、`TEXT_*`、`_MISSING_KEY_*` | 路徑、訊息格式、本地化鍵 |
| `guard()` 內的「÷2 進位」、`is_attack_legal` 內的 `>= 2` | 公式形狀,不是數值旋鈕(未驗證:GDD 是否把進位規則視為旋鈕——我讀的是程式與註解,沒逐條比對 GDD) |

### 1.3 需裁決(不自行歸類)

| 項目 | 為什麼卡住 |
|---|---|
| `DISTANCE_ADJACENT`(1)`DISTANCE_FAR`(3) | 是旋鈕,但 `docs/registry/architecture.yaml` 的飽和算術明文依賴「距離 1 恰有四個整數解 → 最多四條相鄰線 → 4×(+3)=PHI_MAX」。**只要它變成可調,那段推導就變成條件式。**建議搬,但 `why:` 要同步改(文件,需核准) |
| `board.gd` `TERRAIN_TABLE` 的 `cost`(1/2/3) | GDD 戰棋旋鈕 #4 明列為「起始建議」。但同一表的 `passable` 與 `BLOCKS_SIGHT` 是結構(Story 001 明文「不可建第四階/不可用超大 cost 表示不可通行」)。**只搬 `cost` 欄、其餘留碼內**是我的建議,需確認 |
| `BOARD_WIDTH`(13)`BOARD_HEIGHT`(6) 與 `board_coords.gd` 的 `BOARD_COLS/ROWS`(13/6)、`CELL_SIZE`(32) | **同一個 13×6 在兩處各寫一份**(已驗證兩檔都有定義)。是棋盤格式不是平衡旋鈕,建議不搬;但重複本身是另一筆債 |
| `LONE_MID_DISTANCE`(2) | **死常數**:全 `src/` 只有宣告與一行註解,`lone_guard()` 以「落入 fallthrough」得到中段,從不讀它(當場 grep 證實)。改它**沒有任何效果**。搬進資料檔等於放一個調了沒反應的旋鈕 —— 建議**刪除或讓程式真的讀它**,二擇一需裁決 |
| `support_conversation_rules.gd` `MAGNITUDE_ABS`(1.0)、`cursor_*` 的 `MIN_LEGAL_MAX_FRAMES`、`CURSOR_LAYER_DRAW_ORDER` | 前者看似旋鈕,我沒讀該系統 GDD(未驗證);後兩者是游標 ADR 的結構約束。本次不碰 |
| `CombatRules.enemy_stat` 的 `advantage_pct` | 是參數不是常數,且零 production 呼叫端(unit.gd 註解與我讀到的一致)。不在範圍 |

### 1.4 `src/ui` 內「影響玩法」的數字

`src/ui` 的大量 `const`(`*_FPX_MULTIPLIER`、`*_INSET`、`*_WIDTH`、顏色)**都是版面/繪製常數**,
權威是 `design/art/screen-architecture.md`(art-director 網域),搬進資料檔無玩法價值。**不搬。**
**真正影響體驗節奏的有 4 個**:`ENEMY_STEP_PAUSE_SECONDS`(0.3)、`ENEMY_MOVE_CELL_SECONDS`(0.12)、
`RESULT_DISPLAY_SECONDS`(3.0)、`DISCARD_CLICK_GRACE_MSEC`(500)(皆 `battle_screen.gd`)、
另有 `support_conversation_screen.gd` 的 `CHARS_PER_SECOND`(30.0)。它們屬「手感」,
**不屬本技術債登記的 17 個「規則與曲線」**,建議列為第二階段、視需要再搬(見 §6)。
`battle_screen.gd` 已有 5000+ 行,動它的風險獨立於本案。

## 2. 既有規範衝突查核

**1) 規範面:沒有任何一份文件要求這些值必須是程式常數。** 相反地,
`coding-standards.md`(Gameplay values must be data-driven)、技術債登記、
`affinity-position-chain.md` / 戰棋 GDD 的 Tuning Knobs 節都把它們稱為旋鈕。

**2) 其中「釘死值」類**(當場 grep):

```
tests/unit/gameplay/combat/combat_rules_guard_test.gd:31:	assert_int(CombatRules.GUARD_MAX).is_equal(3)
tests/unit/gameplay/combat/combat_rules_guard_test.gd:37:	assert_int(CombatRules.GUARD_MIN).is_equal(-2)
```

這兩條**釘的是「常數等於 3 / -2」本身**。資料驅動後它們要嘛變成「資料檔載入後等於 3/-2」
(釘資料,等於每次調旋鈕都要改測試,與資料驅動目的牴觸),要嘛刪除並改測「夾限行為」。
**這是必須處理的測試改動,不是無傷的。**

**3) ADR/登記表:唯一直接相關的是 forbidden pattern `phi_clamp_treated_as_a_safety_net`**
(`docs/registry/architecture.yaml`,當場讀):

```
AffinityRules.PHI_MIN (-4) and PHI_MAX (+12) are the ONLY thing bounding a unit's
summed affinity bonus Phi ... changing these two numbers IS changing the combat power
ceiling and floor.
Second clause: the clamp is applied exactly once, to the summed total, inside
AffinityRules.bonus_for_at() — never per line, never a second time at a caller.
```

含義:(a) 搬進資料檔**不違反**它 —— 它禁的是「把夾限當保險絲」,不是「禁止外部化」;
但 (b) 它的文字**以常數名 `AffinityRules.PHI_MIN` 點名**,搬家後該條 `description`/`why`
要同步改寫(登記表是文件,需先問再改);(c) **「只夾一次」第二子句是搬家時最容易破的**:
若為了注入把夾限拆到呼叫端,就違規。方案必須讓 `bonus_for_at()` 仍是唯一夾限處。
`PHI_MIN/PHI_MAX` 在 `tests/` 只出現在**註解**(`affinity_rules_test.gd`,當場 grep,無程式引用),
測試用字面值 `+12` 斷言,所以不會被搬家連帶弄壞,但也**不會替你證明搬家沒改值**。

**4) 先例(這是正面訊號)**:`AffinityCalibration`(`src/gameplay/affinity_pool/affinity_calibration.gd`)
已經是「獨立不可變設定型別 + 建構期注入 + 帶預設 + `Rejection` 拒絕碼」,
並登記於 registry(`affinity_calibration_knobs_constructor_injected`)。**本案應比照,不發明第二種形狀。**

**5) 另一個先例(反面)**:`GameSettings`/`CampaignProgress`/`TutorialProgress` 用 `static var`,
各自在檔頭自承「嚴格而言與『DI 優於 singleton』牴觸」並附 `reset_for_test()`。
**有先例但都是自承的例外**,不是推薦做法。`autoload_singleton_for_testable_data_layers`
禁的是 Autoload,不直接禁 `static var`,但同一精神(`why:` 欄:每個測試要乾淨實例)。

**6) 未驗證**:我沒逐份讀 ADR-0001~0005 全文找「常數」字樣;只查了登記表(權威來源)與 PHI 一條。
ADR-0002 對「Φ 範圍」的規定我找不到獨立條文——登記表該條就是它的落地。

## 3. 載入機制提案

**前提事實**(當場查):專案慣例是「**解析與讀檔分離**」—— `Unit.roster_from_text`、
`AffinityLink.links_from_text`、`Card.cards_from_text`、`CampaignSequence.sequence_from_text`
全是純 `*_from_text(text)`,規則類**自己不碰 `FileAccess`**,讀檔集中在組裝點
`battle_screen.gd`(並有 `*_path_override` 注入點)。資料檔為逗號分隔文字、`#` 註解、
固定欄位順序、表頭註解說明欄位(例:`assets/data/units/vs01_roster.txt`)。

### 方案 A:資料檔 + 靜態懶載入(最省改動)

`TuningKnobs`(static func + `static var _cache`),首次呼叫時 `FileAccess` 讀
`res://assets/data/tuning/tuning_knobs.txt`;規則類內 `GUARD_MIN` 改為 `TuningKnobs.guard_min()`。
- 優點:**零簽名變動**,src 內約 34 處引用行(`GUARD_*`/`LONE_*`/`PHI_*`…)原地換名即可,測試幾乎不動。
- 缺點:(1) 隱藏的全域狀態,與「所有相依注入」衝突,屬 `GameSettings` 同款自承例外;
  (2) 規則類開始碰 `FileAccess`,違反上面的慣例;(3) 測試隔離只能靠 `reset_for_test()`,
  而本專案已登記「Autoload/全域狀態測試順序相依」風險;(4) 載入失敗時靜態函式無處回報
  (只能 `push_error` + 回預設,**靜默用舊值**,與「檔案沒打包卻畫空棋盤、151 條測試全綠」
  同形)。

### 方案 B(**推薦**):不可變設定物件 + 建構期/參數注入,讀檔留在組裝點

每系統一個 `RefCounted` 設定型別(`CombatTuning`、`AffinityTuning`、`DeckTuning`、
`CardModifierTuning`;或合一成 `TuningKnobs` 內含四組,**命名為待決,見 §6 不需裁決但請確認**),
形狀比照 `AffinityCalibration`:
- `static func from_text(text: String) -> Variant`:純解析,失敗回 `null`/帶 `Rejection`
  (比照 `links_from_text` 的 null 約定,**不用 `assert()`**——`coding-standards.md` 禁令)。
  驗證:整數、必填鍵齊全、`GUARD_MIN <= GUARD_MAX`、`PHI_MIN <= PHI_MAX`、
  `HAND_SIZE_LIMIT >= 1` 等。
- `static func defaults()`:**僅供單元測試與「未注入」呼叫**,值等於今天的常數
  (這是零行為變更的錨點,見 §4)。
- 規則函式取得設定的方式:`static func` 增一個**末位具預設值**的參數 `tuning = null`
  (`null` → `defaults()`),如 `CombatRules.guard_total(guard_phi, lone, tuning)`;
  有狀態的 `CardDeck`、`BattleState` 在建構時持有一份。
- `battle_screen.gd`(已是組裝點)讀 `assets/data/tuning/tuning_knobs.txt`、解析、**失敗時比照
  既有 `_LOG_LOAD_FAILURE_FORMAT` 行為**(`push_error` 並明確失敗,不靜默回預設),
  再注入 `BattleState`。
- 檔案格式(與既有一致):

```
# tuning_knobs — fixed format: section,key,value
# 同一鍵只能出現一次;未知鍵視為解析失敗(防打錯字靜默失效)
combat,guard_min,-2
combat,guard_max,3
affinity,phi_min,-4
affinity,phi_max,12
...
```

**測試隔離**:
- 單元測試**不讀檔**:直接 `XxxTuning.from_text("...inline...")` 或 `defaults()`,零 I/O,
  也不碰 `static var`,完全符合 `test-standards.md` 的禁令。
- 「真實資料檔能解析且值合法」這一條,走已登記的**甲類例外**(讀 `assets/data/` 唯讀版控檔),
  檔頭照規定聲明屬甲類、並自陳「不證明窮盡性」。
- **敏感度證明**(裁決門檻):間諜/夾具設定把 `HAND_SIZE_LIMIT` 改成 3,斷言
  **真實 `BattleScreen`/`BattleState` 流程**的行為跟著變(形式依 `tests/README` 的
  `test_sensitivity_proof_*` 慣例)。**這是整案最重要的一條測試**:方案 B 最大的失效模式是
  「某個呼叫端忘了把設定傳下去,悄悄用 `defaults()`,資料檔改了沒反應、全套綠燈」
  (與 2026-10-15 CSV 匯入快取事故同形)。
- 載入真實場景時依 `technical-preferences.md` 第 5 點:`instantiate()` → 設 override →
  `call_deferred("add_child")` → 等幀;`battle_screen.gd` 現有 `*_path_override` 模式可加一個
  `tuning_path_override`。

**取捨**:B 比 A 多動簽名與接線(§5 估數),但每個依賴都看得見、可在測試內單獨換掉、
載入失敗會大聲失敗。**如果只想最小代價,A 可行,但請接受它是第三個自承違反 DI 的 `static var`。**

## 4. 風險

1. **零行為變更的證明方式**:`defaults()` 的值 = 今天常數(逐個值對帳);初始
   `tuning_knobs.txt` 的內容 = `defaults()`。**驗證=全套測試 ENGINE EXIT / Overall Summary 前後逐字相同**
   (本機入口 `tools/build/run_tests_with_import.sh`,每步交付時貼 `ENGINE EXIT` 與
   `Overall Summary` 原始三行,協調者自行重跑)。
   ⚠️ **注意假綠燈**:新增 `.txt` 在版控內但引擎匯入產物舊的那類事故不適用(`.txt` 以
   `FileAccess` 讀,非 `.translation`),但 exit 105(收集階段解析錯誤)會讓 grep 兩個都空——
   一律先看引擎 exit code。
2. **`defaults()` 與資料檔是同一組值的兩份複本** —— 本專案反覆登記的「兩份複本漂移」形狀。
   緩解:一條甲類測試斷言 `from_text(真實檔) == defaults()`,**僅在遷移完成當下成立**;
   一旦開始調旋鈕它就會紅。因此我建議該測試**不長期保留為等值斷言**,而改成「真實檔可解析且
   通過驗證」,並在遷移那一步用一次性等值證明(留在 `prototypes/` 證據,而非常駐測試)。
   這是個**真實的設計張力,不是我已解決的事**。
3. **prototypes 引用**(當場驗證):`LONE_*`/`HOLD_BACK_*`/`GUARD_*`/`DELTA_*`/`PHI_*`/
   `ATK/DEF_DELTA_*`/`OPENING_HAND_SIZE`/`CARDS_DRAWN_PER_TURN` 在 `prototypes/` **`.gd` 檔零引用**
   (協調者初查成立)。**唯一例外**:`HAND_SIZE_LIMIT` 被 2 支 `.gd` 引用
   (`prototypes/story-u011-hand-bar-evidence-2026-09-17/evidence_driver.gd`、
   `prototypes/godot-specialist-u013-worldlayer-attribution-2026-09-23/probe_worldlayer_attribution.gd`),
   皆為歷史證據驅動器。**但另有 31 支 prototype `.gd` 呼叫 `CombatRules.`/`AffinityRules.`/
   `CardDeck.` 等的函式**(含協議 2 的 `autoplay_*`/`formation_*`/`retreat_*` 量測腳本)。
   它們不引用常數名,但**依賴函式簽名**:若走方案 B 的「末位預設參數」,舊呼叫仍可編譯、行為不變;
   若改成**必填**參數就會讓這批已簽的歷史量測腳本壞掉。**→ 簽名只能加可選參數,不可改必填。**
   ⚠️ 「未驗證」:我沒逐支跑這 31 支;只確認了它們不引用常數名,且預設參數保留相容。
4. **直接引用常數名的測試**(當場 grep,檔數/總):`HAND_SIZE_LIMIT` 5 檔、`OPENING_HAND_SIZE` 5 檔
   (多為斷言開局手牌、強制棄牌 gate;`card_forced_discard_gate_test.gd`、
   `card_battle_wiring_test.gd`、`forced_discard_test.gd`、`battle_screen_card_play_wiring_test.gd`、
   `battle_screen_real_level_battle_test.gd`…),`GUARD_MAX` 2 檔、`GUARD_MIN` 1 檔(含上述兩條釘值斷言)、
   `LONE_MID_GUARD` 1 檔(`battle_screen_guard_display_test.gd:225`)。其餘常數**測試零引用**。
   `src/` 引用行:`DISTANCE_ADJACENT` 7、`HAND_SIZE_LIMIT` 13(含 UI 4 處用它當手牌列槽數)、
   `PHI_*` 10(多為註解)。
5. **`HAND_SIZE_LIMIT` 的 UI 耦合**:`battle_screen.gd`/`hand_bar.gd` 用它排版與顯示「n/5」。
   資料驅動後手牌上限可變,**版面是否撐得住 ≠ 本案保證**(hand_bar 註解說它設計成「若調整仍正確」,
   未驗證)。
6. **PHI 夾限只夾一次**的不變式(§2.3)——搬家不得把夾限挪位置。
7. **`LONE_MID_DISTANCE` 死常數**(§1.3):搬進資料檔會製造「調了沒用」的旋鈕。

## 5. 切分

每步一個系統、獨立可過全套;每步結束貼 `ENGINE EXIT` + `Overall Summary` 原始三行。
檔案數為估計(`grep` 引用檔數 + 新增檔),「未驗證」= 動工後才會精確。

| 步 | 內容 | 預估影響檔 | 備註 |
|---|---|---|---|
| 0 | 建共用骨架:`tuning_knobs.txt` 初稿、解析器共用工具、`battle_screen` 的載入與 `tuning_path_override`、載入失敗測試、**敏感度證明骨架** | 新增 3~4;改 1(`battle_screen.gd`) | 此步**不搬任何常數**,只證明管線通且失敗會大聲 |
| 1 | `CardDeck` 三項(最簡單、引用面小:src 7 檔) | 改 `card_deck.gd` + 組裝點 ~2~3;測試 5 檔查改 | 順便驗證手牌列 UI 不壞 |
| 2 | `CardModifierRules` 四項 | src 2 檔、測試 2 檔(皆呼叫函式,常數零引用) | 最低風險 |
| 3 | `CombatRules`(`GUARD_*`/`LONE_*`/`HOLD_BACK_*`)並處理 `LONE_MID_DISTANCE` | src 7 檔、測試 14 檔(多為呼叫,常數引用僅 3 檔) | 兩條釘值測試要改寫;死常數需先裁決 |
| 4 | `AffinityRules`(9 + `DISTANCE_*`) | src 8 檔、測試 6 檔 + **registry `phi_clamp_*` 文字改寫(文件,需核准)** | 最敏感,放最後;夾限仍只在 `bonus_for_at` |
| 5(選) | `TERRAIN_TABLE.cost` | `board.gd` + 查表處 4 檔 + 測試 4 檔 | 待 §1.3 裁決 |
| 6(選) | 手感類秒數(4~5 個) | `battle_screen.gd` 等 | 待 §6 裁決,**非技術債原定範圍** |

總量估計(未驗證):步 0~4 約 **改 20~28 個 src/tests 檔 + 新增 5~7 個檔**,5 次提交。
可隨時在任一步停下,已完成的步驟互不依賴。**方案 A 同樣可照此切分**,每步約減少一半改動。

## 6. 需要管理者裁決的事

1. **現在要不要做?** 2026-10-12 你裁決「登記為債、現在不搬」,理由是「現在搬沒有看得到的好處」,
   並說真正時機是「第一次可完整試玩、開始有試玩數據要回饋到數值時」。目前五關都有、
   且最近的提交是在調第 3、4 場難度(提案等你實打)——**這個條件看起來已成立**(此判斷是我的解讀,
   未經你確認)。白話後果:**做 =** 之後調難度只要改一個文字檔,不用動程式也不用等改程式的回合;
   代價是約 5 次提交的搬家工作,期間不會有任何畫面變化。**不做 =** 每次調數字都要改程式碼並重跑全套測試。
2. **做法二選一**:(A) 省事但把全域變數再多加一個、設定檔出錯時只會靜默用舊值;
   (B) 多動約一倍檔案,但設定檔出錯會明確報錯、每個系統的數值看得見來源。**我推薦 B。**
3. **「相鄰距離」(1)與「遠距離」(3)要不要也開放調整?** 白話:好感度「鄰接線最多 4 條、
   剛好頂到加成上限 +12」這個設計推導,是以「相鄰=距離 1」為前提。開放後你可以調,
   但那段推導就不再自動成立。我建議**開放曲線的 5 個加成值與上下限,但距離門檻暫時留在程式內**。
4. **手感秒數**(敵人行動停頓、結果畫面停留等 5 個)要不要一併搬?它們不在原技術債範圍內,
   我建議**這次先不搬**。
5. **`LONE_MID_DISTANCE`**(騎牆「中距離」)目前是改了也沒效果的死設定:要刪掉,
   還是讓程式真的依它判斷?我建議**刪掉**(行為不變)。
