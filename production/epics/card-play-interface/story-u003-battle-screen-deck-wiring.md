# Story U-003: 戰鬥畫面載入兩張表、建 `CardDeck`、傳進 `BattleController`

> **Epic**: 卡牌介面、戰鬥選單與取消鍵(`production/epics/card-play-interface/EPIC.md`)
> **狀態**: ✅ Complete(2026-09-16,`ui-programmer` 實作與驗收;24 條測試全綠。**AC 逐條核對全數滿足**,含 AC-1 三子句的常駐敏感度證明。🔴 **依 2026-09-16 管理者裁決的新完成門檻標記**:原門檻「全部測試補齊敏感度證明才算完成」在新資訊下**結構上不可能達成**(15 條屬 static 純函式 / 真實資料檔 / RNG 決定性契約 / `.tscn` `@onready` 參照 / 注入點在受限範圍外 五類),門檻已改為「每條要嘛有證明、要嘛有寫下來可查證的不可證理由」,全文見 `.claude/rules/test-standards.md`。那 15 條的逐條理由記於提交 `403099c`。⚠️ 原屬本檔但不對應任何 AC 的 `test_cards_table_and_card_text_table_have_identical_id_sets` 已依同日裁決搬離,另立 U-017)
> **層**: Integration —— **資料層與好感度池接線的合流點**
> **型別**: Integration
> **估時**: M
> **依賴**: U-001、U-002
> **解鎖**: U-009、U-011、U-013、U-015、U-016(皆為切片內、不在本次 8 個單元授權範圍內,
>   下一位負責 U-009~U-016 的實作者接手)
> **波次**: 波 1(與 U-005 ∥ 真平行 —— `battle_screen.gd` vs `project.godot`,兩個不同檔)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

🔴 **本 story 是兩條線的合流點,這是管理者 2026-09-15 裁決二的直接後果,不是本 story 自己
決定要做的事**:`affinity-data-pool` epic 的 `story-009-wiring.md`(池的生命週期宿主 + 用
真實埠取代 `NullAffinityWritePort`)**不單獨執行**,原因是它與本單元改的是同一個檔案的同一
種事(「把新東西接進戰鬥畫面」)。**合併後,本 story 同時接好感度池 + 卡牌組。**

> **裁決紀錄(逐字轉錄自 `production/session-state/active.md`)**:
> 「`story-009-wiring.md` 不單獨執行。它與卡牌線的 U-003 改的是同一個檔案的同一種事
> (「把新東西接進戰鬥畫面」),合併成一張,一次接好感度池 + 卡牌組。」
> ⚠️ **已知代價,管理者知情接受**:好感度線會停在「差最後一步」一段時間,要等 B 線推到需要
> 接線時才一起完成。**這不是進度倒退,不要有人跑去把 009 先做掉。**

**權威來源**:
- 卡牌線:兩份 UX 規格都不管轄資料載入,驗收依據是 `vs01_cards.txt`/`vs01_card_text.txt`
  檔頭與 `card.gd`/`card_deck.gd` 的型別契約(同 U-001/U-002)。
- 好感度池線:`design/gdd/affinity-data-pool.md` Core Rules(公開介面窮盡檢視的隱含前提),
  原 `story-009-wiring.md` 的 AC-1(見下方 Acceptance Criteria,原文轉錄)。

**Governing ADR**:
- **主**:ADR-0002(**Accepted**)—— 機制一(擁有模式:依賴注入的一般物件實例,不採
  Autoload,建構一次)。此為本 story 合併進來的好感度池接線半部所遵循的架構。
- **次**:ADR-0001(**Accepted**)—— 本 story 只做建構期接線,不涉及權威寫入呼叫本身,但
  它接通的下游路徑(丙類卡打出 → `commit_authoritative_change`)是 ADR-0001 第一次修訂
  登記的六條權威寫入路徑之一。

## 🔴 已實測的既有事實(讀檔/grep,非引擎執行,無一條是 (A) 級)

