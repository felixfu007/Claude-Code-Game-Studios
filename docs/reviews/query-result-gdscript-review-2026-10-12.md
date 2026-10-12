# QueryResult 契約型別獨立程式碼覆核(2026-10-12)

審查者:`godot-gdscript-specialist`
範圍:`src/gameplay/battle/query_result.gd` 與 6 個子類別 + `battle_screen.gd` 呼叫端一段
性質:覆核,非重寫。測試基線:`1127 test cases | 0 errors | 1 failures | 0 orphans`,`EXIT 100`(唯一具名
FAILED 為既有已核准刻意紅測試)。

## 0. 狀態摘要

- [x] 七項(§1.1~§1.7)全部查證完畢,另加協調者補派一項(§1.6 內的失敗分支測試覆蓋查證)。
- **六項判定無缺陷**(1.1、1.2、1.3、1.4、1.5、1.6 的控制流本身);**一項判定有缺陷**(1.7)。
- **未親自改動任何程式碼**(7 個產品檔 + `battle_screen.gd` 皆未修改)—— 本次純為覆核,
  發現的缺陷(1.7)牽涉產品層決定,已登記為需要裁決的項目,未自行套用修法。
- 因此**本次無需重跑測試套件**(沒有程式碼變更)。

## 1. 逐項發現(對應派工單 §4 七項)

### 1.1 `assert_same_version(results: Array[QueryResult])` 接受子類別實例 —— 協變是否有語言保證

**判定:無缺陷。這不是巧合,是 GDScript 4.x 型別化容器對 Object 衍生型別的保證行為,
從 4.0 引入型別化陣列起即如此,非 4.7 新增或待驗證特性。**

- 機制:型別化陣列(`Array[T]`)在 `T` 為 `class_name` 註冊的 Script 類別時,引擎在賦值/
  `append()` 時以繼承關係(`is_instance_of`)判定是否接受,而非精確型別比對。這與本檔上方
  §1 另記載的「巢狀型別容器不支援」是不同的語言面向,不可混為一談 —— 後者是容器**巢狀宣告**
  的限制,前者是容器**元素繼承關係**的接受規則,兩者互不影響。
- 本專案已有實機探針佐證(非僅理論推論):
  `prototypes/query-result-probe-2026-10-12/run_output_probe1.txt` 第 27 行逐字
  `PROBE1: Array[QueryResult] accepted 2 subclass instances`,且後續
  `assert_same_version` 同版本/混版本兩種分支皆正確判定(true / false,附
  `push_error` 訊息)。
- 風險評估:這個簽章**可以長期成立**。會讓它失效的唯一情況是未來硬塞一個**不是**
  `QueryResult` 子類別的物件進該陣列 —— 但那種情況引擎會在賦值當下直接拒絕
  (`Trying to assign ... Array[QueryResult]` 型別錯誤),屬於 parse/執行期即會攔截的寫法
  錯誤,不是本契約的隱患。
- 參考:`docs/engine-reference/godot/modules/scripting-typing.md` 第 8 節記載
  `class_name` 全域註冊機制(透過 `.godot/global_script_class_cache.cfg`,非 `extends`/
  `preload()` 鏈),是本節判斷「繼承關係在編譯期可被引擎正確解析」的佐證背景。

### 1.2 `_version_source: BattleState` 造成 QueryResult ↔ BattleState 互相參照 —— 為何未觸發 Cyclic reference

**判定:無缺陷。「Cyclic reference」是 GDScript 對 `extends`/`preload()` 形成的檔案層級
靜態依賴環的 parse-time 錯誤,與兩個類別互相以型別註記參照彼此、但透過全域 `class_name`
註冊表(而非顯式 `preload()`)解析,是兩件不同的事 —— 後者結構上不會觸發前者。**

- 已逐一確認本次 7 個檔案中**沒有任何一處 `preload()`**,也沒有任何一處
  `extends QueryResult`/`extends BattleState` 互指(6 個子類別皆 `extends QueryResult`,
  `QueryResult` 本身 `extends RefCounted`;`BattleState` 與 `QueryResult` 之間純粹是
  「欄位型別 / 函式回傳型別」的參照,不是繼承鏈)。
  (`grep -n "preload(|extends QueryResult|extends BattleState" src/gameplay/battle/*.gd`
  只命中 6 個子類別各自的 `extends QueryResult` 宣告,零 `preload()`。)
