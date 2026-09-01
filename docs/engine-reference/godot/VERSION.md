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
  `class_name` 全域註冊的 headless 雙向陷阱(未匯入時的假否證、匯入成功時的假確認)

兩份刻意超出 README 的 150 行上限,理由在各自檔頭「格式偏離說明」——記錄在案的例外。

**⚠️ 來源為訓練資料與官方文件,非本專案量測**:`animation` / `audio` / `input` /
`navigation` / `networking` / `physics` / `rendering` / `ui`(其中 `ui` 有部分經
2026-08-05 游標 spike 驗證)。

### 🔴 這 8 份全部停在 Godot 4.6,而專案釘的是 4.7.1(2026-09-01 稽核)

實測:8 份的檔頭皆為 `Last verified: 2026-02-12 | Engine: Godot 4.6` —— **比 4.7 發布早四個月,
也比本專案的 Project Pinned(2026-07-28)早近半年。** 只有頂層四份(本檔、`breaking-changes.md`、
`current-best-practices.md`、`deprecated-apis.md`)與兩份 ✅ 模組更新到了 4.7.1。

**最要命的巧合**:本檔上方「Knowledge Gap Warning」自己點名的 4.7 三大高風險是
**鍵盤/滑鼠裝置 ID 重編號**、**Control offset transforms**、**shader 前處理器限縮**。
前兩項各有對應模組檔,而實測 `input.md` 對「裝置 ID 重編號」、`ui.md` 對「Control offset
transforms」**各自零命中**。

> **後果**:`modules/` 存在的意義,就是讓查特定子系統的人不必讀完整份 `current-best-practices.md`。
> 但在本專案自己列為重災區的那兩處,這條捷徑是**空的** —— 而且它看起來是滿的
> (檔案存在、內容詳盡、只是停在舊版)。**照這條捷徑查完就停下的人,不會知道自己漏了什麼。**
>
> ⚠️ **這兩項的正確內容確實寫在 `current-best-practices.md` 裡**,所以資訊沒有遺失,
> 遺失的是**查閱路徑的可靠性**。在這 8 份補到 4.7.1 之前:
> **查 input / UI 相關 API,一律以 `current-best-practices.md` 與 `breaking-changes.md` 為準,
> 不得只查 `modules/`。**

> **「未驗證」不等於錯,但要當成待查證而非既定事實。** 2026-08-21 之前本庫有一個
> **看似合理的錯誤範例**擴散到兩份技術設計文件、造成 13 處編譯期錯誤(已修正,見
> `current-best-practices.md` 的 `@abstract` 段)。這個庫是承重結構。
