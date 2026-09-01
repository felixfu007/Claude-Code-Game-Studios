class_name BoardProbe
extends RefCounted

# Mirrors the shape ADR-0001 proposes for Board.board_version /
# Board.settlement_in_progress: private backing field + public read-only
# property with a guarded setter that rejects external writes.

var _board_version: int = 0
var board_version: int:
	get:
		return _board_version
	set(value):
		push_error("board_version is read-only outside BoardProbe; rejected external write of %d" % value)


func commit_settlement_boundary() -> void:
	# Internal write path -- goes straight at the backing field, never
	# through the public property's own setter.
	_board_version += 1
