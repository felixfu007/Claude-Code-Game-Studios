#!/bin/bash
# Claude Code PostToolUse hook: Advises running skill-test after skill file changes
# Fires when any file inside .claude/skills/ is written or edited.
#
# Exit behavior:
#   exit 0 = advisory only (non-blocking)
#
# Input schema (PostToolUse for Write|Edit):
# { "tool_name": "Write", "tool_input": { "file_path": "...", "content": "..." } }

# --- stdin 讀取超時保護(2026-09-11 加)-------------------------------
# 原本是裸的 INPUT=$(cat)。若 Claude Code 沒有關閉 stdin,這一行會無限期
# 阻塞:CPU 0%、無輸出、不留任何痕跡,從外面看跟「還在跑」一模一樣。
# 2026-09-11 實際發生 —— advise-file-owner.sh(PID 9240)與
# validate-commit.sh(PID 35748)各自卡死 89 分鐘,把整個 session 凍住,
# 而 Claude Code 的 hook 逾時只取消了「邏輯上的 hook」,沒有殺掉行程。
#
# 🔴 2026-09-11 傍晚更正:上面那個「89 分鐘卡死」的根因判定是錯的(真因是
# hook 逾時上限低於實際耗時,見 production/session-state/hook-stdin-hang-2026-09-11.md
# 的「更正」節)。本保護予以保留 —— 那種卡法理論上仍存在,但它【不是零成本】:
# 每支每次約付 780~860ms(timeout 與 cat 各一個行程;本機每個 fork/exec 要 0.5~1.5 秒)。
# 且 validate-commit / validate-push / advise-file-owner 三支的 matcher 都是 Bash,
# 代表【每一個】Bash 指令都付這筆,不是只在提交/推送時付。
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
    echo "⚠️  [validate-skill-change.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
    echo "    這不是『檢查通過』,是這道檢查沒有跑。若本次操作涉及受管檔案" >&2
    echo "    或提交/推送,請自行確認,或重跑一次讓閘門真的執行。" >&2
    exit 0
fi
# ----------------------------------------------------------------------

# Parse file path -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
else
    FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Normalize path separators (Windows backslash to forward slash)
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# Only act on files inside .claude/skills/
if ! echo "$FILE_PATH" | grep -qE '(^|/)\.claude/skills/'; then
    exit 0
fi

# Extract skill name from path (.claude/skills/[skill-name]/SKILL.md)
SKILL_NAME=$(echo "$FILE_PATH" | grep -oE '\.claude/skills/[^/]+' | sed 's|\.claude/skills/||')

if [ -z "$SKILL_NAME" ]; then
    exit 0
fi

# --- 送達管道(2026-09-15 修)-----------------------------------------
# 🔴 本檔原本 3 行輸出全部是 stderr + exit 0,而本專案 2026-09-14 的探針實測
# (.claude/docs/hooks-reference/hook-input-schemas.md 的管道矩陣)顯示
# PostToolUse 的 stderr + exit 0【不送達 Claude、使用者也看不到】。
# 加上本檔全檔沒有任何非 0 的 exit,它在結構上從來不可能被任何人讀到 ——
# 亦即「改了 skill 要記得跑 /skill-test」這句話,從上線至今說了幾次就落空幾次。
# 改走佇列,由 session-start.sh 於下次對話開場讀出(實測會送達的管道)。
# ⚠️ 提醒會【延遲到下次開場】才出現,這是平台限制不是設計選擇:
# 依同一份矩陣,「不阻擋 + 立即看得到」這個組合不存在。
if [ -f ".claude/hooks/lib/hook-queue.sh" ]; then
    source ".claude/hooks/lib/hook-queue.sh"
else
    queue_message() { :; }
fi

SKILL_MSG="=== Skill Modified: $SKILL_NAME ===
Run /skill-test static $SKILL_NAME to validate structural compliance.
===================================="
echo "$SKILL_MSG" >&2
queue_message "validate-skill-change" "$SKILL_MSG"

exit 0
