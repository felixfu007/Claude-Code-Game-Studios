#!/bin/bash
# Claude Code PreToolUse hook: Advises which agent owns a skill before it runs
# Fires on the "Skill" tool (invoking a /skill-name).
#
# WHY THIS EXISTS (2026-09-11, tools-programmer, per manager dispatch):
# On 2026-09-10 the coordinator ran /ux-review directly -- its SKILL.md
# frontmatter says `agent: ux-designer` in plain sight, line one of the file,
# and it was never opened. The coordinator's own reasoning ("the File
# Extension Routing table only covers .gd/.tscn, so this skill isn't in
# scope") was correct on its own terms and still missed the answer, because
# the routing lives in three separate places and nobody reads all three at
# the moment of acting. This hook exists to put the owner's name in front of
# whoever is about to run the skill, at the moment they run it, instead of
# relying on them to remember to check.
#
# DESIGN CHOICE: table lookup, not a live re-read of the target SKILL.md.
# .claude/agent-routing.tsv was generated FROM every SKILL.md's `agent:`
# field, so this is one hop removed from the source of truth. That is a
# deliberate trade-off, not an oversight: if a skill's `agent:` field is
# edited without regenerating the table, this hook will report the STALE
# value until the table is refreshed. This is the same drift risk this
# project's own docs warn about repeatedly (docs/consistency-failures.md).
# Regenerate with the command in the table's own header comment.
#
# NON-BLOCKING BY DESIGN (exit 0 always). The dispatch brief did not ask this
# hook to block, and this project has direct precedent for why an
# over-eager blocking gate gets disabled the first time it fires on a
# harmless case (see validate-commit.sh's unproven-completion gate comment).
# The goal here is that the owner's name appears -- not that the skill call
# is stopped.
#
# Input schema (PreToolUse for Skill) -- verified 2026-09-11 by extracting
# strings from the shipped claude.exe binary (no official doc covers this;
# .claude/docs/hooks-reference/hook-input-schemas.md does not list "Skill"
# at all). The extracted source function is:
#   function XZq(H,q,K){if(H!=="Skill")return; if (typeof q==="object" &&
#     q!==null && "skill" in q && typeof q.skill==="string") return q.skill; }
# i.e. tool_name is the literal string "Skill", and tool_input.skill holds
# the skill's name (e.g. "ux-review"). This was NOT verified end-to-end by
# triggering a real Skill tool call from this hook's own dev session --
# this subagent has no Skill tool in its own toolset to invoke one with.
# Treat the schema as string-extracted, not behaviourally confirmed; if this
# hook is ever observed to fire with no output on a real skill invocation,
# check this schema assumption first.
#
# { "tool_name": "Skill", "tool_input": { "skill": "ux-review" } }

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
    echo "⚠️  [advise-skill-owner.sh] 讀取 stdin 逾時 2 秒 —— 本次閘門【未執行】。" >&2
    echo "    這不是『檢查通過』,是這道檢查沒有跑。若本次操作涉及受管檔案" >&2
    echo "    或提交/推送,請自行確認,或重跑一次讓閘門真的執行。" >&2
    exit 0
fi
# ----------------------------------------------------------------------

if command -v jq >/dev/null 2>&1; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
    SKILL_NAME=$(echo "$INPUT" | jq -r '.tool_input.skill // empty')
else
    TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"tool_name"[[:space:]]*:[[:space:]]*"//;s/"$//')
    SKILL_NAME=$(echo "$INPUT" | grep -oE '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"skill"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if [ "$TOOL_NAME" != "Skill" ]; then
    exit 0
fi

if [ -z "$SKILL_NAME" ]; then
    echo "=== 擁有者提醒:讀不到 skill 名稱(tool_input.skill 為空),無法查對照表 ===" >&2
    exit 0
fi

TABLE=".claude/agent-routing.tsv"
if [ ! -f "$TABLE" ]; then
    echo "=== 擁有者提醒:對照表 $TABLE 不存在,無法查核 $SKILL_NAME 的擁有者 ===" >&2
    exit 0
fi

ROW=$(grep -E "^skill	${SKILL_NAME}	" "$TABLE" | head -1)

if [ -z "$ROW" ]; then
    echo "=== 擁有者提醒:對照表沒有 $SKILL_NAME 這一列(可能是新增的 skill,對照表尚未重新產生) ===" >&2
    echo "重新產生指令見 $TABLE 檔頭" >&2
    exit 0
fi

OWNER=$(echo "$ROW" | cut -f3)

case "$OWNER" in
    NO_DESIGNATED_AGENT)
        # Normal state, not a gap -- 53 of 73 skills have no single dedicated
        # agent by design (orchestration skills, general management skills).
        # Deliberately quiet: printing an alarm on the normal case is exactly
        # how the loud UNASSIGNED signal below would get trained into being
        # ignored (see agent-routing.tsv header, 2026-09-11 correction).
        echo "=== 擁有者提醒:skill '$SKILL_NAME' 無單一專屬 agent,由主線執行(正常狀態) ===" >&2
        ;;
    UNASSIGNED)
        echo "=== 擁有者提醒:即將執行 skill '$SKILL_NAME' ===" >&2
        echo "⚠️ 對照表判定此為治理缺口 —— 三個來源都查無擁有者,而這個位置理當要有一個。" >&2
        echo "若這份工作理當有專家覆核,現在是核對的時機,不要等到寫完。" >&2
        echo "==========================================================" >&2
        ;;
    AMBIGUOUS:*)
        CANDS=$(echo "$OWNER" | sed 's/^AMBIGUOUS://;s/|/、/g')
        echo "=== 擁有者提醒:即將執行 skill '$SKILL_NAME' ===" >&2
        echo "⚠️ 對照表列為候選未定案:$CANDS" >&2
        echo "==========================================================" >&2
        ;;
    *)
        echo "=== 擁有者提醒:skill '$SKILL_NAME' 的擁有者是 $OWNER ===" >&2
        echo "若你不是以 $OWNER 的身分/視角在執行這份工作,先確認是否該由它覆核。" >&2
        echo "==========================================================" >&2
        ;;
esac

exit 0
