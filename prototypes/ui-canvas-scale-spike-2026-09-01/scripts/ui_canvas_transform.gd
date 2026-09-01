extends RefCounted
## Pure functions for a UI "reference canvas" counter-transform — no scene-tree access, so
## a measurement pass can call this directly with numbers captured from the live engine.
##
## The idea being tested: the interface layer is specified (art-direction.md section six) to
## render at native resolution, not pixel-aligned to the 480x270 world canvas. To do that
## while the project's global stretch (canvas_items / keep / integer) still applies to
## everything parented under the root Viewport — including any CanvasLayer that does not
## opt out — a UI CanvasLayer needs its own `.transform` that cancels the engine's current
## `Window.get_final_transform()` and replaces it with an independent fit of a chosen
## "design/reference resolution" onto the actual window. This file computes that transform;
## `game_root.gd` assigns it to a real CanvasLayer and reads the property back to confirm
## the result matches and is NOT identity.

## Fits `design_size` onto `window_size` using a "keep aspect, fractional scale allowed"
## rule (unlike the world layer's "integer" rule — the interface layer is explicitly
## specified to NOT be pixel-locked). Returns the design-space -> window-pixel-space
## transform directly; `window_size` can equal `design_size`'s own current value to express
## "native resolution, no letterboxing, 1 design unit == 1 real window pixel".
static func design_to_window_transform(design_size: Vector2, window_size: Vector2) -> Transform2D:
	var s: float = min(window_size.x / design_size.x, window_size.y / design_size.y)
	var scaled_size: Vector2 = design_size * s
	var offset: Vector2 = (window_size - scaled_size) * 0.5
	return Transform2D(Vector2(s, 0.0), Vector2(0.0, s), offset)


## The value to assign to `CanvasLayer.transform` so that, combined with whatever the
## engine's current canvas->window transform is (`final_transform`, i.e.
## `Window.get_final_transform()`), content authored in this layer's local space lands
## exactly where `design_to_window_transform()` says it should on the physical window —
## independent of the world layer's own stretch scale.
static func canvas_layer_transform_for(design_size: Vector2, window_size: Vector2, final_transform: Transform2D) -> Transform2D:
	return final_transform.affine_inverse() * design_to_window_transform(design_size, window_size)
