# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.1 |
| **Release Date** | July 2026 (4.7.1 patch: 2026-07-13) |
| **Project Pinned** | 2026-07-28 |
| **Last Docs Verified** | 2026-07-28 |
| **LLM Knowledge Cutoff** | January 2026 |

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.6 (released Jan 2026, right at
the model's cutoff). Godot 4.7 (Jun/Jul 2026) was released AFTER the model's
training cutoff and introduces changes the model does NOT reliably know about —
notably keyboard/mouse device ID renumbering, Android OBB removal, shader
preprocessor restrictions, and Control offset transforms. Always cross-reference
this directory before suggesting Godot API calls, especially for input handling,
Android export, and custom Control layout code.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | LOW (pre-cutoff) | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | LOW (pre-cutoff) | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | MEDIUM (at cutoff — verify) | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | Jun 2026 | HIGH (post-cutoff) | AreaLight3D, HDR everywhere, Control offset transforms, keyboard/mouse device ID renumbering, Android OBB removed |
| 4.7.1 | 2026-07-13 | HIGH (post-cutoff) | Patch release — 78 fixes, no new breaking changes over 4.7.0 |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.7/
