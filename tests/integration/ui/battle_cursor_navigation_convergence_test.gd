## Story 008 (`production/epics/tactical-combat/story-008-cursor-navigation-convergence.md`)
## — convergence of the normal move/attack cursor path onto [CursorStateHost].
##
## ═══════════════════════════════════════════════════════════════════════════
## 🔴 ENGINE-VERIFIED FINDINGS (this session, real BattleScreen.tscn / real
## CursorStateHost Autoload / real CursorState — see each test's own body).
## Coordinator ruling (2026-10-13): register/unregister anchor moves from
## `unit_selected`/`selection_cleared` (prework, now acknowledged wrong) to
## the `CardPlaySession` open/closed boundary — but "the old plan was wrong"
## does not make "the new plan is right" automatically true (2026-10-12
## registered failure shape: right verdict, wrong reasoning, acted on without
## re-checking). The three items below are that re-check, in the ordered
## priority the coordinator specified.
## ═══════════════════════════════════════════════════════════════════════════
##
## 1. "一次走兩格" (one press moves the cursor twice) — CONFIRMED, engine-run.
##    See `test_registering_board_tile_on_normal_path_causes_two_independent_cursor_movements_per_press`.
##    One real `ui_right` InputEventKey, delivered once to the screen's own
##    `_input()` and once to the real `CursorStateHost` Autoload's real
##    `_input()`/`_process()`/`flush_buffered_navigation()` (both "the same
##    event reaches two nodes" per ADR-0005's own "dispatch order is TREE
##    order" note — simulated as two direct calls here, not a real engine
##    event-loop tick), moves BOTH `instance._cursor_cell` (via
##    `_handle_directional()`'s own untouched `clamp_cursor_move()`) AND the
##    Autoload's own `_state.get_current_target()` (via
##    `apply_buffered_navigation()` calling the just-registered
##    `cursor_navigate()`) by exactly one cell EACH, independently, from the
##    SAME single keypress. Confirms the hypothesis exactly as worded: two
##    separate, uncoordinated state variables each move once — not one
##    variable moving by two. This is reproducible TODAY, with zero production
##    code changes, purely by adding the registration the story's AC-1 already
##    asks for.
##
## 2. "未選取任何單位時,游標還能不能動" — CONFIRMED (today's behavior, before
##    any refactor), engine-run. See
##    `test_directional_navigation_can_select_a_non_default_unit_before_any_selection_exists_today`.
##    Using the real `vs01_roster.txt` fixture (`id 1` 甲 at `(0,2)` is the
##    `_ready()`-seeded default; `id 2` 乙 sits one row below at `(0,3)`), one
##    `ui_down` press + one `battle_confirm` press — with
##    `_controller.selected_unit() == -1` the entire time beforehand — moves
##    the cursor onto 乙's tile and selects 乙, not 甲. This is today's
##    UNMODIFIED behavior (`_handle_directional()`'s own direct write, no
##    `CursorStateHost` involvement at all) and is the capability this file's
##    register/unregister-anchor reasoning (§ below) argues must not be lost —
##    this test is the regression lock: if a future change ties BOARD_TILE
##    registration to `unit_selected`/`selection_cleared` as the coordinator's
##    prework originally proposed, THIS test goes red, with a message that
##    says exactly why.
##
## 3. 手把搖桿去抖動 (gamepad stick debounce gap) — PARTIALLY CONFIRMED,
##    engine-run, with one explicit unverified premise. See
##    `test_apply_buffered_navigation_has_no_builtin_debounce_for_repeated_joypad_motion_events`.
##    Feeding the SAME real, InputMap-bound `InputEventJoypadMotion` (bound to
##    a `CursorTypes.NAVIGATION_ACTIONS` entry in this engine's actual
##    InputMap — the test fails loud rather than assuming if none is bound)
##    through `CursorState.arbitrate_device_authority()` +
##    `apply_buffered_navigation()` TWICE in a row (simulating two
##    consecutive frames) moves the target TWICE — confirmed, by direct
##    engine run, that `apply_buffered_navigation()` has NO built-in
##    "already moved this direction, don't move again" debounce the way
##    `_handle_directional()`'s own `_direction_just_pressed()` /
##    `_direction_was_pressed` Dictionary provides for the screen's own path.
##    🔴 UNVERIFIED PREMISE, explicitly not tested here: whether the real
##    engine actually DELIVERS a fresh `InputEventJoypadMotion` for a held
##    stick on every single frame (vs. only on a value change). If it does,
##    this is a real, user-visible bug once the normal path hands
##    `_handle_directional()`'s debounce duty over to the host's pipeline —
##    the cursor would race across the board while a stick is held. If it
##    does not, this code-level gap may never actually manifest. Confirming
##    delivery frequency needs a WINDOWED, non-headless engine probe (an
##    actual joypad or a synthetic `Input.joy_connection_changed` + polling
##    probe) — out of scope for what could be verified this session.
##    🔴 FLAGGED PER THE COORDINATOR'S OWN FRAMING: if the unverified premise
##    holds, this is a gap in ADR-0005 itself (机制四之二 only filters
##    `InputEventKey.echo`), not merely an implementation detail of this
##    story — do not silently patch it inside `battle_screen.gd` alone
##    without flagging ADR-0005's owner.
##    🔴 **2026-10-13 coordinator ruling: this item is MOVED OUT of story-008's
##    scope.** Registered as a candidate gap in ADR-0005 itself, owner not yet
##    assigned — confirming the unverified delivery-frequency premise needs a
##    windowed, non-headless probe, which is a separate work order. No patch
##    code for this item belongs in this story. It DOES still constrain unit
##    3b below (stripping `_handle_directional()`'s self-movement): if the
##    host has no equivalent debounce and the real engine delivers
##    `InputEventJoypadMotion` every held-stick frame, deleting
##    `_direction_just_pressed()` wholesale would make a held gamepad stick
##    race the cursor across the board. Unit 3b must choose EITHER to keep
##    `_direction_just_pressed()`'s debounce (gating whether the event reaches
##    the host's pipeline at all) and delete only the direct `_cursor_cell`
##    WRITE, or to delete the debounce wholesale with an explicit, written
##    reason why the risk above does not apply — whichever is chosen must be
##    stated explicitly in that change, not left implicit.
##
## ═══════════════════════════════════════════════════════════════════════════
## Register/unregister anchor plan (unchanged from last round, still NOT
## implemented — coordinator ruling was "your plan is accepted provisionally,
## verify first", items 1-3 above are that verification; item 4 below,
## `_TargetRetargetActor` reuse for `_handle_mouse_button()`, is explicitly
## QUEUED NEXT, not yet investigated this round per the coordinator's stated
## priority order).
## ═══════════════════════════════════════════════════════════════════════════
##
## `CardPlaySession`'s `_step` state machine (`src/gameplay/cards/
## card_play_session.gd`) makes `is_card_play_in_progress()` change at
## exactly THREE call sites inside `battle_screen.gd`:
##   - FALSE -> TRUE: `_handle_open_hand_pressed()`'s `_controller.open_hand()`
##     success branch (S0 -> S1).
##   - TRUE -> FALSE, site A: same function's `_controller.cancel()` success
##     branch, reached only while `_card_selecting_from_hand` is true
##     (S1 -> S0).
##   - TRUE -> FALSE, site B: `_apply_pending_card_confirm()`'s
##     `_controller.confirm()` success branch (S3 -> S0, a card was played).
## Proposed anchor for the normal path (still unimplemented):
##   - Register BOARD_TILE once in `_ready()`, right after `_controller` is
##     built, seeding the host's target from `_state.position_of(player_ids[0])`
##     — this is what test #2 above locks in as required behavior.
##   - Unregister BOARD_TILE at the FALSE->TRUE site (hand off to card-play
##     BEFORE `_confirm_selected_card()`'s own register call runs later —
##     `CursorSurfaceRegistry.register()` hard-fails `DUPLICATE_TAG_REJECTED`
##     even for the SAME node re-registering an occupied tag, read directly
##     from `cursor_surface_registry.gd:100-106`).
##   - Re-register BOARD_TILE at BOTH TRUE->FALSE sites (reclaim from
##     card-play once it fully closes).
## The existing 4 card-play register/unregister call sites are UNCHANGED by
## this plan.
##
## 🔴 2026-10-13 STATUS UPDATE — unit 3b, points 1/4, 3/4, 4/4 LANDED AND
## ENGINE-GREEN (`_ready()` seeds the host instead of writing _cursor_cell
## directly; `_handle_directional()` no longer self-writes _cursor_cell, kept
## only its debounce loop + `_device.note_pad_input()` for DeviceAuthority's
## own, separate bookkeeping — see that method's own doc comment for why;
## `_update_cursor_visual()`'s KEYBOARD_GAMEPAD branch now reads
## `CursorStateHost.get_current_target()` instead of trusting a stale
## _cursor_cell). Full suite: 1147 test cases, 0 errors, 1 failure (the known,
## pre-existing, approved-red `affinity_phi_provider_test.gd`), 98/98 suites
## and 1147/1147 cases executed. Point 2/4 (`_handle_mouse_button()`) is the
## ONLY direct-write point NOT yet converted — deferred to the next round per
## explicit coordinator instruction, see finding 4 below for what was learned
## about it so far (read, not yet implemented).
##
## 🔴 Manager ruling (2026-10-13, relayed by coordinator): the gamepad-stick
## debounce question (finding #3 above) is DECIDED for now — "先登記不動,等
## 有手把可測再說", with the explicit default for this story: KEEP
## `_handle_directional()`'s existing `_direction_just_pressed()` /
## `_direction_was_pressed` debounce, remove ONLY the cursor write. This is
## EXACTLY what points 1/4, 3/4, 4/4 above already did — no further action
## needed on this question for this story; removing the debounce itself would
## need a windowed, non-headless proof that is explicitly scheduled for later,
## not this story.
##
## ═══════════════════════════════════════════════════════════════════════════
## 4. `_handle_mouse_button()`'s R5-2 constraint — READ (not yet implemented;
##    coordinator cap: if the conclusion is "needs a new actor", stop and
##    report, do not build it).
## ═══════════════════════════════════════════════════════════════════════════
## `CursorState.set_target()`'s doc comment (`cursor_state_host.gd:566-573`)
## requires callers to invoke it from their OWN node's `_process()` at a
## process_priority strictly between -100 and -25 (R5-2), never from
## `_input()`. `_handle_mouse_button()` runs inside `_input()`'s dispatch, so
## it cannot call `set_target()` directly once mouse clicks need to move the
## host's authoritative target.
##
## 🔴 TENTATIVE CONCLUSION (read this round, NOT yet implemented — reading
## happened before the coordinator's "don't touch this yet" instruction
## arrived; recorded here so it is not lost, not acted on early):
## `_TargetRetargetActor` (battle_screen.gd, process_priority -60) is a THIN,
## GENERIC dispatcher — its entire `_process()` body is one line,
## `_owner._apply_pending_target_jump()`. It is NOT itself the card-play jump
## logic; `_apply_pending_target_jump()` (the owner method it calls) is. This
## means the SAME actor instance can almost certainly be reused for the mouse
## case WITHOUT building a second actor: add a second pending-request field
## (e.g. a clicked-cell Vector2i plus a "pending" bool, set by
## `_handle_mouse_button()`) and a second owner method (e.g.
## `_apply_pending_mouse_cursor_retarget()`, calling
## `CursorStateHost.set_target(CursorTarget.make(BOARD_TILE, encoded_id))`),
## called from the SAME `_TargetRetargetActor._process()` right alongside the
## existing `_apply_pending_target_jump()` call — mirroring that method's own
## established "pending flag set in `_input()`-reached code, consumed in
## `_process()` at priority -60" shape exactly. NOT YET IMPLEMENTED OR
## ENGINE-VERIFIED — this is a reading-based plan, not a tested one.
##
## ═══════════════════════════════════════════════════════════════════════════
## 5. 2026-10-13 (THIS ROUND, READ-ONLY) — unit 3b point 2/4 investigation
##    results. Logged per coordinator instruction after this round burned
##    ~20 tool calls / ~140k tokens of reading with ZERO disk output — the
##    coordinator judged the dispatch brief's "first action must be Write"
##    rule did not fit a half-finished, no-skeleton pickup, and asked for a
##    single append instead. NOTHING below is implemented.
##    `src/ui/battle/battle_screen.gd` has ZERO diff from commit `b4c8e6d`
##    this round.
## ═══════════════════════════════════════════════════════════════════════════
##
## 5a. `_TargetRetargetActor` reuse — CONFIRMED, by directly reading its full
##     class body in `battle_screen.gd` (not just grepping for it). The prior
##     round's claim holds exactly as stated: `_process(_delta)`'s entire
##     body is the one line `_owner._apply_pending_target_jump()`.
##     `_init(owner)` sets `process_priority = -60` and stores `_owner` —
##     nothing else. Reuse plan (add a second pending field + a second owner
##     method, call it from the SAME actor's `_process()` right alongside the
##     existing call) is structurally sound and needs no new class/file/node.
##
## 5b. `_update_cursor_visual()`'s SOLE production call site — CONFIRMED by
##     grep (`grep -n "_update_cursor_visual" src/ui/battle/battle_screen.gd`):
##     called from exactly ONE place, inside this screen's OWN `_process()`
##     (process_priority 100, set in `_init()`), immediately after
##     `_device.resolve_frame()`. No call from `_input()`; no other call site
##     anywhere in `src/`. Matches what this file's OWN finding #1 above
##     already discovered the hard way (`instance._process(0.0)` required,
##     not `_update_cursor_visual()` alone, because the MOUSE/
##     KEYBOARD_GAMEPAD branch depends on `_device.current()`, which only
##     `resolve_frame()` — called earlier in the SAME `_process()` tick —
##     updates).
##
## 🔴 5c. THE DISPATCH BRIEF'S HYPOTHESIS ("`_update_cursor_visual()` might
##     not need pending machinery since it already runs in `_process()`")
##     DOES NOT HOLD AS STATED — but the reason is informative, not a dead
##     end. R5-2's constraint is not "`_input()` vs `_process()`" as such; it
##     is a process_priority WINDOW, strictly between -100 and -25. This
##     screen's OWN `_process()` is priority 100 (role ⑥, downstream reader —
##     see `_init()`'s own doc comment and R4-1's table). 100 is just as far
##     outside the (-100,-25) window as `_input()` is. So calling
##     `CursorStateHost.set_target()` directly from inside
##     `_update_cursor_visual()` would violate R5-2 exactly the way calling
##     it from `_handle_mouse_button()` would. Some deferral is needed for
##     the WRITE half either way. Only the READ half (decoding the host's
##     already-settled target back into `_cursor_cell` for rendering —
##     already how the converged KEYBOARD_GAMEPAD branch works today) is
##     safe to leave at priority 100.
##
## 5d. Hover (continuous) vs click (discrete) — PARTIALLY WORKED OUT, with
##     one open timing wrinkle (5e) I could NOT resolve this round. Tentative
##     unification: `_handle_mouse_button()` and the MOUSE branch of
##     `_update_cursor_visual()` both ultimately do the same thing today —
##     turn `_last_mouse_window_pos` into a board cell via
##     `_window_pos_to_cell()` and treat it as authoritative.
##     `_handle_mouse_button()` ALREADY writes
##     `_last_mouse_window_pos = event.position` as its first line, so a
##     click is really "a mouse-motion update that ALSO fires
##     `_controller.click_tile(cell)`". That `click_tile()` call is
##     INDEPENDENT of `_cursor_cell`/the host — it reads the freshly-computed
##     LOCAL `cell` variable, never a stored field (confirmed by reading the
##     full function body) — so it is UNAFFECTED by whatever convergence
##     timing gets chosen for the VISUAL cursor. This suggests click does NOT
##     need its OWN separate pending-flag/actor wiring for cursor movement —
##     only ONE new per-frame step is needed (not two), living in
##     `_TargetRetargetActor._process()` (-60): "when this screen's LOCAL
##     `_device.current() == DeviceAuthority.Device.MOUSE`, recompute the
##     cell from `_last_mouse_window_pos`, and if in bounds, call
##     `CursorStateHost.set_target(CursorTarget.make(BOARD_TILE, encoded))`."
##     Both hover and click would converge through this one step, since both
##     already funnel into `_last_mouse_window_pos`.
##
## 🔴 5e. THE OPEN WRINKLE 5d DOES NOT RESOLVE — reading this screen's LOCAL
##     `_device.current()` from priority -60 would be ONE FRAME STALE.
##     `_device` (this screen's own `DeviceAuthority`, DISTINCT from
##     `CursorTypes.Authority`, the HOST's internal device-authority enum —
##     see `_handle_directional()`'s own doc comment for why two separate
##     trackers exist) only updates `current()` inside `resolve_frame()`,
##     which this screen calls from ITS OWN `_process()` at priority 100 —
##     AFTER `_TargetRetargetActor` (-60) would already have run for that
##     same frame. So a -60 step reading `_device.current()` sees LAST
##     frame's resolved value, not this frame's.
##     Un-gated (always recompute from mouse position regardless of
##     `_device.current()`), the mouse step would stomp on keyboard
##     navigation every single frame the mouse sits anywhere on/off the
##     board, even while the player uses only keyboard — NOT today's
##     behavior (today's `_update_cursor_visual()` only takes the mouse
##     branch when `_device.current() == MOUSE`). I have NOT found a clean
##     fix within this story's "reuse `_TargetRetargetActor`, no new actor"
##     cap:
##       - Accepting the 1-frame staleness ONLY on the authority-transfer
##         frame itself (not on steady-state mouse tracking) MIGHT be an
##         acceptable, disclosable behavior difference under this AC's own
##         explicit tolerance ("可能暴露既有行為差異...此為已知並接受的代價") —
##         I have NOT verified whether the transfer frame is actually
##         observable/testable, or whether it silently self-corrects one
##         frame later.
##       - Moving `resolve_frame()` earlier touches `DeviceAuthority`, which
##         Implementation Note 1 explicitly reserves for story-009 ("先拆裝置
##         權威會讓游標當場沒有來源" — retiring this tracker is story-009's
##         job). I did NOT investigate this further because it looks like
##         scope expansion into another story's territory, not because I
##         confirmed it is unsafe.
##     🔴 **THIS IS THE ITEM I AM LEAST CONFIDENT "REUSE THE EXISTING ACTOR"
##     ACTUALLY SOLVES CLEANLY — IT MAY BE WHAT PUSHES unit 3b point 2/4 PAST
##     THE "NEEDS A NEW ACTOR" CAP, OR AT LEAST PAST "REUSE TRIVIALLY".**
##     Flagging explicitly rather than picking a resolution and silently
##     coding it.
##
## 5f. Other things found, not in the dispatch brief:
##     - `_handle_mouse_button()` ALSO calls `_board_view.set_cursor(cell)`
##       directly — a second, redundant visual write on top of
##       `_update_cursor_visual()`'s own `_board_view.set_cursor(_cursor_cell)`
##       call later the same frame. This is the mouse-path twin of finding
##       #1's "一次走兩格" shape: two writers, same root cause (a direct write
##       bypassing the per-frame sync point). Likely needs removing in the
##       same change that removes `_cursor_cell = cell`, mirroring how
##       `_handle_directional()` lost its own direct write in point 3/4.
##     - `CursorTypes.Authority` (the HOST's internal device-authority enum,
##       inside `cursor_state.gd`, NOT this screen's local `DeviceAuthority`)
##       already has a `MOUSE` member, decided inside
##       `CursorState.arbitrate_device_authority()` via
##       `MouseReclaimPolicy.evaluate()` — but that mechanism decides WHO HAS
##       DEVICE AUTHORITY (self-drawn cursor vs. native pointer, 機制六①/
##       機制十三); its own doc comment states it "must NOT touch `_target`",
##       and it never calls `set_target()`. Grepped for any existing path
##       that turns a mouse position into a `BOARD_TILE` `set_target()` call
##       — found NONE. **This story is the FIRST thing in this codebase that
##       would make mouse position drive `_target`.** That is a bigger step
##       than "wire into an existing pattern" (how both the dispatch brief
##       and the story doc frame point 2/4) — it is the same SHAPE of wiring
##       (pending flag -> `_TargetRetargetActor` -> `set_target()`), but
##       there is no existing "mouse version" of it to copy the way
##       `_confirm_selected_card()`'s four register/unregister call sites
##       gave a ready template for AC-1. Noting this so the next reader does
##       not assume an unread mouse-side precedent exists somewhere.
##     - `_controller.click_tile(cell)` reads the LOCAL `cell` variable,
##       never `_cursor_cell` (confirmed by reading the full function body).
##       Whatever convergence timing/lag point 2/4 ends up choosing for the
##       VISUAL cursor, the actual gameplay click action is unaffected by it.
##
## STATUS: nothing in this section is implemented; `battle_screen.gd` has
## ZERO diff from commit `b4c8e6d` this round. Next round should settle 5e
## before writing any code — the chosen answer changes what
## `_TargetRetargetActor`'s new owner method needs to read and from where.
##
## ═══════════════════════════════════════════════════════════════════════════
## 6. 2026-10-13 (SAME DAY, LATER) — AC-10b VERIFICATION, per coordinator
##    instruction after a manager ruling accepted "one stale frame at the
##    handoff" on the strength of a coordinator-relayed, EXPLICITLY-UNVERIFIED
##    claim that `design/gdd/cursor-highlight-state.md`'s AC-10b is a
##    precedent for it. Coordinator's own framing: "若不涵蓋 → 停下來回報...
##    這一點沒有商量餘地". READ THE REST OF THIS ITEM BEFORE ACTING ON THE
##    RULING — the verdict below is NOT COVERED, and per that same instruction
##    I have STOPPED rather than implemented anything in section 5 this round.
## ═══════════════════════════════════════════════════════════════════════════
##
## AC-10b VERBATIM (`design/gdd/cursor-highlight-state.md`, Group C, 2026-08-04
## addition): "GIVEN 裝置權威從 A 轉移到滑鼠(B=滑鼠)的觸發影格,WHEN 檢視該影格
## 結束時的游標目標值,THEN 其等於滑鼠取得權威的同一個 ui_* action 所推導出的
## 懸停目標——不殘留 A 的舊值超過該觸發影格本身." Production citation already
## exists at `cursor_state.gd`'s `apply_buffered_navigation()` doc comment,
## which is where the coordinator's "AC-10b mouse-case precedent" phrase
## traces back to — confirmed by reading that comment directly, not just
## grepping for the phrase.
##
## 🔴 VERDICT: NOT COVERED. AC-10b's "裝置權威" is NOT the same thing as the
## stale value in this file's own finding 5e, on two independent grounds:
##
## (i) DIFFERENT FIELD, DIFFERENT SYSTEM. AC-10b's "裝置權威" is AC-1's
##     canonical, GDD-defined field ("本系統的全域狀態物件...恰包含三個頂層
##     欄位——目前游標目標...目前裝置權威...滑鼠奪權累積位移量") — i.e.
##     `CursorState._device_authority` (`CursorTypes.Authority`), resolved by
##     `CursorState.arbitrate_device_authority()`, called from
##     `CursorStateHost._process()` at **process_priority -100**. Finding 5e's
##     stale value is `battle_screen.gd`'s OWN, LOCAL `_device` field
##     (`DeviceAuthority`, a wholly different class), resolved by
##     `DeviceAuthority.resolve_frame()`, called from THIS SCREEN's own
##     `_process()` at **process_priority 100**. `battle_screen.gd`'s own doc
##     comments already state these are deliberately separate trackers (see
##     `_handle_directional()`'s doc comment: "`_device` ... distinct from
##     CursorStateHost's internal one"), and Implementation Note 1 reserves
##     retiring the local one for story-009. AC-10b was written against, and
##     only ever tested against (`frame_buffer_ordering_test.gd`'s
##     `test_ac10_*` pair), the FIRST field. It says nothing about the SECOND.
##
## (ii) DIFFERENT TRIGGER SEMANTICS, CONFIRMED BY READING BOTH IMPLEMENTATIONS.
##     AC-10b's "裝置權威從 A 轉移到滑鼠" is gated by
##     `MouseReclaimPolicy.evaluate()` — Core Rules #3's accumulated-
##     displacement THRESHOLD ("滑鼠奪回權威的空間門檻"), evaluated inside
##     `arbitrate_device_authority()`. `battle_screen.gd`'s own
##     `DeviceAuthority.resolve_frame()` (read directly,
##     `src/ui/battle/device_authority.gd`) has NO threshold at all: "elif
##     _mouse_moved_this_frame: next = Device.MOUSE" — ANY mouse motion this
##     frame flips it, unconditionally. A precedent written for a gesture-
##     gated transfer does not mechanically transfer to an ungated, every-
##     motion flag flip; the two "transfer frames" are not the same event
##     under the same rule.
##
## 🔴 A RELATED OPTION THIS SURFACES, NOT YET EVALUATED FOR SCOPE: reading
##     `CursorStateHost.get_device_authority()` (the CANONICAL field, i) from
##     `_TargetRetargetActor` (-60) instead of the local `_device.current()`
##     would have ZERO staleness — it is resolved at -100, strictly before
##     -60 runs, every frame. But per (ii) above this is NOT a drop-in
##     substitute: it would switch the trigger condition for "does mouse
##     hover move the BOARD_TILE target" from "any mouse motion" (today's
##     local-tracker behavior, unconditional) to "mouse has accumulated
##     enough displacement to win the GDD's reclaim gesture" (the canonical
##     field's actual rule) — a materially different, arguably bigger,
##     behavior change than a one-frame lag, and one that couples BOARD_TILE
##     navigation to the mouse-reclaim submechanism (機制十三) for the first
##     time. Flagging this as a DIFFERENT fifth option the manager's three
##     listed alternatives (②③④ in the coordinator's relay) did not include —
##     not recommending it, not implementing it, just surfacing it since it
##     fell out of this verification pass.
##
## STATUS (this item): read-only verification, as instructed. NO code
## written in response to the manager's ruling this round — the ruling's own
## stated justification (AC-10b precedent) does not hold, so proceeding on it
## would be "verdict acted on without re-checking reasoning" (this project's
## own registered failure shape, 2026-10-12). Returned to the coordinator for
## re-ruling rather than silently picking one of (ii)'s two paths myself.
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _original_arbitration_suspended: bool
var _original_target: CursorTarget
var _original_device_authority: int