- `docs/engine-reference/godot/modules/scripting-typing.md` 第 8 節記載本專案自己的實機探針
  (`prototypes/xcheck-classname-cycle-2026-08-24/`)**已經直接測試過** `class_name` 互相引用
  的情境(`BareRefOtherFile`/`OuterHolder`/`QualifiedRefOtherFile` 三個互指的 class_name),
  結論是**匯入後 `Parse Error`/`Cyclic` 零命中** —— 因為全域類別解析走的是
  `.godot/global_script_class_cache.cfg` 這張表,不是逐檔案靜態展開的 `preload()` 依賴圖。
  這與本次 QueryResult/BattleState 的情況是同一個機制,故可直接套用該結論。
- **什麼情況下會真的觸發**:若未來有人把其中一方改成用 `preload("res://.../other.gd")`
  在檔案頂層建立 `const` 依賴(而不是用全域 class_name 型別註記),且兩邊互相 `preload` 對方,
  才會形成真正的檔案層級循環依賴、才可能觸發 `Cyclic reference`。目前兩個檔案都不這樣寫,
  這條路徑沒有被打開。
- ⚠️ 誠實揭露:我沒有另外寫一支新探針去「刻意把這兩個類別改成用 preload 互指」來實機重現
  觸發情境 —— 上面「會觸發的條件」是依據 Godot 的 `preload()`/`class_name` 解析機制推論,
  不是本次新增的實機驗證。但本專案既有探針(`xcheck-classname-cycle-2026-08-24`)已經涵蓋
  「互指但不用 preload」這個真正相關的情境並得到零命中的結論,我認為這已經足夠回答
  「現狀為何沒事」,只是「反例邊界」那句話屬外推。

### 1.3 生命週期 / 參照語意 —— RefCounted 參照環風險

**判定:無缺陷。目前是單向強參照(`QueryResult → BattleState`),`BattleState`/
`BattleController` 皆未持有任何 `QueryResult` 實例的參照,故不構成參照環,也不會洩漏。**

- `BattleState`(`class_name BattleState extends RefCounted`)與 `BattleController`
  (`class_name BattleController extends RefCounted`)兩個檔案逐一搜尋
  `QueryResult`/各子類別名稱/`cache`/`_last_` 等關鍵字,**沒有任何欄位儲存
  `QueryResult` 或其子類別的實例** —— 兩者都只是在函式**回傳型別**用到這些型別名稱,
  不持有參照。
- 全專案搜尋所有 `.gd` 檔裡「型別宣告為 QueryResult 或其子類別的賦值」,唯一命中的是
  `src/ui/battle/battle_screen.gd` 的 `_refresh_view()` 內的**區域變數**
  (`move_result`/`attack_result`/`threat_result`/`damage_result`),沒有任何一處把
  它們存成物件欄位(`var _xxx: QueryResult` 這種宣告在整個 `src/` 樹裡零命中)。
- 因此生命週期是:每次 `_refresh_view()` 執行時建構、在函式體內使用其 `.cells`/
  `.damage`/`.breakdown`/`.version`/`is_stale()`,函式結束時區域變數離開作用域、
  參照計數歸零、`RefCounted` 立即釋放。沒有任何外部物件在函式結束後仍持有它,
  也沒有互相持有造成的參照環。
- ⚠️ **這個結論目前成立,但不是結構性保證,是今天程式碼寫法的事實。** 若日後有人把
  其中一個 `QueryResult` 存成 `BattleScreen` 的物件欄位(例如「快取上一次查詢結果」),
  且同時 `BattleState`/`BattleController` 任一方也開始持有某個 `QueryResult`(目前沒有
  任何跡象顯示有這個需求),才會形成環。**目前沒有這樣的程式碼,此風險屬於「尚未發生」,
  不是「已發生但測試線量不到」。**

### 1.4 ADR-0001 參照語意約束 —— payload 是否為新配置容器

**判定:無缺陷。6 個子類別的 `_init()` 本身只做淺層指派(`cells = payload` /
`breakdown = breakdown_payload` / `damage = damage_payload`),這一層本身不保證新配置 ——
但逐一追到各自的上游呼叫端後,確認今天進來的每一筆 payload 在呼叫端那一層就已經是新配置的
容器,淺層指派因此是安全的。**

逐一追蹤結果:

