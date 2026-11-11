extends RefCounted
enum R { NONE = 0, BAD_A = 1, BAD_B = 2 }
static var side: int = 0
static func _bump() -> bool:
	side += 1
	return false
static func f_void() -> void:
	print("T1 BEFORE")
	assert(false, "probe")
	print("T1 AFTER_ASSERT")
static func f_enum() -> R:
	assert(false, "probe enum")
	return R.BAD_B
static func f_side() -> void:
	assert(_bump(), "side-effect probe")
static func encode_tile(cell: Vector2i, w: int) -> int:
	assert(w > 0, "w>0")
	assert(cell.x >= 0 and cell.x < w, "x range")
	assert(cell.y >= 0, "y>=0")
	return cell.y * w + cell.x
static func decode_tile(id: int, w: int) -> Vector2i:
	assert(w > 0, "w>0")
	assert(id >= 0, "id>=0")
	return Vector2i(id % w, id / w)
static func run() -> void:
	f_void()
	print("T2 RET=", f_enum(), " is_NONE=", f_enum() == R.NONE)
	f_side()
	print("T3 SIDE_EFFECT_EVALUATED_COUNT=", side)
	print("T4 encode_tile((-1,0),13)=", encode_tile(Vector2i(-1, 0), 13))
	print("T4 encode_tile((13,0),13)=", encode_tile(Vector2i(13, 0), 13), " (collides with (0,1)=", encode_tile(Vector2i(0, 1), 13), ")")
	print("T5 decode_tile(-1,13)=", decode_tile(-1, 13))
	if "skip6" in OS.get_cmdline_user_args():
		print("T6 SKIPPED")
	else:
		print("T6 decode_tile(5,0)=", decode_tile(5, 0))
	print("DONE")