**這件事把本 story 的範圍縮小到比 EPIC.md 描述更精確的程度 —— `BattleController` 早就有
接收牌組與好感度埠的參數,缺口 100% 在呼叫端,不需要新增任何 `BattleController` 介面**:

`src/gameplay/battle/battle_controller.gd:163-172` 的建構子簽章(逐字):

```gdscript
func _init(
	state: BattleState,
	order: TurnOrder,
	phi_provider: Callable = Callable(),
	decide: Callable = Callable(),
	card_deck: CardDeck = null,
	affinity_links: Array[AffinityLink] = [],
	write_port: AffinityWritePort = null,
	authoritative_write_in_progress_check: Callable = Callable()
) -> void:
```

`_init()` 內部**已經**在做 `_state.attach_card_deck(card_deck)`、`_state.deal_opening_hand()`、
以及「`card_deck != null` 時建構 `CardPlaySession`(含 `write_port` 為 `null` 時退回
`NullAffinityWritePort`)」——這些全部是既有程式碼(skill-card-system epic Story
006/008 已交付),本 story 不重寫、不新增。

而 `src/ui/battle/battle_screen.gd:360` 目前的呼叫(逐字):

```gdscript
_controller = BattleController.new(_state, _order, Callable(_phi, "phi"))
```

**只傳了前 3 個參數。** `card_deck`/`affinity_links`/`write_port` 全部使用預設值
(`null`/`[]`/`null`),所以今天玩家打丙類卡,寫入埠是 `NullAffinityWritePort`(收下即丟棄的
空殼)。**本 story 的核心動作是把這個呼叫補上正確的參數,不是設計新介面。**

另外,`battle_screen.gd:330` 已經在解析 `AFFINITY_PATH` 得到 `links: Array[AffinityLink]`
(用於既有的 `_phi` 好感度加成),**這個既有變數可以直接轉傳給 `BattleController.new()` 的
`affinity_links` 參數,不需要重新解析**——這也是本 story 範圍比表面上小的一個原因。

`AffinityPoolWritePort.new(pool: AffinityDataPool)`(`src/gameplay/cards/
affinity_pool_write_port.gd:94`)與 `AffinityDataPool._init()`(無參數,`affinity_data_pool.gd:223`)
兩者都已存在 —— 本 story 只需要各建構一次並串起來,不需要新增任何一個型別。

## 目標

把 U-001/U-002 交付的兩個解析器接進 `battle_screen.gd`:載入 `vs01_cards.txt` +
`vs01_card_text.txt`、建構 `Card` 陣列、組成 `CardDeck`;同時建構一個真實
`AffinityDataPool`、包成 `AffinityPoolWritePort`;把 `card_deck`、既有的 `affinity_links`、
`write_port` 一起傳進 `BattleController.new()`。做完之後,「玩家打一張丙類卡 → 好感度數值
真的改變 → 讀得回來」這條路第一次在**整合測試層級**走得通(EPIC.md 明文:這是整合測試
層級,不是遊戲畫面 —— 畫面呈現是 U-011 以後的介面單元職責,不在本次 8 個單元內)。

## Implementation Notes

### 卡牌線

1. **新增 `CARDS_PATH`/`CARD_TEXT_PATH` 常數**,比照現有 `TERRAIN_PATH`/`ROSTER_PATH`/
   `AFFINITY_PATH` 的形狀,指向 `res://assets/data/cards/vs01_cards.txt` 與
   `res://assets/data/cards/vs01_card_text.txt`。

