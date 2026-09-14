#!/bin/bash
# Claude Code SessionStart hook: Load project context at session start
# Outputs context information that Claude sees when a session begins
#
# Input schema (SessionStart): No stdin input

echo "=== Claude Code Game Studios — Session Context ==="

# Current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "Branch: $BRANCH"

    # Recent commits
    echo ""
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# Current sprint (find most recent sprint file)
LATEST_SPRINT=$(ls -t production/sprints/sprint-*.md 2>/dev/null | head -1)
if [ -n "$LATEST_SPRINT" ]; then
    echo ""
    echo "Active sprint: $(basename "$LATEST_SPRINT" .md)"
fi

# Current milestone
LATEST_MILESTONE=$(ls -t production/milestones/*.md 2>/dev/null | head -1)
if [ -n "$LATEST_MILESTONE" ]; then
    echo "Active milestone: $(basename "$LATEST_MILESTONE" .md)"
fi

# Open bug count
BUG_COUNT=0
for dir in tests/playtest production; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "BUG-*.md" 2>/dev/null | wc -l)
        BUG_COUNT=$((BUG_COUNT + count))
    fi
done
if [ "$BUG_COUNT" -gt 0 ]; then
    echo "Open bugs: $BUG_COUNT"
fi

# Code health quick check
if [ -d "src" ]; then
    TODO_COUNT=$(grep -r "TODO" src/ 2>/dev/null | wc -l)
    FIXME_COUNT=$(grep -r "FIXME" src/ 2>/dev/null | wc -l)
    if [ "$TODO_COUNT" -gt 0 ] || [ "$FIXME_COUNT" -gt 0 ]; then
        echo ""
        echo "Code health: ${TODO_COUNT} TODOs, ${FIXME_COUNT} FIXMEs in src/"
    fi
fi

# --- Pending hook messages (2026-09-14 加) ---
# 累積來源:advise-file-owner.sh / validate-push.sh / validate-commit.sh
# 的非阻擋訊息(見 .claude/hooks/lib/hook-queue.sh 檔頭)。讀出後立即清空,
# 讀取用 bash 內建 $(<file) 而非 cat(同一支檔案內已實測 cat 類外部行程
# 每次約多付 0.6~0.8 秒)。
#
# 「查無擁有者」計數獨立於主佇列(2026-09-14 協調者實測後追加):實測本專案
# 歷史 advise-file-owner 的 29 筆訊息 29 筆都是這一種、0 筆是真正命中,逐筆
# 排隊會讓這裡被幾百行一模一樣的訊息淹沒。摺疊成一行計數,不是丟掉 ——
# 「查無擁有者不等於沒有擁有者」這件事本身仍要露出來。
QUEUE_FILE="production/session-logs/hook-queue.log"
NOMATCH_FILE="production/session-logs/hook-queue-nomatch-count.txt"
NOMATCH_COUNT=0
[ -f "$NOMATCH_FILE" ] && NOMATCH_COUNT=$(<"$NOMATCH_FILE")
case "$NOMATCH_COUNT" in ''|*[!0-9]*) NOMATCH_COUNT=0 ;; esac

if [ -s "$QUEUE_FILE" ] || [ "$NOMATCH_COUNT" -gt 0 ]; then
    echo ""
    echo "=== PENDING HOOK MESSAGES(自上次對話開場累積至今)==="
    echo "以下訊息原本是 stderr + exit 0,已實測不會即時送達 —— 因此改為排入"
    echo "佇列,於本次對話開場一次列出。讀出後本檔案已清空。"
    if [ "$NOMATCH_COUNT" -gt 0 ]; then
        echo "advise-file-owner:查無擁有者(路徑不在 .claude/agent-routing.tsv 對照表)累計 ${NOMATCH_COUNT} 次 —— 不等於沒有擁有者,只是這道閘門判不出來;如需查明請自行核對對照表。"
        : > "$NOMATCH_FILE"
    fi
    if [ -s "$QUEUE_FILE" ]; then
        printf '%s\n' "$(<"$QUEUE_FILE")"
    fi
    echo "=== END PENDING HOOK MESSAGES ==="
    : > "$QUEUE_FILE"
fi

# --- Active session state recovery ---
STATE_FILE="production/session-state/active.md"
if [ -f "$STATE_FILE" ]; then
    echo ""
    echo "=== ACTIVE SESSION STATE DETECTED ==="
    echo "A previous session left state at: $STATE_FILE"
    echo "Read this file to recover context and continue where you left off."
    echo ""
    echo "Quick summary (last 20 lines):"
    tail -20 "$STATE_FILE" 2>/dev/null
    TOTAL_LINES=$(wc -l < "$STATE_FILE" 2>/dev/null)
    if [ "$TOTAL_LINES" -gt 20 ]; then
        echo "  ... ($TOTAL_LINES total lines — read the full file to continue)"
    fi
    echo "=== END SESSION STATE PREVIEW ==="
fi


# --- 提交閘門孤兒記號(2026-09-14 加)---------------------------------
# validate-commit.sh 進入重檢查前會留一個記號,正常結束時刪除。若 harness
# 因逾時中止它,記號會留下 —— 那代表【有一次提交沒被檢查過】。
# 這裡只負責「讓你在開場就看到」,不清除記號:清除由下一次提交時的閘門負責,
# 那條路會 exit 2 並要求確認。本檔的輸出經實測會送達,是第二條管道。
GATE_MARKER="production/session-logs/.commit-gate-running"
if [ -f "$GATE_MARKER" ]; then
    read -r G_TS G_PID < "$GATE_MARKER" 2>/dev/null
    if ! kill -0 "$G_PID" 2>/dev/null; then
        echo ""
        echo "🔴 提交閘門有一次沒有跑完(epoch $G_TS, PID $G_PID)"
        echo "   代表【有一次提交未經檢查就進版控了】,幾乎確定是閘門被逾時取消。"
        echo "   下次提交時會再擋一次並要求確認;要略過:SKIP_GATE_LEDGER=1"
    fi
fi
# ----------------------------------------------------------------------
echo "==================================="
exit 0
