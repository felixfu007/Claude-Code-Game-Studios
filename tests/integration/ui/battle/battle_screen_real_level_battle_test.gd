## Story 019 — 真實關卡(vs01,5 對 5)端到端打到終局.
##
## 與 story-018 的 battle_screen_battle_outcome_test.gd 不同:本測試【不】注入任何
## *_path_override 合成夾具 —— 全程使用真實 assets/data/ 下的 vs01 關卡資料。
## 目的是證明真實內容量級(5 對 5,而非 story-018 的小型合成夾具)也能在畫面側打到終局。
##
## 若本測試顯示真實關卡打不完、或任一方卡住 —— 這是本 story 的核心價值所在,應如實回報，
## 不得為了讓測試變綠而去修改 src/ai/ 或 src/gameplay/ 的遊戲邏輯。
##
## ## 🔴 實測結果與設計文件對照(2026-10-16):第 1 回合就 DEFEAT 不是 bug
##
## 本測試實測 round_count == 1、outcome() == DEFEAT(逐字輸出與逐人 HP/存活狀態見
## test_real_level_battle_reaches_a_terminal_outcome() 內的 print() 區塊,交付報告
## 一併貼了同一次執行的原始 log)。這完全符合設計文件明文的勝敗條件,不是程式壞掉:
##
##   design/gdd/vertical-slice-level-01.md「勝敗條件」節,逐字:
##   「失敗:依 C2,五名主角中任一人 HP 歸零即關卡失敗(非全滅才算輸)。」
##
##   design/quick-specs/unit-stats-provisional.md 關卡段落,逐字:
##   「失敗條件:五名主角任一人 HP 歸零即失敗(非全滅)。」
##
## src/gameplay/battle/battle_state.gd 的 outcome() 本身也是這樣寫的(DEFEAT 比
## VICTORY 優先判定——只要任一 PLAYER 單位死亡,即使同時所有 ENEMY 單位也死了,
## 結果仍是 DEFEAT)。這是不對稱的勝負條件:我方死一個就輸,敵方要死光才算贏。
## 用同一支零 RNG 的 GreedyTacticalAI 同時驅動雙方(敵方 step_enemy_phase() 在沒有
## 覆寫 _decide 時,生產路徑本來就預設呼叫同一個 GreedyTacticalAI.decide() —— 見
## src/gameplay/battle/battle_controller.gd 的 _decide_for()),在這個不對稱規則下,
## 只要敵方任何一次攻擊先命中致命一擊,整場戰鬥就立刻結束。
##
## 🔴 另一個對照,放大這個落差的意義:design/gdd/vertical-slice-level-01.md 自己的
## Acceptance Criteria 第 6 條寫「回合數落在 4~6:明顯偏離代表數值或地圖需調整,
## 非玩家技術問題」——那是對【人類玩家】的期待值。本測試量到的是 1 回合,與設計
## 期待的 4~6 回合差了 4~6 倍。這個落差本身就是下面 AC-6 揭露要強調的重點:貪婪 AI
## 的打法與人類玩家的打法不是同一回事,不能把本測試的「1 回合」讀成「這個關卡只需要
## 1 回合」或「這個關卡打不贏」——兩者都不是本測試能回答的問題。
##
## ## AC-6 誠實揭露:本測試證明了什麼、沒有證明什麼
##
## 證明了:真實 5 對 5 規模的戰鬥,從開局到 outcome() 離開 ONGOING,整條鏈
## (BattleScreen → BattleController.click_tile() / _end_faction_phase_pressed() →
## BattleState)在畫面側跑得動,不會卡死、不會崩潰。
##
## 🔴 沒有證明、而且必須被下一個人知道的事:
##   - 用同一支貪婪 AI(GreedyTacticalAI)驅動我方,不是人類的打法。本測試
##     不證明平衡性、不證明這個關卡「可不可破」、不證明好不好玩。
##   - 🔴 本測試實際只走完 1 個回合就結束(outcome() 在第 1 回合的敵方階段就變成
##     DEFEAT)。_ROUND_CAP = 10 這個上限【從未被接近】。因此本測試完全沒有涵蓋:
##     跨回合的行動旗標重置(TurnOrder.advance_faction())、多回合的回合順序遞迴、
##     長局才會出現的狀態累積(好感度池、卡片/棄牌、CardModifier 的
##     remaining_turns 遞減等)。這些目前仍然是零防線——不要把本測試讀成「真實關卡
##     打完一整場」已經被涵蓋,它只打完了「開局到第一次死亡」這一小段。
##   - 本測試的「我方」決策完全由 GreedyTacticalAI 決定,包含它會不會主動把單位
##     移動到暴露於多個敵人攻擊範圍內的格子——這正是本次量測中造成單回合即敗的
##     直接行為,但本測試不斷言、也不佐證這個移動選擇本身是否「合理」,只佐證
##     click_tile() 確實接受並執行了它。
##
## ## 🔴 Story 020(2026-10-16)—— 加了安全過濾器,但真正撞到的是一個無人踩過的凍結點
##
## story-019 量到的「第 1 回合就死」,成因確實是測試的我方打法直接用未經過濾的
## GreedyTacticalAI,把最脆的丙推進了敵人殺傷範圍 —— 本 story 在
## [method _apply_safety_filter] 加了一道 AC-1/AC-2 要求的「不自殺」規則(完整規則
## 文字見該方法的 doc comment),效果如預期:加了過濾器之後,真正的遊戲回合 1
## 不再有任何單位死亡(見下方座標證據)。
##
## 🔴 但加完過濾器之後,round_count 一度【仍然】卡在上限(10),outcome() 仍是
## ONGOING —— 而根因與我方打法完全無關,是一個本 story 事前完全沒有預期到、
## 先前任何一支測試都從未踩過的系統閘門:
##
## [b]真正發生的事(逐回合診斷輸出的座標行是直接證據,不是推論)[/b]:遊戲內部的
## 真回合 1 完全正常進行 —— 敵我雙方都真的移動了(例如戊從 (0,5) 移到 (2,1),
## E1 從 (10,0) 移到 (4,0),E4/E5 等敵方單位同樣大幅推進),雙方都還沒有進入能
## 互相攻擊的距離,沒有人受傷。到這裡為止,過濾器做的事完全正確。
##
## 緊接著,當遊戲內部推進到真回合 2 開始時([method
## BattleState.begin_player_turn] 的「每個玩家回合開始」鉤子第一次真正觸發 ——
## 真回合 1 依 [method BattleState.deal_opening_hand] 的 doc comment 說明,
## [b]刻意[/b]跳過這個鉤子,只在開局發一次手牌),[CardDeck] 的強制棄牌規則
## (story-007-forced-discard-gate.md)第一次被滿足:開局手牌已經是
## [constant CardDeck.HAND_SIZE_LIMIT],真回合 2 的補牌把手牌推過上限,
## [method CardDeck.has_pending_discard] 從此恆為 true。
##
## 🔴 這個閘門鎖死的範圍比「我方選不到單位」大得多 —— 它連
## [method BattleController.end_faction_phase] 本身都會擋下(見該方法原始碼的
## [code]if _state.has_pending_discard(): return[/code])。[b]不只我方,連敵方的
## production 路徑都無法再推進一步[/b] —— 直到這個閘門被解除為止。
## story-019 從未踩到它,純粹是因為那場戰鬥在真回合 1 就已經結束
## (在閘門第一次有機會觸發之前)。
##
## ✅ 本 story 最終沒有把這個凍結點留著回報了事,而是用遊戲【已經提供的正式
## 入口】解除它:[method _resolve_any_pending_discard] 每回合開始前呼叫
## [method BattleController.resolve_forced_discard](永遠棄 [code]hand[0][/code],
## 決定性選擇,不隨機)—— 這正是 [BattleLoop] 自己的 [code]discard_policy[/code]
## 路徑也會走到的同一個 production 呼叫([method
## BattleController.resolve_forced_discard] 的 doc comment 原文:「the human-driven
## and simulation-driven paths converge on one discard implementation」),
## 不是測試側繞過閘門的捷徑。加上這一步之後,實測
## [b]round_count == 2,outcome() == DEFEAT[/b](2026-10-16 本機 Godot 4.7.1
## headless,獨立連跑兩次逐字相同,僅 elapsed_msec 不同 —— 完全決定性)。
## 真回合 2 裡乙陣亡 —— 查座標證據:此時敵方已大幅推進到 x=1~7(對照真回合 1
## 的 x=4~9),乙本身這一整局都沒有移動過,顯然是【站在原地被圍上來的敵人打死】,
## 不是本 story 過濾器允許的「移動進危險格」—— 完全落在
## [method _apply_safety_filter] 自己揭露的範圍限制內(該方法 doc comment:
## 「若單位這回合根本沒打算移動,這道過濾器不介入,即使它當前的格子已經被威脅」)。
##
## 🔴 誠實揭露(AC-7,以下五點是本次收尾逐條核對過的,不是寫意的摘要):
##
##   1. 這仍然不是人類打法。[method _apply_safety_filter] 的規則目的是「讓
##      雙方撐久一點、不要一碰面就死」,不是「打得好」—— 它不選擇最優的攻擊
##      位置,只排除明顯自殺的那一種。不證明平衡性、不證明這個關卡「可不可
##      破」、不證明好不好玩,也不證明乙在真回合 2 的死亡本身是否「合理」
##      (過濾器刻意不介入「原地不動」的情境,但沒有驗證過不介入是不是正確
##      設計)。
##   2. 這個打法是【測試裝置】,僅供這支測試驅動真實關卡用,不是對遊戲 AI
##      的建議或替代。
##   3. 🔴 本測試揭露了一個先前無人踩到的凍結點:強制棄牌未解決時,
##      [method BattleController.click_tile] 全部回傳
##      [code]&"blocked_pending_discard"[/code]、[method
##      BattleController.end_faction_phase] 直接不做事 —— 玩家與敵方階段
##      【雙雙】停擺。story-019 因為第 1 回合就結束,從未觸及。這個洞一直
##      存在,只是先前沒有任何東西跑得夠久去踩到。
##   4. 本次新涵蓋到什麼(以下皆為本次實際觀測到的,不是推測):
##      [method _apply_safety_filter] 描述的「不自殺」規則本身已被證明有效
##      (真回合 1 零死亡,對照 story-019 的「第 1 回合就死一人」)；
##      [method BattleController.end_unit_turn] 第一次被這支測試實際呼叫並
##      驗證;[method BattleController.resolve_forced_discard] 第一次被這支
##      測試實際呼叫並驗證,棋局因此第一次真正跨越回合 1/回合 2 的邊界 ——
##      跨回合的行動旗標重置([method TurnOrder.advance_faction])與回合順序
##      遞迴這兩條,在這個真回合 2 裡第一次被實際執行到;真回合 2 裡敵方確實
##      開始推進(E1 從開局 (10,0) 走到 (4,0) 再走到 (1,0)),我方也第一次真
##      的打中敵人(E4 32→21,掉 11 點 —— 對照 story-019 全程敵方零受傷);
##      [method _play_faction_turn_via_ai] 原本「不管有沒有真的做事都當作有
##      進度」的舊 bug 已修正(見該方法自己的 doc comment)。
##   5. 仍然沒涵蓋什麼:只走了 2 個回合,仍遠低於
##      [code]design/gdd/vertical-slice-level-01.md[/code] Tuning Knobs 表
##      「預期回合數」列自己訂的 4~6(該列原文:「若實測明顯偏離,先調敵方
##      數值/地圖尺寸,而非判定為玩家技術問題」)—— 更長的對局仍然沒有被
##      測過。長局才會出現的狀態累積(CardModifier 的 remaining_turns 多次
##      遞減、好感度池累積多回合的變化、是否會再次撞上強制棄牌並正確連續
##      解決多次)仍是零防線 —— [method _resolve_any_pending_discard] 目前
##      只被實際驗證「解決一次」這個情境。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


