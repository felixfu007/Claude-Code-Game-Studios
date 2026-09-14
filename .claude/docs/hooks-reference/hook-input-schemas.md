# Hook Input/Output Schemas

This documents the JSON payloads each Claude Code hook receives on stdin for every event type.

## PreToolUse

Fired before a tool is executed. Can **allow** (exit 0) or **block** (exit 2).

### PreToolUse: Bash

```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: add player health system'",
    "description": "Commit changes with message",
    "timeout": 120000
  }
}
```

### PreToolUse: Write

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "content": "extends Node\n..."
  }
}
```

### PreToolUse: Edit

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "src/gameplay/health.gd",
    "old_string": "var health = 100",
    "new_string": "var health: int = 100"
  }
}
```

### PreToolUse: Read

```json
{
  "tool_name": "Read",
  "tool_input": {
    "file_path": "src/gameplay/health.gd"
  }
}
```

## PostToolUse

Fired after a tool completes. **Cannot block** (exit code ignored for blocking).

🔴 **"Stderr messages are shown as warnings" — this line used to say that, and it is WRONG.**
Measured 2026-09-14 with a throwaway probe hook registered on `PostToolUse:Bash` that wrote a
distinct marker to each stream: stdout landed in the transcript's `content` field, stderr landed
only in the discarded `stderr` field, and **neither reached Claude**. Same result for
`PreToolUse`. See the channel matrix in the Notes section below before designing any hook that
needs to be heard.

### PostToolUse: Write

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "content": "{\"goblin\": {\"health\": 50}}"
  },
  "tool_output": "File written successfully"
}
```

### PostToolUse: Edit

```json
{
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "assets/data/enemy_stats.json",
    "old_string": "\"health\": 50",
    "new_string": "\"health\": 75"
  },
  "tool_output": "File edited successfully"
}
```

## SubagentStart

Fired when a subagent is spawned via the Task tool.

```json
{
  "agent_name": "game-designer",
  "model": "sonnet",
  "description": "Design the combat healing mechanic"
}
```

## SessionStart

Fired when a Claude Code session begins. **No stdin input** — the hook just runs and its stdout is shown to Claude as context.

## PreCompact

Fired before context window compression. **No stdin input** — the hook runs to save state before compression occurs.

## Stop

Fired when the Claude Code session ends. **No stdin input** — the hook runs for cleanup and logging.

## Exit Code Reference

| Exit Code | Meaning | Applicable Events |
|-----------|---------|-------------------|
| 0 | Allow / Success | All events |
| 2 | Block (stderr shown to Claude) | PreToolUse only |
| Other | Treated as error, tool proceeds | All events |

## Notes

### 🔴 Which output channels actually reach anyone (measured 2026-09-14)

Established with throwaway probe hooks that wrote a distinct marker to each stream, then
cross-checked against every `hook_success` / `hook_cancelled` record in the project's session
transcripts. **Do not design a hook message without reading this table.**

| Channel | Lands in transcript `content` | Reaches Claude | Seen by the user | Blocks the tool |
|---|---|---|---|---|
| stdout + `exit 0` (PreToolUse) | ✅ | ❌ | ❌ | no |
| stderr + `exit 0` (PreToolUse) | ❌ | ❌ | ❌ | no |
| stdout + `exit 0` (PostToolUse) | ✅ | ❌ | ❌ | no |
| stderr + `exit 0` (PostToolUse) | ❌ | ❌ | ❌ | no |
| **stderr + `exit 2` (PreToolUse)** | — | ✅ **yes** | ✅ | **yes** |
| **stdout of a `SessionStart` hook** | ✅ | ✅ **yes** | ✅ | n/a |

**There is no "does not block AND is seen immediately" combination.** That is a platform
property, not a bug in any hook.

**How this was found, and why it matters:** all nine gates under `.claude/hooks/` wrote to
stderr and exited 0. Across the whole project history that produced **45 records with stderr
text and 0 with `content`** — `advise-file-owner` fired 29 times and was never once read,
`validate-push` announced "Push to protected branch 'main'" 8 times into the void, and
`validate-doc-consistency` reported 157 line-reference violations nobody saw. The project
believed it had gates it did not have. `advise-file-owner`'s own header comment warns against
exactly this shape of failure — "a gate that looks like protection and is silently inert" — and
it was the clearest example of it.

**Current design** (see `.claude/hooks/lib/hook-queue.sh`): blocking findings use `exit 2`;
everything else is appended to a capped queue file and read out, then cleared, by
`session-start.sh` at the next session start.

- Hooks receive JSON on **stdin** (pipe). 🔴 **Use `INPUT=$(timeout 2 cat)`, never a bare
  `INPUT=$(cat)`** — a bare `cat` blocks forever if stdin is never closed, with 0% CPU, no
  output and no trace, which from the outside is indistinguishable from "still working".
  Claude Code's hook timeout cancels the *logical* hook but does **not** kill the process.
  Check `$?` for `124` (timed out) and exit **loudly** — the project rule is that silence
  must never look like "the gate passed". All 9 hooks under `.claude/hooks/` follow this.
  ⚠️ It is **not** free: the two extra processes cost ~780–860 ms per invocation on this
  machine (every `fork`/`exec` here costs 0.5–1.5 s). Do **not** "optimise" it to the bash
  builtin `read -r -d '' -t 2` — that was tried (`b79da9b`) and reverted (`5039e27`) because
  `read` is byte-at-a-time: a 5 MB payload went from 2.8 s to 21.4 s, and `advise-file-owner`
  runs on `Write`/`Edit`, whose input carries the whole file body.
  Full write-up: `production/session-state/hook-stdin-hang-2026-09-11.md`.
- Parse with `jq` if available, fall back to `grep` for cross-platform compatibility.
- On Windows, `grep -P` (Perl regex) is often unavailable. Use `grep -E` (POSIX extended) instead.
- Path separators may be `\` on Windows. Normalize with `sed 's|\\|/|g'` when comparing paths.
