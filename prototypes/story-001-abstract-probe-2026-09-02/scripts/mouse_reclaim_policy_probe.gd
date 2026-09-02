# Probe (1): mirrors the exact shape of the real MouseReclaimPolicy contract
# (ADR-0005 機制八, Story 001 AC-S001-c) — 1 signal + 4 @abstract func with
# four different return types (bool / float / void / Vector2), all in one
# file. Question being answered: do these coexist and compile in 4.7.1?
@abstract
class_name ProbeMouseReclaimPolicy
extends RefCounted

signal reset_triggered(trigger: int)

@abstract
func evaluate(current_mouse_position: Vector2, surface: int) -> bool

@abstract
func reclaim_progress() -> float

@abstract
func reset(seed_position: Vector2, trigger: int) -> void

@abstract
func diagnostic_seed_position() -> Vector2