## Shared Arrange step — loads the REAL BattleScreen.tscn with ZERO path
## overrides, so _ready() reads the production constants (TERRAIN_PATH /
## ROSTER_PATH / etc.), i.e. the real vs01 5-vs-5 level. This is the one
## deliberate difference from story-018's _load_battle_screen() helper,
## which always injects terrain_path_override / roster_path_override.
func _load_battle_screen_real() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


## Story 020 AC-1/AC-2 — a TEST-ONLY safety filter layered on top of
## GreedyTacticalAI.decide()'s raw suggestion. Never a change to
## src/ai/greedy_tactical_ai.gd itself (AC-1 forbids touching src/ at all).
## Story-019 measured that driving the PLAYER faction with the unfiltered
## decider kills our squishiest unit in round 1 (丙, 22 HP / 4 DEF) because
## the decider has no concept of "this tile is also in enemy striking
## distance" — it only optimizes for "can I hit something from here".
##
## 🔴 THE RULE, IN WORDS (AC-2 requires this be readable prose, not just
## code):
## [br]
## If the decider wants to MOVE this unit to a new tile, AND that tile is
## THREATENED by at least one living enemy (see [method _threat_count] for
## what "threatened" means here), AND this turn's attack (if any) would NOT
## kill its target outright (see [method _is_lethal_attack]) — THEN discard
## the decider's move and attack entirely, and instead move this unit to
## whichever candidate tile (its own current tile, plus every tile [method
## BattleState.legal_moves] reports) is threatened by the FEWEST living
## enemies. Ties are broken by preferring to stay at the current tile;
## remaining ties among moved-to candidates are broken by (y, x)
## lexicographic order on the tile — the same deterministic tie-break shape
## [code]greedy_tactical_ai.gd[/code]'s own [code]_is_better_tile[/code]
## already uses, for the identical reason: this project's
## [code]rng_in_combat_settlement[/code] ban means no coin-flip is ever
## available to break a tie.
## [br]
## When this filter overrides the move, no attack is attempted this turn
## from the retreat tile — this filter's purpose is retreating, not
## "retreat AND still land a hit from the new position". A unit that
## retreats this turn keeps its flags unspent for next turn exactly as
## normal (see [method _play_faction_turn_via_ai]'s multi-pass loop).
## [br]
## 🔴 If the decider was not proposing to move at all ([code]move_to ==
## null[/code] — either staying put, or [param can_move] was already false
## because the move flag is spent), this filter does NOT apply, even if the
## unit's CURRENT tile is already threatened. This is a deliberate scope
## limit, not an oversight: the filter only vets a move about to be taken
## this turn. A unit that starts its turn already standing in an enemy's
## threat range (story-019 measured 戊 at (0,5) vs E4 at (7,5), distance
## exactly 7) is left exactly where [GreedyTacticalAI] already decided to
## leave it. See this file's AC-7 disclosure header for what this scope
## limit means for what this test does and does not cover.
func _apply_safety_filter(
	state: BattleState, unit_id: int, decision: Dictionary
) -> Dictionary:
	if decision["move_to"] == null:
		return decision
	var acting_unit: Unit = state.unit_by_id(unit_id)
	var enemies: Array[Unit] = state.units_of(_opposing_faction(acting_unit.faction))
	if enemies.is_empty():
		return decision
	var destination: Vector2i = decision["move_to"]
	if _threat_count(destination, enemies, state) == 0:
		return decision
	var attack_target: int = decision["attack"]
	if attack_target != -1 and _is_lethal_attack(state, unit_id, attack_target):
		return decision  # worth the exposure -- this ends the threat now

	var origin: Vector2i = state.position_of(unit_id)
	var candidates: Array[Vector2i] = state.legal_moves(unit_id)
	var safest_tile: Vector2i = origin
	var safest_count: int = _threat_count(origin, enemies, state)
	for tile: Vector2i in candidates:
		if tile == origin:
			continue
		var count: int = _threat_count(tile, enemies, state)
		if count < safest_count:
			safest_tile = tile
			safest_count = count
		elif count == safest_count and safest_tile != origin and _tile_is_before(tile, safest_tile):
			safest_tile = tile
	var overridden_move: Variant = null
	if safest_tile != origin:
		overridden_move = safest_tile
	return {"move_to": overridden_move, "attack": -1}


