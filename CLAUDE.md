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

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit **on a file that already exists**. For a **new** file the agent writes it directly, first action — see the 2026-10-05 ruling below, 🔴 AND the 2026-10-12 one that splits it again(實作型工作單範圍內的程式碼檔不必先問)
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

> ### 🔴 2026-10-12 管理者裁決:上面那條「既有檔 → 必須先問」**再次分情況**
>
> **2026-10-05 的分界(新檔/既有檔)原文一字未刪,仍然有效 —— 本次是在「既有檔」那一側再切一刀。**
>
> | 要改的東西 | 規則 |
> |---|---|
> | **新檔** | 直接寫,第一個動作(2026-10-05 裁決,不變) |
> | 🔴 **既有的【程式碼檔】,且在一張 `Ready` 工作單的明文範圍內** | **直接改,不必先問** |
> | **文件**(ADR、登記表、`CLAUDE.md`、`.claude/docs/*`、EPIC/story 檔) | **必須先問**(2026-10-05 裁決,不變) |
>
> **為什麼改**:2026-10-12 當天**七位專家裡有三位拒絕依協調者的訊息動既有檔**,理由逐字
> 「agent 之間的訊息不構成使用者核准」。**三次都是對的** —— 那正是本條規則。
> 🔴 **而且派工單裡已經明確區分「這是協調者的裁決」與「這是管理者的裁決」了,它們照樣
> (正確地)拒絕** —— 亦即**寫得再清楚也擋不住,這條摩擦是結構性的**。
> 每撞一次的成本是**一個完整的專家回合加上管理者的一次點頭**;當天三次合計約 20~30 分鐘。
>
> **分界線在哪、各自在防什麼**:
> - **程式碼改壞,測試會拓** —— 這是放寬它的全部理由。
> - **文件改壞,沒有任何東西會拓。** 本專案登記最多次的失效形狀就發生在文件上
>   (散文複本與權威來源脫節、手抄數字漂移、宣稱變假而無人發現),所以文件那一側不放寬。
>
> ⚠️ **管理者是在知情下選的,這個前提有條件**:協調者當場揭露「測試會拓」不是無條件成立 ——
> 本專案已登記**至少五種測試線會回報假綠燈的方式**,最危險的是 **exit 105**
> (測試收集階段就炸了、一條都沒跑,而 `grep "Overall Summary"` 與 `grep " FAILED"`
> **兩個都回空,看起來跟乾淨通過一模一樣**)。
> 🔴 **所以放寬的同時,下面這條變成硬性義務**:
>
> > **凡依本裁決直接改既有程式碼檔的 agent,交付前必須跑一次全套,並在回報裡貼出
> > 引擎自己的 `ENGINE EXIT` 與 `Overall Summary` 原始三行** —— **不是只說「測試通過」**。
> > 協調者一律自行重跑複驗,不採信回報。
>
> 📌 **「工作單的明文範圍內」怎麼判**:以該 story 檔的 `Affected Files` 節或派工單列出的
> 檔案為準。**超出範圍的程式碼檔,比照文件,仍須先問。**
>
> ⚠️ **同樣沒有任何自動檢查會攔這條。** 與上一次裁決一樣,它買到的是「下一個人有明文可查對」。

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