| 子類別 | payload 來源 | 新配置依據 |
|---|---|---|
| `MoveTargetsResult` | `BattleController._move_targets_for()` | 函式內 `var result: Array[Vector2i] = []` 區域變數,逐格 `append()`,doc comment 明文「Always a freshly built array — never a reference into any internal container.」(`battle_controller.gd` 行 261-262,遷移前即有此保證,非今天新增) |
| `AttackTargetsResult` | `_attack_targets_for()` | 同上形狀,`result = []` 區域變數逐格 append |
| `ThreatTargetsResult` | `_threat_targets_for()` | 同上,另外用 `Dictionary` 去重後重建成區域 `result` 陣列 |
| `MoveTargetsBreakdownResult` | `_move_targets_breakdown_for()` → `_classify_move_targets()` | 四個分類陣列(`legal`/`blocked_by_occupancy`/`blocked_by_terrain`/`out_of_range`)皆函式內區域變數,逐格分類 append,最後包成新 Dictionary 字面量回傳 |
| `PreviewDamageResult` | `BattleState.preview_damage()` → `_compute_attack_damage()` | 回傳值是 `int`(`dealt`),值型別,無參照語意問題可言 |
| `DamageBreakdownResult` | `BattleState.preview_damage_breakdown()` → `_attack_damage_breakdown()` | 回傳 Dictionary 字面量 `{...}`(行 616-622),每次呼叫新建;`preview_damage_breakdown()` 另外對該 dict 加一個 key(`target_hp_after`)後才包進 Result,同一個新建的 dict,無外洩 |

- 結論:**今天這批遷移沒有引入任何「回傳內部儲存結構參照」的新違規** —— payload 新鮮度的
  保證早於這次遷移就存在(`move_targets()`/`attack_targets()` 等方法的 doc comment 本來就寫著
  「Always a freshly built array」),這次遷移只是在既有保證之外加了一層 `QueryResult` 包裝,
  沒有改變 payload 本身的配置方式。
- ⚠️ 需要指出的是:`_init()` 這一層**本身**不是這條契約的防線 —— 它只做欄位指派,不做
  `duplicate()` 或任何防禦性複製。**如果日後有任何新呼叫端把一個指向內部儲存結構的參照
  傳進任何一個子類別的建構子,`_init()` 不會攔下來,也不會發出警告。** 這條契約目前完全
  仰賴「呼叫端自律 + doc comment 宣告」,屬於紀律遵守而非結構保證 —— 與本專案一貫記載的
  「規則寫了不代表會被檢查」同一類風險,但範圍只限於*未來的新呼叫端*,今天這 7 個檔案本身
  沒有問題。

### 1.5 兩項設計決定是否正確實作(無參數建構子 / assert_same_version 與 is_stale 的獨立性)

**判定:兩項皆正確實作,無缺陷。**

1. **沒有無參數建構子**:逐一確認 7 個檔案的 `_init()` 簽章 ——
   `QueryResult._init(source: BattleState)`、6 個子類別皆為
   `_init(source: BattleState, xxx_payload: ...)`,**沒有任何一個參數帶預設值**。
   GDScript 呼叫建構子時引數數量不符會在 parse 期直接報錯(arity 不符),
   所以 `MoveTargetsResult.new()`(零引數)在今天的程式碼下**無法通過編譯**,
   不存在繞過的寫法。檔頭註解宣稱的「刻意不給無參數建構子」與實作一致。
2. **`assert_same_version()` 與 `is_stale()` 彼此獨立**:逐行讀 `query_result.gd` 41-49 行,
   `assert_same_version()` 的迴圈只比較 `r.version != expected`,**從未呼叫 `is_stale()`
   或讀取 `_version_source`**,兩個函式之間沒有互相呼叫。檔頭註解「assert_same_version()
   只檢查彼此版本相同,不檢查 is_stale()」與實作完全一致,呼叫端(`battle_screen.gd`)
   也確實分別呼叫兩者(`versions_consistent` 與 `any_stale` 是兩個獨立變數,用
   `or` 合併判斷),沒有誤以為其中一個函式涵蓋另一個的語意。

### 1.6 呼叫端版本核對的控制流 —— 高亮狀態是否可能卡在舊值