## Mirrors [method GreedyTacticalAI._opposing_faction] — duplicated here
## rather than reached into as a private method of a different class (its
## leading underscore marks it an implementation detail GreedyTacticalAI
## does not promise to keep stable for outside callers). Only two factions
## exist, so this is a straight flip — identical logic, intentionally kept
## in sync by inspection rather than by a shared dependency.
func _opposing_faction(faction: Unit.Faction) -> Unit.Faction:
	if faction == Unit.Faction.PLAYER:
		return Unit.Faction.ENEMY
	return Unit.Faction.PLAYER


## 🔴 APPROXIMATION, not an exact simulation of what the opposing AI will
## actually do next turn (dispatch-brief risk #2). Counts a living enemy as
## "threatening" tile if the Manhattan distance from that enemy's CURRENT
## position to tile is <= enemy.mp + enemy.max_range. This OVERESTIMATES
## true reachability in two ways: it ignores terrain movement cost (a cell
## costing more than 1 MP point to enter shrinks the true reachable radius)
## and it ignores occupancy (a blocked path can make a raw-radius tile
## actually unreachable). The overestimate direction is the SAFER one for
## this filter: it can make a unit retreat from a tile that was, in fact,
## already safe, but it can never let a unit walk somewhere genuinely
## lethal while reporting it as safe.
func _threat_count(tile: Vector2i, enemies: Array[Unit], state: BattleState) -> int:
	var count: int = 0
	for enemy: Unit in enemies:
		var enemy_pos: Vector2i = state.position_of(enemy.id)
		var distance: int = absi(enemy_pos.x - tile.x) + absi(enemy_pos.y - tile.y)
		if distance <= enemy.mp + enemy.max_range:
			count += 1
	return count


