#!/bin/bash
# Claude Code PreToolUse hook: Validates git commit commands
# Receives JSON on stdin with tool_input.command
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)
#
# Input schema (PreToolUse for Bash):
# { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }

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
    echo "⚠️  [validate-commit.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
    echo "    這不是『檢查通過』,是這道檢查沒有跑。若本次操作涉及受管檔案" >&2
    echo "    或提交/推送,請自行確認,或重跑一次讓閘門真的執行。" >&2
    exit 0
fi
# ----------------------------------------------------------------------

# --- 訊息分級(2026-09-14 加)-----------------------------------------
# 本檔真正的阻擋型檢查(doc-consistency 的 [ERROR] 級矛盾、injection 標記、
# 停用測試偵測)一律維持 exit 2,不受本次改動影響 —— 那條管道已實測會
# 送達 Claude。本次只改「不阻擋的那些」:它們原本 stderr + exit 0,
# 該組合已實測從不送達。改為額外排入佇列,由 session-start.sh 於下次
# 對話開場一次讀出並清空。完整理由見 .claude/hooks/lib/hook-queue.sh 檔頭。
if [ -f ".claude/hooks/lib/hook-queue.sh" ]; then
    source ".claude/hooks/lib/hook-queue.sh"
else
    queue_message() { :; }
fi
# ----------------------------------------------------------------------

# Parse command -- 純 bash,零子行程(本機每個 fork/exec 要 0.5~1.5 秒,實測)
# 🔴 2026-09-14 重寫,修掉兩個實測到的漏判(管理者裁決)。原版兩行,各有一個洞:
#   ① 舊備援用 '"[^"]*"' 抽值,遇到指令內的跳脫引號 \" 就截斷。本機【沒有 jq】,
#      所以一直走這條備援 —— cd "專案" && git commit 被抽成 `cd \` 兩個字。
#   ② 舊比對是 '^git[[:space:]]+commit' 對【整條指令】,但實測 51 個對話紀錄共
#      6096 條指令中有 4400 條(72%)開頭是 cd。含 git commit 的 71 條裡舊版只
#      認得 20 條(28%)—— 其餘 51 條提交【完全沒經過本閘門,且不留痕跡】。
# 新版把指令拆成片段(換行 / && / || / ; / |)後逐段比對開頭。
# ⚠️ 刻意【不】改成「整串搜尋 git commit」:那會讓 grep 'git commit' 這類純查詢
#    指令觸發本閘門,而本閘門會 exit 2 —— 等於用無關指令被擋來換涵蓋率。
# 實測:9 個單元案例(含 4 個必須不觸發者)全過;71 條真實提交指令 71/71 命中、零誤判。
extract_command() {
    local s="$1" SENT=$'\x01' BSQ='\"' BSN='\n' BST='\t'
    case "$s" in *'"command"'*) ;; *) return;; esac
    s="${s#*\"command\"}"; s="${s#*\"}"
    s="${s//"$BSQ"/$SENT}"; s="${s%%\"*}"; s="${s//$SENT/\"}"
    s="${s//"$BSN"/$'\n'}"; s="${s//"$BST"/$'\t'}"
    printf '%s' "$s"
}
segment_starts_with() {
    local s="$1" line
    s="${s//&&/$'\n'}"; s="${s//||/$'\n'}"; s="${s//;/$'\n'}"; s="${s//|/$'\n'}"
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ $line =~ $2 ]] && return 0
    done <<< "$s"
    return 1
}

if command -v jq >/dev/null 2>&1; then
    COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(extract_command "$INPUT")
fi

# Only process git commit commands
if ! segment_starts_with "$COMMAND" '^git[[:space:]]+commit'; then
    exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null)
if [ -z "$STAGED" ]; then
    exit 0
fi

WARNINGS=""

# Check design documents for required sections
DESIGN_FILES=$(echo "$STAGED" | grep -E '^design/gdd/')
if [ -n "$DESIGN_FILES" ]; then
    while IFS= read -r file; do
        if [[ "$file" == *.md ]] && [ -f "$file" ]; then
            for section in "Overview" "Player Fantasy" "Detailed" "Formulas" "Edge Cases" "Dependencies" "Tuning Knobs" "Acceptance Criteria"; do
                if ! grep -qi "$section" "$file"; then
                    WARNINGS="$WARNINGS\nDESIGN: $file missing required section: $section"
                fi
            done
        fi
    done <<< "$DESIGN_FILES"
fi

