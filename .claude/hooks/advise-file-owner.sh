#!/bin/bash
# Claude Code PreToolUse hook: Advises which agent owns a file path before it
# gets written. Covers two tools: Write/Edit directly, and Bash commands that
# write files by other means (sed -i, redirects, tee, mv, cp, rm).
#
# WHY THE BASH BRANCH EXISTS (2026-09-11, added same day as the rest, after
# the coordinator found the gap live): the coordinator's actual edits in this
# project run almost entirely through Bash (sed -i, awk rewrites, heredoc
# "cat > file"), not through the Write/Edit tools this hook originally only
# covered. A reminder registered on Write|Edit alone never fires for the
# person it was built to catch -- which is the exact shape of failure this
# whole exercise exists to prevent: a gate that looks like protection and is
# silently inert for the highest-risk path. Verified live: a raw
# sed -i s/a/b/ design/ux/foo.md through the original Write|Edit-only
# version produced zero output.
#
# THE BASH BRANCH IS A HEURISTIC, NOT A PARSER. It pattern-matches the
# command TEXT for known write shapes and grabs whitespace-split tokens that
# look like paths. It does not parse shell syntax, does not resolve
# variables/command substitution, and does not understand quoting beyond a
# bare strip of surrounding quote characters. NO OUTPUT FROM THIS BRANCH
# MEANS "NO KNOWN PATTERN MATCHED", NOT "NOTHING WAS WRITTEN". See the
# KNOWN BLIND SPOTS list below and in .claude/agent-routing.tsv's header --
# this project's own rule is that partial coverage is fine, pretending it is
# complete is not.
#
# KNOWN BLIND SPOTS (not caught by this hook, found 2026-09-11 by construction,
# not by testing every case):
#   - Non-literal targets: variables, command substitution, glob expansion
#     (sed -i ... "$FILE", mv "$(find ...)" dest)
#   - Heredoc BODIES are not scanned for embedded paths; only a redirect
#     target token adjacent to whitespace is caught.
#   - Chained/piped commands (&&, ;, |) are scanned as one flat token
#     stream -- a candidate token from a read-only half of the chain can still
#     fire if it happens to look path-like and land in the table.
#   - Non-bash write paths: PowerShell (Set-Content, Out-File, -replace
#     in place), python -c "open(...).write(...)", git apply,
#     git checkout -- file, rsync, curl -o, dd, install.
#   - git mv (only bare mv is matched).
#
# QUIETING RULE FOR THE BASH BRANCH (deliberately asymmetric with Write/Edit):
# Write/Edit prints an explicit "not in table" line on a miss (added earlier
# today after the same silence-vs-broken concern). The Bash branch does NOT --
# it only speaks when a write-like pattern AND a concrete table hit both
# occur. Reasoning: most Bash write-like commands target files outside this
# table entirely (temp files, log redirects, 2>/dev/null), and an explicit
# miss line on every one of those would retrain exactly the habituation this
# whole project keeps finding and fixing. This means: a Bash write to a path
# this table does not cover produces NO reminder at all, by design, not by gap.
#
# NON-BLOCKING BY DESIGN, exit 0 always (manager ruling) -- see the
# report_owner_for_path bookkeeping-exemption comment further down, unchanged
# from the earlier version of this hook.
#
# Input schemas:
#   Write/Edit (documented in .claude/docs/hooks-reference/hook-input-schemas.md):
#     { "tool_name": "Write"|"Edit", "tool_input": { "file_path": "..." } }
#   Bash (same doc):
#     { "tool_name": "Bash", "tool_input": { "command": "..." } }

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
    echo "⚠️  [advise-file-owner.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
    echo "    這不是『檢查通過』,是這道檢查沒有跑。若本次操作涉及受管檔案" >&2
    echo "    或提交/推送,請自行確認,或重跑一次讓閘門真的執行。" >&2
    exit 0
fi
# ----------------------------------------------------------------------

if command -v jq >/dev/null 2>&1; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
else
    TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

TABLE=".claude/agent-routing.tsv"
if [ ! -f "$TABLE" ]; then
    exit 0
fi

