# Story 004: `AffinityDataPool` 執行期實例擁有權 + roster id↔Character 對映層(M2 前置)

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready
> **Layer**: Gameplay(控制清單「核心層規則(Core)」——好感度數值池段直接適用)
> **Type**: Integration
> **Estimate**: M(1～2 session,取決於下方第一步查證結果——若 S-009 已解決 P-1,
> 可能收斂為 XS)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`(Interactions ①)+
`design/gdd/affinity-data-pool.md`(#1,資料來源方)
**需求**: R1(關係表資料來源)+ R9 配對側 的前置基礎設施——本 story 本身不改變任何
`Φ` 的計算行為,是讓 story-005 有東西可以接的準備工作。
**TR-ID**: ⚠️ 本系統(#5)尚未登記進 `tr-registry.yaml`。本 story 涉及的介面契約
`affinity_pairing_data_per_query_refetch` 已登記於 `docs/registry/architecture.yaml`
的 `interfaces` 節(`adr: none`——已記錄義務,非待決架構選擇)。

**Governing ADR**: **ADR-0002**(`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`,**Accepted**)——本 story 建立的是 #5 對 #1 的消費端接線基礎,雖然 ADR-0002
治理的主體是 #1 自身的資料結構,但其機制一(依賴注入,非 Autoload)與機制四之四(序數驗證)
直接約束本 story 怎麼建立與持有這個實例。
**ADR 決策摘要**:好感度數值池必須採依賴注入而非 Autoload 單例;跨檔列舉需在
`AffinityTypes` 內宣告;所有進入 `pair_of()` 的角色序數必須先經 `is_valid_character()` 驗證。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純資料層物件持有與轉換,不涉及節點生命週期或
post-cutoff 引擎變更範圍)

**Engine Notes**: 無 post-cutoff 風險。

**Control Manifest Rules(此層,直接摘自「好感度數值池(ADR-0002)」段)**:
- Required:**採依賴注入,不採 Autoload 單例**——這是本 story 建立實例擁有權時最直接的
  硬性約束,結構上排除「把 `AffinityDataPool` 包成 Autoload」這個看似省事的選項。
- Required:**`pair_of()` 的呼叫端必須先以 `AffinityTypes.is_valid_character()` 驗證兩個參數。**
- Forbidden:**絕不對可測試資料層使用 Autoload 單例**(禁令
  `autoload_singleton_for_testable_data_layers`,ADR-0002)。
- Forbidden:**絕不把未驗證的角色序數傳進 `pair_of()`**(禁令
  `unvalidated_character_into_pair_of`,ADR-0002)。

---

## 🔴 第一個動作:讀 S-009,不是動手蓋基礎設施

EPIC.md 的 P-1(誰建立 `AffinityDataPool` 實例)標記的解法欄寫著「`lead-programmer`
（擁有權與生命週期)+ 第 9 節裁決項 3」,而系統 #1(好感度數值池)自己的 epic 底下已有
一張 `production/epics/affinity-data-pool/story-009-wiring.md`(S-009,接線故事)。
**本 story 撰寫期間刻意沒有讀取 S-009 的內容**(協調者中途指示,為了節省本輪派工的
讀檔預算)——這不是因為它不重要,而是留給下一個真正動手實作的人去做,理由是:

> **這是給實作者的第一步指示,不是本 story 作者現在要替他做的事。**

**因此,本 story 的第一步是**:

1. 讀 `production/epics/affinity-data-pool/story-009-wiring.md` 全文。
2. 判斷它是否已經解決以下問題(EPIC.md 稱為 P-1):
   - `AffinityDataPool` 的實例掛在哪個物件上(`BattleState`?一個新的戰鬥層 manager?)
   - 那個物件的生命週期是否涵蓋整場戰鬥(控制清單對跨幀協程宿主的既有要求:
     「持有跨幀協程的物件必須是生命週期涵蓋整場戰鬥的物件」,本例雖非協程,但同一精神
     適用——實例不能掛在會隨場景切換 / UI 面板關閉而被釋放的暫時性節點上)。
3. **若 S-009 已完全解決 P-1**(即已有一個生命週期正確、依賴注入取得的
   `AffinityDataPool` 實例存在,且有明確方式讓 #5 側取得對它的參照):
   本 story 的範圍**收斂為只剩下方「roster id ↔ Character 對映層」這一項(P-2)**,
   跳過「建立實例」的部分,直接使用 S-009 已建立的實例。
4. **若 S-009 尚未解決,或只解決一部分**(例如只在 #1 系統自己的測試裡 `new()` 一個
   實例,沒有接進真正跑起來的戰鬥場景):本 story 維持原定範圍,自行決定實例掛載點,
   但**必須在 story 完成時把決定寫回這裡**(而不是留給 story-005 的作者重新判斷一次)。

⚠️ **未查證**:本 story 撰寫時完全沒有讀取 S-009 或任何 `battle_state.gd` 現況以外的
`src/gameplay/battle/` 檔案來確認候選掛載點。**下一個人從 `production/epics/affinity-data-pool/story-009-wiring.md` 與 `src/gameplay/battle/battle_state.gd` 查起。**

## Acceptance Criteria

- [ ] **已判定 S-009 對 P-1 的涵蓋範圍**,並在本 story 完成時把判定結果(「已完全解決」/
  「部分解決,本 story 補完剩下的 ___」/「S-009 不存在或與此無關,本 story 從頭解決」)
  寫回本節下方的「實作決定」小節(留待 `/dev-story` 開工時補)。
- [ ] **`AffinityDataPool` 有且只有一個生命週期涵蓋整場戰鬥的擁有者**,不是 Autoload,
  且該擁有者可以被 #5 側的物件(未來的 `AffinityPhiProvider` 或其替代/夥伴物件)
  透過建構子注入取得參照。
- [ ] **roster id(`assets/data/units/vs01_roster.txt` 的 1～5,對應甲乙丙丁戊)↔
  `AffinityTypes.Character` 序數(0 起算)的對映層存在且可被 #5 側呼叫**,且呼叫前
  已驗證輸入落在合法範圍(不得未驗證直接送進 `AffinityTypes.pair_of()`)。
  ⚠️ **強烈建議直接複用 `src/gameplay/cards/affinity_pool_write_port.gd` 裡
  `_ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET = 1` 這個既有、已在生產中驗證過的對映方式**
  ——同一份專案已經有一支寫入端轉接器解決過完全相同的問題(roster id 1～5 減 1 得到
  `Character` 序數,6～10 為敵方單位、減去偏移量後落在 0～4 之外、被
  `is_valid_character()` 擋下)。**不要重新發明一套不同的對映規則**,但**是否要把這個
  常數抽成兩邊共用、還是讀端獨立複製一份同樣的偏移量常數**,是本 story 需要決定的實作
  細節(本文件不預先裁定——見下方 Implementation Notes 的提醒)。

## Implementation Notes

*本 story 沒有現成的 Implementation Guidelines 可抄(ADR-0002 沒有專門討論「#5 怎麼取得
池的參照」這件事,那是本 story 自己要解的問題),以下是作者(lead-programmer)的建議,
非強制規格:*

- **P-1(實例擁有權)候選方案**(未查證優先順序,留給實作者依 S-009 查證結果判斷):
  a. 若 `BattleState` 本身已是「生命週期涵蓋整場戰鬥」的物件(`AffinityPhiProvider`
     現有建構子已經接受一個 `BattleState state`,兩者生命週期高度相關),讓
     `BattleState` 額外持有一個 `AffinityDataPool` 參照可能是阻力最小的路徑。
  b. 若 S-009 已經指定別的擁有者(例如戰鬥層一個獨立的 manager),優先沿用 S-009 的決定,
     不要另立第二個擁有者——**兩個地方各自 `new()` 一份 `AffinityDataPool` 會導致寫入端
     (#6 技能卡牌)與讀取端(#5)看到不同的資料池,是比「沒有池」更隱蔽的錯誤**。
- **P-2(id 對映層)**:建議寫成一個小型靜態工具方法或類別(可仿照
  `AffinityPoolWritePort` 的風格,但本 story 只需要「roster id → Character」單向轉換
  加驗證,不需要完整的 port 抽象——是否值得為讀端也建一個對稱的
  `AffinityPoolReadPort` 類別,還是把轉換邏輯內聯進 story-005 要修改的
  `affinity_phi_provider.gd`,**留給 story-005 的實作者決定**,本 story 只需要保證
  「roster id → Character,含驗證」這個能力存在且可呼叫,不強制規定它住在哪個檔案。

## Out of Scope

- **實際呼叫 `combat_strength_read()` 取得配對資料、把結果餵回 `Φ` 計算** —— 那是
  story-005 的範圍。本 story 只交付「有一個池可以查」與「roster id 轉得成 Character」
  這兩件基礎設施,不改變 `Φ` 今天的任何計算行為。
- **`Φ` 讀取被拒絕時該怎麼降級** —— 那是 story-005 的範圍(裁決 4)。

## QA Test Cases

*`lean` 模式跳過 qa-lead 正式規格產生。本 story 是純接線/基礎設施性質,建議的驗證方式
偏 Integration 而非傳統 Given/When/Then 斷言:*

- **驗證池擁有者存活**:在一個模擬完整戰鬥生命週期的測試裡(建立 `BattleState` 或其
  替代物、經過若干步驟),確認 `AffinityDataPool` 參照全程有效,沒有因為場景切換或
  暫時性節點釋放而失效。
- **驗證 id 對映邊界**:roster id 1～5 應對映到合法 `Character` 序數;roster id 6～10
  (敵方)或任何超出 1～10 的值,應被 `is_valid_character()` 擋下,不得未驗證直接送進
  `pair_of()`。

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gameplay/affinity/` 下一條新測試(目錄若不存在
需新建,比照 `tests/integration/gameplay/affinity_pool/` 的既有慣例),驗證池的存活範圍
與 id 對映的邊界行為。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(但**第一步是讀 S-009**,若 S-009 尚未 Done,本 story 的實例擁有權
  部分可能需要與 S-009 的作者協調,避免兩邊各自決定擁有者)
- Unlocks: **story-005 必須在本 story Done 之後才能開始**——005 需要一個已存在的池參照
  與可用的 id 對映層才能實作「逐次查詢」。
- 🔴 **排程限制(協調者派工單明文要求寫入此欄,不只留在 EPIC.md/story-index.md)**:
  **本 story 與 story-005 必須依序執行,不可平行**(005 依賴本 story 的產出)。
  **story-005 與 story-006(M3 本系統側)不可同時派人**——兩者都可能涉及
  `src/ui/battle/battle_screen.gd` 既有呼叫慣例的調整面(見 EPIC.md 風險 R-4,
  6 處既有呼叫點)。本 story(004)本身不受此限制,可與 006 平行進行。
