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

**權威清單在 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節,連同每項的
完整理由(`why:` 欄)。本節不複述** —— 2026-08-21 實測發現散文複本已與登記表脫節
(散文寫「其餘 26 項」實際 27 項、「ADR-0005 共 11 項」實際 12 項),
且登記表的 `why:` 欄比散文摘要詳細數倍。複述只會製造漂移面。

**逐節實測數(2026-08-21)**:

| 來源 | 項數 |
|---|---|
| 專案級 —— 不掛任何 ADR | 4 |
| ADR-0001 戰棋查詢 | 5 |
| ADR-0002 好感度數值池 | 8 |
| ADR-0003 存檔序列化格式 | 1 |
| ADR-0004 存檔原子寫入 | 1 |
| ADR-0005 游標裝置權威 | 12 |
| **合計** | **31** |

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

第 4 項專案級禁令是 **`abstract_func_with_body`**(抽象方法宣告必須是裸簽章,不可帶
`pass` 主體 —— 帶主體是**編譯期錯誤**,已實機驗證)。它 `adr: none`,因為根因在參考庫的
錯誤範例而非任一 ADR;ADR-0004/0005 兩份的症狀已於 2026-08-21 修畢,該條目仍
`active` 作為**前瞻性禁令**。

其餘 27 項由 ADR-0001~0005 各自推導,**一律查登記表,不在此複述**。
查法:`docs/registry/architecture.yaml` 的 `forbidden_patterns` 節,每項都有
`pattern:`(名稱)、`adr:`(來源文件)、`why:`(完整理由與實測依據)。
## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
**修訂歷史全文在 `docs/architecture/adr-revision-history.md`。** 本節只記現況。
2026-08-21 起本節不再累積修訂敘述 —— 該檔每次對話開場載入,歷史屬按需查閱。

**核准門檻**:`docs/architecture/adr-acceptance-criteria.md`(白話,含五個必要條件與
五項明確不阻擋核准的事)。**立場登記表(權威來源)**:`docs/registry/architecture.yaml`,
目前 **85** 項(10 state-ownership、11 interface contracts、29 API decisions、35 forbidden patterns)。
⚠️ 本行歷來落後於登記表(2026-08-25 修正:原寫 81 項/31 forbidden,漏掉 ADR-0003 上一輪新增的 4 項)。
**數字有疑義時一律以 `docs/registry/architecture.yaml` 為準,本行是摘要不是來源。**

✅ **2026-08-25:ADR-0002、ADR-0003 兩份已 `Accepted`**(管理者同批裁決;0003 的核准條件五就是
0002 已核准,故必須同一次動作)。**ADR-0001、0004、0005 三份仍為 `Proposed`。**
依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋 —— 這擋的是 `src/` 正式開發,
**不擋 `prototypes/` 的驗證性試作**。`/story-readiness` 已於同日補上遞迴追 `Depends On` 鏈與循環偵測,
因此「已核准的壓在草案上」不再會被自動放行。

| ADR | 主題 | 最近動作 | 現在卡在什麼 |
|---|---|---|---|
| 0001 | 戰棋查詢介面原子性契約 | 2026-08-18 建立,**從未修訂、從未驗證** | ⚠️ 唯一未被檢查過的一份。它的紀錄乾淨是因為沒人看過,不是因為它正確(見核准門檻第六節) |
| 0002 | 好感度數值池資料結構與並發契約 | ✅ **2026-08-25 `Accepted`**(收斂批次補完三個未宣告型別、關閉 VR#9/#11/#12) | 可開始寫正式程式碼。剩下的皆不阻擋:證據搬家、登記表三項提案、VR#4/#7 未量測。第八輪獨立審查優先查核點:第一輪覆核後才產生的兩項修正、`can_write()` 簽章、`pair_of()` 保護等級 |
| 0003 | 存檔系統序列化格式與型別安全 | ✅ **2026-08-25 `Accepted`**(2026-08-24 六組必修已執行完畢;2026-08-25 再修三項並修掉參考庫根因) | 可開始寫正式程式碼。剩下的皆不阻擋:技術總監列的 8 項(B-1~B-8,B-6 已修)、延後項見 `adr-0003-deferred-to-implementation.md`(41 項)。⚠️ 歷史教訓保留:2026-08-21 探針曾推翻其全文 18 處呼叫寫法 |
| 0004 | 存檔系統原子寫入與遷移執行模型 | 事實層修訂 2026-08-21(零決策變更) | 待第八輪。已知缺口 1 項:雲端存檔同步無人擁有 |
| 0005 | 單一游標/高亮狀態系統:裝置權威輸入架構 | 第四次修訂 2026-08-21 | 待第八輪。1609 行、四次修訂,是否凍結未決 |

**最新權威涵蓋數字(2026-08-20 第七輪)**:130 項需求 64 ✅ / 34 ⚠️ / 32 ❌。
三個 Foundation 系統合計 73 項**只有 1 項缺口**。判定 CONCERNS。
**第八輪從未執行** —— 上表「待第八輪」全部指同一次尚未進行的審查。

**跨文件銜接缺口**:C1~C6 已於第五輪全部關閉;**C7 仍開**(ADR-0002 單方面替 ADR-0005
記帳一項未查證項,而 ADR-0005 已於第四次修訂自行認定,尚未對帳)。

**重複失誤紀錄**:`docs/consistency-failures.md`(七種模式 A~G,其中「修東西反而修出新
問題」已第九次)。撰寫或修訂 ADR 前請先讀該檔。

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
