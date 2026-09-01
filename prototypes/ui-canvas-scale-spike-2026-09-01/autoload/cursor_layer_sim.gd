extends CanvasLayer
## Spike stand-in for ADR-0005's `CursorStateHost` (mechanism 12/13): "an Autoload that
## holds a dedicated CanvasLayer for the self-drawn cursor / idle indicator / hover
## detector, and that layer must maintain an identity transform throughout (VR #11b)."
##
## This script deliberately NEVER assigns `transform`, `offset`, `rotation`, or `scale` on
## this CanvasLayer anywhere in this file, or from any other file in this spike. That
## omission IS the thing being tested: does an untouched CanvasLayer registered as an
## Autoload actually stay at Transform2D.IDENTITY across window resizes, independent of
## whatever content-scale/stretch transform the project applies to the rest of the tree?
## `game_root.gd`'s measurement pass reads `transform` back after every resize to confirm
## this by direct property inspection, not by assuming it from the absence of code that
## would change it.

var marker: ColorRect


func _ready() -> void:
	layer = 100 # arbitrary "always on top" value; mirrors ADR-0005 mechanism 12's intent
	marker = ColorRect.new()
	marker.name = "CursorMarkerSim"
	marker.size = Vector2(4, 4)
	marker.color = Color.RED
	add_child(marker)


## Mirrors the ADR-0005 constraint that `get_viewport().get_mouse_position()` is allowed to
## appear exactly once in the whole project, at the point `CursorStateHost` builds its
## `mouse_position_provider`. Reproduced here only so the measurement pass can call it.
func get_mouse_position_via_viewport() -> Vector2:
	return get_viewport().get_mouse_position()