2. 🔴 **卡表載入失敗時,畫面該停還是該警告?—— 2026-09-15 管理者裁決(EPIC.md 第八節第 1
   項,原文轉錄,逐字適用於本 story)**:

   > **裁決內容**:**「檔案不存在 / 讀不到」→ `_fail_load()`,響亮地停下來;
   > 「檔案讀到了但解析出 0 張」→ 只警告,繼續跑。**
   >
   > **裁決依據(管理者當場看到的三項事實)**:
   > ① `battle_screen.gd` 現有兩套政策在跑,而卡表沒人指定走哪一套;
   > ② 本專案已踩過一次「資料檔沒打包進 .exe → 遊戲靜默畫出空棋盤 → 151 條測試全綠」;
   > ③ 但 GDD 明文「卡池不足 5 張時開局發不滿」合法、S7 空手牌也是明文定義的狀態,
   > 故不能一律停。
   >
   > 🔴 **實作者注意:這條分界線是【裁決】不是慣例,不得為了「跟其他資料檔一致」而簡化成
   > 單一政策。** 兩種情況的差別是「包裝缺陷」vs「合法的設計狀態」,合併它們會讓前者變成
   > 靜默失敗。

   **實作方式**:比照現有 `affinity` 那一套 —— `classify_file_access(CARDS_PATH)` /
   `classify_file_access(CARD_TEXT_PATH)` 若回傳 `MISSING`/`UNREADABLE`,併入 `_fail_load()`
   的失敗集合(該函式簽章需要擴充以接受這兩個新的失敗來源,擴充方式由實作時判斷,可以是
   新增具名參數,或重構成一個 `Dictionary[String, LoadFailure]`/陣列傳入 —— 本 story 不
   預先指定重構形狀,只要求擴充後仍保留現有列舉語意與現有三個呼叫點的行為不變)。若檔案
   讀取成功但 `cards_from_text()` 解析出 0 張,**只 `push_warning()`,不進 `_fail_load()`**,
   `CardDeck` 以空 `Array[Card]` 建構(`CardDeck._init()` 已合法處理空陣列 —— 見
   `card_deck.gd` 的 Edge Cases 註解「卡池張數少於開局手牌數是合法的」,0 張是這個規則的
   極端情形)。

3. 🔴 **`CardDeck` 的 RNG 預設未注入,會讓截圖證據無法重現(EPIC.md 陷阱五,轉錄)**:

   `card_deck.gd:81` 逐字 `func _init(cards: Array[Card], rng: RandomNumberGenerator =
   null) -> void:`,第 83 行 `_rng = rng if rng != null else RandomNumberGenerator.new()`。
   **若 U-003 用預設值,每次開遊戲手牌都不同。** 本 epic 有 6 條 AC 要求截圖或灰階比對,
   而 `coding-standards.md` 的 Determinism 規則明文要求 no random seeds。

   ⚠️ **要處理的不是「能不能隨機」,是「測試與截圖時怎麼固定」**——牌面隨機本身合法
   (本作唯一的隨機豁免,`rng_in_combat_settlement` 禁令管的是結算路徑,不是洗牌)。

   **本 story 決定的注入形狀**:把「用兩份檔案文字建構一副 `CardDeck`」的邏輯抽成一個
   獨立、可直接呼叫的靜態方法(比照 `battle_screen.gd` 既有的 `_parse_terrain_rows()` /
   `affinity_line_dicts()` / `format_affinity_preview()` 這幾個既有靜態輔助方法的形狀 ——
   全部是「不依賴場景樹、可以在測試裡直接呼叫」的既有慣例),簽章大致為:

   ```gdscript
   static func _build_card_deck(
       cards: Array[Card], rng: RandomNumberGenerator = null
   ) -> CardDeck:
       return CardDeck.new(cards, rng)
   ```

   `_ready()` 呼叫時傳 `rng = null`(production 行為不變,時間種子、真的隨機);**整合測試
   直接呼叫這個靜態方法並傳入一個固定種子的 `RandomNumberGenerator`**,不需要透過場景樹或
   `_ready()` 路徑,即可得到可重現的手牌順序供截圖/灰階比對測試使用。**這與
   `story-009-wiring.md` 既有的「測試替身注入,不需要真的走遊戲場景」精神一致**
   (`card_play_session_test.gd` 既有整合測試風格)。

### 好感度池線(合併自原 `story-009-wiring.md`)

