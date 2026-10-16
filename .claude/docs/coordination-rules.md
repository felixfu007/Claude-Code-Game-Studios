# Agent Coordination Rules

1. **Vertical Delegation**: Leadership agents delegate to department leads, who
   delegate to specialists. Never skip a tier for complex decisions.
2. **Horizontal Consultation**: Agents at the same tier may consult each other
   but must not make binding decisions outside their domain.
3. **Conflict Resolution**: When two agents disagree, escalate to the shared
   parent. If no shared parent, escalate to `creative-director` for design
   conflicts or `technical-director` for technical conflicts.
4. **Change Propagation**: When a design change affects multiple domains, the
   `producer` agent coordinates the propagation.
5. **No Unilateral Cross-Domain Changes**: An agent must never modify files
   outside its designated directories without explicit delegation.

## Model Tier Assignment

Skills and agents are assigned to model tiers based on task complexity:

| Tier | Model | When to use |
|------|-------|-------------|
| **Haiku** | `claude-haiku-4-5-20251001` | Read-only status checks, formatting, simple lookups — no creative judgment needed |
| **Sonnet** | `claude-sonnet-4-6` | Implementation, design authoring, analysis of individual systems — default for most work |
| **Opus** | `claude-opus-4-6` | Multi-document synthesis, high-stakes phase gate verdicts, cross-system holistic review |

Skills with `model: haiku` (7): `/help`, `/sprint-status`, `/scope-check`,
`/project-stage-detect`, `/changelog`, `/patch-notes`, `/onboard`

Skills with `model: opus` (3): `/review-all-gdds`, `/architecture-review`, `/gate-check`

> 🔴 **Corrected 2026-09-01.** This list previously included `/story-readiness` under Haiku;
> the file is `model: sonnet`. Sonnet is the correct tier for it — it walks ADR `Depends On`
> chains recursively with cycle detection and caching (~390 lines) and its `allowed-tools`
> includes `Task`, so it can spawn subagents. That is not "read-only status check, no creative
> judgement" as the Haiku row below defines it. **The other direction is clean**: no skill file
> declares a tier the list omits. Verified by reading all 73 skill frontmatters:
> `for d in .claude/skills/*/; do awk '/^---$/{n++;next} n==1&&/^model:/{print FILENAME, $2}' "$d/SKILL.md"; done`
>
> ⚠️ **Six skills declare `model: sonnet` while their `agent:` points at an Opus agent**
> (`adopt`, `content-audit`, `create-architecture`, `create-control-manifest`, `create-epics`,
> `propagate-design-change`). Whether the skill's `model:` overrides or is ignored for
> agent-bearing skills **is documented nowhere** — registered as open in
> `docs/reviews/doc-audit-2026-09-01.md`, not resolved here.

All other skills default to Sonnet. When creating new skills, assign Haiku if the
skill only reads and formats; assign Opus if it must synthesize 5+ documents with
high-stakes output; otherwise leave unset (Sonnet).

## Subagents vs Agent Teams

This project uses two distinct multi-agent patterns:

### Subagents (current, always active)
Spawned via `Task` within a single Claude Code session. Used by all `team-*` skills
and orchestration skills. Subagents share the session's permission context, run
sequentially or in parallel within the session, and return results to the parent.

**When to spawn in parallel**: If two subagents' inputs are independent (neither
needs the other's output to begin), spawn both Task calls simultaneously rather
than waiting. Example: `/review-all-gdds` Phase 1 (consistency) and Phase 2
(design theory) are independent — spawn both at the same time.

### Agent Teams (experimental — opt-in)
Multiple independent Claude Code *sessions* running simultaneously, coordinated
via a shared task list. Each session has its own context window and token budget.
Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` environment variable.

**Use agent teams when**:
- Work spans multiple subsystems that will not touch the same files
- Each workstream would take >30 minutes and benefits from true parallelism
- A senior agent (technical-director, producer) needs to coordinate 3+ specialist
  sessions working on different epics simultaneously

**Do not use agent teams when**:
- One session's output is required as input for another (use sequential subagents)
- The task fits in a single session's context (use subagents instead)
- Cost is a concern — each team member burns tokens independently

**Current status**: Opt-in via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Document first usage here when adopted.

## 🔴 每批程式碼的獨立覆核(2026-10-16 管理者裁決,常設)

**裁決逐字**:選項為「**繼續,但改成我自己讀(推薦)**」。
被跳過的三個:維持另派專家 / 兩種都要但只在指定情況 / 拆掉並寫下結果。

**做法**:一批程式碼交付後,**協調者本人讀引擎原始輸出與 diff**,不另派專家。
**協調者一律自行重跑驗收,不採信回報。**

### 它要抓的是特定一類東西

> 🔴 **程式跑得起來、測試全綠、但假設是錯的。**
> 這類目前**沒有任何其他防線** —— 測試只證明「沒壞掉」,證明不了「做對了事」。

**2026-10-16 實測抓到三次**(該日交接文件有逐條紀錄):
① 測試框架的失敗報告去色後兩行逐字相同,害實作者追錯方向;
② 迴圈終止條件寫成「這個單位不是 DONE」而非「它真的做了事」;
③ **一份讀起來完全合理、卻會抵銷自己全部意義的規格**(三條驗收條件疊起來讓量測值必然 100%)。
**第三項最貼合定義 —— 那不是程式 bug,是假設錯了。**

### 🔴 這個做法的已知盲點,管理者在知情下接受

**協調者不是「沒被污染的眼睛」** —— 派工單是他寫的,他會帶著自己的假設讀。
2026-10-16 當天就有兩次是**專家更正協調者**,不是協調者抓到專家。

**唯一的補償機制**:
> **凡呈給管理者、或交給專家的理由,未驗證的逐字標出來,
> 並明令對方「查證不符就停下」。**

那個閘門 2026-10-13 救過兩次、2026-10-16 救過兩次。**它不是客套,是這道覆核的盲點補丁。**

### 停損條件

> **逐批記錄它實際抓到什麼。連續 3 批零收穫 → 拆掉,並把結果寫下來,不要安靜地停止執行。**
> 「排版意見」「命名建議」**不計為收穫** —— 只有上面那一類才算。

⚠️ **沒有任何自動檢查會確認這道覆核有沒有被執行**,與本專案其餘同類規則一樣
—— 它買到的是「下一個人有明文可查對」。

## Parallel Task Protocol

When an orchestration skill spawns multiple independent agents:

1. Issue all independent Task calls before waiting for any result
2. Collect all results before proceeding to dependent phases
3. If any agent is BLOCKED, surface it immediately — do not silently skip
4. Always produce a partial report if some agents complete and others block
