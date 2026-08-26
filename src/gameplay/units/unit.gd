## Roster/unit data for the tactical layer: stats, position, faction.
##
## Pure data holder — no combat math lives here. Damage, range legality, and
## enemy stat scaling are owned by [CombatRules]
## ([code]src/gameplay/combat/combat_rules.gd[/code]); this class only
## parses and stores the values that combat math consumes.
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


## Reduces [member hp] by [param amount], clamped at 0 — [member hp] never
## goes negative.
func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)


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
