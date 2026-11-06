extends SceneTree
## 量每關開場好感度連線可見性。只 headless。讀數全來自真實 BattleScreen。
## 私有成員讀取:inst._relation_minimap._statuses(BattleScreen 傳給關係圖的真實 statuses,含 distance/delta)、
## inst._board_view._affinity_line_layer(棋盤實際畫出的 Line2D)、inst._hide_affinity_display_for_this_battle。
## 為何全用 load() 而非全域類別名:-s 腳本編譯時 Autoload 尚未註冊,靜態引用 BattleScreen 會 Compile Error。
const SEQS: Array[String] = [
	"res://assets/data/levels/tutorial_sequence.txt",
	"res://assets/data/levels/campaign_sequence.txt",
]

func _initialize() -> void:
	_run()

func _rows(path: String) -> Array:
	var out: Array = []
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	for line: String in f.get_as_text().split("\n"):
		var t: String = line.strip_edges()
		if t == "" or t.begins_with("#"):
			continue
		out.append(t.split(","))
	return out

func _run() -> void:
	var BS: GDScript = load("res://src/ui/battle/battle_screen.gd")
	var ALS: GDScript = load("res://src/gameplay/affinity/affinity_line_status.gd")
	var BV: GDScript = load("res://src/ui/battle/board_view.gd")
	var scene: PackedScene = load("res://src/ui/battle/BattleScreen.tscn")
	var total: int = 0
	var hidden_total: int = 0
	var summary: Array[String] = []
	for seq: String in SEQS:
		var tag: String = "TUT" if seq.contains("tutorial") else "VS"
		for row: PackedStringArray in _rows(seq):
			var inst: Node = scene.instantiate()
			inst.terrain_path_override = row[1]
			inst.roster_path_override = row[2]
			inst.affinity_path_override = row[3]
			inst.cards_path_override = row[4]
			inst.card_text_path_override = row[5]
			root.call_deferred("add_child", inst)
			await process_frame
			await process_frame
			print("LEVEL %s%s injected terrain=%s roster=%s affinity=%s" % [tag, row[0], row[1], row[2], row[3]])
			print("  resolved=", inst.diagnostic_resolved_data_paths())
			var statuses: Array = inst._relation_minimap._statuses
			var drawn_strokes: int = 0
			for c: Node in inst._board_view._affinity_line_layer.get_children():
				if c is Line2D:
					drawn_strokes += 1
			var diag: Array = inst.diagnostic_relation_minimap_lines()
			var hidden: int = 0
			for i: int in range(statuses.size()):
				var s: Object = statuses[i]
				var style: Dictionary = BS.line_style_for(s)
				var drawn: bool = not style.is_empty()
				if not drawn:
					hidden += 1
				print("  PAIR %d,%d dist=%d delta=%d state=%s shape=%s drawn=%s (diag shape=%s)" % [
					s.unit_id, s.partner_id, s.distance, s.delta,
					ALS.State.keys()[s.state],
					BV.LineShape.keys()[BS.line_shape_for(s)],
					str(drawn), str(diag[i]["shape"])])
			print("  hide_affinity_flag=%s board_Line2D_children=%d (=%d lines x2 strokes)" % [
				str(inst._hide_affinity_display_for_this_battle), drawn_strokes, drawn_strokes / 2])
			var line: String = "%s%s pairs=%d undrawn=%d board_lines=%d" % [tag, row[0], statuses.size(), hidden, drawn_strokes / 2]
			print("  LEVEL_SUMMARY ", line)
			summary.append(line)
			total += statuses.size()
			hidden_total += hidden
			inst.queue_free()
			await process_frame
	print("TOTAL pairs=%d undrawn=%d" % [total, hidden_total])
	for l: String in summary:
		print("SUMMARY ", l)
	quit()
