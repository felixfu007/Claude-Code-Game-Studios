# Story S-009:接線 —— 池的生命週期宿主 + 用真實埠取代 `NullAffinityWritePort`

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Integration
> **狀態**:🔴 **不單獨執行 —— 已併入卡牌介面 epic 的 U-003**(2026-09-15 管理者裁決二)
> **估時**:M
> **依賴**:S-007、S-008

> 🔴 **不要把這張單獨做掉。**(2026-09-15 管理者裁決二,全文在
> `production/session-state/active.md`「裁決二:接線合併成一張工作單」節)
>
> **理由**:本張的足跡是 `battle_controller.gd` + `battle_screen.gd`,而卡牌介面 epic 的
> **U-003** 改的是同一支檔案的同一件事(「把新東西接進戰鬥畫面」)。兩張分開做等於同一個
> 檔案改兩次。**已合併為一次接好:好感度池 + 卡牌組。**
>
> **接手的人請改去做** `production/epics/card-play-interface/story-u003-battle-screen-deck-wiring.md`。
>
> ⚠️ **已知代價,管理者知情接受**:好感度線會停在「差最後一步」一段時間,要等卡牌線推到
> 需要接線時才一起完成。**那不是進度倒退。**
>
> 📌 **本檔內容刻意保留不刪** —— 它的 Context / AC / 測試證據仍是 U-003 好感度那一半的規格來源。

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules(公開介面窮盡檢視的隱含前提)
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制一(擁有模式:依賴注入的一般物件實例,不採 Autoload,戰役開始時由持有者建構一次)
- **Engine**:Godot 4.7.1

## 目標

把 S-001~S-008 交付的 `AffinityDataPool` 真正接進遊戲的生命週期——找一個戰役層級的持有者建構它一次,並把 S-008 的真實轉接器換掉現有的 `NullAffinityWritePort`。做完之後,**「玩家打一張丙類卡 → 好感度數值真的改變 → 讀得回來」這條路第一次在整合測試層級走得通**——這是本 epic 一句話目標的兌現點,也是切片內最後一張、唯一依賴其餘 8 張全部完成的一張。

⚠️ **本 story 完成之前不會有任何「端到端」的東西可看**(EPIC.md 明文,這是本 epic 的形狀決定的,不是進度落後)。

## 🔴 本 story 決定的原始碼目錄路徑

**不新增檔案於 `affinity_pool/` 或 `cards/`**——本 story 是**接線**,產物是對既有檔案的修改(`src/ui/battle/battle_screen.gd`、`src/gameplay/battle/battle_controller.gd` 或本 story 實作時判斷的等效位置),不是新建型別。若接線邏輯需要一個獨立的小類別(例如「戰役層好感度池宿主」),沿用既定目錄 `src/gameplay/affinity_pool/`。

## Implementation Notes