## 🔴 APPROXIMATION (dispatch-brief risk #2, second half): treats Φ (the
## affinity-driven flat damage bonus BattleScreen's real AffinityPhiProvider
## supplies in production attacks, via BattleController's private
## _compute_phi()) as always 0, rather than querying the real provider. This
## can UNDERESTIMATE a player attack's true damage whenever Φ is actually
## positive that turn, which in turn can make this filter retreat in a case
## where the real, unfiltered attack would in fact have been lethal.
## Accepted as a known imprecision of this TEST-ONLY harness — it is never
## used to decide an actual combat outcome, only to decide whether THIS
## filter lets a risky move through.
func _is_lethal_attack(state: BattleState, attacker_id: int, target_id: int) -> bool:
	var attacker: Unit = state.unit_by_id(attacker_id)
	var target: Unit = state.unit_by_id(target_id)
	var predicted_damage: int = CombatRules.damage(attacker.effective_atk(), target.effective_def(), 0)
	return predicted_damage >= target.hp


## Deterministic tile tie-break — smaller y first, then smaller x — the same
## shape [code]greedy_tactical_ai.gd[/code]'s own [code]_is_better_tile[/code]
## already uses, for the identical reason (no RNG available to break a tie).
func _tile_is_before(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## Stage C — drives a single unit's turn through the REAL BattleController
## input entry point (click_tile()), never a BattleState mutator directly
## (AC-3). The move/attack decision itself comes from GreedyTacticalAI.decide()
## (faction-agnostic — see src/ai/greedy_tactical_ai.gd's own doc comment),
## fed the can_move/can_attack flags derived from this unit's CURRENT
## TurnOrder.ActionState so the AI never tries to spend a flag already spent.
##
## 🔴 ActionState direction, confirmed by reading turn_order.gd's own doc
## comment plus the TEXT_TILE_INFO_STATE_ATTACK_ONLY / _STATE_MOVE_ONLY
## caption constants in battle_screen.gd (named for what the player can STILL
## do): ATTACK_ONLY means "attack remains, move already spent"; MOVE_ONLY
## means "move remains, attack already spent".
##
## A unit may legally move THEN attack in the same call (dispatch brief trap
## note) — click_tile()'s own _apply_move() never clears _selected_unit_id
## (read from battle_controller.gd:1493-1505), so after the move click the
## same unit is still selected and the attack click targets its NEW position's
## legal targets, not a re-selection.
##
## 🔴 story-020 AC-1/AC-2: before any click happens, [method
## _apply_safety_filter] gets a chance to override [param decision] entirely
## — see that method's own doc comment for the rule it applies, in prose.
##
## 🔴 2026-10-16 coordinator finding, same-day follow-up: [method
## BattleController.click_tile]'s [code]"selected"[/code] result is the ONLY
## branch of its contract that carries a [code]"unit_id"[/code] key — the
## real production method ([code]src/gameplay/battle/battle_controller.gd[/code]
## [method BattleController.click_tile]) returns
## [code]{"action": &"blocked_pending_discard"}[/code] with NO
## [code]"unit_id"[/code] key whenever [method
## BattleController.has_pending_discard] is true
## ([code]src/gameplay/cards/card_deck.gd[/code]'s forced-discard-gate,
## story-007). Indexing [code]select_result["unit_id"][/code]
## unconditionally after that branch is a [code]SCRIPT ERROR[/code]
## ("Invalid access to property or key"), not a controlled test failure —
## measured live: a multi-round run produced exactly this crash 900 times
## before [method _resolve_any_pending_discard] existed (see that method's
## doc comment for the fix — [method
## test_real_level_battle_reaches_a_terminal_outcome] now calls it at the
## top of every round, BEFORE any unit's turn is attempted, specifically so
## this branch should no longer be reachable in the steady state). This
## guard is kept regardless: it prints the full result Dictionary plus the
## live [method BattleController.has_pending_discard] flag so the moment
## selection ever fails for ANY reason is directly visible in the log, and
## returns [code]false[/code] rather than crash on the missing key or let
## the caller re-try forever — a cheap defense against the NEXT undiscovered
## gate of this shape, not just the one this story found.
##
## Returns [code]true[/code] if this call actually changed something
## (selected-and-moved/attacked, OR explicitly ended an idle turn via
## [method BattleController.end_unit_turn] — see the [code]did_something ==
## false[/code] branch below), [code]false[/code] if nothing happened at
## all. [method _play_faction_turn_via_ai]'s pass loop uses this return
## value to know when a faction phase has genuinely stalled, instead of the
## previous "not DONE yet" proxy that could never distinguish "still has
## work to do" from "tried and failed to do anything, forever" (see that
## method's own doc comment for the bug this replaces).
func _play_unit_turn_via_ai(instance: BattleScreen, unit_id: int) -> bool:
	var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit_id)
	if (
		action_state == TurnOrder.ActionState.DONE
		or action_state == TurnOrder.ActionState.NOT_FOUND
	):
		return false
	var can_move: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.MOVE_ONLY
	)
	var can_attack: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.ATTACK_ONLY
	)
	var decision: Dictionary = GreedyTacticalAI.decide(instance._state, unit_id, can_move, can_attack)
	# story-020 AC-1/AC-2: vet the raw decision through the test-only safety
	# filter before executing anything -- see _apply_safety_filter()'s doc
	# comment for the full rule in prose.
	decision = _apply_safety_filter(instance._state, unit_id, decision)

	# AC-3: select by clicking the unit's OWN current tile first.
	var origin: Vector2i = instance._state.position_of(unit_id)
	var select_result: Dictionary = instance._controller.click_tile(origin)
	if select_result["action"] != &"selected":
		print(
			"    !! unit ", unit_id, " could not be selected -- select_result=", select_result,
			" has_pending_discard=", instance._controller.has_pending_discard()
		)
		return false
	assert_int(select_result["unit_id"]).is_equal(unit_id)

	var did_something: bool = false
	if decision["move_to"] != null:
		var move_result: Dictionary = instance._controller.click_tile(decision["move_to"])
		assert_that(move_result["action"]).is_equal(&"moved")
		did_something = true

	var attack_target: int = decision["attack"]
	if attack_target != -1:
		var target_pos: Vector2i = instance._state.position_of(attack_target)
		var attack_result: Dictionary = instance._controller.click_tile(target_pos)
		assert_that(attack_result["action"]).is_equal(&"attacked")
		did_something = true

	if not did_something:
		# story-020 AC-1/AC-2: the safety filter chose "stay put, don't
		# attack" (either the raw decision already was that, or the filter
		# overrode a risky move into one). That spends neither flag, so
		# without explicitly ending the turn here this unit would still
		# read NONE_USED next pass and _play_faction_turn_via_ai would try
		# it again, every pass, for the rest of this round -- the exact bug
		# the coordinator found (see that method's doc comment). Ending the
		# turn through the real production entry point also means this test
		# is the first to exercise BattleController.end_unit_turn() at all.
		var ended: bool = instance._controller.end_unit_turn(unit_id)
		assert_bool(ended).is_true()

	return true


