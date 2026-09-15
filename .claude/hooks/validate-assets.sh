#!/bin/bash
# Claude Code PostToolUse hook: Validates asset files after Write/Edit
# Checks naming conventions for files in assets/ directory
#
# Exit behavior:
#   exit 0 = success or advisory warnings only (non-blocking)
#   exit 1 = 有 build-breaking 問題(🔴 實測【不會阻擋】,詳見檔尾「送達管道」段)
#
# Input schema (PostToolUse for Write/Edit):
# { "tool_name": "Write", "tool_input": { "file_path": "assets/data/foo.json", "content": "..." } }

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
    echo "⚠️  [validate-assets.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
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

# Only check files in assets/
if ! echo "$FILE_PATH" | grep -qE '(^|/)assets/'; then
    exit 0
fi

FILENAME=$(basename "$FILE_PATH")
WARNINGS=""   # Style/convention issues -- exit 0 with advisory message
ERRORS=""     # Build-breaking issues -- 排入佇列(exit 1 實測【不阻擋】,見檔尾)

# ADVISORY: Check naming convention (lowercase with underscores only)
# Naming issues are style violations -- warn but do not block
# Uses grep -E (POSIX) not grep -P (Perl) for Windows Git Bash compatibility
if echo "$FILENAME" | grep -qE '[A-Z[:space:]-]'; then
    WARNINGS="$WARNINGS\n  NAMING: $FILE_PATH must be lowercase with underscores (got: $FILENAME)"
fi

# BLOCKING: Check JSON validity for data files
# Invalid JSON will break runtime loading -- this is a build-breaking error
if echo "$FILE_PATH" | grep -qE '(^|/)assets/data/.*\.json$'; then
    if [ -f "$FILE_PATH" ]; then
        # Find a working Python command
        PYTHON_CMD=""
        for cmd in python python3 py; do
            if command -v "$cmd" >/dev/null 2>&1; then
                PYTHON_CMD="$cmd"
                break
            fi
        done

        if [ -n "$PYTHON_CMD" ]; then
            if ! "$PYTHON_CMD" -m json.tool "$FILE_PATH" > /dev/null 2>&1; then
                ERRORS="$ERRORS\n  FORMAT: $FILE_PATH is not valid JSON — fix syntax errors before continuing"
            fi
        fi
    fi
fi

# --- 送達管道(2026-09-15 修)-----------------------------------------
# 🔴 修正一個假的檔頭宣告。本檔原本寫「exit 1 = blocking error … to block
# the operation」,而那是【錯的】:依本專案 2026-09-14 以探針實測的管道矩陣
# (.claude/docs/hooks-reference/hook-input-schemas.md),PostToolUse 事件
# 只有 exit 0 與「其他」兩種結果,「其他」的定義逐字是
# 「Treated as error, tool proceeds」—— 亦即 exit 1 【不會擋下任何東西】。
# 而 exit 2 的阻擋語意是 PreToolUse 專屬,對 PostToolUse 同樣無效,
# 所以這裡【不能】靠把 1 改成 2 來修。
#
# 同一份矩陣另一列:PostToolUse 的 stderr + exit 0 →「不送達 Claude、
# 使用者也看不到」。本檔原本 5 行輸出全部走這條,亦即這道資產閘門
# 從上線以來說的每一句話都沒有任何人收到,同時還自稱它會擋。
#
# 修法與其餘閘門一致:排入佇列,由 session-start.sh 於下次對話開場一次讀出
# (實測 SessionStart 的 stdout 是會送達的管道)。
# ⚠️ stderr 那兩行【保留不刪】—— 它們會進逐字紀錄的 stderr 欄位,事後稽核
# 查得到;刪掉只是少一份證據,留著不會多花任何行程。
# ⚠️ exit 1 同樣【保留不改】—— 它實測不阻擋,但也沒有害處,而「其他 exit code
# 對使用者到底看不看得到」本專案【尚未實測】。把它改掉等於在沒有量測的情況下
# 動一條可能有用的管道。本次只補上一條確定會送達的,不移除未知的。
if [ -f ".claude/hooks/lib/hook-queue.sh" ]; then
    source ".claude/hooks/lib/hook-queue.sh"
else
    queue_message() { :; }
fi

# Report warnings (advisory -- non-blocking)
if [ -n "$WARNINGS" ]; then
    WARN_MSG=$(echo -e "=== Asset Validation: Warnings ===$WARNINGS\n==================================\n(Warnings are advisory. Fix before final commit.)")
    echo "$WARN_MSG" >&2
    queue_message "validate-assets:warnings" "$WARN_MSG"
fi

# Report errors.
# 🔴 標題原寫「Report errors and block」—— 見上方,它從來沒有 block 過。
if [ -n "$ERRORS" ]; then
    ERR_MSG=$(echo -e "=== Asset Validation: ERRORS ===$ERRORS\n================================\nFix these errors before proceeding.\n⚠️ 本檢查【無法阻擋】這次寫入(PostToolUse 沒有阻擋語意),檔案已經寫下去了。")
    echo "$ERR_MSG" >&2
    queue_message "validate-assets:ERRORS" "$ERR_MSG"
    exit 1
fi

exit 0