1. 🔴 **今天的既有事實(EPIC.md 限制表第 1 條,原文轉錄)**:「玩家在畫面上看不到任何變化。`battle_screen.gd` 對卡牌零命中(實測 `grep -n "CardDeck\|card_deck\|deck\|Card\b" src/ui/battle/battle_screen.gd` → 0 命中),且 `src/` 裡唯一構造 `BattleController` 的地方是 `battle_screen.gd:360`,**沒傳牌組**。本切片的「端到端」是**整合測試層級**,不是遊戲畫面」——**已於本 story 撰寫時重新查證,`battle_screen.gd:360` 逐字為 `_controller = BattleController.new(_state, _order, Callable(_phi, "phi"))`,確認沒有第四個參數傳牌組/埠,現況與 EPIC.md 記載一致。**
2. **本 story 不把卡牌 UI 接上畫面**——那是介面層,已另派 `ui-programmer` 獨立調查,本 epic 明文不規劃、不預留、不評論。本 story 的「端到端」範圍是:**建構一個真實 `AffinityDataPool` → 注入到 S-008 的轉接器 → 注入到卡牌系統既有的寫入路徑(`PermanentAffinityWriteRules`/`CardPlaySession` 等,技能卡牌系統 Story 004/005 已完成的既有程式碼)→ 打一張丙類卡的整合測試觸發真正的 `append_record()` → 讀回**,全程無節點、無畫面,以整合測試驗證。
3. **擁有模式(ADR-0002 機制一)**:`AffinityDataPool` 為一般類別(`RefCounted` 基底,無場景樹依附需求),於戰役開始時由持有者(戰役層級的 controller)建構一次,以參照方式注入給需要它的系統。**本 story 判斷合理的持有者位置**:既有 `BattleController`(`src/gameplay/battle/battle_controller.gd`)或其直接呼叫端(`battle_screen.gd`)——具體選擇留待實作時依既有建構順序判斷,但**不採 Autoload**(機制一硬性要求,禁令已登記於 `docs/registry/architecture.yaml`)。
4. **用真實埠取代 `NullAffinityWritePort`**:找到目前建構 `NullAffinityWritePort` 的呼叫點,改為建構 S-008 的轉接器(`AffinityPoolWritePort`),並傳入本 story 建構的真實 `AffinityDataPool` 實例。**若目前建構 `NullAffinityWritePort` 屬於某種「沒有真實池就退回空殼」的降級路徑**(例如未傳牌組的戰鬥),本 story 需保留該降級路徑本身(不強制每場戰鬥都有池),只確保**有池的情境下**用的是真實轉接器。
5. **測試替身注入,不需要真的走遊戲場景**:本 story 的整合測試可直接建構 `AffinityDataPool`、S-008 的轉接器、卡牌系統既有的 `CardPlaySession`/`PermanentAffinityWriteRules` 等物件並手動組裝依賴鏈,不需要透過 `battle_screen.gd` 的場景樹路徑——這與 `card_play_session_test.gd`(技能卡牌系統既有測試)的整合測試風格一致。
6. **驗證方式為行為檢視,不依賴方法命名**(AC-1 本身的要求)——本 story 需要**逐一檢視 `AffinityDataPool` 目前的公開方法**(S-001~S-007 累積交付的:`append_record`/`advance_campaign_tick`/`notify_death`/`combat_strength_read`/`narrative_depth_read`/`shape_feature_read`/`begin_non_atomic_window`/`end_non_atomic_window`/`export_state`/`validate_semantics`/`import_state`——**本切片只交付到 S-007,`begin_non_atomic_window`/`end_non_atomic_window`/`export_state`/`import_state` 屬 S-013/S-014,切片外,不在本 story 逐一檢視的範圍內**),確認恰有 `append_record` 一個方法會附加記錄、恰有 `advance_campaign_tick` 一個方法會使戰役刻度標記列表增加一筆,其餘方法(含 `notify_death`)不刪除/修改/清空/重新排序既有記錄或標記(見 S-004 機制四之四說明:`notify_death`/`begin_non_atomic_window`/`end_non_atomic_window` 改變的是結構獨立的其他狀態,不在 AC-1 定義範圍內)。
7. 🔴 **AC-1 的範圍限定(EPIC.md 原文轉錄)**:「範圍限於本切片交付的介面,新增介面時須重跑。它嚴格說不屬於任何單一 story,放這裡是判斷」——本 story 是本切片最後一張,交付本切片全部公開介面已定案的時間點,適合做這次窮盡檢視;若切片外的 S-010~S-016 之後新增公開方法(例如 S-014 的 `begin_non_atomic_window`/`end_non_atomic_window` 若尚未計入),須重跑本檢視。
8. 🔴 **陷阱五(EPIC.md)——一張 story 至少一個獨立測試檔**:本 story 是整合測試,建議放 `tests/integration/gameplay/affinity_pool/`。**⚠️ 尚未驗證、且本專案有過相反前例的事(EPIC.md 陷阱五附帶事項)**:`tests/gdunit4_runner.gd` 的 `FORCED_ARGS` 是否需要因新子目錄而改動,本 epic 未驗證,已交由協調者驗證。**本 story 跑完測試後必須核對執行條數確實增加,不得只看 exit code**——2026-09-04 Story 009(技能卡牌系統的同名編號,不同 epic)有過「測試存在、看起來全綠、實際一條都沒跑」的前例。
9. **今天的基線**(供對照):574 test cases / 44 套件全部執行 / 0 errors / 0 orphans / 1 failure(`affinity_phi_provider_test.gd`,刻意留紅、已核准、不要動)。本 story 落地後,執行條數應為 574 + S-001~S-009 全部新增測試數之和。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-1**: **GIVEN** Delta Log 模組的公開介面,**WHEN** 逐一檢視每個公開方法的行為,**THEN** 應恰有一個方法的唯一效果是「附加一筆合法記錄」、恰有一個方法的唯一效果是「使戰役刻度計數器與戰役刻度標記列表各增加一筆」,除此之外不存在任何能刪除、修改、清空或重新排序既有記錄(或既有標記)的方法——驗證方式為行為檢視,不依賴方法命名(實際命名以 `/create-architecture` 階段定案版本為準)。**(2026-08-03 第三輪修訂:原版本以方法名稱示意作為驗證依據,但命名本身已聲明非驗收基礎,導致 QA 無法據此獨立驗證;已改為純行為判定,見 /design-review 第三輪 qa-lead 審查發現。)**

## Test Evidence

**型別**:Integration
**測試檔**(獨立單一檔):`tests/integration/gameplay/affinity_pool/affinity_pool_wiring_test.gd`

預期涵蓋:

- `test_public_method_inventory_has_exactly_one_record_appending_method`(AC-1,行為檢視——非命名依賴)
- `test_public_method_inventory_has_exactly_one_campaign_tick_advancing_method`(AC-1)
- `test_no_other_public_method_deletes_modifies_clears_or_reorders_records_or_marks`(AC-1)
- `test_playing_combat_card_end_to_end_writes_a_record_and_is_readable_back`(端到端整合——建構真實池 → 真實轉接器 → 卡牌系統既有寫入路徑 → 讀回)
- `test_null_write_port_fallback_path_still_works_when_no_pool_is_supplied`(若既有降級路徑仍需保留,驗證未破壞)

## Out of Scope

- **卡牌 UI、戰鬥選單、任何畫面呈現**——另派 `ui-programmer`,本 epic 不規劃、不預留、不評論。
- **序列化生命週期(`begin_non_atomic_window`/`end_non_atomic_window`)接線**——屬 S-014(切片外)。
- **存檔系統的實際串接**(`export_state`/`import_state`)——屬 S-013(切片外),存檔系統本身已降級至垂直切片層、零實作。
- **好感度—位置連鎖系統、敘事解鎖與結局分支系統對本池的讀取串接**——這兩個系統本身尚未開始實作(`systems-index.md` Not Started),本 story 不預先接線。
