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

## 模組參考索引

Agent 的查閱起點是本檔。**新增模組檔時必須同時更新此表**,否則後來的人找不到它存在。

**✅ 經 2026-08-21 逐條實機驗證,2026-08-24 各補兩節(每條宣稱附探針與 log 引用)**:

- `modules/core-serialization.md` — 二進位 Variant 序列化、`HashingContext`、
  `Callable`/`Signal`/`RID` 邊界、Variant 型別枚舉、巢狀 `PackedByteArray` 保真、
  `_with_objects` 跨行程實例化自訂類別
- `modules/scripting-typing.md` — 型別化容器邊界、enum 型別化參數、`@abstract`、
  中止 vs 靜默矩陣、`Callable` 綁 `RefCounted` 的生命週期、`StringName`/`String` 當鍵、
  `class_name` 全域註冊的 headless 假否證陷阱

兩份刻意超出 README 的 150 行上限,理由在各自檔頭「格式偏離說明」——記錄在案的例外。

**⚠️ 來源為訓練資料與官方文件,非本專案量測**:`animation` / `audio` / `input` /
`navigation` / `networking` / `physics` / `rendering` / `ui`(其中 `ui` 有部分經
2026-08-05 游標 spike 驗證)。

> **「未驗證」不等於錯,但要當成待查證而非既定事實。** 2026-08-21 之前本庫有一個
> **看似合理的錯誤範例**擴散到兩份技術設計文件、造成 13 處編譯期錯誤(已修正,見
> `current-best-practices.md` 的 `@abstract` 段)。這個庫是承重結構。
