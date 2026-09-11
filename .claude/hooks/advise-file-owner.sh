#!/bin/bash
# Claude Code PreToolUse hook: Advises which agent owns a file path before
# Write/Edit touches it.
#
# WHY: same root cause as advise-skill-owner.sh (2026-09-11 dispatch) -- the
# routing answer exists but lives somewhere nobody looks at the moment of
# acting. This one covers the case a skill-name lookup can't: a raw file
# write/edit that never goes through a named skill at all.
#
# NON-BLOCKING BY DESIGN, exit 0 always (manager ruling). The coordinator
# legitimately retains bookkeeping work (status labels, counts, cross-refs,
# writing down decisions already made, git ops, running existing commands --
# "make existing decisions consistent" vs "produce a new decision", the
# latter always delegated). A hard block would catch that legitimate work
# too, and get bypassed -- which is the same failure this hook exists to
# prevent, wearing a different hat. So: always print, never block. The
# reminder's job is to put the owner's name in front of the person acting,
# not to stop the action.
#
# Input schema (PreToolUse for Write/Edit) -- per
# .claude/docs/hooks-reference/hook-input-schemas.md (documented, unlike the
# Skill tool): { "tool_name": "Write"|"Edit", "tool_input": { "file_path": ... } }

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Normalize path separators (Windows backslash to forward slash)
FILE_PATH="${FILE_PATH//\\//}"

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Strip a leading absolute-path prefix down to a repo-relative path so table
# prefixes (e.g. "design/ux/") match regardless of how the tool passed the path.
REL_PATH=$(echo "$FILE_PATH" | sed -E 's#^.*/Claude-Code-Game-Studios/##')

TABLE=".claude/agent-routing.tsv"
if [ ! -f "$TABLE" ]; then
    exit 0
fi

# Longest-prefix match among type=path rows.
BEST_KEY=""
BEST_OWNER=""
BEST_SRC=""
while IFS=$'\t' read -r TYPE KEY OWNER SRC; do
    [ "$TYPE" = "path" ] || continue
    case "$REL_PATH" in
        "$KEY"*)
            if [ ${#KEY} -gt ${#BEST_KEY} ]; then
                BEST_KEY="$KEY"
                BEST_OWNER="$OWNER"
                BEST_SRC="$SRC"
            fi
            ;;
    esac
done < "$TABLE"

# Suffix match among type=ext rows (independent of path match -- a file can
# have both a directory owner and a code-quality gatekeeper by extension).
EXT_OWNER=""
while IFS=$'\t' read -r TYPE KEY OWNER SRC; do
    [ "$TYPE" = "ext" ] || continue
    case "$REL_PATH" in
        *"$KEY")
            EXT_OWNER="$OWNER"
            ;;
    esac
done < "$TABLE"

if [ -z "$BEST_KEY" ] && [ -z "$EXT_OWNER" ]; then
    # Silence here must not be indistinguishable from "hook did not run" --
    # this project has a live precedent (coding-standards.md CI section) of a
    # silently-degraded command reading as a clean pass. Count path rows at
    # runtime rather than hardcode N, since a hardcoded count is exactly the
    # kind of number this project keeps finding stale.
    PATH_ROW_COUNT=$(grep -c "^path	" "$TABLE" 2>/dev/null)
    echo "此路徑不在對照表中(對照表 ${PATH_ROW_COUNT:-0} 個路徑前綴皆未命中)—— 無法判定擁有者,不等於沒有擁有者。" >&2
    exit 0
fi

echo "=== 檔案擁有者提醒:即將寫入 $REL_PATH ===" >&2

PRINTED_OWNER=""

if [ -n "$BEST_KEY" ]; then
    case "$BEST_OWNER" in
        UNASSIGNED)
            echo "⚠️ 路徑 '$BEST_KEY' 對照表判定為治理缺口 —— 三個來源都查無擁有者。" >&2
            ;;
        AMBIGUOUS:*)
            CANDS=$(echo "$BEST_OWNER" | sed 's/^AMBIGUOUS://;s/|/、/g')
            echo "⚠️ 路徑 '$BEST_KEY' 候選未定案:$CANDS" >&2
            PRINTED_OWNER="1"
            ;;
        *)
            echo "路徑擁有者:$BEST_OWNER(命中對照表 '$BEST_KEY')" >&2
            PRINTED_OWNER="1"
            ;;
    esac
fi

if [ -n "$EXT_OWNER" ]; then
    echo "副檔名/程式碼品質擁有者:$EXT_OWNER" >&2
    PRINTED_OWNER="1"
fi

# Bookkeeping-exemption note. Answers BOTH questions instead of choosing one:
# the owner above still prints in full, and this line adds the test for
# whether the coordinator's recordkeeping exemption applies here, so the
# judgement call happens at the moment of editing rather than being hidden.
# Scope is deliberately narrow and named, not inferred from BEST_OWNER --
# these three are the paths this project's own docs describe as places the
# coordinator routinely writes state/decisions already made elsewhere
# (production/session-state, PROJECT-STATUS.md, ADR status tables, registry
# entries), not every path a producer/technical-director happens to own.
case "$REL_PATH" in
    production/*|docs/architecture/*|docs/registry/*)
        echo "⚠️ 協調者的記帳豁免可能適用於此路徑。判準:這次編輯是「讓已有的決定一致」還是" >&2
        echo "   「產生一個新的決定」?後者一律委派。" >&2
        ;;
esac

if [ -n "$PRINTED_OWNER" ]; then
    echo "若你不是以上述擁有者的身分/視角在寫這個檔案,先確認是否該由它覆核。" >&2
else
    echo "上面沒有列出可用的擁有者名字 —— 這正是要停下來確認的理由,不要假設沒事。" >&2
fi
echo "===========================================================" >&2

exit 0