## Drives every not-yet-DONE unit of faction through _play_unit_turn_via_ai(),
## repeating passes until a full pass changes nothing (handles the "moved but
## could not then attack, still has a flag left" case — see
## _play_unit_turn_via_ai's doc comment on ActionState direction). _PASS_CAP
## bounds this independently of the outer round cap so a single stuck faction
## phase cannot itself loop forever.
##
## 🔴 2026-10-16 coordinator finding, same-day follow-up: [code]acted_this_pass[/code]
## used to be set unconditionally whenever a unit was not yet DONE, regardless
## of whether [method _play_unit_turn_via_ai] actually changed anything. Once
## story-020's safety filter started legitimately choosing "stay put, don't
## attack, flags unspent" for a unit, that unit stayed NONE_USED forever (it
## never became DONE on its own), so this loop re-tried it every single pass
## up to [constant _PASS_CAP] — EVERY round, not just the ones where it
## mattered. Measured live: a 10-round run that also hit the forced-discard
## crash (see [method _play_unit_turn_via_ai]'s doc comment) produced 900
## runtime errors, matching 9 rounds (once [method
## BattleController.has_pending_discard] went true) x [constant _PASS_CAP]
## (20) x ~5 units. [method _play_unit_turn_via_ai] now returns whether it
## actually changed anything (including explicitly ending an idle unit's
## turn via [method BattleController.end_unit_turn]), and this loop uses
## THAT to decide whether another pass is worth attempting.
const _PASS_CAP: int = 20