4. **擁有模式(ADR-0002 機制一)**:`AffinityDataPool` 為一般類別(`RefCounted` 基底,無
   場景樹依附需求),於戰役開始時由持有者建構一次,以參照方式注入給需要它的系統。
   📌 **本 story 對「戰役層級的持有者」做了一個範圍縮小的判斷,需要記錄下來**:本垂直切片
   目前沒有「戰役」這一層(`battle_screen.gd` 就是最外層),故本 story 判斷合理的持有者
   位置是 `BattleScreen`(或其直接建構 `BattleController` 的同一個地方)——**不採
   Autoload**(機制一硬性要求,禁令 `autoload_singleton_for_testable_data_layers` 已登記於
   `docs/registry/architecture.yaml`)。若未來出現真正的戰役層級節點,持有者要搬家,
   但那不是本 story 的範圍。

5. **用真實埠取代 `NullAffinityWritePort`**:建構 `AffinityDataPool.new()`(無參數)、包成
   `AffinityPoolWritePort.new(pool)`,傳入 `BattleController.new()` 的 `write_port` 參數。
   **保留既有的降級路徑本身**(`card_deck == null` 時 `BattleController` 本來就不會建構
   `CardPlaySession`,`write_port` 也就無關緊要)——不強制每場戰鬥都有池,只確保**有池的
   情境下**用的是真實轉接器。

6. **驗證方式為行為檢視,不依賴方法命名(AC-1 本身的要求,見下方 Acceptance Criteria)**——
   需要逐一檢視 `AffinityDataPool` 目前的公開方法(`append_record`/`advance_campaign_tick`/
   `notify_death`/`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`/
   `export_state`/`validate_semantics`/`import_state` 等,**本切片只交付到既有 S-007 的範圍,
   `begin_non_atomic_window`/`end_non_atomic_window`/`export_state`/`import_state` 屬
   affinity-data-pool epic 的 S-013/S-014,切片外,不在本 story 逐一檢視的範圍內**),
   確認恰有 `append_record` 一個方法會附加記錄、恰有 `advance_campaign_tick` 一個方法會
   使戰役刻度標記列表增加一筆,其餘方法(含 `notify_death`)不刪除/修改/清空/重新排序既有
   記錄或標記。

7. 🔴 **AC-1 的範圍限定(原 `story-009-wiring.md` 轉錄)**:範圍限於本切片交付的介面,
   新增介面時須重跑。它嚴格說不屬於任何單一 story,放在本 story 是判斷 —— 本 story 是
   affinity-data-pool 那條線最後一張、交付其全部公開介面已定案的時間點,適合做這次窮盡
   檢視;若切片外的 story 之後新增公開方法,須重跑本檢視。

8. **今天的基線(供對照,原 `story-009-wiring.md` 轉錄)**:574 test cases / 44 套件全部
   執行 / 0 errors / 0 orphans / 1 failure(`affinity_phi_provider_test.gd`,刻意留紅、
   已核准、不要動)。本 story 落地後,執行條數應為 574 + affinity-data-pool epic
   S-001~S-009(即本 story)全部新增測試數之和,再加上本 story 卡牌線自己的新增測試。
   **跑完測試後必須核對執行條數確實增加,不得只看 exit code**——本專案有「測試存在、
   看起來全綠、實際一條都沒跑」的前例(2026-09-04)。

## Acceptance Criteria

*本單元沒有對應的 AC-U / AC-M 條文(卡牌線半部,理由同 U-001/U-002)。好感度池線半部的
AC-1 為原 `story-009-wiring.md` 的驗收條件,原文轉錄,未改寫:*

- **AC-1**:**GIVEN** Delta Log 模組的公開介面,**WHEN** 逐一檢視每個公開方法的行為,
  **THEN** 應恰有一個方法的唯一效果是「附加一筆合法記錄」、恰有一個方法的唯一效果是
  「使戰役刻度計數器與戰役刻度標記列表各增加一筆」,除此之外不存在任何能刪除、修改、清空或
  重新排序既有記錄(或既有標記)的方法——驗證方式為行為檢視,不依賴方法命名(實際命名以
  `/create-architecture` 階段定案版本為準)。**(2026-08-03 第三輪修訂:原版本以方法名稱
  示意作為驗證依據,但命名本身已聲明非驗收基礎,導致 QA 無法據此獨立驗證;已改為純行為
  判定,見 /design-review 第三輪 qa-lead 審查發現。)**