func before_test() -> void:
	# Same save convention as tests/integration/ui/menu/battle_menu_gating_test.gd's
	# before_test()/after_test() pair — CursorStateHost is a shared Autoload
	# singleton across every test file in this engine process; its mutable
	# state must be restored, not merely reset to a guessed default.
	var host: Node = _host()
	_original_arbitration_suspended = host.get(&"_arbitration_suspended")
	var state: CursorState = host.get(&"_state")
	_original_target = state.get_current_target()
	_original_device_authority = state.get_device_authority()


func after_test() -> void:
	var host: Node = _host()
	host.set(&"_arbitration_suspended", _original_arbitration_suspended)
	host.set(&"_frame_events", [])
	var state: CursorState = host.get(&"_state")
	state.set(&"_target", _original_target)
	state.set(&"_device_authority", _original_device_authority)
	# Unconditional, idempotent cleanup for this file's own BOARD_TILE
	# registration (test #1 below) — harmless UNREGISTERED_NOT_FOUND on every
	# other test in this file, which never registers anything under this tag.
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)
	Input.action_release(&"ui_right")
	Input.action_release(&"ui_down")


func _host() -> Node:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).append_failure_message(
		"CursorStateHost autoload not found at /root -- is it still " +
		"registered in project.godot's [autoload] section?"
	).is_not_null()
	return host


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _test_mouse_position() -> Vector2:
	return Vector2.ZERO