func _play_faction_turn_via_ai(instance: BattleScreen, faction: Unit.Faction) -> void:
	var pass_count: int = 0
	while pass_count < _PASS_CAP:
		pass_count += 1
		var acted_this_pass: bool = false
		for unit: Unit in instance._state.units_of(faction):
			var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit.id)
			if (
				action_state == TurnOrder.ActionState.DONE
				or action_state == TurnOrder.ActionState.NOT_FOUND
			):
				continue
			if _play_unit_turn_via_ai(instance, unit.id):
				acted_this_pass = true
		if not acted_this_pass:
			break


## 2026-10-16 coordinator finding, same-day second follow-up — resolves any
## owed forced discard through the REAL production entry point:
## [method BattleController.resolve_forced_discard], which delegates to
## [method BattleState.card_deck]'s [method CardDeck.discard_card] — the
## exact same call [BattleLoop]'s injected [code]discard_policy[/code] path
## also ends at, per [method BattleController.resolve_forced_discard]'s own
## doc comment ("the human-driven and simulation-driven paths converge on
## one discard implementation"). This is the correct way to clear
## [CardDeck]'s forced-discard gate (story-007-forced-discard-gate.md), not
## a workaround around it.
##
## 🔴 Without this call, NOTHING in this battle can progress past the first
## turn boundary where a discard becomes owed: [method
## BattleController.click_tile] refuses every selection
## ([code]&"blocked_pending_discard"[/code]) AND [method
## BattleController.end_faction_phase] itself no-ops while [method
## BattleController.has_pending_discard] is true (its own source line is
## literally [code]if _state.has_pending_discard(): return[/code] — it does
## not even advance [method BattleController.phase]), so BOTH factions
## freeze simultaneously, forever. story-019 never hit this because its
## battle ended inside the real game's round 1, before round 1's opening
## hand (already at [constant CardDeck.HAND_SIZE_LIMIT] — see [method
## BattleState.deal_opening_hand]'s doc comment) could ever draw past its
## limit; that can only happen starting round 2's [method
## BattleState.begin_player_turn] hook.
##
## 🔴 DETERMINISTIC choice, not optional (this project's
## [code]rng_in_combat_settlement[/code] ban, plus Determinism in
## [code].claude/rules/test-standards.md[/code]): always discards
## [code]hand[0][/code] — never a random index. The CARD IDENTITIES
## [CardDeck] actually deals are themselves NOT guaranteed deterministic
## across separate runs of this test ([code]src/ui/battle/battle_screen.gd[/code]'s
## [code]_build_card_deck(cards)[/code] call site passes no [param rng]
## argument, so [method CardDeck._init] falls back to a fresh, unseeded,
## time-seeded [RandomNumberGenerator] per its own doc comment) — but this
## is harmless for this test specifically: discarding a card only ever moves
## it out of hand ([method CardDeck.discard_card]); this test never PLAYS a
## card, so no [CardModifier] effect ever fires regardless of which card
## ends up at [code]hand[0][/code]. Only the COUNT of cards in hand (not
## their identity) determines when [method
## BattleController.has_pending_discard] becomes true, and that count is
## fully deterministic — confirmed by [code]round_count[/code],
## [code]outcome()[/code], and every unit's position/HP reading
## byte-for-byte identical across two independent reruns of this exact file
## ([code]elapsed_msec[/code] itself is the one field that differs, as
## expected for a wall-clock measurement).
##
## Bounded by [constant _FORCED_DISCARD_RESOLVE_CAP] rather than an
## unconditional [code]while[/code] loop: if [method
## BattleController.has_pending_discard] is STILL true after resolving that
## many times, something OTHER than a simple over-limit discard is holding
## the flag up — a new, different discovery, not something to paper over
## with an infinite retry. The trailing assertion makes that discovery a
## loud, named test failure instead of a silent hang.
const _FORCED_DISCARD_RESOLVE_CAP: int = 10

