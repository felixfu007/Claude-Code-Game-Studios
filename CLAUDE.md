# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7.1
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit **on a file that already exists**. For a **new** file the agent writes it directly, first action — see the 2026-10-05 ruling below
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

> 🔴 **上面第一條於 2026-10-05 由管理者裁決修訂為「分情況適用」。**
> **原文逐字為**:`- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools`
> —— 無條件適用於所有檔案,不分新舊。
>
> **為什麼改**:它與派工單既有的「第一個動作必須是寫檔」正面衝突,**兩條同時遵守做不到**。
> 2026-09-30 第一次撞上(登記在 `docs/ai-art-pipeline/SPEC.md` 附錄 B 第 1 項與 C-4,
> 當時只登記、未裁決);2026-10-05 第二次撞上 —— `technical-director` 裁決 ADR-0001
> 巢狀語意時選了本條、交回**零檔案寫入**,管理者當場裁決。**每撞一次的成本是一個完整的
> 專家回合加上管理者的一次點頭。**
>
> **新規則的分界,以及兩邊各自在防什麼**:
> - **新檔 → 直接寫,不必先問。**「先寫」防的是「忙了一整輪、磁碟上零產出」這個失效模式
>   (本專案實測發生過「23 次工具呼叫、磁碟零產出」),而它幾乎只在建新檔時發作。
> - **既有檔 → 必須先問。**「先問」防的是改壞承重文件,而那只可能發生在既有檔上。
>
> ⚠️ **沒有任何自動檢查會攔這條。** 與本專案其餘同類規則一樣,遵守與否目前不可觀測 ——
> 它買到的是「下一個派工的人有明文可查對」,不是「下一個人一定會照做」。

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
