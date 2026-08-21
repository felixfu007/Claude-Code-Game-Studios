class_name SkelFixture
extends RefCounted
# 共用夾具。刻意持有 source 的強參照 —— 見 t_h 的量測:
# Callable 不會讓它綁定的 RefCounted 續命。

const GAME_RULESET_VERSION: int = 5
const TACTICAL_ID: String = "tactical_board"

var source: FakeAffinitySource = FakeAffinitySource.new()
var registry: SaveBlockRegistry = SaveBlockRegistry.new()

func _init(register_all: bool = true) -> void:
	if register_all:
		registry.register(FakeAffinitySource.SOURCE_ID, source.validate_semantics)
		registry.register(TACTICAL_ID, source.validate_tactical)

func writer_input(record_count: int, bad_c: bool = false) -> Array:
	var p: Dictionary = source.export_state(record_count)
	if bad_c:
		var recs: Array = p["records"]
		if recs.size() > 0:
			var r0: Dictionary = recs[0]
			r0["c"] = 99  # 型別合法(int)、值域不合 -> 只能由語意驗證器攔
	return [
		{
			"source_id": FakeAffinitySource.SOURCE_ID,
			"format_version": FakeAffinitySource.FORMAT_VERSION,
			"payload": p,
			"migration_completion_marker": null,
		},
		{
			"source_id": TACTICAL_ID,
			"format_version": 1,
			"payload": {"turn": 7, "tiles": [1, 2, 3], "board_version": 42},
			"migration_completion_marker": 12,
		},
	]

func build(record_count: int, ruleset_version: int = GAME_RULESET_VERSION,
		bad_c: bool = false) -> SaveWriter.WriteResult:
	var w := SaveWriter.new()
	return w.build(ruleset_version, writer_input(record_count, bad_c))

func reader() -> SaveReader:
	return SaveReader.new(registry)

static func write_file(path: String, buf: PackedByteArray) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "OPEN-WRITE-FAILED err=%d" % FileAccess.get_open_error()
	f.store_buffer(buf)
	f.close()
	return ""

static func read_file(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var n: int = f.get_length()
	var b: PackedByteArray = f.get_buffer(n)
	f.close()
	return b
