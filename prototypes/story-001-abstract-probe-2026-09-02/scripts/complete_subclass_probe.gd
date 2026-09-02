# Probe (2): control group — a concrete subclass implementing all 4
# @abstract methods. Expected to compile cleanly; this is the baseline that
# probe (3)'s failure is compared against.
extends ProbeMouseReclaimPolicy

func evaluate(_current_mouse_position: Vector2, _surface: int) -> bool:
	return true

func reclaim_progress() -> float:
	return 1.0

func reset(_seed_position: Vector2, _trigger: int) -> void:
	pass

func diagnostic_seed_position() -> Vector2:
	return Vector2.ZERO