func test_suite_file_parses_and_collects() -> void:
	assert_bool(true).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# Finding #1 — "一次走兩格"
# ═══════════════════════════════════════════════════════════════════════════

func test_board_cursor_has_a_single_authoritative_source_after_convergence() -> void:
	# Arrange — 🔴 2026-10-13: REWRITTEN per this test's own prior narrative
	# promise, now that Story 008 unit 3b (points 1/4, 3/4, 4/4 — _ready()
	# seeding, _handle_directional()'s self-write removed,
	# _update_cursor_visual() reading the host) has landed. This test used to
	# assert the BUG (two independent writers); it now asserts the CONVERGED
	# invariant the bug has been fixed into: _cursor_cell is a MIRROR of
	# CursorStateHost's target, not an independently computed value.
	var instance: BattleScreen = _fresh_instance()
	var host: Node = _host()
	var state: CursorState = host.get(&"_state")

	assert_int(CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, instance)) \
		.append_failure_message(
			"precondition: _ready() should already own BOARD_TILE for a freshly built BattleScreen"
		).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)

	var cursor_cell_before: Vector2i = instance._cursor_cell
	var host_cell_before: Vector2i = CursorTypes.decode_tile(
		state.get_current_target().id, BoardCoords.BOARD_COLS
	)
	assert_vector(cursor_cell_before).append_failure_message(
		"precondition: _ready()'s seeding (unit 3b point 1/4) should have " +
		"left _cursor_cell and the host's target already in sync"
	).is_equal(host_cell_before)

	# Act — same single ui_right press as this test used before the rewrite,
	# plus one new step: force the per-frame visual sync (unit 3b point 4/4)
	# that the live game loop would run every frame. 🔴 2026-10-13 fix: this
	# MUST be instance._process(0.0), not instance._update_cursor_visual()
	# directly — engine-verified the hard way (first attempt called
	# _update_cursor_visual() alone and got '(0,2)' instead of '(1,2)').
	# Root cause was in THIS TEST, not production: _update_cursor_visual()'s
	# branch depends on _device.current(), which DeviceAuthority only updates
	# inside resolve_frame() (note_pad_input() above, fired by
	# _handle_directional()'s debounce loop, only sets a flag — see
	# device_authority.gd's own two-phase note/resolve split). Production's
	# real BattleScreen._process() always calls _device.resolve_frame() BEFORE
	# _update_cursor_visual() (see that method's own body); calling the visual
	# sync alone skipped the resolve step, so _device.current() was still its
	# constructed default (MOUSE), took the MOUSE branch instead of the
	# just-converged KEYBOARD_GAMEPAD branch, and read stale
	# _last_mouse_window_pos instead of the host's target.
	var nav_event: InputEventKey = _real_pressed_event(&"ui_right")
	Input.action_press(&"ui_right")
	instance._input(nav_event)
	host._input(nav_event)
	host._process(0.0)
	host.flush_buffered_navigation()
	instance._process(0.0)
	Input.action_release(&"ui_right")

	# Assert — moved by EXACTLY one cell, through the single authoritative
	# source (the host) — not two independent writers.
	var host_cell_after: Vector2i = CursorTypes.decode_tile(
		state.get_current_target().id, BoardCoords.BOARD_COLS
	)
	assert_vector(host_cell_after).append_failure_message(
		"CursorStateHost's own target should have moved exactly one cell right"
	).is_equal(host_cell_before + Vector2i.RIGHT)
	assert_vector(instance._cursor_cell).append_failure_message(
		"_cursor_cell should now MIRROR the host's target exactly (single " +
		"source of truth) -- not independently computed by _handle_directional() " +
		"anymore. If this diverges from host_cell_after, the two writers are " +
		"back (regression), or _update_cursor_visual()'s read conversion broke."
	).is_equal(host_cell_after)


