## Roster/unit data for the tactical layer: stats, position, faction.
##
## Pure data holder — no combat math lives here. Damage, range legality, and
## enemy stat scaling are owned by [CombatRules]
## ([code]src/gameplay/combat/combat_rules.gd[/code]); the ATK/DEF modifier
## stack's clamp-and-floor arithmetic is owned by [CardModifierRules]
## ([code]src/gameplay/cards/card_modifier_rules.gd[/code]). This class only
## parses and stores the values that combat math and modifier math consume,
## including the list of currently active [CardModifier]s
## ([member _modifiers]) — it never computes a clamp or a floor itself.
class_name Unit
extends RefCounted

## Faction a unit belongs to.
enum Faction { PLAYER, ENEMY }

## Number of comma-separated fields expected per roster line, in fixed order:
## id,code_name,faction,hp_max,atk,def,mp,min_range,max_range,start_x,start_y
const FIELD_COUNT: int = 11

var id: int
var code_name: String
var faction: Faction
var hp_max: int

## story-017-unit-combat-field-setters.md (ADR-0001 硬性義務第 2 條): optional
## write-window guard, same selective-mount contract as [method
## Board.attach_write_guard] / [method TurnOrder.attach_write_guard] — unset
## by default (invalid [Callable]), in which case every one of the six
## guarded properties below behaves exactly as a plain [code]var[/code]
## always did. [Unit] remains a fully standalone, directly-constructible
## [RefCounted] for every existing [method from_csv_line] / [code]Unit.new()[/code]
## test fixture that never goes through [BattleState] at all — see
## [method attach_write_guard].
var _write_guard: Callable = Callable()


## Attaches [param checker] (signature [code]func() -> bool[/code]) as this
## unit's write-window guard — checked by each of the six guarded setters
## below before mutating, rejecting the assignment (via [method
## @GlobalScope.push_error], value left unchanged) if it returns
## [code]false[/code]. [method BattleState.create] is the only production
## caller, passing [code]Callable(state, "write_window_is_open")[/code] — a
## [Callable] injection, deliberately NOT a reference to [BattleState]
## itself, matching [method Board.attach_write_guard]'s and [method
## TurnOrder.attach_write_guard]'s own doc comments (ADR-0001's layering:
## [Unit] "does not hold the flag"). Passing an unset/invalid [Callable]
## restores the pre-guard default (always permitted) — this is a legitimate,
## supported call, not an edge case to avoid.
func attach_write_guard(checker: Callable) -> void:
	_write_guard = checker


# Shared by all six guarded setters below: true if this mutation may
# proceed — no guard attached (selective mount) or the attached guard
# reports the write window open. Identical shape to
# [method Board._write_allowed] / [method TurnOrder._write_allowed] — see
# [member _write_guard]'s doc comment for why all three must share one
# contract.
func _write_allowed() -> bool:
	return not _write_guard.is_valid() or bool(_write_guard.call())


# Backing fields for the six guarded combat-value properties below. Actual
# storage lives here, never directly under the public property name — see
# each property's doc comment for the guard contract.
var _hp: int
var _atk: int
var _def: int
var _mp: int
var _min_range: int
var _max_range: int

## Current hit points. Guarded property (story-017-unit-combat-field-setters.md,
## ADR-0001 硬性義務第 2 條): rejects assignment (via [method
## @GlobalScope.push_error], value left unchanged) if a write guard is
## attached ([method attach_write_guard]) and reports the write window
## closed. Unguarded [Unit]s (the selective-mount default) accept assignment
## unconditionally, exactly as before this property existed.
##
## 🔴 [method take_damage] does NOT go through this setter — it writes
## [member _hp] directly, bypassing the guard entirely. See that method's
## doc comment for why ("未決的實作細節" 第 1 項, 選項 B).
var hp: int:
	get:
		return _hp
	set(value):
		if not _write_allowed():
			push_error("Unit.hp: rejected -- write window is not open (value=%d)" % value)
			return
		_hp = value


