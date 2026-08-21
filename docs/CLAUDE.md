# Docs Directory

When authoring or editing files in this directory, follow these standards.

## Architecture Decision Records (`docs/architecture/`)

Use the ADR template: `.claude/docs/templates/architecture-decision-record.md`

**Required sections:** Title, Status, Context, Decision, Consequences,
ADR Dependencies, Engine Compatibility, GDD Requirements Addressed

**Status lifecycle:** `Proposed` → `Accepted` → `Superseded`
- Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked
- Use `/architecture-decision` to create ADRs through the guided flow

**TR Registry:** `docs/architecture/tr-registry.yaml`
- Stable requirement IDs (e.g. `TR-MOV-001`) that link GDD requirements to stories
- Never renumber existing IDs — only append new ones
- Updated by `/architecture-review` Phase 8

**Control Manifest:** `docs/architecture/control-manifest.md`
- Flat programmer rules sheet: Required / Forbidden / Guardrails per layer
- Date-stamped `Manifest Version:` in header
- Stories embed this version; `/story-done` checks for staleness

**Reflexion Log:** `docs/consistency-failures.md`
- Cross-round accumulation of recurring consistency failures. **Created 2026-08-21** after being
  recommended by seven consecutive `/architecture-review` rounds without ever being built —
  five skills (`architecture-review`, `consistency-check`, `design-system`, `gate-check`) read it
  when present, but none creates it ("Do not create the file if missing"), so it stayed a file
  everyone waited for and nobody made.
- Machine-readable part: the header table plus `### [date] — /skill — 🔴 CONFLICT` entries with
  the five required fields (`Domain` / `Documents involved` / `What happened` / `Resolution` /
  `Pattern`). `/architecture-review` Phase 1 matches on **`Domain`** and surfaces **`Pattern`**
  as "Known conflict-prone areas". Keep those field names exact.
- Human-authored part (sections 一 and 二 preamble): the cross-round pattern synthesis. Read it
  **before** revising any ADR — it carries the four self-check questions that the last five
  rounds each paid a full review cycle to learn.
- Append new entries at the end of section 二. Never renumber or delete historical entries.

**Validation:** Run `/architecture-review` after completing a set of ADRs.

## Engine Reference (`docs/engine-reference/`)

Version-pinned engine API snapshots. **Always check here before using any
engine API** — the LLM's training data predates the pinned engine version.

Current engine: see `docs/engine-reference/godot/VERSION.md`