# ═══════════════════════════════════════════════════════════════════════════
# Finding #2 — cursor must stay movable before any unit is selected
# ═══════════════════════════════════════════════════════════════════════════

func test_directional_navigation_can_select_a_non_default_unit_before_any_selection_exists_today() -> void:
	# Arrange — vs01_roster.txt: unit id 1 (甲) at (0,2) is _ready()'s seeded
	# default cursor position; unit id 2 (乙) sits one row below at (0,3).
	# 🔴 2026-10-13: Act updated after Story 008 unit 3b landed —
	# _handle_directional() no longer moves _cursor_cell itself (point 3/4);
	# movement now genuinely depends on CursorStateHost's own pipeline
	# (registered by _ready(), point 1/4) actually running, exactly as the
	# real engine does automatically every frame. This test now drives that
	# pipeline explicitly (host._input()/_process()/flush_buffered_navigation()
	# + instance._process() to sync the visual, point 4/4) instead of relying
	# on instance._input() alone — matching
	# test_board_cursor_has_a_single_authoritative_source_after_convergence's
	# own established pattern. The capability this test locks in (keyboard
	# navigation works before any unit is selected) is unchanged; only HOW
	# that movement happens changed.
	var instance: BattleScreen = _fresh_instance()
	var host: Node = _host()
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: nothing should be selected yet"
	).is_equal(-1)
	var second_unit_cell: Vector2i = instance._cursor_cell + Vector2i.DOWN

	# Act — one ui_down press, driven through both the screen's own _input()
	# and the real Autoload's real pipeline, then confirm at the new cursor
	# position.
	var nav_event: InputEventKey = _real_pressed_event(&"ui_down")
	Input.action_press(&"ui_down")
	instance._input(nav_event)
	host._input(nav_event)
	host._process(0.0)
	host.flush_buffered_navigation()
	instance._process(0.0)
	Input.action_release(&"ui_down")
	assert_vector(instance._cursor_cell).append_failure_message(
		"precondition: one ui_down press should move the cursor exactly one " +
		"row down onto unit id 2's tile"
	).is_equal(second_unit_cell)
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"方向鍵+確認應能在完全沒有單位被選取的情況下，選到游標當下所在的單位，" +
		"而非只能選到 _ready() 預設的那一個。若本 story 把 register/unregister " +
		"錨點掛在 unit_selected/selection_cleared（協調者前置檔的原始建議）而非 " +
		"從 _ready() 起就註冊 BOARD_TILE，這條測試預期會變紅。"
	).is_not_equal(-1)


