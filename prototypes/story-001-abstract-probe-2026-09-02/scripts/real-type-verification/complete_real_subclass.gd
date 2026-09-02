# Control group: concrete subclass of the REAL MouseReclaimPolicy, implementing
# all 4 @abstract methods with the real CursorTypes.SurfaceType/ResetTrigger
# parameter types (not the earlier probe's placeholder int). Expected to
# compile cleanly.
extends MouseReclaimPolicy

var _seed: Vector2 = Vector2.ZERO

func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
	return true

func reclaim_progress() -> float:
	return 1.0

func reset(seed_position: Vector2, _trigger: CursorTypes.ResetTrigger) -> void:
	_seed = seed_position

func diagnostic_seed_position() -> Vector2:
	return _seed
