## story-059 成因實測探針:載入真實 BattleScreen,開圖例,印出圖示實際外框與文字矩形。
## 用法:godot --headless --path . -s res://prototypes/story-059-legend-layout-evidence-2026-11-17/probe_cause.gd
extends SceneTree

const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"


func _init() -> void:
	var inst: BattleScreen = load(SCENE).instantiate()
	inst.terrain_path_override = "res://assets/data/levels/test_fixture_terrain_duel.txt"
	inst.roster_path_override = "res://assets/data/units/test_fixture_roster_duel.txt"
	root.call_deferred("add_child", inst)
	await process_frame
	await process_frame
	var panel: LegendPanel = inst.legend_panel()
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		panel.open(size)
		print("SIZE ", size, " iscale=", LegendPanel.icon_scale_for(size), " fpx=", HudLayout.font_size(size))
		for kind: int in [BoardView.MarkerKind.MOVE_RANGE, BoardView.MarkerKind.ATTACK_RANGE]:
			var sample: Node2D = panel.icon_for(kind)
			var holder: Control = sample.get_parent()
			var b: Rect2 = BoardView.legend_sample_bounds(sample)
			var r: Rect2 = Rect2(holder.position + sample.position + b.position * sample.scale, b.size * sample.scale)
			var n: Label = panel.name_label_for(kind)
			var d: Label = panel.desc_label_for(kind)
			print("  kind ", kind, " holder=", holder.position, " sample.pos=", sample.position,
				" actual_icon_rect=", r, " name=", Rect2(n.position, n.size), " desc=", Rect2(d.position, d.size),
				" icon∩name=", r.intersects(Rect2(n.position, n.size)))
	quit()
