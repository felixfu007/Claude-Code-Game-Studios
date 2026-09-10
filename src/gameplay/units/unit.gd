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
var hp: int
var atk: int
var def: int
var mp: int
var min_range: int
var max_range: int
var start_pos: Vector2i

# Currently active card-driven ATK/DEF modifiers (skill-card-system #6,
# story-001-modifier-model.md). Never transferred to another Unit and never
# survives this unit's death — see take_damage()'s doc comment. Owned
# exclusively through add_modifier() / active_modifiers() / tick_modifiers() /
# clear_modifiers() below; nothing outside this file appends to, mutates, or
# reads this array directly.
var _modifiers: Array[CardModifier] = []


## Parses a single roster line into a [Unit]. [member hp] is initialized to
## [member hp_max]. Field order is fixed: [code]id,code_name,faction,hp_max,
## atk,def,mp,min_range,max_range,start_x,start_y[/code].
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
	unit.faction = _faction_from_string(fields[2])
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
static func roster_from_text(text: String) -> Array[Unit]:
	var roster: Array[Unit] = []
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		roster.append(Unit.from_csv_line(line))
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
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		clear_modifiers()


## Maps the roster file's faction string to a [enum Faction] value.
static func _faction_from_string(value: String) -> Faction:
	match value:
		"PLAYER":
			return Faction.PLAYER
		"ENEMY":
			return Faction.ENEMY
		_:
			assert(false, "Unit._faction_from_string: unknown faction '%s'" % value)
			return Faction.PLAYER