# ═══════════════════════════════════════════════════════════════════════════
# Finding #3 — gamepad stick debounce gap in CursorState's own pipeline
# ═══════════════════════════════════════════════════════════════════════════

class _CountingSurface extends Node:
	var call_count: int = 0

	func cursor_navigate(from_id: int, _direction: Vector2i) -> Variant:
		call_count += 1
		return from_id + 1


func test_apply_buffered_navigation_has_no_builtin_debounce_for_repeated_joypad_motion_events() -> void:
	# Arrange — find a REAL InputEventJoypadMotion actually bound to a
	# NAVIGATION-class ui_* action in this engine's InputMap. Fails loud
	# rather than assuming one exists, per this project's own discipline
	# against unverified engine-behavior assumptions.
	var joy_event: InputEventJoypadMotion = null
	for action: StringName in CursorTypes.NAVIGATION_ACTIONS:
		if joy_event != null:
			break
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				joy_event = (event as InputEventJoypadMotion).duplicate()
				break
	if joy_event == null:
		fail(
			"PRECONDITION FAILED: no InputEventJoypadMotion is bound to any " +
			"CursorTypes.NAVIGATION_ACTIONS entry in this engine's real " +
			"InputMap -- cannot test the gamepad-stick debounce hypothesis " +
			"against a real bound event. This does not confirm OR refute the " +
			"hypothesis; it means this test could not run."
		)
		return

	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	var counting_surface: _CountingSurface = auto_free(_CountingSurface.new())
	assert_int(registry.register(CursorTypes.SurfaceType.BOARD_TILE, counting_surface)) \
		.is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	var state: CursorState = CursorState.new(
		null, registry, Callable(self, "_test_mouse_position")
	)

	# Act — "frame 1": arbitrate (claims KEYBOARD_GAMEPAD authority) then
	# apply, using the SAME bound event object both times to simulate the
	# engine re-delivering it on a later frame while the stick stays held
	# (delivery-frequency itself is NOT verified here -- see header finding
	# #3's explicit caveat).
	state.arbitrate_device_authority([joy_event])
	state.apply_buffered_navigation([joy_event])
	var id_after_frame_1: int = state.get_current_target().id

	# "frame 2" -- identical event, fed again.
	state.arbitrate_device_authority([joy_event])
	state.apply_buffered_navigation([joy_event])
	var id_after_frame_2: int = state.get_current_target().id

	# Assert
	assert_int(counting_surface.call_count).append_failure_message(
		"CONFIRMS the debounce-gap hypothesis AT THE CODE LEVEL: " +
		"apply_buffered_navigation() called cursor_navigate() twice for two " +
		"separate buffered-event batches containing the identical joypad " +
		"motion event, with no 'already pressed last frame' suppression -- " +
		"unlike _handle_directional()'s own _direction_just_pressed() debounce. " +
		"Whether the real engine actually delivers InputEventJoypadMotion " +
		"every frame while a stick is held is NOT verified by this test -- " +
		"see this file's header finding #3."
	).is_equal(2)
	assert_int(id_after_frame_2).append_failure_message(
		"target id should have advanced on BOTH frames if there is truly no " +
		"debounce in this pipeline"
	).is_not_equal(id_after_frame_1)