## Base attack value — see [method effective_atk] for the base/effective
## seam this value feeds. Guarded property; same contract as [member hp]
## above.
var atk: int:
	get:
		return _atk
	set(value):
		if not _write_allowed():
			push_error("Unit.atk: rejected -- write window is not open (value=%d)" % value)
			return
		_atk = value


## Base defense value — see [method effective_def] for the base/effective
## seam this value feeds. Guarded property; same contract as [member hp]
## above.
var def: int:
	get:
		return _def
	set(value):
		if not _write_allowed():
			push_error("Unit.def: rejected -- write window is not open (value=%d)" % value)
			return
		_def = value


## Movement points. Guarded property; same contract as [member hp] above.
var mp: int:
	get:
		return _mp
	set(value):
		if not _write_allowed():
			push_error("Unit.mp: rejected -- write window is not open (value=%d)" % value)
			return
		_mp = value


## Minimum attack range. Guarded property; same contract as [member hp]
## above.
var min_range: int:
	get:
		return _min_range
	set(value):
		if not _write_allowed():
			push_error("Unit.min_range: rejected -- write window is not open (value=%d)" % value)
			return
		_min_range = value


## Maximum attack range. Guarded property; same contract as [member hp]
## above.
var max_range: int:
	get:
		return _max_range
	set(value):
		if not _write_allowed():
			push_error("Unit.max_range: rejected -- write window is not open (value=%d)" % value)
			return
		_max_range = value


var start_pos: Vector2i

# Currently active card-driven ATK/DEF modifiers (skill-card-system #6,
# story-001-modifier-model.md). Never transferred to another Unit and never
# survives this unit's death — see take_damage()'s doc comment. Owned
# exclusively through add_modifier() / active_modifiers() / tick_modifiers() /
# clear_modifiers() below; nothing outside this file appends to, mutates, or
# reads this array directly.
var _modifiers: Array[CardModifier] = []


## Parses a single roster line into a [Unit], or returns [code]null[/code] if
## [param line]'s faction field is not a recognized [enum Faction] name. Field
## order is fixed: [code]id,code_name,faction,hp_max,
## atk,def,mp,min_range,max_range,start_x,start_y[/code].
##
## 🔴 Returns [code]null[/code] rather than asserting on an unrecognized
## faction string — per [code].claude/docs/coding-standards.md[/code]'s
## 2026-09-15 entry, an [code]assert()[/code] on that branch would abort and
## silently yield ordinal 0 of [enum Faction] ([constant Faction.PLAYER]),
## indistinguishable from a genuine [code]"PLAYER"[/code] match. Concretely: a
## roster row whose faction column is typo'd would silently be treated as a
## player unit instead of failing loudly — this is the exact defect
## `.claude/docs/coding-standards.md`'s rule and this change both exist to
## prevent. [method roster_from_text] is the caller that turns a
## [code]null[/code] result here into a loud, whole-roster parse failure —
## see that method's doc comment.
static func from_csv_line(line: String) -> Unit:
	var fields: PackedStringArray = line.split(",")
	assert(
		fields.size() == FIELD_COUNT,
		"Unit.from_csv_line: expected %d fields, got %d in line: %s"
		% [FIELD_COUNT, fields.size(), line]
	)

	var unit: Unit = Unit.new()
	unit.id = int(fields[0])
	unit.code_name = fields[1]
	var faction: Variant = _faction_from_string(fields[2])
	if faction == null:
		push_error(
			"Unit.from_csv_line: unknown faction '%s' in line: %s" % [fields[2], line]
		)
		return null
	unit.faction = faction
	unit.hp_max = int(fields[3])
	unit.hp = unit.hp_max
	unit.atk = int(fields[4])
	unit.def = int(fields[5])
	unit.mp = int(fields[6])
	unit.min_range = int(fields[7])
	unit.max_range = int(fields[8])
	unit.start_pos = Vector2i(int(fields[9]), int(fields[10]))
	return unit