func _resolve_any_pending_discard(instance: BattleScreen) -> void:
	var attempts: int = 0
	while instance._controller.has_pending_discard() and attempts < _FORCED_DISCARD_RESOLVE_CAP:
		attempts += 1
		var hand: Array[Card] = instance._state.card_deck().hand()
		assert_int(hand.size()).is_greater(0)
		var resolved: bool = instance._controller.resolve_forced_discard(hand[0])
		assert_bool(resolved).is_true()
	if attempts > 0:
		print("    (resolved ", attempts, " forced discard(s) via hand[0])")
	assert_bool(instance._controller.has_pending_discard()).is_false()


## AC-2 的上限 —— 刻意遠大於下方「實測」段落記下的真實量測值(見
## test_real_level_battle_reaches_a_terminal_outcome() 內的 AC-1+AC-2 斷言註解),
## 不是用猜的。觸發這個上限時,下方 AC-1+AC-2 的斷言會明確 FAILED(outcome() 仍是
## ONGOING),不會讓迴圈默默跑完後測試照樣綠燈。
##
## 🔴 2026-10-16 收尾:story-020 最終實測 round_count == 2,10 是刻意保留的餘裕 ——
## 不要把它改小貼著 2,那樣會讓這道「上限真的能攔到異常」的把關名存實亡。
const _ROUND_CAP: int = 10