# =============================================================================
# story-009 implementation notes 2026-10-13 (ui-programmer)
# =============================================================================
# 本區塊是本回合的第一個落地產出,依協調者的回合預算指示寫下 —— 讀了必讀材料
# 後的實作計畫,寫下這段的當下尚未改動任何正式程式碼(src/ 零改動)。
#
# 1. 讀到哪裡
#    - 全讀完:story-009-coordinator-prework-2026-10-13.md(98 行)、
#      docs/architecture/cursor-device-authority-for-board-tile-2026-10-13.md
#      (407 行,含第 0/2/3/4/5/6/7 節全文)、
#      story-009-device-authority-convergence.md 本體(132 行,含今天新增
#      的 AC 第一項與 Dependencies 的 2026-10-13 裁決註記)。
#    - src/ui/battle/device_authority.gd:全讀(116 行)。
#    - src/ui/battle/battle_screen.gd(實測 2939 行):讀了類別檔頭(1-40)、
#      _device 宣告與 _ready() 建構段(390-450、820-968)、
#      _TargetRetargetActor 與其鄰近欄位(640-820)、_handle_mouse_button /
#      _window_pos_to_cell / _handle_directional / _handle_hand_navigation /
#      _handle_forced_discard_input(1770-2000)、_apply_pending_target_jump /
#      _apply_target_confirm_from_cursor_state(2046-2180)、
#      _update_cursor_visual(2560-2650)。**沒有全讀** —— 跳過約
#      40-390、450-640、1000-1770 非上述片段、2180-2560、2650-2939。
#      全部 17 處 _device.note_* 呼叫點與 2 處 current()/resolve_frame()
#      的精確行號已用 grep 核對,與前置檔第一節數字一致(15+2+1+1+2)。
#    - src/ui/cursor/cursor_state_host.gd:讀了 func 簽章清單 +
#      _input()/_process()/get_device_authority()/get_current_target()/
#      set_target() 的簽章與緊鄰文件註解(未逐行讀 599 行全文)。關鍵
#      發現:host 的 _input() 是獨立於 battle_screen 的 Autoload
#      _input(),把【全部】引擎事件(含滑鼠按鍵/移動)塞進 _frame_events
#      —— 與 battle_screen 自己的 _input() 完全無關、互不依賴。
#    - src/ui/cursor/cursor_state.gd:讀了 arbitrate_device_authority()
#      全文(340-516)。關鍵發現:滑鼠裝置權威判定【不看事件】,而是
#      每幀用 _mouse_position_provider 取【即時座標】餵
#      MouseReclaimPolicy.evaluate() 算淨位移 —— 也就是說移除
#      _device.note_mouse_motion() 不會讓 host 端的滑鼠裝置權威判定漏掉
#      任何東西,host 本來就不靠那個呼叫。**尚未讀** set_target() /
#      _write_target_internal() 的函式本體,只讀過簽章,見第 6 點。
#
# 2. 目前的實作計畫(可編譯單位怎麼切)—— 大致同意前置檔的三單位切法,
#    單位 1 的具體寫法比前置檔/意見書都更具體一點:
#
#    單位 1(先做,因為單位 3 的刪除依賴它存在):滑鼠路徑接上 host
#      a. _TargetRetargetActor._process() 新增一行,呼叫 owner 的新方法
#         _apply_mouse_target_if_authoritative()(不新建 actor —— 沿用
#         現有這個已在 -60 跑的節點,它目前 _process() 全文只有一行)。
#      b. 新方法邏輯(草案,尚未定案 —— 見第 6 點的不確定項):若
#         _controller.is_card_play_in_progress() 或 has_pending_discard()
#         為真就不動(鏡射 _handle_mouse_button() 既有的同一組守衛);
#         否則讀 CursorStateHost.get_device_authority() != MOUSE 就不動;
#         否則用 _window_pos_to_cell(_last_mouse_window_pos) 算格子,
#         越界就不動,在界內就呼叫 CursorStateHost.set_target()。
#      c. _handle_mouse_button() 移除 _device.note_mouse_motion() 呼叫
#         (host 不需要它,見第 1 點 cursor_state.gd 的發現);是否同時
#         移除它原本直接寫 _cursor_cell / _board_view.set_cursor(cell)
#         那兩行 —— 傾向移除(改由 (a)(b) 新寫入路徑 + _update_cursor_visual()
#         的既有讀取路徑接手,理論上同一幀內仍可 resolve,見意見書第零節
#         的影格順序表),但這會讓點擊的視覺即時反應多繞一層,**尚未實測
#         確認行為不變,算未定案,見第 6 點**。
#
#    單位 2:_update_cursor_visual()(:2600)的 if 條件,
#      `_device.current() == DeviceAuthority.Device.MOUSE` 改成
#      `CursorStateHost.get_device_authority() == CursorTypes.Authority.MOUSE`。
#      傾向【只改這一行】,兩個分支內部邏輯不動 —— AC 第三項字面只要求
#      換掉判斷依據,不要求改分支內容,而且 mouse 分支本來就直接從
#      _last_mouse_window_pos 算格子,不依賴單位 1 有沒有把值寫進 host。
#
#    單位 3:17 處 note_* 全刪 + device_authority.gd 整份退役 + 建構呼叫
#      (:968 `_device = DeviceAuthority.new()`)移除 + 宣告(:416
#      `var _device: DeviceAuthority`)移除。連帶要清掉類別檔頭(1-40 行
#      附近)三處提到 DeviceAuthority 的文件註解,以及 :768、:1838-1845、
#      :2708 三處 doc comment 段落 —— 這些是我讀檔時發現、前置檔/意見書
#      都沒提到的東西(見第 5 點)。
#
#    順序:1 → 2 → 3,原因同前置檔:單位 3 是純刪除,但 :2600 的 if 在
#    1、2 做完前還讀著 _device,先刪會讓它當場沒有來源。
#
# 3. 17 處 note_* 的處置想法
#    不打算分批刪、也不打算動它們各自所在呼叫情境的其餘邏輯(方向鍵/
#    確認鍵/棄牌等分支都不碰,只刪那一行 note_* 呼叫)。15 處
#    note_pad_input 全部只是記帳,沒有一處夾帶其他副作用 —— 已用 grep
#    逐行核對過(:1175/1197/1210/1227/1231/1251/1256/1261/1268/1282/
#    1289/1858/1871/1954/1969),每一行單獨成行、前後都是其他邏輯,刪除
#    是純減法。2 處 note_mouse_motion(:1151 在 _input() 的滑鼠移動分支、
#    :1780 在 _handle_mouse_button())同樣是單獨一行。**沒有發現任何一處
#    note_* 身兼他職** —— 與前置檔「17 處全部只為了服務 :2600 那一個 if」
#    的結論一致。
#
# 4. 滑鼠路徑(自 008 移交)怎麼接 —— 同第 2 點單位 1,核心判斷依據:
#    閘門讀 CursorStateHost.get_device_authority()(-100 解出,同幀內對
#    -60 讀者無過期,意見書第零節已論證),寫入動作放在 _TargetRetargetActor
#    既有節點的 _process() 裡新增一行,不新建節點、不新建檔案。兩項已知
#    代價(75px 累積位移門檻、E1 可從主棋盤路徑觸及)照單全收,不在實作
#    中迴避或補救,也不改 mouse_reclaim_threshold_config.gd 的 75px。
#
# 5. 發現但前置檔/意見書沒寫到的東西
#    - battle_screen.gd 類別檔頭(1-40 行附近)與至少三處散落的 doc
#      comment(:768、:1838-1845、:2708)用文字描述 DeviceAuthority 的
#      架構地位與退役計畫 —— 這些是【文件性質的程式碼註解】,整份退役
#      _device 時必須連帶改寫,否則會變成指著一個不存在類別的死文件。
#      前置檔與意見書都只算了【可執行的呼叫行】,沒算這些純文件行,所以
#      單位 3 實際改動的行數會比「17+2+2」這個數字看起來的範圍大一些,
#      但不影響程式行為,純粹是保持文件誠實。
#    - cursor_state_host.gd 的 _input() 是 Autoload 自己的事件迴圈,完全
#      獨立於 battle_screen 的 _input() —— 前置檔第二節有提到結論
#      (「host 已經自動解析」)但沒展示機制;我用程式碼核對過機制本身,
#      結論相同,只是現在多了機制層的依據(見第 1 點)。
#
# 6. 還不確定的地方 —— 卡在這幾點,尚未動手實作
#    - 單位 1(c):_handle_mouse_button() 原本直接寫 _cursor_cell /
#      _board_view.set_cursor(cell) 那兩行,移除後是否會改變點擊當幀的
#      視覺即時性(現在是點了立刻畫,改法要繞 -60 的 actor 再回到 100 的
#      _update_cursor_visual() 才畫,理論上同一幀內仍會 resolve,但沒有
#      實測驗證過)。傾向移除以避免兩條寫入路徑並存,但這是本單位實作
#      時要親自驗證的風險點,不是現在就能拍板的。
#    - CursorStateHost.set_target() 對相同目標重複呼叫(例如滑鼠沒動,
#      但 actor 每幀仍嘗試寫入)是否為安全的 no-op,還是每次都會觸發
#      CONDITIONAL_ON_CHANGE 以外的副作用(意見書第二節提過「①之下
#      TARGET_CHANGED 重置會讓滑鼠自己的 75px 累積歸零」這個二階效應,
#      但那是在討論選項①的脈絡,單位 1 的設計是直接寫 host 的權威欄位,
#      待確認是否有類似耦合)—— 動手前要先讀 cursor_state.gd 的
#      _write_target_internal() / set_target() 全文,目前只讀過簽章與
#      上方文件註解,還沒讀函式本體。
#    - 工作單 Test Evidence 節寫的新檔名是
#      tests/integration/ui/battle_device_authority_convergence_test.gd
#      (目前不存在),但本回合的筆記依協調者指示落在 story-008 留下的
#      battle_cursor_navigation_convergence_test.gd 檔尾。尚未決定新測試
#      要新建獨立檔案還是併入這支既有檔案 —— 待單位 1 開始寫測試時再定,
#      傾向比照 Test Evidence 節字面新建獨立檔案。
# =============================================================================


