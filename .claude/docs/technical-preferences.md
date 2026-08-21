# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.7.1
- **Language**: GDScript
- **Rendering**: Forward+ (Godot 4.7 default renderer)
- **Physics**: Jolt Physics (Godot 4.6+ default)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC, Console
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse (full Gamepad support required for console parity)
- **Gamepad Support**: Full
- **Touch Support**: None
- **Platform Notes**: All UI must support both mouse hover/click and d-pad/analog-stick navigation equally — no hover-only interactions, since console has no cursor.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case (e.g., `move_speed`)
- **Signals/Events**: snake_case, past tense (e.g., `health_changed`)
- **Files**: snake_case matching class (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PlayerController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6ms
- **Draw Calls**: < 1000 (turn-based tactics — modest scene complexity, generous budget)
- **Memory Ceiling**: [TO BE CONFIGURED — set once content volume and target hardware are known]

## Testing

- **Framework**: **GdUnit4**(2026-08-19 `/test-setup` 由使用者裁決;此前本行寫 `GUT`,
  與 `coding-standards.md` 的 CI 指令 `tests/gdunit4_runner.gd` 互相矛盾——兩者是不相容的框架。
  判定 `GUT` 為範本預設值而非實際決定,理由:同區塊其餘欄位皆為未設定佔位符,
  而 CI 指令是具體到檔名的。基礎設施見 `tests/README.md`)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->

**權威清單在 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節(目前 31 項;2026-08-21 ADR-0005 第四次修訂新增 2 項:`abstract_func_with_body`〔**專案級**,`adr: none` —— 它曾同時存在於 ADR-0004 與 ADR-0005,且根因在參考庫的錯誤範例,故不掛任一 ADR 名下。**2026-08-21 更新:兩份文件皆已修畢**(ADR-0005 八處於第四次修訂、ADR-0004 五處於同日事實層修訂),`referenced_by` 兩份**保留** —— 它是治理範圍清單,不是待辦清單。該條目仍 `active`,作為**前瞻性禁令**:本專案任何未來的 `@abstract` 宣告都必須是裸簽章。registry 的 `why:` 欄同日擴充為 8 種已實測回傳型別,並新增兩項實測 —— 漏實作的錯誤訊息**只指名其中一個**方法(其餘以 `and other inherited abstract methods` 概括,不逐一列舉),以及**字面 `ClassName.new()` 構造抽象類別是編譯期錯誤**、但 `set_script()`/`load().new()`/`ClassDB` 三條間接路徑**未查證**〕、`silent_freeze_fallback_for_invalid_provider`;同日 ADR-0002 第四次修訂新增 4 項:`death_marks_prefill_or_unguarded_read`、`raw_enum_name_subscript_from_untrusted_string`、`wholesale_reassignment_of_affinity_record_list_items`、`unvalidated_character_into_pair_of`;此前 2026-08-20 新增 `raw_variant_subscript_into_typed_container`)。**
以下 3 項是**專案級身分/範圍裁決**,來源為 `design/gdd/game-concept.md` 而非任何 ADR,
因此在任何 ADR 被 `Accepted` 之前就已生效,寫在這裡供實作時直接查閱:

- **`rng_in_combat_settlement`** — 戰鬥結算路徑絕不可使用 RNG(無骰子、無隨機事件、
  無機率決定的結算結果,亦無機率造成的 permadeath)。
  **唯一豁免**:好感度對話卡牌的**牌面**隨機,但**發牌節奏固定**(`game-concept.md`
  第三輪 creative-director 裁決)——隨機只出現在「提供什麼選項」,絕不出現在
  「結算如何解出」。
- **`networking_features`** — 無連線/多人/線上功能,單機遊戲。
  (與 `TR-save-030` 的 Steam Cloud 待決問題無關:雲端**存檔同步**是平台提供的
  檔案層服務,不是本作的連線功能。)
- **`procedural_terrain_generation`** — 棋盤地形與其演變一律手工設計、劇情觸發,
  絕不程序化/隨機生成。

其餘 26 項為 ADR-0001~0005 各自推導出的實作級禁令。**2026-08-21 ADR-0002 第四次修訂新增的 4 項,四者都是「已實測的引擎行為使某個文件層假設不成立」**:`_death_marks` 絕不預填且讀取一律 `has()` 守衛(與 `_records` **相反** —— 前者的鍵存在本身就是「已陣亡」的語意,預填會摧毀語意;而缺鍵 subscript 讀取已實測會**中止呼叫函式**)、對不可信字串裸用 `Pair[name]` 這個**形狀**(`.has()` 方法呼叫與 `[]` subscript 已實測是兩種完全不同的命運:後者中止,前者乾淨回傳 `false`)、`AffinityRecordList` 內層陣列的整體重新賦值(包裝類別把 Alternative 7 被拒的「不強制」從 Dictionary 值槽搬到了公開欄位;⚠️ GDScript **無真正的私有成員**,故此項是紀律而非結構保證,ADR 明文不宣稱達到「結構保證優於紀律要求」的標準)、未驗證即呼叫 `pair_of()`(它是第 8 個帶 enum 參數的入口,且**唯一無拒絕通道**者 —— 回傳裸 `Pair` 不可為 null)。ADR-0001~0004 的 10 項:節點樹推導佔位、
動畫驅動邏輯狀態、結算路徑 `call_deferred()`、回傳內部容器參照、依賴容器迭代順序、
可測試資料層用 Autoload、可變容器當 Dictionary 鍵、enum 位置索引字串轉換、
Resource 承載存檔 payload、取鎖與釋放之間提前 return。**ADR-0005 共 11 項(游標系統;2026-08-18 
首版 4 項 + 2026-08-19 第一次修訂新增 2 項 + 第二次修訂新增 3 項 + 第三次修訂新增 2 項)**:游標 Autoload 薄殼加邏輯、用 `_unhandled_input()` 做裝置
權威裁定、讀取 `InputEvent.device` 裝置 ID、已註冊游標表面使用原生 Control hover/focus(注意:
此項需**兩個**條件,`focus_mode = FOCUS_NONE` 單獨不足——它不關 Control 主題內建的滑鼠 hover 
管線);**2026-08-19 新增**:下游系統在 `_input()`/`_unhandled_input()` 內判讀確認類 `ui_*` action
(`confirm_action_read_in_unhandled_input`——`process_priority` 管不到這兩個回呼,只能靠明文禁止)、
在本系統自己發出的訊號處理函式內回頭呼叫寫入介面(`cursor_state_write_from_own_signal_handler`);
**2026-08-19 第二次修訂新增 3 項**:`CursorState` 的公開寫入入口互相呼叫
(`public_cursor_write_entry_calling_another`——會被自己的重入閘門鎖死,緩衝內導覽寫入靜默失效)、
以 `call_deferred()` 把改標呼叫延後進 `_process()`(`call_deferred_for_cursor_retarget_deferral`
——沖洗時點未查證,會重開四步定序的洞;唯一許可手段是設旗標)、
把梯上**不相鄰**的兩個行為者角色實作在同一個節點上
(`single_node_for_nonadjacent_cursor_actor_roles`——②+⑥ 雙角色必須拆兩個節點,
陳述順序只對相鄰角色有效);**2026-08-19 第三次修訂新增 2 項**:`CursorState` 以外的任何程式
碼持有或呼叫 `MouseReclaimPolicy` 實例(`external_access_to_cursor_reclaim_instance`——該實例
唯一擁有者是 `CursorState`,私有且無 getter;Host 與呈現層一律走
`reseed_reclaim_on_focus_regained()`/`reclaim_progress()`/`reclaim_reset_triggered` 三條轉發。
連帶規則:`get_viewport().get_mouse_position()` 全專案只准出現一次,即建構
`mouse_position_provider` 的那一行)、把 `_write_target_internal()` 的兩條重置路徑寫成兩個
獨立 `if` 而非 `if`/`elif`(`independent_ifs_for_cursor_target_reset_policy`——交接乙分支會在
同一次寫入內連發 `SURFACE_HANDOFF` 與 `TARGET_CHANGED` 兩次重置)。詳見 registry 各條的 `why:` 欄。

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **ADR-0001 — 戰棋查詢介面原子性契約** (`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`) — **Proposed**, 2026-08-18. Snapshot identity via monotonic `board_version` stamp (incremented only at committed settlement boundaries) rather than deep-copied board state; `settlement_in_progress` re-entrancy gate with reject-on-input; sparse `Dictionary[Vector2i, int]` logical occupancy. Carries the architecture-grade mechanisms behind `design/gdd/tactical-combat-system.md` Core Rules #10 b/c and #11. Registered stances live in `docs/registry/architecture.yaml` (3 state-ownership, 2 interface contracts, 3 API decisions, 5 forbidden patterns).
- **ADR-0002 — 好感度數值池資料結構與並發契約** (`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`) — **Proposed**, 2026-08-18. Per-pair indexed `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` satisfying the GDD-locked `O(n_p + m)` query contract; campaign-tick marker list and death-marker table as structurally independent stores; monotonic-int serialization-lifecycle tokens under unconditional `Mutex` (defence-in-depth — ADR-0004 has since ruled the background-thread condition of `TR-affinity-016` to be NO, so this is a lock with no current contender; see the C3 note below); dependency-injected ownership, not Autoload. **2026-08-20 第七輪 `/architecture-review` 獨立重推:24 項 `TR-affinity-*` 為 21 ✅ / 3 ⚠️ / 0 缺口**(此前本行寫 "Covers all 24 requirements" —— 零缺口成立,但「全部涵蓋」是過度宣稱,第六輪已點名、第七輪 `TR-affinity-011` 再降一格後更不可辯護)。3 項 ⚠️:`-008`(同結算步呼叫順序的決定性歸戰棋系統,`TR-tactical-023` 仍無 ADR)、`-020`(記憶化契約擁有者無 GDD 亦無 ADR)、**`-011`(成因在本 ADR 內部 —— R7E-4,enum 型別化參數對數值近親靜默轉換,已實機確認)**。 Registry: 3 state-ownership, 2 interface contracts, 4 API decisions, 3 forbidden patterns. **2026-08-19 銜接缺口修訂(不改動任何機制)**:C1 —— `TOKEN_TIMEOUT_MS` 的定值責任移交 ADR-0004(只有它掌握遷移鏈深度上界與兩階段回寫最壞 I/O 時間);C3 —— `TR-affinity-016` 的條件已由 ADR-0004 判為「否」,`Mutex` 決策不變但理由改為**縱深防禦**,不再宣稱是「全專案唯一已成立的執行緒安全義務」。**2026-08-20 引擎行為實機驗證修訂(BLOCKING)**:2026-08-20 的引擎驗證 spike 與 `godot-gdscript-specialist` 獨立交叉覆核在 Godot 4.7.1 實機測出本 ADR 機制二的**核心宣告 `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` 無法編譯**(`Nested typed collections are not supported`,class member / 函式參數 / 回傳型別三種形狀皆同,兩個獨立專案重現),已改採包裝類別 `AffinityRecordList`(本次驗證四個候選中唯一同時保住兩層型別者)。連帶:型別安全論述由單層改寫為**三層圖像**(層一編譯期已實證會擋 enum 家族;層二執行期容器驗證 debug 已實證、**release 未查證**;層三型別化 `Dictionary` 的 subscript 鍵路徑**已實證完全不擋**),新增機制四之二的**鍵邊界/值邊界兩條規則**與機制四之三的**呼叫端型別義務**;`validate_semantics()` 逐欄位檢查擴充為**型別 + 值域**,型別檢查明訂只能用 `typeof()` 內省(實測 `is_nan`/`is_inf` 與比較運算子對 `String` 皆中止所在函式,而 `var t: int = <float 1.5>` **靜默截斷為 1** ——後者是唯一「不出錯但也不安全」的情況);Verification Required 五項擴為八項(六關兩開)。**這是本專案第一份經實機驗證的 ADR,而驗證直接擊落了它的核心宣告** —— 若照原計畫先推 `Accepted` 再走 story,那一行會在實作第一天爆,且屆時已是「已核准的架構決策」。寫入前執行 Step 5.5 雙軌覆核(`godot-gdscript-specialist` + `godot-specialist`),抓出並修畢本次修訂初稿**自己引入的 2 項缺陷**(用鍵邊界規則去支撐值層降級、推導鏈不成立;VR 計數低估為「一項新增」會讓讀者漏掉未查證的 #7)——與 ADR-0005 第三/四/五輪同一模式,第六次。**2026-08-21 第四次修訂(第七輪 17 項)**:兩項 BLOCKING(R7E-6 —— `t_query: Variant` 才是本 ADR 真正的 `Variant` 入口,而 2026-08-20 的範圍宣告只稽核了自己剛寫的兩個方法,致 `FUTURE_TIME_QUERY` 成死碼;R7E-4 —— enum 型別化參數對數值近親靜默轉換)+ R7-P1/P2/P3 + R7E-2 的二選一裁決 + 其餘 11 項。**機制層面的實質變更**:讀取拒絕改由結果物件的 `rejection` 欄位承載(`SpeculativeRejection` 併入 `ReadRejection`,四個簽章**全部不再回傳 `Variant`**);`t_query` 新增 `typeof()` 三分支閘門(`TYPE_FLOAT` 一律拒絕);`_records` 建構子預填 10 對而 `_death_marks` 刻意不預填;`AffinityRecordList.items` 改私有 + 最小存取面;**8 個帶 enum 參數的入口統一序數驗證**(`can_write()` 回傳型別 `bool` → `WriteRejection` —— **本次唯一改變既有公開簽章回傳型別之處**);`_reclaimed_tokens` 次要逾時**撤回時間門檻**改固定容量 FIFO(不再引用任何外部常數,C7 同形缺陷未被複製)。**寫入前執行 Step 5.5 雙軌覆核兩輪**:第一輪 11 BLOCKING/高 + 12 非阻塞,**8 項是修訂初稿自己引入或漏掉的**;協調者另自行 grep 核實出範圍宣告**連續被低估三次**(4 → 17 → 約 30 處),並抓到**修正 A 讓 ADR 第 238 行「兩條規則都不改變任何既有簽章」變成假話**(該句逐字點名 `can_write`)。第二輪窄範圍重驗覆核後才產生的兩項機制變更,再抓到 4 項,含 `can_write() -> WriteRejection` 有 **3 個**結構上不可達的值(兩軌獨立收斂)、`pair_of()` 是第 8 個入口且**無拒絕通道**、以及 FIFO 在 `Dictionary` 上**需要一個新的排序容器**(關鍵理由:權杖移入 `_reclaimed_tokens` 的時點不等於 token id 順序,故「用 key 大小近似最舊」也不成立)。**「修法本身引入新缺陷」模式第八次。** Registry 69 → **78**,ADR-0002 佔 **22** 項。**本 ADR 明文不自陳修訂後涵蓋分佈,留給第八輪獨立 `/architecture-review`;優先查核點:修正 A/H(第一輪覆核後才產生)、`can_write()` 簽章、`pair_of()` 的保護等級不與其他 7 個入口同級。**

  以下為前次紀錄:**本 ADR 明文不自陳修訂後涵蓋分佈,留給第七輪獨立 `/architecture-review`。**
- **ADR-0003 — 存檔系統序列化格式與型別安全** (`docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`) — **Proposed**, 2026-08-18. Resolves `save-system.md` Open Question 3: binary Variant serialization via `var_to_bytes()`/`bytes_to_var(bytes, false)`, rejecting `Resource`/`.tres` and JSON — this makes Core Rules #9's deserialization type whitelist *structurally unnecessary* (no custom `Object` can be produced) rather than app-maintained, and moots Open Question 4. Layered per-block `PackedByteArray` buffers enabling the manifest-only read path; two-layer SHA-256 hash chain in canonical `source_id` order. Retrofits ADR-0002 with `validate_semantics()`. Registry: 1 interface contract, 4 API decisions, 1 forbidden pattern.
- **ADR-0004 — 存檔系統原子寫入與遷移執行模型** (`docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md`) — **Proposed**, 2026-08-18. Swappable `SaveIOBackend` abstraction (sync-blocking implementation today) confining `save-system.md` Open Question 9's unresolved console-SDK dependency to one file; Core Rules #14's locked six-step atomic-replace sequence including Step 0 branch logic; stepped migration state machine via `await scene_tree.process_frame`, reusing ADR-0001's verified cross-frame lifecycle constraint; single-entry/single-release per-slot reentrancy lock (the only way to guarantee unconditional release given GDScript has no `try`/`finally`). **Coverage of the 30 `TR-save-*` requirements independently re-derived by the 2026-08-18 round-2 `/architecture-review`: 22 covered, 7 partial, 1 gap (`TR-save-030`, cloud-save sync) — the earlier "completes all 30" claim did not hold.** Registry: 1 state-ownership, 1 interface contract, 4 API decisions, 1 forbidden pattern。**2026-08-19 銜接缺口修訂(不改動任何機制)**:C1 —— 本 ADR **接下** `TOKEN_TIMEOUT_MS` 的定值責任(機制六新增推導規則,Validation Criteria 新增版本連動測試;registry 新增 api decision `token_timeout_ms_ownership`);C6 —— `Related Decisions` 補回指 ADR-0005 機制十一並寫明游標交接義務歸**呼叫方**而非存檔系統;**另修正該節殘留的第四處「`TR-save-*` 全數覆蓋」過度宣稱**(`1c3d5d0` 只改了第 27/421 兩行,漏改此處),現與 22/7/1 一致。**2026-08-21 事實層修訂(零決策內容,不改任何機制、簽章或風險評級)**:第七輪點名的 5 處 `@abstract func ...: pass` 改**裸簽章**,並**連同根因的第 71 行指示句一起改**(該句原本明文要求沿用參考庫「冒號 + `pass`」形式,只刪症狀不改指示句,下一個實作者會照著加回來 —— 與 ADR-0005 第四次修訂同一修法);VR **#6/#6a 關閉、新增 #6b**(間接構造路徑未查證);機制一新增「抽象基底以字面 `ClassName.new()` 構造是**編譯期**錯誤」,**明文限定範圍**在直接構造這一條路徑上。**證據為當日新跑的探針 E**(`prototypes/xcheck-round7-2026-08-20/`,exit 0):裸簽章已對 **8 種**回傳型別各有獨立 `COMPILED OK` 證據,且**機制一那整段的完整組合已逐字編譯通過**(`bool`×4 + `Variant`×1 —— 第 91 行的 `-> Variant` 先前不在已測五種之內,屬外推),具體子類別完整實作五方法後可實例化、`-> Variant` 多型覆寫兩分支皆正常、**含透過抽象基底靜態型別的多型呼叫**。**Step 5.5 單軌 `godot-specialist` 覆核零 BLOCKING**,但抓出 3 項可行動:草稿漏處理 registry `why:` 欄那組會因刪行而位移的行號(已改為描述性說明並明說為何不留行號)、「結構保證」宣稱**超出已驗證範圍**(已收窄 + 新增 VR #6b)、以及一項**範圍外新發現** —— ADR-0003:350 是「`TR-save-*` 全數覆蓋」的**第五處**,且是唯一不在 ADR-0004 檔內者,而第五輪曾宣稱「四處全數清除」(**那個全稱宣稱的定義域只涵蓋 ADR-0004 自己**)。協調者另自行抓到**第六處**:`design/gdd/systems-index.md:4` 的「涵蓋全部 24 項 `TR-affinity-*`」,與第七輪的 21/3/0 矛盾 —— 該行的 `TR-save-*` 部分反而已修正,**同一行只被修了一半**。第五、六處皆於本次一併關閉。**registry 不新增條目,維持 81 項。涵蓋分佈不自陳,待第八輪。**
- **ADR-0005 — 單一游標/高亮狀態系統:裝置權威輸入架構** (`docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`) — **Proposed**, 2026-08-18. Closes the round-2 `/architecture-review`'s **sole FAIL cause** (19/19 uncovered, Foundation layer). Autoload thin shell (`CursorStateHost`) as lifetime host + dependency-injected `CursorState` core — satisfies the GDD's cross-screen lifetime requirement without needing an exception to ADR-0002's `autoload_singleton_for_testable_data_layers` ban. Full-frame `_input()` buffering with arbitration in `_process()` (because `process_priority` governs `_process` only, never `_input()` dispatch); four-actor priority ladder −100/0/50/100 making the ≤1-frame handoff a same-frame guarantee. Device classification by `InputEvent` subclass, never `.device` — structural immunity to 4.7's device-ID renumbering. Explicit suspend flag instead of `SceneTree.paused` (the GDD's own AC-60 establishes non-pausing surfaces exist). One Autoload-owned `CanvasLayer` resolves **both** the ownerless per-device idle indicator (TR-cursor-016) and the self-drawn continuous-alpha carrier (TR-cursor-017). Frozen mouse-reclaim sub-mechanism isolated behind a swappable `MouseReclaimPolicy` — mirroring ADR-0004's `SaveIOBackend` treatment of OQ-9. **Self-declared coverage: 16 of 19 complete, 3 partial (`TR-cursor-009`/`-010`/`-011`, all inside the user-frozen sub-mechanism) — explicitly does NOT claim 19/19**, pending independent `/architecture-review`. Registry (as originally written 2026-08-18): 3 state-ownership, 2 interface contracts, 5 API decisions, 4 forbidden patterns. **2026-08-19 round-3 `/architecture-review` independently re-derived this to 11 complete / 8 partial / 0 gaps (overturning the self-claim), found two BLOCKING defects (F1, F5) plus F2/F3/F4 and N1–N4 (9 items total); `/architecture-decision` revised ADR-0005 the same day to address all 9** — adding a fifth `process_priority` actor and a downstream confirm-read constraint (F1), closing two deterministic bugs in the suspend/resume path (F5), reworking the `MouseReclaimPolicy` interface and adding a presentation-layer smoother (F2/F3/F4), and adding action-class classification, `_notification()` timing verification, unregistered-surface cursor-visibility handling, and a signal-push+reentrancy-guard model for downstream updates (N1–N4). Registry after the revision: 3 state-ownership, 4 interface contracts, 7 API decisions, 6 forbidden patterns (2 existing API decisions revised in place). **2026-08-19 第四輪 `/architecture-review` 獨立重推該修訂為 13 完整 / 6 部分 / 0 缺口(第三輪 11/8)——9 項中 6 項完整關閉,但 F1 只關一半、F3 修法引入新違反,並新增 R4-1~R4-7 共 7 項發現與 `TR-cursor-015` 兩項落差(R4-2 為 BLOCKING 編譯期錯誤:`diagnostic_seed_position()` 寫在抽象基底卻讀只宣告於子類別的 `_seed`;R4-1/R4-3 視同 BLOCKING)。同日 `/architecture-decision` 第二次修訂處理全部 9 項**——`arbitrate_frame()` 拆為 `arbitrate_device_authority()`(−100)與 `apply_buffered_navigation()`(**新增 −25 子節點 `CursorNavigationApplier`**),定序自 1&3→2→4 改為與 GDD 逐步對齊的 1→2→3→4(R4-1);`diagnostic_seed_position()` 改標 `@abstract`(R4-2);呈現層平滑器改為**上升立即同步、只對下降限速**(R4-3);明文區分公開入口與不掛閘門的私有 `_write_target_internal()`(R4-4);`ui_*` action 改為明文三分割 + 載入期 `UI_ACTION_UNCLASSIFIED` 完整性驗證(R4-5);刪除未查證的 `call_deferred()` 路線(R4-6);多角色系統節點拆分規則,**部分修正第四輪採納的修法方向**(R4-7);甲/乙分支補 `SURFACE_HANDOFF` 重置、丙分支改回 GDD 的條件式沿用(`TR-cursor-015`)。**另處理三項本次核對出的新事實**:`ResetTrigger` 四個觸發點中 (a)(b)(d) 三者原本零呼叫點;`CursorState` 取不到滑鼠座標(建構子新增 `mouse_position_provider: Callable`);Consequences 殘留的舊自陳「19 項全部有機制支撐」已刪除。Registry 因此再新增 3 forbidden + 就地修訂 7 項,ADR-0005 佔 23 項(3/4/7/9)。**涵蓋分佈依舊不自陳——待第五輪獨立 `/architecture-review`。** **2026-08-19 第五輪 `/architecture-review` 獨立重推第二次修訂**:判定 CONCERNS(130 項需求 **68 ✅ / 30 ⚠️ / 32 ❌**),游標系統 **15 完整 / 4 部分 / 0 缺口**;第四輪 9 項中**完整關閉 8 項**,並新增 R5-1~R5-6 與專家發現 S-1~S-5 共 11 項,其中 **R5-1 為 BLOCKING**(`TR-cursor-015` 乙分支的 `SURFACE_HANDOFF` 沒有任何合法呼叫路徑,三種讀法全部不成立,需新增介面面)。**C1/C3/C6 全部關閉——五輪來第一次零懸置銜接缺口**;registry 首次逐節對帳零落差。詳見 `docs/architecture/architecture-review-2026-08-19-round5.md`。**同日 `/architecture-decision` 第三次修訂(約定為最後一次全面修訂)處理全部 11 項,並於寫入前先跑 `godot-specialist` Step 5.5 覆核(使用者明文授權)——該覆核判定 R5-1 的初版修法「只寫了骨架」,額外抓出 6 項**:(A) 兩條 reset 路徑未明文互斥會造成乙分支雙重重置;(B) 私有層的 `handoff_reset: bool` 是與公開層剛否決的同一個 boolean trap(GDScript 無呼叫端具名引數)→ 改用 `TargetResetPolicy` enum;(2b) `handoff_after_mount()` 的前置驗證無處可放 → 新增 `_validate_target_writable()`;(D) `reseed_reclaim_on_focus_regained()` 的閘門歸屬未定案 → 納入第七個掛閘門入口;(F) 已註冊表面的根節點型別從未約束,而機制十四整套只對 `Control` 有意義;(G) `Callable.is_valid()` 對 lambda 隱式捕獲 `self` 的偵測行為未查證,而 S-1 的防禦押在它上面。**修法要點**:R5-1 補完私有路徑地圖(1 條擴為 4 條)、新增乙分支專用入口 `handoff_after_mount()`,並一併關閉「甲分支呼叫公開 `mark_pending_reresolve()` 會被自己的閘門鎖死」這項與 R4-4 同形狀、第四輪只修了三處中一處的缺陷;**R5-6 與發現 F 以同一修法一次關閉**——機制十三之二的 hover 判定由黑名單**反轉為白名單**,失敗方向從「錯誤顯示原生指標(違反 Core Rules #5 硬性規則)」翻轉為「錯誤隱藏(僅 AC-60 便利性失效)」;R5-3 把 `_reclaim` 收攏為 `CursorState` 單一擁有者(無 getter)並把滑鼠座標的三條路徑收成一條。`CursorState` 公開入口 5 → **7**,私有路徑 1 → **4**。**2026-08-19 第六輪 `/architecture-review`(範圍限縮,依約定只驗這 17 項)**:判定 **CONCERNS、零 BLOCKING** —— **16 項完整關閉,僅 R5-2 只關一半**(規範表已改 −60,但 ADR 內文 7 處、registry 6 處仍寫 −50)。`godot-specialist` 逐一展開七個公開入口 × 四條私有路徑的呼叫圖,確認**沒有任何公開入口需要回頭呼叫另一個公開入口**,R5-1 的核心修法成立。新增 R6-1~R6-13:**R6-1~R6-5 已於該 session 修補**(13 處 −50 殘留、registry YAML 重複鍵〔**高**,會靜默抹掉 c 戳記或使整份 registry 無法載入〕、2 處 `revised:` 欄未同步、涵蓋歷史表落後一次修訂、本檔的 `Mutex` 摘要句與 C3 修訂自相矛盾);**R6-6~R6-13 需改動 ADR 決策內容,待第四次修訂**(R6-6 `handoff_before_unload(surface)` 參數全文零讀取、R6-7 乙分支同值寫入時 `is_valid` 翻轉無訊號涵蓋〔根因:`CursorTarget.equals()` 語意未定案〕、R6-8 機制六⑤「同一節點」與機制十二/十三「兩個元素」矛盾、R6-9「兩兩相異」只管角色不管實例、R6-10 `reseed_reclaim_on_focus_regained()` 掛閘門的反方向失敗未討論、R6-11 `_safe_mouse_position()` fallback 製造靜默凍結、R6-12 第五輪的 `add_child()` 前設優先序建議掉件、R6-13 第二張登記表共用 enum 且無自動反登記)。**模式警示第四次一致:9 項新發現中 7 項出自第三次修訂自身** —— Step 5.5 那道關卡有效但不充分,專家建議下次修法的自問改為「這個修法會不會讓某個既有簽章、既有正交性宣告變得不成立」。****2026-08-20 第七輪 `/architecture-review` 已完成該推導(第三次修訂後首次):19 項 `TR-cursor-*` 為 12 完整 / 7 部分 / 0 缺口**(第五輪 15/4/0)。⚠️ **下降不是 ADR 退步** —— 第五輪的 15/4/0 是在 R6-6~R6-13 被發現之前算的,第六輪範圍限縮未重推,而第四次修訂至今未執行、**8 項全部仍開**(專家逐項讀現行檔案並附行號證據)。`-008`(R6-9,「兩兩相異」只管角色不管實例)、`-010`(R6-10,閘門反方向失敗)、`-013`(R6-7,`equals()` 是否納入 `is_valid` 未定案)三項由 ✅ 降 ⚠️;`-015`(R6-6+R6-7)、`-017`(R6-13)維持 ⚠️ 但成因已換。**另 ADR-0004/0005 共 13 處 `@abstract func ...: pass` 為已實測的編譯期錯誤**(ADR-0004 五處、ADR-0005 八處),外加兩處明文指示句 —— 根因 `current-best-practices.md` 的錯誤範例已於第七輪修正。詳見 `docs/architecture/architecture-review-2026-08-20-round7.md`。** 詳見 `docs/architecture/architecture-review-2026-08-19-round6.md`。**2026-08-21 第四次修訂已執行**:R6-6~R6-13 八項全數處理 + 五項事實層(8 處 `@abstract func ...: pass` 改裸簽章**並改掉根因的指示句**、`Constraints` 的「無 Godot 執行環境」刪除、VR #12/#15 標已查證、**C7 的另一半由本 ADR 自己認定依賴層 B**、R6-1 的 −50 計數落差以 `git log` 關閉〔第六輪的「4 處」是計數失誤,現行精確 3 處,`−50` 是 U+2212 全角減號〕)。**機制實質變更**:刪懸空 `surface` 參數;`equals()` 定案只比表面 + `id`、`is_valid` 翻轉納入 `target_changed()`;CanvasLayer 下**拆三節點**(`modulate.a` 只掛自繪游標);「兩兩相異」限定**角色之間**;閘門反方向失敗改記旗標;provider 失效升為**系統層降級**;`process_priority` 須在 `add_child()` **之前**;第二張登記表拆 `ExceptionRegisterResult` + `tree_exited` 自動反登記。**私有路徑 4 → 6。** **Step 5.5 雙軌覆核回傳 2 BLOCKING + 11 非阻塞,並關閉草稿自標的全部 3 處「需覆核」**:B-1(變更六「寫了行為沒寫接線」,`_safe_mouse_position() -> Vector2` 無管道告知呼叫方失效)、B-2(「四條私有路徑」的宣告**至少 7 處**必然失效,協調者另發現其中一處**修訂前就已與另一處不一致**)。**另一項自我修正**:VR #15 初稿誤判「未查證」,量測其實在更早那批 spike 裡 —— 檢索紀律教訓已寫進 ADR 的 Constraints。Registry 78 → **81**,ADR-0005 佔 **29** 項。**涵蓋分佈不自陳,待第八輪。**

> **Registry 累計(2026-08-21 更新,逐節實測)**:**81** 項立場(10 state-ownership、11 interface contracts、**29** API decisions、**31** forbidden patterns)。2026-08-21 ADR-0005 第四次修訂新增 3 項(1 api `cursor_process_priority_before_add_child`、2 forbidden)+ 就地修訂 `cursor_target_write`(`signal_signature` 由 5 個公開入口改為 **7**、私有路徑 FOUR → **SIX**、`handoff_before_unload` 刪 `surface` 參數),**ADR-0005 佔 29 項**。以下為前次紀錄:**78** 項立場(10、11、**28**、**29**)。2026-08-21 ADR-0002 第四次修訂新增 9 項(5 api、4 forbidden)+ 就地修訂 2 項(interface `affinity_delta_log`、api `affinity_pair_key_representation`),**ADR-0002 佔 22 項**。以下為前次紀錄:**69** 項立場(10 state-ownership、11 interface contracts、23 API decisions、**25** forbidden patterns)。2026-08-20 ADR-0002 引擎行為實機驗證修訂新增 1 項 forbidden pattern(`raw_variant_subscript_into_typed_container`)並就地修訂 `affinity_delta_log` 的 `interface` 欄(第 87 行,型別由巢狀改為包裝類別),ADR-0002 佔 **13** 項。以下為前次紀錄:**68** 項立場(10 state-ownership、**11** interface contracts、23 API decisions、**24** forbidden patterns),ADR-0005 佔 **26** 項(3 state / 5 interface / 7 api / 11 forbidden)。第三次修訂新增 3 項(1 interface `cursor_native_pointer_exception_registration`、2 forbidden `external_access_to_cursor_reclaim_instance` / `independent_ifs_for_cursor_target_reset_policy`)+ 就地修訂既有 8 項(皆 `revised: 2026-08-19c`,不計入新增數)。以下為前次紀錄:**65** 項立場(10 state-ownership、10 interface contracts、**23** API decisions、**22** forbidden patterns)——原 55 項(14 項為 ADR-0005 首版新增)→ 第一次修訂 ADR-0005 新增 6 項(2 interface / 2 api / 2 forbidden)+ 就地修訂 3 項既有條目 = 61 項 → **第二次修訂新增 4 項**(1 api `token_timeout_ms_ownership`〔擁有者為 ADR-0004,非 ADR-0005〕、3 forbidden `public_cursor_write_entry_calling_another` / `call_deferred_for_cursor_retarget_deferral` / `single_node_for_nonadjacent_cursor_actor_roles`)**+ 就地修訂既有 7 項**(1 state / 2 interface / 4 api,皆 `revised: 2026-08-19b`,不計入新增數)= **65 項**。ADR-0005 佔 23 項(3 state / 4 interface / 7 api / 9 forbidden)。其中 3 項 forbidden pattern 為 2026-08-18 第二輪 `/architecture-review` 補登的**專案級身分/範圍裁決**(`rng_in_combat_settlement`、`networking_features`、`procedural_terrain_generation`,對應 `TR-concept-012`/`-014`)——來源為 `game-concept.md` 而非任何 ADR,故 `adr:` 欄記為 `none` 並附 `gdd:` 欄,是 registry 檔頭「`adr:` 為權威來源」慣例的明文例外。全部 5 份 ADR 皆為 `Proposed`,無任何一份達 `Accepted`——依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。**2026-08-18 第二輪 `/architecture-review` 已獨立驗證完畢**:判定 FAIL(130 項需求 50 ✅ / 24 ⚠️ / 56 ❌);無阻塞級跨 ADR 衝突,但有 5 項銜接缺口待調和(C1 `TOKEN_TIMEOUT_MS` 無人擁有、C2 驗證器回傳型別名不一致、C3 執行緒條件已解未回傳、C4 `write_temp()` 底層呼叫未拍板、C5 措辭超出上游驗證範圍);棄用 API 零命中。唯一硬阻塞為單一游標/高亮狀態系統 19 項需求零涵蓋。詳見 `docs/architecture/architecture-review-2026-08-18-round2.md`。**該硬阻塞已由同日撰寫的 ADR-0005 處理**(自陳 16 完整 / 3 部分)。**2026-08-19 第三輪 `/architecture-review` 獨立重推,推翻該自陳為 11 完整 / 8 部分 / 0 缺口**,並判定 F1/F5 為 BLOCKING、F2/F3/F4 為高/中、N1~N4 為額外發現,共 9 項待修訂,詳見 `docs/architecture/architecture-review-2026-08-19.md`。**同日 `/architecture-decision` 已修訂 ADR-0005 處理全部 9 項**。**2026-08-19 第四輪 `/architecture-review` 獨立重推該修訂**:判定 CONCERNS(130 項需求 65 ✅ / 33 ⚠️ / 32 ❌),游標系統 13 完整 / 6 部分 / 0 缺口;9 項待修訂中 6 項完整關閉(F5/F2/F4/N1/N2/N4),**F1 只關一半、F3 修法引入新違反**,並新增 7 項發現 R4-1~R4-7 與 `TR-cursor-015` 的兩項落差(R4-2 為 BLOCKING 編譯期錯誤,R4-1/R4-3 視同 BLOCKING)。**本輪抓到的模式與第三輪不同:是修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為第一次修訂新產生)。詳見 `docs/architecture/architecture-review-2026-08-19-round4.md`。**同日 `/architecture-decision` 第二次修訂 ADR-0005 處理全部 9 項,並一併關閉自第二輪起懸置的跨 ADR 銜接缺口 C1/C3/C6**(C1 `TOKEN_TIMEOUT_MS` 定值責任由 ADR-0004 接下;C3 ADR-0002 的 `Mutex` 保留為縱深防禦並明文交叉引用 ADR-0004 已把條件判為「否」;C6 ADR-0004 補回指 ADR-0005 機制十一並寫明義務歸屬)。**另修正 ADR-0004 `Related Decisions` 殘留的第四處「`TR-save-*` 全數覆蓋」過度宣稱**(`1c3d5d0` 只改了第 27/421 兩行)。第二次修訂後的涵蓋判定已由**第五輪**(15/4/0)、第三次修訂後的判定已由**第七輪**(12/7/0)各自獨立重新推導完畢。**目前最新的權威數字是 2026-08-20 第七輪:130 項需求 64 ✅ / 34 ⚠️ / 32 ❌**(好感度 21/3/0、存檔 22/7/1、游標 12/7/0、戰棋 5/13/25、game-concept 4/4/6)。判定 **CONCERNS**;三個 Foundation 系統合計 73 項**仍只有 1 項缺口**(`TR-save-030`)。**但三份 ADR 各帶 BLOCKING 級項目,且沒有一項屬於涵蓋缺口** —— 全部是已寫下的決策內容與已實測的引擎現實不符:ADR-0002 兩項(R7E-6 死碼、R7E-4 enum 參數靜默轉換,後者已由探針實機確認並連帶推翻機制四「`INVALID_PAIR`/`INVALID_SOURCE` 理論上不可達」)、ADR-0004/0005 共 13 處 `pass` 主體、ADR-0003 第 17 行與 ADR-0005 第 121 行殘留已被推翻的「無 Godot 執行環境」宣稱。**新增跨 ADR 銜接缺口 C7**(ADR-0002 單方面替 ADR-0005 記帳一項未查證項,而 ADR-0005 全文對此零字 —— 與第三輪的 C6 同形狀;C1~C6 於第五輪剛全部關閉)。詳見 `docs/architecture/architecture-review-2026-08-20-round7.md`。

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