func test_real_level_battle_reaches_a_terminal_outcome() -> void:
	# Arrange
	var instance: BattleScreen = _load_battle_screen_real()

	# Assert — 開局防誤報:真實 vs01 名冊是 5 對 5(grep -v "^#"
	# assets/data/units/vs01_roster.txt | awk -F, '{print $3}' | sort | uniq -c),
	# 且還沒有人採取任何行動前,outcome() 不得已經不是 ONGOING。
	assert_int(instance._state.units_of(Unit.Faction.PLAYER).size()).is_equal(5)
	assert_int(instance._state.units_of(Unit.Faction.ENEMY).size()).is_equal(5)
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.ONGOING)

	# 捕捉原始 5+5 名單的 Unit 參照(此刻全員存活)——BattleState 從不把死亡單位從
	# _units 字典移除(outcome() 自己也靠遍歷 _units.values() 判定,見其 doc comment),
	# 只標記 is_alive() == false,所以同一組參照在迴圈跑完之後讀,.hp / .is_alive()
	# 會反映最終狀態,不必另外查詢「原本是誰」。
	var player_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var enemy_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)

	# Act — 逐回合推進。我方全部透過 AC-3 要求的真實入口 click_tile() 驅動
	# (_play_faction_turn_via_ai() -> _play_unit_turn_via_ai());敵方透過 AC-4
	# 要求的真實畫面入口 _end_faction_phase_pressed() 驅動 —— 該方法本身同時負責
	# 「結束我方回合」與「逐步播放敵方整個 ENEMY_ACTING 階段」兩件事(見其原始碼
	# src/ui/battle/battle_screen.gd:3369-3391),不是本檔自己拼湊的簡化版。
	var round_count: int = 0
	var start_msec: int = Time.get_ticks_msec()
	print("=== battle_screen_real_level_battle_test diagnostic (story-020) ===")
	while instance._controller.outcome() == BattleState.Outcome.ONGOING and round_count < _ROUND_CAP:
		round_count += 1
		# story-020 coordinator finding, same-day second follow-up: a forced
		# discard owed from the PREVIOUS iteration's begin_player_turn() (set
		# while draining the enemy phase inside the previous await below)
		# must be resolved BEFORE attempting any player action this round --
		# see _resolve_any_pending_discard()'s own doc comment for why this
		# gate exists and why clearing it here is the real production entry
		# point, not a workaround.
		_resolve_any_pending_discard(instance)
		# AC-6: one line per round -- how many of each faction died THIS
		# round (not cumulative), not just the final tally. Snapshot alive
		# counts immediately before and after the round's actions so the
		# delta is attributable to this round specifically.
		var alive_player_before: int = instance._state.units_of(Unit.Faction.PLAYER).size()
		var alive_enemy_before: int = instance._state.units_of(Unit.Faction.ENEMY).size()
		if instance._controller.phase() == BattleController.Phase.PLAYER_INPUT:
			_play_faction_turn_via_ai(instance, Unit.Faction.PLAYER)
		await instance._end_faction_phase_pressed()
		var alive_player_after: int = instance._state.units_of(Unit.Faction.PLAYER).size()
		var alive_enemy_after: int = instance._state.units_of(Unit.Faction.ENEMY).size()
		print(
			"  round ", round_count,
			": PLAYER died=", alive_player_before - alive_player_after,
			" ENEMY died=", alive_enemy_before - alive_enemy_after,
			" (PLAYER alive=", alive_player_after, "/5 ENEMY alive=", alive_enemy_after, "/5)",
			" pending_discard=", instance._controller.has_pending_discard()
		)
		# 2026-10-16 coordinator follow-up: print every living unit's TILE
		# POSITION each round, not just HP -- this is the only way to
		# directly verify "did the enemy actually advance" instead of
		# inferring it from the final HP tally alone (zero HP loss is
		# ambiguous between "nobody got close enough to attack" and "attacks
		# landed but this test never observed them").
		for u: Unit in player_units_at_start:
			if u.is_alive():
				print("    PLAYER ", u.code_name, " pos=", instance._state.position_of(u.id), " hp=", u.hp)
		for u: Unit in enemy_units_at_start:
			if u.is_alive():
				print("    ENEMY  ", u.code_name, " pos=", instance._state.position_of(u.id), " hp=", u.hp)
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec

	# 🔴 診斷輸出 —— 管理者 2026-10-16 要求「第 1 回合到底發生了什麼」必須留得下來
	# 查證,不得只留結論。刻意保留在檔案裡,不要刪:逐人 code_name + HP + 存活狀態、
	# 最終 round_count、最終 outcome()。這段輸出的原始文字已逐字貼進本故事的交付
	# 報告(2026-10-16 這次重跑的原文)。
	print("=== battle_screen_real_level_battle_test diagnostic (2026-10-16) ===")
	for u: Unit in player_units_at_start:
		print("  PLAYER ", u.code_name, " (id=", u.id, ") hp=", u.hp, "/", u.hp_max, " alive=", u.is_alive())
	for u: Unit in enemy_units_at_start:
		print("  ENEMY  ", u.code_name, " (id=", u.id, ") hp=", u.hp, "/", u.hp_max, " alive=", u.is_alive())
	print("  round_count=", round_count, " outcome=", instance._controller.outcome(),
		" elapsed_msec=", elapsed_msec)
	print("=== end diagnostic ===")

	# Assert — AC-1 + AC-2:結果必須是 VICTORY 或 DEFEAT,絕不是 ONGOING。這一條
	# 斷言同時是 AC-2 要求的上限把關:若 _ROUND_CAP 回合內從未脫離 ONGOING,
	# outcome() 仍是 ONGOING,本斷言會明確 FAILED —— 不是迴圈默默跑完後測試照樣通過。
	#
	# 🔴 story-020 最終實測結果(2026-10-16,本機 Godot 4.7.1 headless,零 RNG
	# 故完全決定性,獨立連跑兩次逐字相同,僅 elapsed_msec 不同):
	# round_count == 2,outcome() == DEFEAT (2)。真回合 2 裡乙陣亡 ——
	# 座標證據顯示乙全程未移動,是被推進到近身的敵人打死,完全落在
	# _apply_safety_filter() 自己揭露的範圍限制內(該方法不介入「本回合根本
	# 沒打算移動」的單位,見其 doc comment)。
	#
	# 🔴 中途曾經有一個版本的本測試卡在 round_count == 10 == _ROUND_CAP、
	# outcome() 仍是 ONGOING —— 根因與我方打法完全無關(見本檔檔頭 AC-7
	# story-020 節的完整分析):真正的遊戲回合 1 本身進行得完全正常,直到遊戲
	# 內部推進到真正的回合 2 時,CardDeck 的強制棄牌閘門
	# (src/gameplay/cards/card_deck.gd 的 has_pending_discard(),
	# story-007-forced-discard-gate.md)鎖死了 BattleController.click_tile()
	# 的選取與 BattleController.end_faction_phase() 本身,敵我雙方都無法再推進。
	# 這不是靠調整我方 AI 能修好的,而是靠 _resolve_any_pending_discard() 在每回合
	# 開始前呼叫遊戲【已經提供】的 BattleController.resolve_forced_discard()
	# 正式解除 —— 見該方法自己的 doc comment。
	assert_bool(
		instance._controller.outcome() == BattleState.Outcome.VICTORY
		or instance._controller.outcome() == BattleState.Outcome.DEFEAT
	).is_true()

	# Assert — AC-5:耗時必須量測並揭露。🔴 story-020 最終實測 elapsed_msec
	# 落在 4977~5073ms 區間(本機 Godot 4.7.1 headless,兩次獨立重跑),
	# 遠低於 30 秒門檻,未觸發「停下來回報」。斷言只設一個遠高於實測值的安全
	# 上限,理由與 _ROUND_CAP 相同:上限要存在且會在真的異常變慢時明確失敗,
	# 不是用來卡一個精確數字。
	assert_int(elapsed_msec).is_less(30000)
