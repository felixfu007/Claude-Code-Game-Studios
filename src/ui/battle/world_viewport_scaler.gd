## Applies [WorldLayout]'s manually-managed scale/centering rules to this
## [SubViewportContainer] every time the owning window's size changes
## ("視窗尺寸會變...是要持續維持的關係,不是啟動時算一次" — story-001
## Implementation Notes #1). Attached directly to
## [code]BattleScreen.tscn[/code]'s [code]WorldViewportContainer[/code] node.
##
## Deliberately does [b]NOT[/b] set [member SubViewport.size] directly — that
## assignment is rejected by the engine when the container has
## [member SubViewportContainer.stretch] enabled (measured 2026-09-01, see
## `.claude/docs/technical-preferences.md` 反噬事實 2: the engine prints
## [code]"Can't change the size of a SubViewport with a SubViewportContainer
## parent that has stretch enabled"[/code] and rejects the assignment
## on the spot). Instead this sets [member Control.position] /
## [member Control.size] on itself (this node IS the container) and
## [member SubViewportContainer.stretch_shrink], and lets the container
## derive the child [SubViewport]'s size from those two — verified together
## (manual position/size AND non-1 [code]stretch_shrink[/code] applied at the
## same time) in
## `prototypes/story-001-manual-scaling-verification-2026-09-04/`.
##
## Switches this node's anchors away from the full-rect preset the scene file
## ships with ([code]anchors_preset=15[/code], a leftover from the retired
## `canvas_items` era — see `src/ui/CLAUDE.md`'s now-retired "條件一") to
## [constant Control.PRESET_TOP_LEFT] so [member Control.position]/[member
## Control.size] are free to be set manually instead of being forced back to
## the parent rect.
##
## Also enforces the 2026-09-04 manager ruling's [code]Window.min_size =
## (960, 540)[/code] (see [WorldLayout]'s [method WorldLayout.compute_scale]
## doc comment) — [b]not[/b] a [code]project.godot[/code] setting, because
## Godot 4.7.1 has none for minimum window size (empirically confirmed: no
## [code]display/window/size/*[/code] registered project setting exists for
## it, only the runtime [member Window.min_size] property — see
## `prototypes/story-001-manual-scaling-verification-2026-09-04/`). [b]Known
## scope gap, flagged rather than silently accepted:[/b] this is a
## scene-level node setting a process-level (whole OS window) property. It
## takes effect the moment ANY scene containing this script enters the tree
## — today that is harmless because [code]BattleScreen.tscn[/code] is
## [code]run/main_scene[/code], so it is the very first scene loaded. If a
## title/menu screen is ever added ahead of [code]BattleScreen[/code] in the
## boot sequence, the minimum would not be enforced until the player reaches
## battle — see this story's report for the explicit call on whether that
## gap is acceptable as shipped or needs a process-level owner (e.g. a
## dedicated boot Autoload) once such a screen exists. Not something this
## script should silently work around: per the forbidden pattern
## [code]logic_in_cursor_autoload_shell[/code] (ADR-0005), this is
## specifically NOT to be moved into [code]CursorStateHost[/code] just
## because it is a convenient existing Autoload — that shell is deliberately
## empty of logic unrelated to its own system.
extends SubViewportContainer

const MIN_WINDOW_SIZE: Vector2i = Vector2i(WorldLayout.BASE_WIDTH * 2, WorldLayout.BASE_HEIGHT * 2)


func _ready() -> void:
	get_window().min_size = MIN_WINDOW_SIZE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var rect: Rect2i = WorldLayout.compute_rect(window_size)
	position = Vector2(rect.position)
	size = Vector2(rect.size)
	stretch_shrink = WorldLayout.compute_scale(window_size)
