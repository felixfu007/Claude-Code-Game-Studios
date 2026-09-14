#!/bin/bash
# Claude Code Stop hook: Log session summary when Claude finishes
# Records what was worked on for audit trail and sprint tracking

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_DIR="production/session-logs"

mkdir -p "$SESSION_LOG_DIR" 2>/dev/null

# Log recent git activity from this session (check up to 8 hours for long sessions)
RECENT_COMMITS=$(git log --oneline --since="8 hours ago" 2>/dev/null)
MODIFIED_FILES=$(git diff --name-only 2>/dev/null)

# --- Note that active session state exists (do NOT delete, do NOT copy) ---
# active.md persists across clean exits so multi-session recovery works.
# It is only valid to delete active.md manually or when explicitly superseded.
# That part is unchanged. What changed (2026-09-14, manager ruling) is that this
# hook no longer COPIES active.md into session-log.md.
#
# 🔴 WHY the copy was removed — it was redundant AND unbounded:
#   1. REDUNDANT. active.md is itself under version control (verified
#      2026-09-14: `git ls-files` matches it, 139 historical revisions). Every
#      version is already recoverable from git history. session-log.md is
#      gitignored, so the copy was the *less* durable of the two.
#   2. UNBOUNDED. Stop is NOT "once per session" — it fires every time Claude
#      finishes a reply. Measured 2026-09-11: 970 whole-file copies, active.md
#      508 KB, session-log.md 187 MB and accelerating (the longer active.md
#      grows, the faster the log grows). 190 MB by 2026-09-14.
#
# The block below already records what this log actually exists for: which
# commits happened and which files changed. That is kept untouched.
#
# ⚠️ Deliberately records no size/mtime here: each would cost an extra process,
# and on this machine every fork/exec costs 0.5-1.5s (measured 2026-09-11).
STATE_FILE="production/session-state/active.md"
if [ -f "$STATE_FILE" ]; then
    {
        echo "## Session State Pointer: $TIMESTAMP"
        echo "- $STATE_FILE exists (content NOT copied — it is in git; see hook header)"
        echo ""
    } >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
fi

if [ -n "$RECENT_COMMITS" ] || [ -n "$MODIFIED_FILES" ]; then
    {
        echo "## Session End: $TIMESTAMP"
        if [ -n "$RECENT_COMMITS" ]; then
            echo "### Commits"
            echo "$RECENT_COMMITS"
        fi
        if [ -n "$MODIFIED_FILES" ]; then
            echo "### Uncommitted Changes"
            echo "$MODIFIED_FILES"
        fi
        echo "---"
        echo ""
    } >> "$SESSION_LOG_DIR/session-log.md" 2>/dev/null
fi


# --- Stale-handoff check at session end (added 2026-09-03) -------------------
# C4/C7 in validate-doc-consistency.sh require a CLEAN git tree, so they can
# never fire from the pre-commit gate (pre-commit the tree is dirty by
# definition). Session end is the other moment the tree is usually clean AND the
# handoff document is about to be relied on by the next session — which reads it
# FIRST, before anything else. --handoff runs only those two invariants (~3.5s of
# the full 8.4s) to stay well inside this hook's 10s timeout.
# REPORT ONLY. A Stop hook must never block, and this one deliberately exits 0
# regardless of what it finds.
if [ -f ".claude/hooks/validate-doc-consistency.sh" ]; then
    bash .claude/hooks/validate-doc-consistency.sh --handoff
fi

exit 0