# =============================================================================
# story-009 handoff notes 2026-10-13 (ui-programmer) — END OF SESSION, stopped
# by coordinator's "提早收工" instruction. Unit 1, unit 2, unit 3a landed and
# GREEN. Unit 3b NOT STARTED. Next session: read this block first.
# =============================================================================
#
# STATE ON DISK AT HANDOFF (own engine run, this same session):
#   Overall Summary: 1165 test cases | 0 errors | 1 failures | 0 flaky |
#   0 skipped | 0 orphans | Executed test suites: (100/100) | Exit code: 100
#   Only named FAILED: affinity_phi_provider_test.gd (pre-existing, not
#   touched by this story). Matches coordinator's independent rerun exactly.
#
# UNIT 3a (DONE): all ~17 _device.note_pad_input()/note_mouse_motion() call
# sites removed; _device.resolve_frame() call removed (battle_screen.gd
# _process()). 🔴 One MUST-FIX found and fixed while doing this mechanically
# (sed by line number, not the Edit tool, since all ~17 sites were identical
# one-line statements needing cross-referenced line numbers): removing the
# SOLE statement inside _handle_directional()'s
# `if _direction_just_pressed(...):` body left an EMPTY BLOCK — a GDScript
# syntax error. Fixed with an explicit `pass` + comment (search for "the sole
# statement this branch used to run" in battle_screen.gd). Every other
# removal site was checked BY HAND against printed before/after context
# before running anything — all ~16 other sites had a SIBLING statement
# remaining in the same block; only this one site was the sole statement.
# Full suite was run AFTER this fix and came back clean on the first try —
# but the lesson for next session doing 3b: after ANY multi-site mechanical
# deletion in this file, grep the touched function bodies for blocks that are
# now empty BEFORE running the engine, the same way this session did.
#
# UNIT 3b (NOT STARTED) — remaining checklist, BY SYMBOL NAME not line number
# (lines have drifted all session and will drift again the moment 3b starts):
#   1. Delete `var _device: DeviceAuthority` field declaration — in the
#      member-variable block alongside `_state`/`_order`/`_controller`.
#   2. Delete `_device = DeviceAuthority.new()` construction call — inside
#      `_ready()`, right after `_controller = BattleController.new(...)`.
#   3. Delete `src/ui/battle/device_authority.gd` AND its companion
#      `src/ui/battle/device_authority.gd.uid` (both confirmed present at
#      handoff via `ls`).
#   4. 🔴 NEW FINDING THIS SESSION — not named in the original dispatch brief,
#      the coordinator's prework doc, or the technical-director's opinion
#      doc. MUST be deleted in the SAME unit as #3, not after:
#      `tests/unit/ui/device_authority_test.gd` (+ its `.uid`) is a DEDICATED
#      unit-test suite, 10 `test_` functions (`grep -c "^func test_"` =
#      confirmed this session), that directly instantiates
#      `DeviceAuthority.new(...)` as REAL CODE (not comments) ~20 times —
#      full grep output pasted below. Deleting device_authority.gd WITHOUT
#      also deleting this test file will make this file fail to parse
#      ("Identifier DeviceAuthority not declared"), which per this project's
#      own registered trap (coding-standards.md's exit-105 entry) means test
#      DISCOVERY aborts and ZERO tests run across the ENTIRE suite, while
#      `grep "Overall Summary"` / `grep " FAILED"` both come back EMPTY —
#      indistinguishable from a clean pass unless the engine's own exit code
#      is checked FIRST. Delete both files (and both `.uid`s) in the same
#      unit as device_authority.gd itself, never device_authority.gd alone.
#      Expected total-test-case delta after deleting it: Overall Summary's
#      count should drop by exactly 10 from whatever baseline 3b starts from
#      — a LOWER total here is the CORRECT outcome, not a regression; verify
#      against this comment's "10", not just eyeballed.
#      (By contrast: the OTHER file matching "DeviceAuthority",
#      `battle_cursor_navigation_convergence_test.gd` — this very file — only
#      ever mentions it inside `#`/`##` COMMENTS: historical narrative about
#      story-008's own findings, never compiled code. It needs NO code change
#      for unit 3b; those comments remain historically accurate as written.)
#   5. Stale doc-comment cleanup still outstanding (found this session, not
#      yet fixed — the coordinator's stop instruction landed before this one):
#      search battle_screen.gd for the Chinese comment
#      `所以主機端沒有指標也一樣看得到` (inside the paragraph explaining why
#      `focus_cell` is bound to the cursor rather than mouse hover). Full
#      surrounding paragraph read this session:
#        "綁在游標而非滑鼠 hover:游標由鍵盤/手把/滑鼠三種裝置共同驅動
#        (DeviceAuthority),所以主機端沒有指標也一樣看得到。"
#      Fix: replace the parenthetical `(DeviceAuthority)` with
#      `(CursorStateHost)` — the underlying claim ("the cursor is driven by
#      all three devices so console, with no pointer, still sees it") stays
#      TRUE after 3b, only the mechanism's NAME needs updating. Low-risk,
#      single-token fix; not done this session purely because the stop
#      instruction arrived first, not because of any uncertainty about it.
#   6. Already fixed THIS session (do NOT redo, do NOT re-grep looking for
#      more — these three are closed): the class header doc comment (top of
#      file, "Owns [BattleState]..." paragraph — now says device authority is
#      answered entirely by CursorStateHost, DeviceAuthority "formerly"
#      existed); `_init()`'s doc comment (the "Side effect, disclosed rather
#      than silent" paragraph about process_priority 100 — DeviceAuthority's
#      resolve_frame() removed from the historical list, with an explanation
#      of why removing it from that sentence doesn't make the sentence
#      retroactively wrong); and `_fail_load()`'s neighboring comment (the
#      "_state/_order/_controller/_phi" list — `_device` already dropped from
#      it). This brings the real count of stale-doc locations found this
#      story to 6 (class header, _init(), _fail_load() neighbor,
#      _handle_directional()'s block [item 5a below], the
#      所以主機端沒有指標 one [item 5 above], and _TargetRetargetActor's own
#      doc which was self-authored correctly from the start) — NOT the "three"
#      estimated in this file's own EARLIER note block above (search
#      "三處提到 DeviceAuthority 的文件註解" above in this same file): that
#      estimate undercounted once the actual edit pass started finding more.
#   5a. One more location needing a FINAL touch-up once 3b actually lands
#      (currently accurate, will become stale the moment 3b is done): the big
#      comment block directly above `func _handle_directional` — search for
#      "unit 3a, _device ITSELF" — currently says "_device ITSELF ... still
#      exists ... Deleting it is unit 3b, not yet landed as of this comment".
#      Once 3b lands, update that sentence to past tense / remove the caveat.
#
# grep -rn "DeviceAuthority" tests/ --include=*.gd — FULL OUTPUT AT HANDOFF
# (run read-only this session after the stop instruction, nothing modified
# as a result of running it):
#   tests/integration/ui/battle_cursor_navigation_convergence_test.gd
#     (this file): lines 130, 247, 255, 278, 300, 357, 358, 372, 510, 730,
#     737, 738, 739, 766 — ALL inside `#`/`##` comments, zero compiled-code
#     references, confirmed by reading each hit's surrounding context.
#   tests/unit/ui/device_authority_test.gd:
#     lines 1, 3, 11, 14, 19, 22, 27, 35, 40, 48, 53, 62, 71, 75, 83, 88, 95,
#     108, 110, 112, 123, 132, 134, 153, 157, 164 — REAL CODE; this entire
#     file's sole purpose is testing this one class (see item 4 above).
#
# NEXT SESSION START POINT: do unit 3b checklist items 1-5 above in one
# commit/unit, fix item 5a as the final step once 1-4 are done, then run the
# full suite once before reporting done. Expected result if correct:
# identical to this session's baseline (1165 test cases, 1 pre-existing
# failure, 0 orphans, exit 100) MINUS 10 (device_authority_test.gd's own test
# count, confirmed above) = 1155 test cases, same 1 failure, same exit 100.
# =============================================================================
