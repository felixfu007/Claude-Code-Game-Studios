#!/bin/bash
# Shared helper, SOURCED (not executed) by PreToolUse gates that need to
# report something without blocking every single Bash command.
#
# WHY THIS EXISTS (2026-09-14): advise-file-owner.sh, validate-push.sh, and
# most of validate-commit.sh's findings print to stderr and exit 0. That exact
# combination is measured to never reach Claude or the user under PreToolUse
# -- only stderr+exit2 (blocks) and SessionStart's own stdout (delayed to next
# session) are delivered. advise-file-owner fired 23 times with 0 delivered
# before this existed; the manager confirmed never having seen these warnings.
#
# 🔴 那段是【本檔為何誕生】的歷史,不是【今天誰在用它】。2026-09-15 實測:
# 它點名的 advise-file-owner.sh 與 validate-push.sh 兩者已於 2026-09-14
# (1416ed7)取消掛載,不可能再供稿;validate-commit 的 doc-consistency 那一路
# 也已於 2026-09-15(8462c75)移除。今天實際的供稿者是四個:
#   advise-skill-owner / validate-assets / validate-commit / validate-skill-change
# (查法:`grep -l queue_message .claude/hooks/*.sh` 與 settings.json 掛載表取交集。)
# ⚠️ 連帶:queue_no_match_hit() 的唯一呼叫者就是未掛載的 advise-file-owner.sh,
# 因此該計數路徑今天是死碼 —— 詳見 session-start.sh 排空段的註解。
#
# POLICY (manager ruling, 2026-09-14): a real cross-document contradiction
# (validate-doc-consistency.sh's [ERROR] tier, surfaced through
# validate-commit.sh) still blocks immediately via exit 2 -- that path is
# UNCHANGED by this file, it never calls queue_message. Everything else
# (ownership reminders, protected-branch pushes, missing-section warnings,
# unproven-completion-claim warnings, doc-consistency [warn]-only findings)
# queues here and is dumped once, at the next SessionStart, by
# session-start.sh, which also clears the file. Trunk-based dev means every
# push targets main -- a hard block on every push would just get the whole
# gate switched off within days, so queuing rather than blocking is the
# deliberate choice for that tier.
#
# 🔴 HARD SIZE CAP, ON PURPOSE. production/session-logs/session-log.md grew to
# 190MB because session-stop.sh copied a whole file on every Stop event with
# no bound (fixed in 023eca7, same day this file was written). This queue
# must not become the second instance of that shape. Past the cap, further
# messages are dropped and a single overflow marker is written once (checked
# so it is not rewritten on every call) -- the drop itself stays visible
# instead of silently discarding forever.
#
# COST NOTE: every fork/exec on this machine costs ~0.5-1.5s, worse under
# load (measured 2026-09-11,
# production/session-state/hook-stdin-hang-2026-09-11.md). queue_message()
# only runs on the message path -- a gate that already decided it has
# something to say -- never on the silent/read-only path, so it does not add
# a fork to every Bash command. Within queue_message() itself, size is read
# with bash's builtin `$(<file)` rather than the external `wc -c`: measured
# on this machine, 3 calls of `wc -c < file` took 2339ms (~780ms each) vs 3
# calls of `$(<file)` took 421ms (~140ms each) -- see the session-state file
# above for the general fork-cost finding this specific pair confirms.

HOOK_QUEUE_FILE="production/session-logs/hook-queue.log"
HOOK_QUEUE_CAP_BYTES=262144   # 256 KiB. Generous for short text warnings
                              # (each message is a few hundred bytes; this
                              # holds hundreds of them) but nowhere near the
                              # 190MB shape this is written to avoid repeating.

HOOK_QUEUE_NOMATCH_FILE="production/session-logs/hook-queue-nomatch-count.txt"

# queue_message SOURCE MSG
#   SOURCE: short tag identifying which gate/check produced MSG (freeform,
#           printed as-is, used only for the human/Claude reading the queue
#           later -- not parsed by anything).
#   MSG:    the message body, may be multi-line.
# Always returns 0 -- a queuing failure must never change a gate's exit code.
queue_message() {
    local SOURCE="$1"
    local MSG="$2"
    [ -z "$MSG" ] && return 0

    local QDIR
    QDIR="$(dirname "$HOOK_QUEUE_FILE")"
    [ -d "$QDIR" ] || mkdir -p "$QDIR" 2>/dev/null

    local CUR=""
    [ -f "$HOOK_QUEUE_FILE" ] && CUR=$(<"$HOOK_QUEUE_FILE")
    local CUR_SIZE=${#CUR}

    if [ "$CUR_SIZE" -ge "$HOOK_QUEUE_CAP_BYTES" ]; then
        case "$CUR" in
            *"QUEUE OVERFLOW"*) return 0 ;;  # marker already written this cycle, stay silent
        esac
        {
            echo ""
            echo "🔴 QUEUE OVERFLOW -- pending hook messages exceeded ${HOOK_QUEUE_CAP_BYTES} bytes."
            echo "Further messages are being dropped until this file is read and cleared"
            echo "at next session start (session-start.sh). This is a size safety valve,"
            echo "not a check result -- it means messages are arriving faster than"
            echo "sessions are starting, not that everything past this point is fine."
        } >> "$HOOK_QUEUE_FILE" 2>/dev/null
        return 0
    fi

    {
        printf '%(%Y-%m-%d %H:%M:%S)T' -1 2>/dev/null
        printf ' [%s]\n' "$SOURCE"
        printf '%s\n' "$MSG"
        echo ""
    } >> "$HOOK_QUEUE_FILE" 2>/dev/null
    return 0
}

# queue_no_match_hit
#
# WHY THIS EXISTS (2026-09-14, added after the coordinator measured actual
# session transcripts): advise-file-owner's "path not in table" line is not
# rare noise, it is the OVERWHELMING majority of what that gate has ever said.
# Measured across this project's history: 29 advise-file-owner messages,
# 29 of them this exact line, 0 a real owner match. Routing it through
# queue_message() like everything else would mean the pending-messages
# summary gets flooded with hundreds of identical lines until nobody reads
# it -- the same failure this whole mechanism exists to fix, just moved one
# hop downstream instead of solved.
#
# NOT a mute switch. This project's own rule is that silence must not look
# like "the gate didn't run" (commit c9f2f88), and the line itself exists to
# say "unknown owner" is not "no owner" -- both still need to surface. The
# fix here is COLLAPSE, not DROP: a tiny counter file, rolled up into a
# single summary line by session-start.sh (which also resets the counter),
# instead of one queue_message() call per hit.
#
# DELIBERATELY NOT deduplicated by reading/diffing the main queue file --
# that would mean a fork-heavy file scan on a path that fires on every
# Write/Edit, on a machine where every fork/exec costs 0.5-1.5s (measured
# 2026-09-11). The counter file itself is read and written with bash
# builtins only ($(<file) / plain `>` redirection) -- no external process.
queue_no_match_hit() {
    local N=0
    [ -f "$HOOK_QUEUE_NOMATCH_FILE" ] && N=$(<"$HOOK_QUEUE_NOMATCH_FILE")
    case "$N" in ''|*[!0-9]*) N=0 ;; esac  # corrupt/missing counter -> treat as 0, never crash the gate
    N=$((N + 1))

    local QDIR
    QDIR="$(dirname "$HOOK_QUEUE_NOMATCH_FILE")"
    [ -d "$QDIR" ] || mkdir -p "$QDIR" 2>/dev/null

    echo "$N" > "$HOOK_QUEUE_NOMATCH_FILE" 2>/dev/null
    return 0
}