## Parses an entire roster text blob (as read from a roster data file) into
## an array of [Unit]s, one per non-skipped line. Blank lines and lines
## starting with [code]#[/code] are skipped.
##
## 🔴 If any non-skipped line fails to parse (currently: an unrecognized
## faction string — see [method from_csv_line]), the [b]entire[/b] result is
## discarded and an empty array is returned, after logging the 1-based line
## number of the offending row via [method @GlobalScope.push_error]. This is
## deliberate, per the 2026-09-16 manager ruling for this failure ("響亮地停"
## — loud stop, not skip-and-continue): a roster that is partially valid must
## not be used as if it were fully valid.
##
## This empty-array result is what [code]src/ui/battle/battle_screen.gd[/code]'s
## [code]_ready()[/code] already treats as [constant
## BattleScreen.LoadFailure.PARSED_EMPTY] via [method
## BattleScreen.classify_content] — unlike the affinity table (see [method
## AffinityLink.links_from_text]'s doc comment), a roster that parses to zero
## units was already a hard load failure before this change, so no caller
## change was needed to make a corrupted roster row stop the battle from
## starting.
static func roster_from_text(text: String) -> Array[Unit]:
	var roster: Array[Unit] = []
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var unit: Unit = Unit.from_csv_line(line)
		if unit == null:
			push_error(
				"Unit.roster_from_text: aborting -- invalid data at line %d: %s"
				% [line_number, line]
			)
			return []
		roster.append(unit)
	return roster


## Returns [code]true[/code] if this unit still has HP remaining.
func is_alive() -> bool:
	return hp > 0


## Returns this unit's currently effective ATK — the value combat math must
## read, as opposed to [member atk] (the roster-parsed base value). [member
## atk] itself is never mutated by this method or by [method add_modifier]:
## it stays the roster-parsed baseline for this unit's entire lifetime, and
## every active [CardModifier] is layered on top of it fresh on each call.
## The clamp-and-floor arithmetic is delegated to
## [method CardModifierRules.effective_atk] — see that method's doc comment
## for the formula (skill-card-system #6, story-001-modifier-model.md).
func effective_atk() -> int:
	return CardModifierRules.effective_atk(atk, _modifiers)


## Returns this unit's currently effective DEF — see [method effective_atk]
## for the full rationale; the same seam applies symmetrically to DEF via
## [method CardModifierRules.effective_def].
func effective_def() -> int:
	return CardModifierRules.effective_def(def, _modifiers)