# Validate JSON data files -- block invalid JSON
DATA_FILES=$(echo "$STAGED" | grep -E '^assets/data/.*\.json$')
if [ -n "$DATA_FILES" ]; then
    # Find a working Python command
    PYTHON_CMD=""
    for cmd in python python3 py; do
        if command -v "$cmd" >/dev/null 2>&1; then
            PYTHON_CMD="$cmd"
            break
        fi
    done

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if [ -n "$PYTHON_CMD" ]; then
                if ! "$PYTHON_CMD" -m json.tool "$file" > /dev/null 2>&1; then
                    echo "BLOCKED: $file is not valid JSON" >&2
                    exit 2
                fi
            else
                echo "WARNING: Cannot validate JSON (python not found): $file" >&2
            fi
        fi
    done <<< "$DATA_FILES"
fi

# Check for hardcoded gameplay values in gameplay code
# Uses grep -E (POSIX extended) instead of grep -P (Perl) for cross-platform compatibility
CODE_FILES=$(echo "$STAGED" | grep -E '^src/gameplay/')
if [ -n "$CODE_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -nE '(damage|health|speed|rate|chance|cost|duration)[[:space:]]*[:=][[:space:]]*[0-9]+' "$file" 2>/dev/null; then
                WARNINGS="$WARNINGS\nCODE: $file may contain hardcoded gameplay values. Use data files."
            fi
        fi
    done <<< "$CODE_FILES"
fi

# Check for TODO/FIXME without assignee -- uses grep -E instead of grep -P
SRC_FILES=$(echo "$STAGED" | grep -E '^src/')
if [ -n "$SRC_FILES" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if grep -nE '(TODO|FIXME|HACK)[^(]' "$file" 2>/dev/null; then
                WARNINGS="$WARNINGS\nSTYLE: $file has TODO/FIXME without owner tag. Use TODO(name) format."
            fi
        fi
    done <<< "$SRC_FILES"
fi

# Print warnings (non-blocking) and allow commit
if [ -n "$WARNINGS" ]; then
    echo -e "=== Commit Validation Warnings ===$WARNINGS\n================================" >&2
    # 佇列版本需先展開 $WARNINGS 裡的字面 \n(printf %b,builtin,不 fork)。
    EXPANDED_WARNINGS=$(printf '%b' "$WARNINGS")
    queue_message "validate-commit:warnings" "=== Commit Validation Warnings ===
$EXPANDED_WARNINGS
================================"
fi

# ---------------------------------------------------------------------------
# Unproven-completion gate (added 2026-09-07).
#
# WHY: on 2026-09-07 the coordinator wrote "✅ ... AC-31 / AC-31b 兩條已解除"
# into story-011 while the wiring that would actually resolve them had not been
# done yet -- "the code exists" was silently equated with "the effect is live".
# It was self-caught a minute later, but it had already been written to a
# load-bearing work order. This project's whole recurring failure mode is
# "the thing exists" != "the thing works" (see docs/consistency-failures.md).
#
# WHAT: for staged .md files under production/ or design/, any ADDED line that
# claims completion must carry something checkable on the SAME line -- a file
# path, a test count, an exit code, or the words 測試/證據/spike. A bare claim
# gets named with its file:line.
#
# DELIBERATELY NON-BLOCKING. A gate that fires on harmless prose gets switched
# off, and a switched-off gate is worse than none because everyone assumes
# something is watching. This one names the line and lets the author answer.
CLAIM_DOCS=$(echo "$STAGED" | grep -E '^(production|design)/.*\.md$')
if [ -n "$CLAIM_DOCS" ]; then
    UNPROVEN=$(git diff --cached -U0 -- $CLAIM_DOCS 2>/dev/null | awk '
        /^\+\+\+ b\// { file = substr($0, 7); next }
        /^@@ / {
            # @@ -old,cnt +new,cnt @@  -> take the +new start line
            match($0, /\+[0-9]+/); ln = substr($0, RSTART+1, RLENGTH-1) + 0; next
        }
        /^\+/ {
            line = substr($0, 2)
            # NARROW ON PURPOSE. A first, broader version of this check
            # (any ✅/已完成 without evidence) flagged 18 of 29 claim-bearing
            # lines on the very commit that introduced it -- all but one a false
            # positive from coverage tables, Status headers and check tables that
            # legitimately carry ✅. A gate that noisy gets switched off, and a
            # switched-off gate is worse than none because everyone assumes
            # something is watching. So this matches ONE shape: a claim that a
            # SPECIFICALLY NUMBERED item changed state, with nothing checkable
            # beside it. Measured on 2026-09-07: 0 hits on that days good commit,
            # 1 hit on the actual mistake, 0 hits once the proof was cited.
            if (line ~ /已解除|已生效|不再是空|定義域.*不再/ &&
                line ~ /AC-[0-9]+|Story [0-9]+|TR-[a-z]+-[0-9]+|ADR-[0-9]+/ &&
                line !~ /^\|/ &&
                line !~ /\.(gd|md|png|txt|tscn|tres|yaml|sh)|[0-9]+ ?條|exit|測試|證據|spike|prototypes|待|尚未|未/) {
                printf "  %s:%d  %s\n", file, ln, substr(line, 1, 95)
                hits++
            }
            ln++; next
        }
        END { if (hits) printf "  --- %d unproven completion claim(s) ---\n", hits }
    ')
    if [ -n "$UNPROVEN" ]; then
        UNPROVEN_MSG="=== Unproven completion claims in staged docs ===
$UNPROVEN
Each line above says something is done without naming a checkable artifact
on the same line (a path, a test count, an exit code, or 測試/證據/spike).
If it IS done, cite the proof. If it is not, say what it is waiting on.
================================================"
        echo "$UNPROVEN_MSG" >&2
        queue_message "validate-commit:unproven-claims" "$UNPROVEN_MSG"
    fi
fi

# Cross-file documentation drift gate.
# Runs in --gate mode: BLOCKS the commit on high-confidence contradictions
# (e.g. a GDD header and systems-index.md disagreeing about approval status,
# a placeholder claiming no ADRs exist when they do, active.md claiming
# uncommitted work when the tree is clean). Heuristic findings only warn.
# This project's most expensive recurring failure is a fact updated in one
# place and left stale in another; blocking here stops new drift from landing.
# Escape hatch: SKIP_DOC_CONSISTENCY=1
if [ -f ".claude/hooks/validate-doc-consistency.sh" ]; then
    # 2026-09-14:捕捉輸出而非直接串流,以便在 WARN-only(不阻擋)時排入佇列。
    # ERROR 級(DOC_RC=2)行為完全不變 —— 仍是 stderr + exit 2,立即送達。
    DOC_OUTPUT=$(bash .claude/hooks/validate-doc-consistency.sh --gate 2>&1)
    DOC_RC=$?
    if [ -n "$DOC_OUTPUT" ]; then
        echo "$DOC_OUTPUT" >&2
    fi
    if [ "$DOC_RC" -eq 2 ]; then
        exit 2
    fi
    if [ -n "$DOC_OUTPUT" ]; then
        queue_message "validate-commit:doc-consistency" "$DOC_OUTPUT"
    fi
fi


# ---------------------------------------------------------------------------
# Sensitivity-proof injection gate (added 2026-09-10).
#
# WHY: proving a test is sensitive means deliberately breaking the production
# code and checking the test goes red. That break must then be reverted. Twice
# now it was not: once a specialist left
# `return atk + 1 # INJECTED FAULT FOR SENSITIVITY PROOF -- DO NOT COMMIT`
# in production code with its report truncated before "Now revert", and on
# 2026-09-10 two specialists each stopped mid-proof with a live injection in
# src/gameplay/cards/card_modifier_rules.gd. BOTH times the only thing that
# caught it was a human running grep by hand. A defence that depends on
# someone remembering to look is exactly the shape this project keeps failing
# at (docs/consistency-failures.md).
#
# BLOCKING, unlike the prose gate below it. An uppercase INJECT marker in
# staged source has no legitimate use -- and a deliberately broken formula
# reaching main is not a style nit, it is a wrong game rule that every later
# test would then be validated against.
#
# UPPERCASE ONLY, and that is measured rather than assumed. On 2026-09-10 the
# case-sensitive pattern below matched 0 lines across src/ tests/ tools/
# (excluding the live injection it was written for), while a case-INsensitive
# `inject` matched 60 -- every one of them ordinary "dependency injection" /
# "inject the RNG" prose in doc comments. A gate that noisy gets switched off,
# and a switched-off gate is worse than none.
#
#
# 🔴 KNOWN LIMITATION, found the same day this gate was written: it only sees
# injections that carry a marker. On 2026-09-10 a fifth specialist proved AC-5
# by replacing `_selected_card.delta_atk` with a literal `0` in
# card_play_session.gd's confirm() -- no marker, so this gate was blind to it.
# That particular break means "every ATK buff card silently does nothing": it
# does not crash, does not fail to compile, and would only ever surface as a
# player wondering why the cards feel useless.
#
# What caught it was a human reading the diff, which is the same thing that
# caught the two marked ones. So: this gate raises the floor, it does not
# replace review. Do not read a green gate as "no injection present."
# Dispatch briefs should tell specialists to always mark injections -- the
# marker is their own insurance too, since three of ten agent reports that day
# truncated while an injection was still live.
# Escape hatch: SKIP_INJECTION_GATE=1 (for committing this hook's own docs).
if [ "$SKIP_INJECTION_GATE" != "1" ]; then
    GATE_FILES=$(echo "$STAGED" | grep -E '^(src|tests|tools)/')
    if [ -n "$GATE_FILES" ]; then
        FOUND=""
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                HITS=$(grep -nE '(INJECT[A-Z_]*|INJECTED FAULT|DO NOT COMMIT)' "$file" 2>/dev/null)
                if [ -n "$HITS" ]; then
                    FOUND="$FOUND\n  $file:\n$(echo "$HITS" | sed 's/^/    /')"
                fi
            fi
        done <<< "$GATE_FILES"
        if [ -n "$FOUND" ]; then
            echo "BLOCKED: staged code still contains a sensitivity-proof injection marker." >&2
            echo -e "$FOUND" >&2
            echo "" >&2
            echo "A deliberately broken formula must be reverted before committing." >&2
            echo "If this is a false positive, rename the marker or set SKIP_INJECTION_GATE=1." >&2
            exit 2
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Disabled-test gate (added 2026-09-10, same session as the injection gate).
#
# WHY: the correct way to prove test N is sensitive is to rename the test_
# functions BEFORE it out of GdUnit4's collection, because a real failure
# aborts the remaining tests in its own suite (coding-standards.md). That
# rename must then be undone. On 2026-09-10 a specialist stopped mid-proof
# with 12 of 18 tests renamed to off_test_*: the file still looked full, the
# suite still went green, and it was running one third of what it claimed.
# That is this project's signature failure -- "the test exists" != "the test
# ran" -- and the injection gate above does NOT catch it, because a renamed
# test contains no INJECT marker.
#
# BLOCKING. A test file committed with two thirds of its cases uncollected is
# worse than one with no tests at all, because the count in the CI log reads
# as coverage.
#
# Pattern measured 2026-09-10 across the whole tests/ tree: 12 hits, all of
# them the live in-flight renames it was written for; 0 hits among the 448
# pre-existing tests. Matches a func whose name embeds test_ but does not
# start with it -- off_test_, ztest_, xtest_, disabled_test_, skip_test_.
#
# Escape hatch: SKIP_DISABLED_TEST_GATE=1
if [ "$SKIP_DISABLED_TEST_GATE" != "1" ]; then
    TEST_FILES=$(echo "$STAGED" | grep -E '^tests/.*\.gd$')
    if [ -n "$TEST_FILES" ]; then
        DISABLED=""
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # Precise, because the obvious regex is wrong. A first version
                # used `^func [a-z_]+_test_`, which also matched a legitimate
                # `test_latest_test_naming_ok` -- any test whose own name
                # happens to contain `_test_` again further along. Measured on
                # a scratch probe 2026-09-10: that regex flagged it, this awk
                # does not. Rule: the function name embeds `test_` but does
                # NOT start with `test_` (a real case) and does NOT start with
                # `_` (a private helper).
                HITS=$(awk '
                    /^func [A-Za-z_][A-Za-z0-9_]*[ \t]*\(/ {
                        name = $2
                        sub(/[ \t]*\(.*/, "", name)
                        if (index(name, "test_") > 0 && name !~ /^test_/ && name !~ /^_/)
                            printf "%d: func %s\n", FNR, name
                    }
                ' "$file" 2>/dev/null)
                if [ -n "$HITS" ]; then
                    DISABLED="$DISABLED\n  $file:\n$(echo "$HITS" | sed 's/^/    /')"
                fi
            fi
        done <<< "$TEST_FILES"
        if [ -n "$DISABLED" ]; then
            echo "BLOCKED: staged test files contain cases renamed out of collection." >&2
            echo -e "$DISABLED" >&2
            echo "" >&2
            echo "These will never run, while the file still reads as full coverage." >&2
            echo "Rename them back to test_* before committing." >&2
            echo "If a case is disabled on purpose, say so in the story and set" >&2
            echo "SKIP_DISABLED_TEST_GATE=1 for this commit." >&2
            exit 2
        fi
    fi
fi

exit 0
