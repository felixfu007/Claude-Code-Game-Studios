#!/bin/bash
# ⚠️ 本 hook 於 2026-09-14 刻意【未註冊】—— 效能未過關,見 config/gdd-line-limit-exceptions.txt 檔尾
# 單次實測 50462 ms,會重演 2026-09-11 的 hook 逾時事故。修好效能才可註冊。
# Claude Code PreToolUse hook: Enforce GDD file line limits
#
# POLICY (Manager ruling 2026-09-14):
# - System design documents in design/gdd/ must not exceed 400 lines
# - Exception: three files (listed in config) are exempt from the 400-line limit
#   BUT all files (excepted or not) must not GROW if already over their base
# - Non-system documents (game-concept, gameplay-flow-decisions, etc.) are excluded
#
# IMPLEMENTATION:
# - Use git comparison: if a file's new version > HEAD version's line count,
#   check if growth is allowed (file is under limit and not over base)
# - Excluded patterns: game-concept, gameplay-flow-decisions, systems-index, gdd-cross-review
#
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Timeout protection (same as validate-commit.sh)
INPUT=$(timeout 2 cat)
if [ $? -eq 124 ]; then
    echo "⚠️  [enforce-gdd-line-limit.sh] stdin read timeout 2s — gate did not execute." >&2
    exit 0
fi

# Minimal check: is this a git commit? (avoid jq dependency)
if ! echo "$INPUT" | grep -q "git commit"; then
    exit 0  # not a commit, skip check
fi

# Load exception list
EXCEPTION_FILE=".claude/hooks/config/gdd-line-limit-exceptions.txt"
get_exceptions() {
    if [ ! -f "$EXCEPTION_FILE" ]; then
        return 0
    fi
    grep -v '^#' "$EXCEPTION_FILE" | grep -v '^$'
}

is_exception() {
    local filename="$1"
    get_exceptions | grep -Fxq "$filename"
}

# Patterns to exclude (non-system documents)
is_excluded() {
    local filename="$(basename "$1")"
    case "$filename" in
        game-concept.md)
            return 0  # excluded
            ;;
        gameplay-flow-decisions.md)
            return 0  # excluded
            ;;
        systems-index.md)
            return 0  # excluded
            ;;
        gdd-cross-review*)
            return 0  # excluded
            ;;
        *)
            return 1  # not excluded
            ;;
    esac
}

# Check all .md files in design/gdd/
VIOLATIONS=""
EXIT_CODE=0

for filepath in design/gdd/*.md; do
    [ ! -f "$filepath" ] && continue

    filename="$(basename "$filepath")"

    # Skip excluded documents
    if is_excluded "$filepath"; then
        continue
    fi

    # Get HEAD version line count (or 0 if file is new)
    HEAD_LINES=0
    if git cat-file -e HEAD:"$filepath" 2>/dev/null; then
        HEAD_LINES=$(git show HEAD:"$filepath" 2>/dev/null | wc -l)
    fi

    # Get working directory version line count
    WD_LINES=$(wc -l < "$filepath")

    # Check if file grew
    if [ "$WD_LINES" -gt "$HEAD_LINES" ]; then
        # File grew. Is growth allowed?

        if is_exception "$filename"; then
            # Exception file: growth is not allowed (ratchet rule)
            if [ "$HEAD_LINES" -gt 0 ]; then
                VIOLATIONS+="  - $filename: grew from $HEAD_LINES → $WD_LINES lines (ratchet violation)"$'\n'
                EXIT_CODE=2
            fi
        else
            # Normal file: growth allowed only if still ≤ 400
            if [ "$WD_LINES" -gt 400 ]; then
                VIOLATIONS+="  - $filename: grew from $HEAD_LINES → $WD_LINES lines (exceeds 400-line limit)"$'\n'
                EXIT_CODE=2
            fi
        fi
    fi
done

if [ -n "$VIOLATIONS" ]; then
    cat >&2 <<EOF
❌ [enforce-gdd-line-limit] GDD line limit violations detected:
$VIOLATIONS
Action: Either remove content (400-line soft limit for new docs,
no-growth ratchet for existing), or request manager exception.
EOF
fi

exit "$EXIT_CODE"