**判定:控制流本身無缺陷**(三層高亮在失敗分支確實全部清空,沒有「清了三層、第四層殘留」
的情況 —— 這組疊圖設計上就只有 move/attack/threat 三層,不存在協調者原假設的「第四層」)。
`_board_view.set_move_highlights([])` / `set_threat_highlights([])` / `set_attack_highlights([])`
三者在失敗分支逐一呼叫,沒有遺漏。

**但協調者加派的查證項(失敗分支零測試覆蓋)有實質發現,判定:可測但沒測,非結構性測不到。**

- `grep -rn "assert_same_version" tests/` 確認只有 `query_result_test.gd` 測到
  `QueryResult.assert_same_version()` 這個函式本身(含子類別協變、同版本/混版本等情境),
  但 `battle_screen.gd._refresh_view()` 裡【接線】那段 `if not versions_consistent or any_stale:`
  分支從未被任何測試執行過。
- **判定依據**:本專案測試套件裡,`extends BattleController` 與 `extends BattleScreen` 兩種
  間諜/突變子類別都是**已確立、已大量使用**的既有技巧,不是本次才要發明:
  - `tests/unit/gameplay/battle/movement_range_query_test.gd` 的
    `_MutantCollapsesTerrainIntoOutOfRange extends BattleController` /
    `_MutantBypassesMoveLegalityCheck extends BattleController` —— 直接覆寫
    `BattleController` 的查詢方法。
  - `tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd` 的
    `_MutantSynchronousEnemyPhase extends BattleScreen`,該類別內**直接呼叫
    `_refresh_view()`**(第 53 行),證明 `_refresh_view()` 本身可在突變子類別裡被呼叫。
  - `tests/integration/ui/forced_discard_test.gd` 多處直接對一個已建構的 `BattleScreen`
    實例呼叫 `instance._refresh_view()`,證明這個函式可以在測試裡被直接觸發,不需要真正的
    游標輸入事件。
  - GDScript 的底線底線前綴(`_controller`)**只是命名慣例,不是強制存取控制** ——
    語言本身沒有真正的私有成員機制,測試碼可以直接對一個已建構的 `BattleScreen` 實例
    賦值 `instance._controller = spy_controller`,引擎不會阻擋。
  - 綜合以上:具體做法是寫一個 `_MutantMoveTargetsStaleVersion extends BattleController`
    (或 `extends BattleScreen` 搭配覆寫建構 `_controller` 的那一步),覆寫
    `move_targets()`/`attack_targets()`/`threat_targets()` 三者之一,讓它在回傳前先觸發一次
    真實的 `commit_authoritative_change()`(例如呼叫一個會遞增 `combat_state_version` 的
    既有合法操作),使該次回傳的 `QueryResult.version` 與另外兩支的版本號不同 ——
    這樣可以忠實重現檔內註解點名的風險情境(日後有人在 `_refresh_view()` 裡插入
    `await`/權威寫入),而不必更動 `_refresh_view()` 本身的程式碼。之後斷言
    `_board_view` 的三層高亮皆為空(可能需要在 `BoardView` 上加一個唯讀的
    diagnostic getter 讀回目前的高亮集合,若尚未存在)。
- **不落入 `test-standards.md` 登記的五類「已知證明不了」之一**(A 靜態純函式 / A′ 真實資料檔 /
  B RNG 決定性契約 / C 進樹後換腳本 / D 唯一注入點在受限範圍外)—— 本情境的注入點
  (覆寫 `BattleController` 的查詢方法、或進樹前 `set_script()`)完全落在既有已驗證安全的
  `set_script()` Case A(進樹前換腳本)或純粹的子類別覆寫,兩者都在本專案已證實可行的範圍內。
- ⚠️ **誠實揭露**:我沒有實際寫這條測試,也沒有驗證「`BoardView` 是否已有可讀回高亮集合的
  diagnostic getter」—— 這是我沒有查證的部分,下一個人要把這個測試寫出來前,需要先確認
  這個讀取介面存不存在,不存在則需要先補一個唯讀 getter(本身不算改動被測行為,屬於新增
  測試腳手架)。

### 1.7 `preview_damage` 刻意不併入核對 —— 理由是否站得住

**判定:部分站得住 —— 排除出 `assert_same_version()` 合併檢查的理由本身成立,但這段理由
沒有涵蓋 ADR-0001 另一條獨立義務,而 `damage_result` 目前完全沒有實作那條義務。
這是本次覆核七項裡唯一判定為「有缺陷」的一項。**

