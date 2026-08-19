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

- **Framework**: GUT (Godot Unit Test)
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->

**權威清單在 `docs/registry/architecture.yaml` 的 `forbidden_patterns` 節(目前 17 項)。**
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

其餘 14 項為 ADR-0001~0005 各自推導出的實作級禁令。ADR-0001~0004 的 10 項:節點樹推導佔位、
動畫驅動邏輯狀態、結算路徑 `call_deferred()`、回傳內部容器參照、依賴容器迭代順序、
可測試資料層用 Autoload、可變容器當 Dictionary 鍵、enum 位置索引字串轉換、
Resource 承載存檔 payload、取鎖與釋放之間提前 return。**ADR-0005 新增 4 項(游標系統)**:
游標 Autoload 薄殼加邏輯、用 `_unhandled_input()` 做裝置權威裁定、讀取 `InputEvent.device` 
裝置 ID、已註冊游標表面使用原生 Control hover/focus(注意:此項需**兩個**條件,`focus_mode = 
FOCUS_NONE` 單獨不足——它不關 Control 主題內建的滑鼠 hover 管線)。詳見 registry 各條的 `why:` 欄。

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- **ADR-0001 — 戰棋查詢介面原子性契約** (`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`) — **Proposed**, 2026-08-18. Snapshot identity via monotonic `board_version` stamp (incremented only at committed settlement boundaries) rather than deep-copied board state; `settlement_in_progress` re-entrancy gate with reject-on-input; sparse `Dictionary[Vector2i, int]` logical occupancy. Carries the architecture-grade mechanisms behind `design/gdd/tactical-combat-system.md` Core Rules #10 b/c and #11. Registered stances live in `docs/registry/architecture.yaml` (3 state-ownership, 2 interface contracts, 3 API decisions, 5 forbidden patterns).
- **ADR-0002 — 好感度數值池資料結構與並發契約** (`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`) — **Proposed**, 2026-08-18. Per-pair indexed `Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` satisfying the GDD-locked `O(n_p + m)` query contract; campaign-tick marker list and death-marker table as structurally independent stores; monotonic-int serialization-lifecycle tokens under unconditional `Mutex` (the project's only declared thread-safety obligation); dependency-injected ownership, not Autoload. Covers all 24 `TR-affinity-*` requirements of `design/gdd/affinity-data-pool.md`. Registry: 3 state-ownership, 2 interface contracts, 4 API decisions, 3 forbidden patterns.
- **ADR-0003 — 存檔系統序列化格式與型別安全** (`docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`) — **Proposed**, 2026-08-18. Resolves `save-system.md` Open Question 3: binary Variant serialization via `var_to_bytes()`/`bytes_to_var(bytes, false)`, rejecting `Resource`/`.tres` and JSON — this makes Core Rules #9's deserialization type whitelist *structurally unnecessary* (no custom `Object` can be produced) rather than app-maintained, and moots Open Question 4. Layered per-block `PackedByteArray` buffers enabling the manifest-only read path; two-layer SHA-256 hash chain in canonical `source_id` order. Retrofits ADR-0002 with `validate_semantics()`. Registry: 1 interface contract, 4 API decisions, 1 forbidden pattern.
- **ADR-0004 — 存檔系統原子寫入與遷移執行模型** (`docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md`) — **Proposed**, 2026-08-18. Swappable `SaveIOBackend` abstraction (sync-blocking implementation today) confining `save-system.md` Open Question 9's unresolved console-SDK dependency to one file; Core Rules #14's locked six-step atomic-replace sequence including Step 0 branch logic; stepped migration state machine via `await scene_tree.process_frame`, reusing ADR-0001's verified cross-frame lifecycle constraint; single-entry/single-release per-slot reentrancy lock (the only way to guarantee unconditional release given GDScript has no `try`/`finally`). **Coverage of the 30 `TR-save-*` requirements independently re-derived by the 2026-08-18 round-2 `/architecture-review`: 22 covered, 7 partial, 1 gap (`TR-save-030`, cloud-save sync) — the earlier "completes all 30" claim did not hold.** Registry: 1 state-ownership, 1 interface contract, 4 API decisions, 1 forbidden pattern.
- **ADR-0005 — 單一游標/高亮狀態系統:裝置權威輸入架構** (`docs/architecture/adr-0005-cursor-device-authority-input-architecture.md`) — **Proposed**, 2026-08-18. Closes the round-2 `/architecture-review`'s **sole FAIL cause** (19/19 uncovered, Foundation layer). Autoload thin shell (`CursorStateHost`) as lifetime host + dependency-injected `CursorState` core — satisfies the GDD's cross-screen lifetime requirement without needing an exception to ADR-0002's `autoload_singleton_for_testable_data_layers` ban. Full-frame `_input()` buffering with arbitration in `_process()` (because `process_priority` governs `_process` only, never `_input()` dispatch); four-actor priority ladder −100/0/50/100 making the ≤1-frame handoff a same-frame guarantee. Device classification by `InputEvent` subclass, never `.device` — structural immunity to 4.7's device-ID renumbering. Explicit suspend flag instead of `SceneTree.paused` (the GDD's own AC-60 establishes non-pausing surfaces exist). One Autoload-owned `CanvasLayer` resolves **both** the ownerless per-device idle indicator (TR-cursor-016) and the self-drawn continuous-alpha carrier (TR-cursor-017). Frozen mouse-reclaim sub-mechanism isolated behind a swappable `MouseReclaimPolicy` — mirroring ADR-0004's `SaveIOBackend` treatment of OQ-9. **Self-declared coverage: 16 of 19 complete, 3 partial (`TR-cursor-009`/`-010`/`-011`, all inside the user-frozen sub-mechanism) — explicitly does NOT claim 19/19**, pending independent `/architecture-review`. Registry (as originally written 2026-08-18): 3 state-ownership, 2 interface contracts, 5 API decisions, 4 forbidden patterns. **2026-08-19 round-3 `/architecture-review` independently re-derived this to 11 complete / 8 partial / 0 gaps (overturning the self-claim), found two BLOCKING defects (F1, F5) plus F2/F3/F4 and N1–N4 (9 items total); `/architecture-decision` revised ADR-0005 the same day to address all 9** — adding a fifth `process_priority` actor and a downstream confirm-read constraint (F1), closing two deterministic bugs in the suspend/resume path (F5), reworking the `MouseReclaimPolicy` interface and adding a presentation-layer smoother (F2/F3/F4), and adding action-class classification, `_notification()` timing verification, unregistered-surface cursor-visibility handling, and a signal-push+reentrancy-guard model for downstream updates (N1–N4). Registry after the revision: 3 state-ownership, 4 interface contracts, 7 API decisions, 6 forbidden patterns (2 existing API decisions revised in place). Coverage after this revision is undeclared by design — pending a fourth, independent `/architecture-review`.

> **Registry 累計(2026-08-19 更新)**:**61** 項立場(10 state-ownership、**10** interface contracts、**22** API decisions、**19** forbidden patterns)——原 55 項(14 項為 ADR-0005 首版新增)之上,2026-08-19 `/architecture-decision` 修訂 ADR-0005 時再新增 6 項(2 interface / 2 api / 2 forbidden),並就地修訂既有 2 項 api_decisions(不計入新增數,`revised: 2026-08-19`)。其中 3 項 forbidden pattern 為 2026-08-18 第二輪 `/architecture-review` 補登的**專案級身分/範圍裁決**(`rng_in_combat_settlement`、`networking_features`、`procedural_terrain_generation`,對應 `TR-concept-012`/`-014`)——來源為 `game-concept.md` 而非任何 ADR,故 `adr:` 欄記為 `none` 並附 `gdd:` 欄,是 registry 檔頭「`adr:` 為權威來源」慣例的明文例外。全部 5 份 ADR 皆為 `Proposed`,無任何一份達 `Accepted`——依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。**2026-08-18 第二輪 `/architecture-review` 已獨立驗證完畢**:判定 FAIL(130 項需求 50 ✅ / 24 ⚠️ / 56 ❌);無阻塞級跨 ADR 衝突,但有 5 項銜接缺口待調和(C1 `TOKEN_TIMEOUT_MS` 無人擁有、C2 驗證器回傳型別名不一致、C3 執行緒條件已解未回傳、C4 `write_temp()` 底層呼叫未拍板、C5 措辭超出上游驗證範圍);棄用 API 零命中。唯一硬阻塞為單一游標/高亮狀態系統 19 項需求零涵蓋。詳見 `docs/architecture/architecture-review-2026-08-18-round2.md`。**該硬阻塞已由同日撰寫的 ADR-0005 處理**(自陳 16 完整 / 3 部分)。**2026-08-19 第三輪 `/architecture-review` 獨立重推,推翻該自陳為 11 完整 / 8 部分 / 0 缺口**,並判定 F1/F5 為 BLOCKING、F2/F3/F4 為高/中、N1~N4 為額外發現,共 9 項待修訂,詳見 `docs/architecture/architecture-review-2026-08-19.md`。**同日 `/architecture-decision` 已修訂 ADR-0005 處理全部 9 項**——修訂後的涵蓋判定須由全新 session 的第四輪 `/architecture-review` 獨立重新推導,尚未執行。

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