# report_owner_for_path REL_PATH SHOW_NO_MATCH LABEL
# SHOW_NO_MATCH=1 prints an explicit "not covered" line on a miss (Write/Edit
# behaviour). SHOW_NO_MATCH="" stays silent on a miss (Bash-heuristic
# behaviour, see QUIETING RULE above). Returns 0 if it printed an owner block.
report_owner_for_path() {
    local REL_PATH="$1"
    local SHOW_NO_MATCH="$2"
    local LABEL="$3"

    local BEST_KEY="" BEST_OWNER="" TYPE KEY OWNER SRC
    while IFS=$'\t' read -r TYPE KEY OWNER SRC; do
        [ "$TYPE" = "path" ] || continue
        case "$REL_PATH" in
            "$KEY"*)
                if [ ${#KEY} -gt ${#BEST_KEY} ]; then
                    BEST_KEY="$KEY"; BEST_OWNER="$OWNER"
                fi
                ;;
        esac
    done < "$TABLE"

    local EXT_OWNER=""
    while IFS=$'\t' read -r TYPE KEY OWNER SRC; do
        [ "$TYPE" = "ext" ] || continue
        case "$REL_PATH" in
            *"$KEY") EXT_OWNER="$OWNER" ;;
        esac
    done < "$TABLE"

    if [ -z "$BEST_KEY" ] && [ -z "$EXT_OWNER" ]; then
        if [ "$SHOW_NO_MATCH" = "1" ]; then
            local PATH_ROW_COUNT
            PATH_ROW_COUNT=$(grep -c "^path	" "$TABLE" 2>/dev/null)
            echo "此路徑不在對照表中(對照表 ${PATH_ROW_COUNT:-0} 個路徑前綴皆未命中)—— 無法判定擁有者,不等於沒有擁有者。" >&2
        fi
        return 1
    fi

    echo "=== 檔案擁有者提醒${LABEL}:即將寫入 $REL_PATH ===" >&2

    local PRINTED_OWNER=""
    if [ -n "$BEST_KEY" ]; then
        case "$BEST_OWNER" in
            UNASSIGNED)
                echo "⚠️ 路徑 '$BEST_KEY' 對照表判定為治理缺口 —— 三個來源都查無擁有者。" >&2
                ;;
            AMBIGUOUS:*)
                local CANDS
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

    # Bookkeeping-exemption note -- answers both questions instead of
    # choosing one. Scope is deliberately named, not inferred from
    # BEST_OWNER (production/session-state, PROJECT-STATUS.md, ADR status
    # tables, registry entries -- the places this project's own docs describe
    # the coordinator as routinely recording decisions made elsewhere).
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
    return 0
}

if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
    if command -v jq >/dev/null 2>&1; then
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    else
        FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"file_path"[[:space:]]*:[[:space:]]*"//;s/"$//')
    fi
    FILE_PATH="${FILE_PATH//\\//}"
    [ -z "$FILE_PATH" ] && exit 0
    REL_PATH="${FILE_PATH##*/Claude-Code-Game-Studios/}"
    report_owner_for_path "$REL_PATH" "1" ""
    exit 0
fi

if [ "$TOOL_NAME" = "Bash" ]; then
    if command -v jq >/dev/null 2>&1; then
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    else
        COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
    fi
    [ -z "$COMMAND" ] && exit 0

    # Gate: only proceed if the command TEXT looks write-shaped. This is what
    # keeps grep/git status/wc etc. (the bulk of Bash calls) silent -- without
    # this gate, a plain "cat design/ux/foo.md" (a READ) would also produce a
    # false "owner" reminder purely because the path happens to be in the
    # table, once we start tokenizing for candidate paths below.
    WRITE_LIKE=""
    echo "$COMMAND" | grep -qE '(^|[;&|]|[[:space:]])sed[[:space:]]+-i' && WRITE_LIKE=1
    echo "$COMMAND" | grep -qE '(^|[;&|]|[[:space:]])tee([[:space:]]|$)' && WRITE_LIKE=1
    echo "$COMMAND" | grep -qE '(^|[;&|]|[[:space:]])mv[[:space:]]' && WRITE_LIKE=1
    echo "$COMMAND" | grep -qE '(^|[;&|]|[[:space:]])cp[[:space:]]' && WRITE_LIKE=1
    echo "$COMMAND" | grep -qE '(^|[;&|]|[[:space:]])rm[[:space:]]' && WRITE_LIKE=1
    echo "$COMMAND" | grep -qE '>>?[[:space:]]*[^&[:space:]]' && WRITE_LIKE=1

    [ -z "$WRITE_LIKE" ] && exit 0

    # Tokenize on whitespace (word-splitting only, not real shell parsing --
    # see header). Strip a leading redirect operator or surrounding quote
    # char from each token, then keep tokens that look path-like (contain
    # '/' or a dot) and are not bare flags.
    for TOKEN in $COMMAND; do
        CAND="${TOKEN#>>}"; CAND="${CAND#>}"
        CAND="${CAND%\"}"; CAND="${CAND#\"}"
        CAND="${CAND%\'}"; CAND="${CAND#\'}"
        CAND="${CAND//\\//}"
        [ -z "$CAND" ] && continue
        case "$CAND" in
            -*) continue ;;
        esac
        case "$CAND" in
            */*|*.*)
                REL_PATH="${CAND##*/Claude-Code-Game-Studios/}"
                report_owner_for_path "$REL_PATH" "" "(Bash 指令偵測,啟發式、可能有漏)"
                ;;
        esac
    done
    exit 0
fi

exit 0