**站得住的部分**:檔內註解①②③(`assert_same_version()` 契約是「少於 2 筆恆成立」、
搬動既有控制流的代價、三層高亮與傷害預覽文字語意上不是同一次合併疊圖)—— 這三點
正確回答了「為什麼 `damage_result` 不需要跟 move/attack/threat 三者一起做
`assert_same_version()` 檢查」,而 ADR-0001 原文對「合併呈現」的定義
(`docs/architecture/adr-0001-tactical-query-atomicity-contract.md` 行 117:
「被合併判讀為單一畫面的一組輸出」)也確實是指**疊在同一張棋盤上、彼此必須一致**的
那一類輸出,獨立產生的 `info_text` 不屬於這個範疇。**這部分判斷正確。**

**站不住的部分(缺陷)**:ADR-0001 對呈現層另有一條**獨立於合併檢查**的義務,
逐字(同檔行 587):
> 「呈現層的義務:任何一組要合併呈現給玩家的查詢結果,渲染前須通過
> `assert_same_version`;**任一結果 `is_stale()` 為真時,不得以該結果接受玩家輸入**
> (須重算或拒絕該輸入)。」

這句話的第二個分句用的是「**任一結果**」,不限定於合併群組 —— 也就是說,即使
`damage_result` 正確地不需要加入 `assert_same_version()`,它仍然單獨適用
「`is_stale()` 為真時不得使用」這條義務。**實測 `damage_result.is_stale()` 在
`battle_screen.gd` 全檔零呼叫**(`grep -n "damage_result\.is_stale"` 零命中)——
這個傷害預覽數字被直接拿去組 `info_text` 並顯示給玩家,中間完全沒有過期檢查。

- **今天為何沒有實際後果**:與三層高亮檢查的註解一致,`_refresh_view()` 這次執行
  是同步的、`damage_result` 建構後立即被使用,中間沒有 `await`/`call_deferred`/
  權威寫入,所以 `is_stale()` 今天結構上恆為 false —— 這點與三層高亮的情況完全對稱。
- **不對稱之處**:三層高亮檢查**特地加了一段防禦性檢查**來防範「日後有人在這段加
  `await`」這個風險(檔內註解明講這是為了日後,不是為了今天),而 `damage_result`
  這條路徑**完全沒有對應的防禦**——同一個未來風險(有人在 `_refresh_view()` 的
  這個分支裡插入 `await`)對兩條路徑同等適用,但只有一條路徑有防線。
- **這不是我在雞蛋裡挑骨頭式地要求「風格更好」**:ADR-0001 的文字是逐字寫著
  「任一結果」,不是「任一組被合併的結果」——這是契約義務本身的覆蓋範圍問題,
  不是品味偏好。

**我沒有自行修補這處**,原因:正確的修法不只是機械地加一行
`if damage_result.is_stale(): ...`,還牽涉到一個產品層決定——**過期時這格的
傷害預覽要顯示什麼**(空白文字?維持上一次的數字?跳過整個 info_text 賦值?)。
三層高亮的既有作法是「清空疊圖 + push_error」,但傷害預覽文字沒有「清空」這個
對應概念可直接套用(`info_text` 是單一字串,不是三個陣列)。這屬於需要協調者或
ADR 擁有者裁決的產品行為,不是我這次覆核該自行決定的事。

## 2. 實際變更(若有)

**沒有變更任何程式碼檔。** 這是一次純覆核,§1.7 發現的缺陷因牽涉產品層決定
(過期時傷害預覽要顯示什麼)而刻意不自行套用修法 —— 詳見該節與下方第 4 節。

## 3. 全套測試輸出(若有改動程式碼)

**不適用 —— 本次沒有程式碼變更,未重跑測試套件。** 基線維持派工單提供的
`1127 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans`、`EXIT 100`。

## 4. 需要管理者裁決的項目