## story-006-atk-def-phi-breakdown-query.md (#6 skill-card-system's registered
## reverse dependency; GDD "基準值/有效值存取層" — not yet written up by
## `systems-designer` as of this story, see that story's own Context section):
## a single read-only query exposing BOTH the baseline and the currently
## effective value for all four of this unit's roster-parsed stats —
## [code]"atk"[/code], [code]"def"[/code], [code]"hp"[/code], [code]"mp"[/code]
## — each as [code]{"base": int, "effective": int}[/code]. Returns a fresh
## [Dictionary] (and fresh inner Dictionaries) every call; no internal state
## is ever handed out by reference. This method is the ENTIRE surface of this
## access layer — it provides no write/mutate counterpart (Implementation
## Notes #4: reading, never modifying, is this layer's contract).
##
## 🔴 The four stats are NOT uniform underneath this common shape — read each
## note below before assuming one generalizes to another (GDD: "HP/MP 不與
## ATK/DEF 同構,不得類推套用"):
## [br]
## - [code]"atk"[/code]/[code]"def"[/code]: base = [member atk]/[member def]
##   (the roster-parsed value, constant for this unit's entire battle
##   lifetime); effective = [method effective_atk]/[method effective_def]
##   (base plus whatever [CardModifier]s are currently active). This is the
##   "base + additive modifier stack" composition GDD Formula 一/#6 define.
## [br]
## - [code]"hp"[/code]: base = [member hp_max]; effective = [member hp] (the
##   CURRENT value). This is NOT a "base + modifier" composition — [member hp]
##   is a monotonically-decreasing battle-state value ([method take_damage]),
##   never something a [CardModifier] stack layers onto. "base" here only
##   means "the ceiling this unit started the battle at".
## [br]
## - [code]"mp"[/code]: base = effective = [member mp], always, because there
##   is NO modifier mechanism over movement points anywhere in today's
##   codebase — verified 2026-10-12,
##   [code]grep -rn "\.mp\b" src/gameplay/cards/[/code] returns zero hits.
##   This is reported honestly as "no effective layer exists yet", not
##   simulated by a fake pass-through that LOOKS like ATK/DEF's shape but
##   isn't backed by anything.
## [br]
## ⚠️ [code]Φ[/code] (the damage formula's flat modifier term) is
## deliberately NOT one of these four — it is an independent additive term in
## [method CombatRules.damage] / [method BattleState.preview_damage_breakdown],
## never composed through this base/effective seam.
## [br]
## ⚠️ An ENEMY unit's "pre-scaling baseline" (GDD Formula 二,
## [method CombatRules.enemy_stat]) has NO representation here or anywhere in
## today's roster data model — verified 2026-10-12,
## [code]grep -rn "enemy_stat(" src/ --include=*.gd | grep -v ":#"[/code]
## returns exactly ONE line — the function's own definition in
## [code]combat_rules.gd[/code]. Zero production call sites.
## [br]
## 🔴 The [code]grep -v ":#"[/code] is load-bearing, not tidiness: without
## it this very comment is itself a hit, and so is any future comment that
## quotes the command. A verification command that matches its own
## documentation reports a number that grows every time someone writes it
## down — the reader then cannot tell a real new call site from another
## mention. Filtering comment lines makes the count stable at the thing it
## is actually measuring. The roster
## file format ([constant FIELD_COUNT] = 11 columns) carries no "pre-scaling
## value" column. For every ENEMY [Unit] that exists in this project today,
## [member atk]/[member def] already ARE whatever value design put in the
## roster row — this method's [code]"base"[/code] for an ENEMY unit is that
## stored value, not a reverse-derived pre-scaling number. This story does
## not decide the application order of scaling vs. card modifiers for a
## future ENEMY-with-modifiers case — that is GDD's own registered open
## question, not resolved here.
func stat_access_view() -> Dictionary:
	return {
		"atk": {"base": atk, "effective": effective_atk()},
		"def": {"base": def, "effective": effective_def()},
		"hp": {"base": hp_max, "effective": hp},
		"mp": {"base": mp, "effective": mp},
	}


## Attaches [param modifier] to this unit — it stacks additively with any
## other active modifiers (see [CardModifierRules]) starting from the very
## next [method effective_atk]/[method effective_def] call. Does not clone
## [param modifier]; the caller must not keep mutating the instance it hands
## in if it wants this unit's effective values to stay stable between reads.
func add_modifier(modifier: CardModifier) -> void:
	_modifiers.append(modifier)


## Returns a read-only, per-entry snapshot of every [CardModifier] currently
## active on this unit — source, signed ATK/DEF delta, and remaining turns
## per entry, as required by GDD OQ-12 (`design/gdd/skill-card-system.md`
## #6, "逐條可讀的查詢"). Each returned [CardModifier] is an independent
## [method CardModifier.clone], and the array itself is a new [Array] — the
## caller mutating either the array or any entry it contains can never affect
## this unit's actual modifier state. Order matches attachment order; there
## is no other defined ordering.
func active_modifiers() -> Array[CardModifier]:
	var result: Array[CardModifier] = []
	for modifier: CardModifier in _modifiers:
		result.append(modifier.clone())
	return result


