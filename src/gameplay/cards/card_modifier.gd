## A single temporary battle-stat modifier applied to a [Unit] by a played
## card (甲類, "class-A" cards — `design/gdd/skill-card-system.md` #6).
##
## Pure data holder — carries no arithmetic of its own. Aggregation, clamping,
## and the ≥0 floor over a collection of these are owned by
## [CardModifierRules] ([code]src/gameplay/cards/card_modifier_rules.gd[/code]).
## Multiple [CardModifier]s can be attached to the same [Unit] at once
## (`Unit._modifiers`); they stack by plain summation — this class does not
## know about, or interact with, any other instance.
##
## [member remaining_turns] is stored here so the read-only listing query
## (`Unit.active_modifiers()`, GDD OQ-12) can report it per entry, but this
## class does not decrement or expire itself — that lifecycle (turn-start
## countdown, removal at 0) is Story 002's responsibility
## (`story-002-modifier-lifecycle.md`), not implemented here.
class_name CardModifier
extends RefCounted

## Human/debug-readable identifier for where this modifier came from (e.g. a
## card's name or id). Purely descriptive — no game logic branches on this
## value in this class or in [CardModifierRules].
var source_name: String

## Signed ATK contribution of this single modifier. Zero if this modifier
## does not affect ATK.
var atk_delta: int

## Signed DEF contribution of this single modifier. Zero if this modifier
## does not affect DEF.
var def_delta: int

## Turns remaining before this modifier expires. Owned/mutated by Story 002's
## lifecycle logic, not by this class.
var remaining_turns: int


func _init(
	p_source_name: String = "",
	p_atk_delta: int = 0,
	p_def_delta: int = 0,
	p_remaining_turns: int = 0
) -> void:
	source_name = p_source_name
	atk_delta = p_atk_delta
	def_delta = p_def_delta
	remaining_turns = p_remaining_turns


## Returns a new [CardModifier] with the same field values. Used to hand out
## read-only copies from [method Unit.active_modifiers] — callers can freely
## mutate the returned instance without it ever affecting the [Unit]'s actual
## modifier list, since it shares no reference with anything the [Unit]
## still holds.
func clone() -> CardModifier:
	return CardModifier.new(source_name, atk_delta, def_delta, remaining_turns)