1. 🔴 **§1.7 的缺陷**:`PreviewDamageResult`(`damage_result`)在 `battle_screen.gd`
   的 `_refresh_view()` 裡被使用前,從未呼叫 `is_stale()`,違反 ADR-0001 逐字義務
   「任一結果 `is_stale()` 為真時,不得以該結果接受玩家輸入」。今天因為
   `_refresh_view()` 全程同步、無 `await`,這個缺口**結構上還沒有實際後果**,
   風險性質與三層高亮檢查完全對稱(都是防「日後有人加 `await`」),但只有三層高亮
   那條路徑有防線。**需要決定**:
   - 是否要補一個對稱的防禦性檢查(`if damage_result.is_stale(): ...`)?
   - 若要補,過期時 `info_text`/`preview_target_id`/`preview_target_hp` 這組變數該呈現
     什麼(空白?跳過賦值?push_error + 不顯示預覽?)—— 這是產品層決定,不是我能代為決定的。
   - 或者,若架構上認為「這條路徑永遠不會有 await」是可長期維持的不變式,是否要把這個
     判斷明文寫進 ADR-0001 的 scope boundary 文件,做為明文例外(類似 `QueryResult`
     持有 `BattleState` 參照那條「明文例外」的寫法),而不是留著一條沒人看得出來的隱性假設?

2. **1.4 節提到的紀律缺口**(非今天的缺陷,是潛在風險登記):6 個子類別的 `_init()`
   完全仰賴上游呼叫端提供新配置的容器,自己不做防禦性複製或型別/所有權檢查。
   今天的 7 個呼叫端都正確,但這條契約目前沒有任何結構性保證能擋住未來的錯誤呼叫端。
   是否需要加一層防禦(例如呼叫端慣例文件化、或在 debug build 加執行期檢查),
   留給協調者/ADR 擁有者判斷是否值得投入。

## 5. 誠實揭露 —— 引用但未親自驗證之處

- **1.2(Cyclic reference)的「會觸發的條件」段落是外推,不是本次新驗證。**
  我引用了本專案既有探針 `prototypes/xcheck-classname-cycle-2026-08-24/`
  (透過 `docs/engine-reference/godot/modules/scripting-typing.md` 第 8 節轉述),
  那支探針測的是「class_name 互指、不用 preload」的情境並得到零命中結論 ——
  這與今天 QueryResult/BattleState 的情況確實是同一個機制,但我沒有另外寫一支新探針
  去刻意把這兩個類別改成用 `preload()` 互指,實機重現「真的會觸發」的那個反例邊界。
  那句話的可信度建立在對 Godot `preload()`/`class_name` 解析機制的理解上,不是新量測。
- **1.6 節的測試做法(覆寫 `BattleController` 查詢方法 + 讀回 `BoardView` 高亮集合)
  是設計,不是已驗證可行的實作。** 我確認了「`extends BattleController`」與
  「`extends BattleScreen`」兩種子類別技巧在本專案既有測試裡都已被使用且運作正常
  (`movement_range_query_test.gd`、`battle_screen_enemy_phase_playback_test.gd`、
  `forced_discard_test.gd`),但沒有實際寫出這條新測試、沒有驗證
  `BoardView` 上是否已經有可讀回目前高亮集合的 diagnostic getter —— 如果沒有,
  下一個人需要先加一個。
- **1.3 節(參照環)的搜尋範圍**:我用 grep 搜尋了 `BattleState`/`BattleController`
  兩個檔案裡是否有儲存 `QueryResult` 類型欄位,以及全 `src/` 樹裡是否有
  `var _x: QueryResult`(或各子類別名)這種物件欄位宣告,兩者皆零命中。
  我**沒有**窮舉搜尋間接路徑(例如某個欄位型別是 `Variant` 或 `Dictionary`,
  執行期塞進一個 `QueryResult` 實例,靜態 grep 看不到)——這個可能性理論上存在但
  我認為可能性極低(本專案一貫做法是明確型別化欄位,見本檔案開頭「基本的靜態型別紀律
  已經過了」那條快篩結果),故未進一步窮舉。
- **1.4 節的「payload 新鮮度」判斷,我核對到 `_classify_move_targets()`/
  `_attack_damage_breakdown()` 這一層的程式碼本身,確認是函式內區域變數逐格建構** ——
  但我沒有再往下一層追 `board.reachable_tiles()`(`_move_targets_for()`/
  `_threat_targets_for()` 最終呼叫的 Board 方法)的實作本身是否真的回傳新配置陣列,
  是依賴該方法既有 doc comment 的宣稱(「Always a freshly built array」)與
  移動範圍測試套件的既有綠燈作為間接佐證,不是直接讀了 `board.gd` 裡
  `reachable_tiles()` 的實作逐行確認。
