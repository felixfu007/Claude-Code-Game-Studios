#!/bin/bash
# Claude Code SubagentStop hook: Log agent completion for audit trail
# Tracks when agents finish and their outcome
#
# Input schema (SubagentStop) — per Claude Code hooks reference:
# { "session_id": "...", "agent_id": "agent-abc123", "agent_type": "Explore",
#   "agent_transcript_path": "...", "last_assistant_message": "...", ... }
#
# The agent name is in `agent_type`, NOT `agent_name`. Reading `.agent_name`
# returns null on every invocation, so the fallback "unknown" is always used
# and the audit trail captures nothing useful.

# --- stdin 讀取超時保護(2026-09-11 加)-------------------------------
# 原本是裸的 INPUT=$(cat)。若 Claude Code 沒有關閉 stdin,這一行會無限期
# 阻塞:CPU 0%、無輸出、不留任何痕跡,從外面看跟「還在跑」一模一樣。
# 2026-09-11 實際發生 —— advise-file-owner.sh(PID 9240)與
# validate-commit.sh(PID 35748)各自卡死 89 分鐘,把整個 session 凍住,
# 而 Claude Code 的 hook 逾時只取消了「邏輯上的 hook」,沒有殺掉行程。
#
# 🔴 2026-09-11 傍晚更正:上面那個「89 分鐘卡死」的根因判定是錯的(真因是
# hook 逾時上限低於實際耗時,見 production/session-state/hook-stdin-hang-2026-09-11.md
# 的「更正」節)。本保護予以保留 —— 那種卡法理論上仍存在、且現在零成本:
# ⚠️ 2026-09-11 夜:曾改用 bash 內建 read -t 省下那兩個行程,【已改回】。
# 原因:內建 read 是逐位元組讀的。小輸入快約 400ms,但 5MB 輸入從 2.8 秒暴增到
# 21.4 秒(7.5 倍)。Write/Edit 的輸入含整份檔案內容,而「最壞情況暴增」正是
# 本日害兩個 session 卡死的機制 —— 省 0.4 秒不值得換這個。實測見事故紀錄第八節。
#
# 逾時後的行為是【放行,但大聲說出來】。理由:本專案明文規則是
# 「沉默不得與『hook 沒跑』長得一樣」(commit c9f2f88)。靜默 exit 0
# 會讓「檢查通過」與「檢查根本沒執行」在畫面上無法區分。
INPUT=$(timeout 2 cat)
if [ $? -eq 124 ]; then
    echo "⚠️  [log-agent-stop.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
    echo "    這不是『檢查通過』,是這道檢查沒有跑。若本次操作涉及受管檔案" >&2
    echo "    或提交/推送,請自行確認,或重跑一次讓閘門真的執行。" >&2
    exit 0
fi
# ----------------------------------------------------------------------

# Parse agent name -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_type // "unknown"' 2>/dev/null)
else
    AGENT_NAME=$(echo "$INPUT" | grep -oE '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"agent_type"[[:space:]]*:[[:space:]]*"//;s/"$//')
    [ -z "$AGENT_NAME" ] && AGENT_NAME="unknown"
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SESSION_LOG_DIR="production/session-logs"

mkdir -p "$SESSION_LOG_DIR" 2>/dev/null

echo "$TIMESTAMP | Agent completed: $AGENT_NAME" >> "$SESSION_LOG_DIR/agent-audit.log" 2>/dev/null

exit 0