## Story 002's turn-decrement step (`story-002-modifier-lifecycle.md`, GDD
## Formula 二): decrements [member CardModifier.remaining_turns] by 1 on
## every currently active modifier, then removes — from this unit's actual
## internal list, not merely from what a later query happens to report —
## every modifier whose [member CardModifier.remaining_turns] is now [code]<=
## 0[/code]. Mutates the [CardModifier] instances this unit already holds
## in place (unlike [method active_modifiers], which only ever hands out
## clones); this is deliberate, since this is the one path in the project
## allowed to change [member CardModifier.remaining_turns] after a card was
## played.
##
## 🔴 Removal happens here, synchronously, before this method returns — never
## deferred to the next [method effective_atk] / [method effective_def] /
## [method active_modifiers] call. This is load-bearing, not a style choice:
## the story's AC-4 requires that the round a modifier expires in, the
## [i]first[/i] query of that round already reflects the removal, and a
## design that instead filtered expired-but-still-present entries out at
## query time would make [method active_modifiers] keep reporting a
## zero-or-negative-[code]remaining_turns[/code] entry that was never
## actually taken out of [member _modifiers] — which is exactly the failure
## mode the story's own sensitivity-proof instruction calls out
## ("把「遞減後移除」改成「查詢後移除」").
##
## Callers do not invoke this per-unit directly during normal play — see
## [method BattleState.tick_all_modifiers], the single shared "a player turn
## just started" hook both battle drivers call into.
func tick_modifiers() -> void:
	var still_active: Array[CardModifier] = []
	for modifier: CardModifier in _modifiers:
		modifier.remaining_turns -= 1
		if modifier.remaining_turns > 0:
			still_active.append(modifier)
	_modifiers = still_active


## Discards every currently active [CardModifier] on this unit unconditionally
## — regardless of [member CardModifier.remaining_turns] — the same effect
## [method take_damage] already applies on death, factored out here so
## [method BattleState.clear_all_modifiers] (the battle-end AC-11a hook) has
## one call to make per unit instead of reaching into [member _modifiers]
## itself.
func clear_modifiers() -> void:
	_modifiers.clear()


## Reduces [member hp] by [param amount], clamped at 0 — [member hp] never
## goes negative. When this reduces [member hp] to exactly 0, every active
## [CardModifier] is discarded immediately in the same call: a dead unit's
## modifiers do not transfer, do not persist, and are not readable through
## [method active_modifiers] or [method effective_atk]/[method effective_def]
## by any caller from this point on — see story-001-modifier-model.md's
## "甲類修正隨宿主單位陣亡消失" supplementary test.
##
## 🔴 story-017-unit-combat-field-setters.md ("未決的實作細節" 第 1 項, 選項
## B): writes [member _hp] directly instead of going through the public
## [member hp] setter, deliberately BYPASSING that setter's write-window
## guard check entirely. This mirrors [method Board._set_occupant] / [method
## Board._clear_occupant]'s status as the trusted internal mutation entry
## point for their class — [method take_damage] is this class's equivalent
## trusted entry point for HP loss, and is therefore callable unconditionally,
## regardless of whether a write guard is attached or whether the write
## window is currently open. Chosen over the alternative (routing through
## the guarded [member hp] setter, which would require this method's 7
## existing call sites — 6 of which are direct test calls that never go
## through [BattleState] at all — to only ever fire inside a [method
## BattleState.commit_authoritative_change] window) specifically to leave
## those call sites byte-for-byte unaffected by this story. See the story's
## own "未決的實作細節" section for the full tradeoff discussion between the
## two options.
func take_damage(amount: int) -> void:
	_hp = maxi(0, _hp - amount)
	if _hp == 0:
		clear_modifiers()


## Maps the roster file's faction string to a [enum Faction] value, or
## returns [code]null[/code] if [param value] is not a recognized name.
##
## 🔴 Returns [code]null[/code] on the unknown branch instead of
## [code]assert(false, ...)[/code] — see [method from_csv_line]'s doc comment
## for why an assert here is exactly the pattern
## [code].claude/docs/coding-standards.md[/code] banned on 2026-09-15: it
## would abort and silently return ordinal 0 of [enum Faction] ([constant
## Faction.PLAYER]), making an unknown string indistinguishable from a genuine
## [code]"PLAYER"[/code] match. [method from_csv_line] is the sole caller and
## is responsible for turning [code]null[/code] into a loud failure; this
## method itself never logs or aborts.
static func _faction_from_string(value: String) -> Variant:
	match value:
		"PLAYER":
			return Faction.PLAYER
		"ENEMY":
			return Faction.ENEMY
		_:
			return null
