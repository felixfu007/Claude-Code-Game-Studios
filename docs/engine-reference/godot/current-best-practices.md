# Godot — Current Best Practices

Last verified: 2026-07-28 | Engine: Godot 4.7.1

Practices that are **new or changed** since the model's training data (~4.3).
This supplements (not replaces) the agent's built-in knowledge.

## Input (4.7)

- **Keyboard/mouse device IDs were renumbered** — never hardcode a device ID; query it at runtime instead. This affects any local multiplayer or multi-device input handling code.

## UI (4.7)

- **Control offset transforms**: Controls can now be translated, rotated, or scaled visually without fighting container re-layout. Useful for animated UI (hover feedback, popups, tweened menus) that previously required workarounds inside containers.
- **DrawableTexture2D**: A simpler layer above Viewport/RenderingDevice for drawing directly onto textures at runtime.

## Rendering (4.7)

- **AreaLight3D**: New node for real-time light from a rectangular surface — useful for interior/architectural lighting without scattering multiple point lights.
- **Vulkan subsampled images**: Foveated rendering performance improvement, primarily relevant for XR.
- **HDR output** supported across all platforms.

## XR (4.7)

- Production-ready Android XR and Steam Frame support, with improved OpenXR composition layers.

## Platform (4.7)

- **Android OBB support removed** — projects must use Play Asset Delivery or a split PCK instead. Audit any Android export presets that still reference OBB before upgrading.
- **Godot Android Build Environment** reached stable release.

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]
  ```

  > **2026-08-20 更正(Godot 4.7.1 headless 實機驗證)**:`@abstract func` 必須是**裸簽章**
  > —— 無冒號、無函式主體,**連 `pass` 都不行**。本範例先前的版本在簽章後帶 `:` 與 `pass`
  > 主體,那是硬性 parse error:`Parse Error: An abstract function cannot have a body.`
  > 裸簽章已實測對 `Array[T]`/`bool`/`float`/`void`/`Vector2` 五種回傳型別皆合法;
  > `@abstract` 類別內亦可同時宣告 `signal` 與多個 `@abstract func`。
  > **類別層寫法(`@abstract` 獨立一行、置於 `class_name` 之前)原本就是對的,未改動。**
  > 證據:`prototypes/engine-verification-spike-2026-08-20/logs/run-final-2026-08-20-headless.txt`。
  >
  > ⚠️ **本範例曾是 ADR-0004 與 ADR-0005 引為「本專案唯一已查證的 `@abstract` 範例」的唯一依據**,
  > 錯誤因此傳播到那兩份文件共 13 處宣告(ADR-0004 五處、ADR-0005 八處),兩份各另有一處
  > 明文指示句要求「沿用該形式」。第三輪 `/architecture-review` 把 `@abstract` 語法由「印象」
  > 升級為「已查證」的依據就是逐字比對這個錯誤範例 —— **那次升級無效**。
  > 詳見 `docs/architecture/architecture-review-2026-08-20-round7.md` 第 3.3/3.5 節。

- **Script backtracing**: Detailed call stacks available even in Release builds

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability
