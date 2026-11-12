extends SceneTree
## Microbenchmark: BoardView.render_pieces with vs without "label" field.
## Loads the REAL BoardView.tscn (real class, real scene; no production host chain needed
## because render_pieces only touches BoardView's own layers).
## Run: godot --headless --path . -s res://prototypes/piece-label-perf-2026-11-12/bench.gd

const N: int = 100
const RUNS: int = 3

func _pieces(with_label: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in range(10):
		var d: Dictionary = {
			"cell": Vector2i(i % 12, i / 2), "faction": "PLAYER" if i < 5 else "ENEMY",
			"sprite_index": i % 5, "hp": 10, "hp_max": 20,
		}
		if with_label:
			d["label"] = "藍" if i < 5 else str(i - 4)
		out.append(d)
	return out

func _time(view: BoardView, with_label: bool) -> float:
	var pieces: Array[Dictionary] = _pieces(with_label)
	view.render_pieces(pieces)  # warm-up (texture load, font cache)
	var t0: int = Time.get_ticks_usec()
	for _i: int in range(N):
		view.render_pieces(pieces)
	return (Time.get_ticks_usec() - t0) / 1000.0

func _count_all(v: Node) -> int:
	var lay: Node = v.get_node_or_null("PieceLabelLayer")
	return _count(v.get_node("StatsLayer")) + (_count(lay) if lay != null else 0)

func _count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _count(ch)
	return c

func _median(a: Array[float]) -> float:
	var s: Array[float] = a.duplicate()
	s.sort()
	return s[s.size() / 2]

var _view: BoardView = null
var _frames: int = 0

func _initialize() -> void:
	_view = (load("res://src/ui/battle/BoardView.tscn") as PackedScene).instantiate()
	root.call_deferred("add_child", _view)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_run(_view)
	return false

func _run(view: BoardView) -> void:
	var no_l: Array[float] = []
	var yes_l: Array[float] = []
	for r: int in range(RUNS):  # interleaved to share machine noise
		no_l.append(_time(view, false))
		yes_l.append(_time(view, true))
	var stats: Node = view.get_node("StatsLayer")
	view.render_pieces(_pieces(true))
	var n_with: int = _count_all(view)
	view.render_pieces(_pieces(true)); view.render_pieces(_pieces(true))
	var n_with_after: int = _count_all(view)
	view.render_pieces(_pieces(false))
	var n_without: int = _count_all(view)
	print("BENCH N=%d renders x10 pieces; no_label ms runs=%s median=%.1f" % [N, no_l, _median(no_l)])
	print("BENCH with_label ms runs=%s median=%.1f" % [yes_l, _median(yes_l)])
	print("BENCH overhead = %.1f%%" % ((_median(yes_l) / _median(no_l) - 1.0) * 100.0))
	print("BENCH stats_layer nodes: with_label=%d after 2 more renders=%d without_label=%d" % [n_with, n_with_after, n_without])
	quit(0)