以下是本 story 卡牌線半部自訂的驗收基準(無對應 AC-U/AC-M,理由同 U-001/U-002):

- [ ] `battle_screen.gd` 的 `_ready()` 呼叫 `BattleController.new()` 時,`card_deck`、
      `affinity_links`、`write_port` 三個參數皆非預設值(驗證「呼叫端補參數」這個核心動作)
- [ ] 卡表/牌面文字表檔案不存在或不可讀 → `_fail_load()` 被呼叫,畫面顯示失敗訊息
- [ ] 卡表檔案讀取成功但解析出 0 張卡 → 只有 `push_warning()`,畫面正常繼續、`CardDeck`
      為空
- [ ] `_build_card_deck()` 傳入固定種子的 `RandomNumberGenerator` → 兩次呼叫得到相同的
      開局手牌順序(可重現性核心宣稱)
- [ ] 打一張丙類卡的整合測試觸發真正的 `AffinityDataPool.append_record()`,並可讀回

## Test Evidence

**型別**:Integration
**測試檔(至少兩個獨立檔案)**:
- `tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd`(AC-1,承接原
  `story-009-wiring.md` 的測試規劃)
- `tests/integration/ui/battle/battle_screen_card_deck_wiring_test.gd`(卡牌線半部,呼叫
  `BattleScreen._build_card_deck()` 等靜態/可測試方法,不需要真正的場景樹路徑)

預期涵蓋(合併自兩條線):
- `test_public_method_inventory_has_exactly_one_record_appending_method`(AC-1,行為
  檢視——非命名依賴)
- `test_public_method_inventory_has_exactly_one_campaign_tick_advancing_method`(AC-1)
- `test_no_other_public_method_deletes_modifies_clears_or_reorders_records_or_marks`(AC-1)
- `test_playing_combat_card_end_to_end_writes_a_record_and_is_readable_back`(端到端整合
  ——建構真實池 → 真實轉接器 → 卡牌系統既有寫入路徑 → 讀回)
- `test_null_write_port_fallback_path_still_works_when_no_pool_is_supplied`
- `test_missing_card_table_file_triggers_fail_load`
- `test_zero_parsed_cards_only_warns_does_not_fail_load`
- `test_build_card_deck_with_fixed_seed_rng_is_reproducible_across_two_calls`
- `test_battle_controller_new_call_site_passes_card_deck_affinity_links_and_write_port`

## Out of Scope

- **卡牌 UI、戰鬥選單、任何畫面呈現**——另派負責 U-009~U-016 的實作者,本 story 不規劃、
  不預留、不評論
- **序列化生命週期(`begin_non_atomic_window`/`end_non_atomic_window`)接線**——屬
  affinity-data-pool epic 的 S-014(切片外)
- **存檔系統的實際串接**(`export_state`/`import_state`)——屬 S-013(切片外)
- **好感度—位置連鎖系統、敘事解鎖與結局分支系統對本池的讀取串接**——這兩個系統本身尚未
  開始實作,本 story 不預先接線
- **兩表(`vs01_cards.txt`/`vs01_card_text.txt`)id 集合一致性檢查**——U-002 已登記此缺口
  但未指派;本 story 亦不主動承接(範圍已經很大,見上方合流點說明),留待實作時判斷是否
  順手補上,或另開工作單

## Dependencies

- 依賴:U-001(`Card.cards_from_text()`)、U-002(`CardText.flavor_texts_from_text()`)
- 解鎖:U-009、U-011、U-013、U-015、U-016(下一位負責 U-009~U-016 的實作者接手,不在本次
  8 個單元授權範圍內)
