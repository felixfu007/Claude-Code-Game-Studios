#!/bin/bash
# Hook: validate-doc-consistency.sh
# Events: SessionStart (report mode) + called from validate-commit.sh (gate mode)
#
# PURPOSE
#   Checks CROSS-FILE FACT AGREEMENT — not whether a doc exists (detect-gaps.sh
#   already does that), but whether two docs storing the same fact still agree.
#
# WHY THIS EXISTS
#   This project's dominant failure mode, by a wide margin, is desynchronization:
#   the same fact recorded in two places, one updated, the other left stale.
#   Real incidents encoded below as invariants:
#     - systems-index.md claimed a GDD was "尚未經 /design-review" after 4 rounds
#     - technical-preferences.md claimed "[No ADRs yet]" after ADR-0001 was committed
#     - active.md claimed "尚未 commit" while the git tree was clean
#     - a GDD header claimed session-state was gitignored when it was not (64b425b)
#     - 2026-08-09: three systems' Status columns disagreed with their GDD headers
#   Every one was caught only because a human happened to look. This converts
#   "happened to look" into "looks every time".
#
# PERFORMANCE CONSTRAINT (measured, not assumed)
#   On this project's Windows Git Bash a subprocess costs ~372ms (50 trivial spawns
#   = 18.6s), while grepping every GDD costs 0.27s. Process count IS the runtime.
#   The first version of this script spawned ~150 processes and took 64s — unusable
#   against settings.json's 10s SessionStart timeout. It is therefore written to
#   BATCH every grep and do all per-file logic with shell builtins (case/parameter
#   expansion, which fork nothing). Keep it that way: adding one grep inside a loop
#   over files will silently make this hook time out.
#
# USAGE
#   bash .claude/hooks/validate-doc-consistency.sh            # report mode, exit 0
#   bash .claude/hooks/validate-doc-consistency.sh --gate     # exit 2 on [ERROR]
#   bash .claude/hooks/validate-doc-consistency.sh --handoff  # C4+C7 only, ~1s
#   bash .claude/hooks/validate-doc-consistency.sh --line-refs # the C6 backlog
#   SKIP_DOC_CONSISTENCY=1 ...                                # escape hatch
#
# Cross-platform: Windows Git Bash compatible (grep -E only, never grep -P).
#
# CHANGE LOG — 2026-09-03 (manager-approved items 1-3 of the tooling proposal)
#   The trigger was measuring this hook's OWN output instead of trusting it:
#   21 visible lines, 8 of them one warning class that self-reported 152 members,
#   and the single [ERROR] sitting at line 7 inside that block.
#   1. Same-class warning collapse. C6 prints ONE summary line + a reproduce
#      command (--line-refs); C1's "no Status header" class prints one line.
#      Measured: 21 output lines -> 13.
#   2. C4 was a PERMANENT FALSE POSITIVE and is now scoped. active.md is an
#      append-only handoff log; it grepped the whole file and tripped on a
#      "待 commit" note from an archived batch whose work shipped long ago.
#      A red light that is always on is not a red light.
#   3. New C7: a ruling recorded in the tech-debt register vs a blanket
#      "nothing has been ruled" claim left in the handoff documents. That exact
#      desync happened on 2026-09-03, thirty minutes after the ruling.
#   Also: [ERROR]s are printed FIRST, in their own counted block. Ordering is
#   the only fix here that does not depend on anyone curating the warning set.
#
# RUNTIME after these changes (measured on this machine, clean tree):
#   6.1s before -> 7.7s after, against settings.json's 20s SessionStart timeout.
#   The delta is 3 added greps at ~0.4s each. Process count is still the runtime;
#   see the performance constraint above before adding a fourth.
#
# FIRING-POINT LIMIT, stated because it is not obvious and was missed for weeks
#   C4 requires a CLEAN tree, and --gate runs PRE-commit where the tree is dirty
#   by definition. C4 therefore CANNOT block a commit, ever. It is a report-mode
#   invariant. session-stop.sh runs this script so it is also surfaced at session
#   end, when the tree is usually clean. Do not "fix" this by relaxing C4 to fire
#   on a dirty tree — during an edit session the claim is legitimately true.
#
# SELF-REFERENCE TRAP (hit immediately, while documenting the fix above)
#   Prose that QUOTES a trigger string is not a claim. Three exclusion layers:
#   markdown blockquote lines, same-line quote markers (原文寫 / 原登記為 / …),
#   and an explicit fence:
#       <!-- doc-consistency: ignore -->  …  <!-- doc-consistency: end-ignore -->
#   The fence is a real suppression mechanism. It is greppable on purpose.

set +e

MODE="report"
[ "$1" = "--gate" ] && MODE="gate"
[ "$1" = "--handoff" ] && MODE="handoff"
[ "$SKIP_DOC_CONSISTENCY" = "1" ] && exit 0

cd "$(dirname "$0")/../.." 2>/dev/null || exit 0

# ── --line-refs: print the C6 backlog in full, then stop ────────────────────
# C6 is collapsed to one line in normal runs (2026-09-03). This is where the
# individual hits live now. Nothing else runs in this mode.
if [ "$1" = "--line-refs" ]; then
    grep -rnoE '第 ?[0-9]+(/[0-9]+)* ?[列行]|see line [0-9]+|見第 ?[0-9]+' \
        --include='*.md' design docs/architecture docs/registry 2>/dev/null \
      | awk -F: '
          { file=$1; ln=$2; text=$0; sub(/^[^:]*:[^:]*:/, "", text);
            if (match(text, /[0-9]+/)) {
                n = substr(text, RSTART, RLENGTH) + 0;
                if (n > 14) { k=file":"ln":"n; if (seen[k]++) next; total++;
                    printf "  %s:%s cites number %d as a location\n", file, ln, n; } } }
          END { printf "  --- %d suspected line-number self-references ---\n", total+0; }'
    exit 0
fi

FINDINGS=""
# Builtin-only accumulation: no forks.
add_err()  { FINDINGS="$FINDINGS  [ERROR] $1
"; }
add_warn() { FINDINGS="$FINDINGS  [warn]  $1
"; }

# ── Classification helpers: pure builtins, set a global, never fork ──────────
# Only the first 60 chars of a status field are examined. The verdict always sits
# at the start, while the prose after it routinely contains "Approved" inside
# negations ("尚未 Approved", "才得判 Approved") that fool a plain substring test.
CLASS=""
classify_status() {
    local h=${1:0:60}
    case "$h" in
        *"尚未 Approved"*|*"尚未Approved"*|*"不得視為 Approved"*|*"未 Approved"*|\
        *"Not Started"*|*Designed*|*Revised*|*"NEEDS REVISION"*|*"Needs Revision"*|\
        *"MAJOR REVISION"*|*"In Review"*|*Draft*) CLASS="NOT_APPROVED" ;;
        *Approved*) CLASS="APPROVED" ;;
        *) CLASS="UNKNOWN" ;;
    esac
}

CNINT=""
cn_to_int() {
    case "$1" in
        一) CNINT=1 ;;  二) CNINT=2 ;;  三) CNINT=3 ;;  四) CNINT=4 ;;  五) CNINT=5 ;;
        六) CNINT=6 ;;  七) CNINT=7 ;;  八) CNINT=8 ;;  九) CNINT=9 ;;  十) CNINT=10 ;;
        十一) CNINT=11 ;; 十二) CNINT=12 ;; 十三) CNINT=13 ;; 十四) CNINT=14 ;;
        十五) CNINT=15 ;; 十六) CNINT=16 ;; 十七) CNINT=17 ;; 十八) CNINT=18 ;;
        十九) CNINT=19 ;; 二十) CNINT=20 ;; *) CNINT="" ;;
    esac
}

# ── Gather: build the GDD list with a glob (a glob forks nothing; find would) ──
GDDS=""
for f in design/gdd/*.md; do
    [ -f "$f" ] || continue
    case "$f" in *systems-index*|*game-concept*|*cross-review*) continue ;; esac
    GDDS="$GDDS $f"
done
[ -z "$GDDS" ] && exit 0

ADR_COUNT=0
for f in docs/architecture/adr-*.md; do
    [ -f "$f" ] && ADR_COUNT=$((ADR_COUNT + 1))
done

# --handoff runs ONLY the two handoff-document invariants (C4, C7). Everything
# below this line is skipped in that mode: those greps cost ~6s of the 7.7s
# total, and the Stop hook that calls --handoff has a 10s timeout.
if [ "$MODE" != "handoff" ]; then
# ── Batched greps (each one spawn, all outside any loop) ─────────────────────
STATUS_LINES=$(grep -H -m1 '^> \*\*Status\*\*' $GDDS 2>/dev/null)
IDX_ROWS=$(grep '^|' design/gdd/systems-index.md 2>/dev/null)
LOG_COUNTS=$(grep -Hc '^## Review —' design/gdd/reviews/*-review-log.md 2>/dev/null)
AC_HITS=$(grep -HoE '^[-*[:space:]]*\*\*AC-[0-9]+[a-z]?' $GDDS 2>/dev/null)
STATED_TOTALS=$(grep -HoE 'AC ?[0-9]+ ?條' $GDDS 2>/dev/null)
PLACEHOLDER_FILES=$(grep -lE '\[No ADRs yet|尚無 ADR|No ADRs yet' \
    .claude/docs/technical-preferences.md docs/registry/architecture.yaml 2>/dev/null)
ADR_PLACEHOLDERS=$(grep -rn '\[ADR:' --include='*.md' design docs/architecture 2>/dev/null)
fi
GIT_DIRTY=$(git status --porcelain 2>/dev/null)

# active.md is an APPEND-ONLY handoff log: superseded batches stay in the file
# forever, and each new batch heading says so in words ("取代下方第N批的指示順位").
# Hits are line-numbered so C4 can clip them to the CURRENT region — everything
# above the SECOND '## 🔴 接手第一件事' heading.
ACTIVE_MD="production/session-state/active.md"
STATUS_MD="production/PROJECT-STATUS.md"
# ONE grep, two jobs: batch headings (region boundary) and ignore-region
# sentinels. Folded together to avoid a second fork — see the performance
# constraint at the top of this file.
ACTIVE_MARKS=$(grep -nE '^## 🔴 接手第一件事|^<!-- doc-consistency: (ignore|end-ignore) -->' \
    "$ACTIVE_MD" 2>/dev/null)
ACTIVE_CLAIM_HITS=$(grep -nE '尚未 ?commit|待提交|待 ?commit|uncommitted|not yet committed' \
    "$ACTIVE_MD" 2>/dev/null)

# C7 inputs. TD_RULED counts entries the register marks as ruled/closed;
# BLANKET_DENIALS finds handoff text asserting that NOTHING has been ruled.
TD_RULED=$(grep -cE '✅ \*\*[^*]*(已裁決|已關閉|全部關閉)' docs/tech-debt-register.md 2>/dev/null)
BLANKET_DENIALS=$(grep -nE '全部沒有裁決|全部尚未裁決|全部都沒有裁決|一項都沒有裁決|都還沒有裁決|^<!-- doc-consistency: (ignore|end-ignore) -->' \
    "$ACTIVE_MD" "$STATUS_MD" 2>/dev/null)

if [ "$MODE" != "handoff" ]; then
# ── C1: GDD header approval class vs systems-index Status column ─────────────
# NO_STATUS is accumulated and emitted as ONE line (2026-09-03). Four separate
# warnings for one class pushed the only [ERROR] down the screen, and it is one
# decision to make ("do these files need a Status header?"), not four.
NO_STATUS=""
for gdd in $GDDS; do
    base=${gdd##*/}
    hdr=""
    while IFS= read -r line; do
        case "$line" in "$gdd":*) hdr=${line#*: }; break ;; esac
    done <<< "$STATUS_LINES"

    if [ -z "$hdr" ]; then
        NO_STATUS="$NO_STATUS ${base%.md}"
        continue
    fi

    row=""
    while IFS= read -r line; do
        case "$line" in *"$gdd"*) row="$line"; break ;; esac
    done <<< "$IDX_ROWS"

    if [ -z "$row" ]; then
        add_warn "$base — not referenced by any systems-index.md table row"
        continue
    fi

    # Status is the 6th pipe-delimited field (leading | makes field 1 empty).
    # Split with builtin IFS, no awk.
    idx_status=""
    n=0
    old_ifs=$IFS; IFS='|'
    for fld in $row; do
        n=$((n + 1))
        [ "$n" -eq 6 ] && idx_status=$fld
    done
    IFS=$old_ifs

    if [ "$n" -lt 7 ]; then
        add_warn "systems-index.md row for $base has $n fields (expected >=7); skipping status compare"
        continue
    fi

    classify_status "${hdr#\*\*Status\*\*: }"; c_hdr=$CLASS
    classify_status "${idx_status# }";         c_idx=$CLASS

    if [ "$c_hdr" = "UNKNOWN" ] || [ "$c_idx" = "UNKNOWN" ]; then
        add_warn "$base — could not classify status (header=$c_hdr, index=$c_idx); check wording"
    elif [ "$c_hdr" != "$c_idx" ]; then
        add_err "$base APPROVAL MISMATCH — GDD header says $c_hdr, systems-index says $c_idx. One of them is stale."
    fi
done
[ -n "$NO_STATUS" ] && add_warn "no '> **Status**:' header, so no systems-index cross-check is possible for:$NO_STATUS"

# ── C2: review-log entry count vs the round the GDD header claims ────────────
# Takes the FIRST 第N輪 in the status line — that is the round being reported.
# (Taking the highest was wrong: a Status line legitimately cites the UPCOMING
# round as a next step, e.g. "尚未經第五輪 /design-review 覆核", which made a
# correctly-logged 4-round document look like it had an unlogged round.)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    f=${line%%:*}
    txt=${line#*:}
    base=${f##*/}; base=${base%.md}

    max_round=0
    rest=$txt
    while [ -n "$rest" ]; do
        case "$rest" in
            *第*輪*)
                rest=${rest#*第}
                token=${rest%%輪*}
                case "$token" in
                    *[!一二三四五六七八九十]*) ;;
                    "") ;;
                    *) cn_to_int "$token"
                       if [ -n "$CNINT" ]; then max_round=$CNINT; break; fi ;;
                esac
                rest=${rest#*輪}
                ;;
            *) break ;;
        esac
    done
    [ "$max_round" -eq 0 ] && continue

    entries=""
    while IFS= read -r lc; do
        case "$lc" in *"$base-review-log.md":*) entries=${lc##*:}; break ;; esac
    done <<< "$LOG_COUNTS"
    [ -z "$entries" ] && continue

    if [ "$entries" -ne "$max_round" ]; then
        add_warn "$base — header cites 第${max_round}輪 but review-log has $entries '## Review —' entries. Mid-session skew is expected; a persistent gap means rounds went unlogged (this happened: rounds 1-2 of tactical-combat were never logged)."
    fi
done <<< "$STATUS_LINES"

# ── C3: placeholder text vs whether the thing now exists ────────────────────
# SCOPED DELIBERATELY. An earlier version searched production/ too and produced
# two false positives: session-logs/ is an append-only audit trail whose old
# entries SHOULD retain the old text, and active.md legitimately *quotes* the
# placeholder when recording that it was fixed.
if [ "$ADR_COUNT" -gt 0 ] && [ -n "$PLACEHOLDER_FILES" ]; then
    while IFS= read -r f; do
        [ -n "$f" ] && add_err "$f claims no ADRs exist, but $ADR_COUNT ADR file(s) are present in docs/architecture/."
    done <<< "$PLACEHOLDER_FILES"
fi
if [ -n "$ADR_PLACEHOLDERS" ]; then
    shown=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        shown=$((shown + 1))
        [ "$shown" -gt 5 ] && break
        add_err "unbackfilled ADR placeholder in ${line%%:*} — backfill the real ADR number/path."
    done <<< "$ADR_PLACEHOLDERS"
fi
fi


# ── C4: active.md's commit claims vs the actual git tree ────────────────────
# Three defects fixed 2026-09-03, all found by measuring this hook's own output
# and then by writing the incident up inside the very file it checks:
#   (a) PERMANENT FALSE POSITIVE. It grepped the whole append-only file, so a
#       "待 commit" note left by an archived batch — true when written, shipped
#       long ago — tripped it on every clean tree, forever. Now clipped to the
#       current region. A red light that is always on is not a red light.
#   (b) It now reports WHERE. The old message named no line, so acting on it
#       began with a manual grep.
#   (c) PROSE THAT DISCUSSES THIS CHECK TRIPPED IT. Writing up the incident
#       above — quoting the offending line verbatim — put the trigger string
#       back into the current region. Same-line keyword exclusion was not
#       enough. Two more layers now: markdown blockquote lines are never live
#       claims, and a block can be fenced with
#           <!-- doc-consistency: ignore -->  …  <!-- doc-consistency: end-ignore -->
#       This IS a suppression mechanism and can hide a real finding. It is
#       greppable on purpose, and the ERROR message names it.
# Lines QUOTING a superseded wording are also excluded: this project
# deliberately keeps the old text beside the correction, as a lesson. C3's
# comment records the same trap being hit before.
if [ -z "$GIT_DIRTY" ] && [ -n "$ACTIVE_CLAIM_HITS" ]; then
    boundary=0; seen_h=0; ig_start=0; IGNORE_RANGES=""
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        mln=${m%%:*}; mtxt=${m#*:}
        case "$mtxt" in
            "## 🔴 接手第一件事"*)
                seen_h=$((seen_h + 1))
                [ "$seen_h" -eq 2 ] && boundary=$mln ;;
            "<!-- doc-consistency: ignore -->"*)     ig_start=$mln ;;
            "<!-- doc-consistency: end-ignore -->"*)
                [ "$ig_start" -gt 0 ] && IGNORE_RANGES="$IGNORE_RANGES $ig_start-$mln"
                ig_start=0 ;;
        esac
    done <<< "$ACTIVE_MARKS"

    stale=""
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        ln=${hit%%:*}
        txt=${hit#*:}
        if [ "$boundary" -gt 0 ] && [ "$ln" -ge "$boundary" ] 2>/dev/null; then continue; fi
        case "$txt" in
            \>*) continue ;;
            *原文寫*|*原登記為*|*原本寫*|*此前寫*|*原寫*|*"previously read"*) continue ;;
        esac
        skip=0
        for r in $IGNORE_RANGES; do
            a=${r%%-*}; b=${r##*-}
            if [ "$ln" -ge "$a" ] && [ "$ln" -le "$b" ] 2>/dev/null; then skip=1; break; fi
        done
        [ "$skip" -eq 1 ] && continue
        stale="$stale $ln"
    done <<< "$ACTIVE_CLAIM_HITS"

    if [ -n "$stale" ]; then
        add_err "$ACTIVE_MD claims work is uncommitted, but the git tree is clean. Stale claim — the next session will act on a false premise. Line(s):$stale — if the line only QUOTES the wording, fence the block with <!-- doc-consistency: ignore --> / end-ignore."
    fi
fi

if [ "$MODE" != "handoff" ]; then
# ── C5: acceptance-criteria numbering integrity ─────────────────────────────
# [warn] only, never [ERROR]: AC id formats differ across this project's GDDs
# (**AC-1(Logic...)** vs - **AC-27a**: **GIVEN**) and a prose line citing an AC can
# match the same anchor as a definition, so duplicates are not high-confidence.
for gdd in $GDDS; do
    base=${gdd##*/}
    ids=""
    for_this=""
    while IFS= read -r line; do
        case "$line" in
            "$gdd":*)
                m=${line#*:}
                m=${m##*\*\*}
                for_this="$for_this $m"
                ;;
        esac
    done <<< "$AC_HITS"
    [ -z "$for_this" ] && continue

    # Distinct IDS and distinct NUMBERS are tracked separately. Comparing id count
    # against the numeric span was apples-to-oranges: suffixed ids (AC-63a) push the
    # id count past the highest number, so a complete document reported "74 distinct
    # ids spanning AC-1..AC-63" and looked broken.
    dups=""
    seen=" "; seen_nums=" "
    count=0; numcount=0
    maxn=0; minn=999999
    for id in $for_this; do
        case "$seen" in
            *" $id "*) case "$dups" in *" $id "*) ;; *) dups="$dups $id " ;; esac; continue ;;
        esac
        seen="$seen$id "; count=$((count + 1))
        num=${id#AC-}; num=${num%%[a-z]}
        case "$seen_nums" in
            *" $num "*) ;;
            *) seen_nums="$seen_nums$num "; numcount=$((numcount + 1))
               [ "$num" -gt "$maxn" ] 2>/dev/null && maxn=$num
               [ "$num" -lt "$minn" ] 2>/dev/null && minn=$num ;;
        esac
    done

    if [ -n "$dups" ]; then
        add_warn "$base — AC id defined more than once:$dups(verify these are real duplicates, not a prose citation matching the definition anchor)"
    fi

    if [ "$maxn" -gt 0 ]; then
        expected=$((maxn - minn + 1))
        if [ "$numcount" -ne "$expected" ]; then
            add_warn "$base — AC numbering has gaps: $numcount distinct numbers spanning AC-$minn..AC-$maxn (expected $expected if contiguous). Retirements are fine (this project keeps retired ids on the books); verify none were dropped accidentally."
        fi
    fi

    stated=""
    while IFS= read -r line; do
        case "$line" in
            "$gdd":*) s=${line#*:}; s=${s#AC}; s=${s## }; s=${s%%[^0-9]*}
                      [ -n "$s" ] && stated=$s && break ;;
        esac
    done <<< "$STATED_TOTALS"
    if [ -n "$stated" ] && [ "$stated" != "$count" ]; then
        add_warn "$base — text states $stated ACs but $count ids are actually defined."
    fi
done

# ── C6: line-number self-references (banned by .claude/rules/design-docs.md) ─
# Heuristic: the systems table has 14 rows, so "第 N 列" with N > 14 is almost
# certainly a line number, not a table row. docs/engine-reference is excluded:
# a curated upstream API snapshot, not a doc governed by this project's rules.
#
# 2026-09-03: COLLAPSED TO ONE LINE. Measured before the change — the class had
# 152 members and, even truncated to 8 examples, occupied 8 of the 21 visible
# output lines, with the run's only [ERROR] at line 7 inside that block. This is
# a known standing backlog, not news. The count is the signal; the individual
# hits moved behind --line-refs. Only the NUMBER is computed here because awk on
# Git Bash mangles the multibyte 列/行 char.
LINE_REF_COUNT=$(grep -rnoE '第 ?[0-9]+(/[0-9]+)* ?[列行]|see line [0-9]+|見第 ?[0-9]+' \
    --include='*.md' design docs/architecture docs/registry 2>/dev/null \
  | awk -F: '
      { file=$1; ln=$2; text=$0; sub(/^[^:]*:[^:]*:/, "", text);
        if (match(text, /[0-9]+/)) {
            n = substr(text, RSTART, RLENGTH) + 0;
            if (n > 14) { k=file":"ln":"n; if (seen[k]++) next; total++; } } }
      END { print total+0 }')
if [ "${LINE_REF_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    add_warn "$LINE_REF_COUNT suspected line-number self-references in design/, docs/architecture/, docs/registry/ (banned by .claude/rules/design-docs.md — use a stable handle). Standing backlog, deliberately one line. List them: bash .claude/hooks/validate-doc-consistency.sh --line-refs"
fi

fi

# ── C7: a recorded ruling vs a handoff doc still saying nothing was ruled ────
# Added 2026-09-03, the day this exact desync happened: two of four items had
# been ruled AND executed, docs/tech-debt-register.md said so, and both handoff
# documents still told the next session "none of the four has been ruled — do
# not cite one". Handoff docs are read FIRST at session start, so the stale one
# wins, and the next session re-asks a question the manager already answered.
#
# The same three exclusions as C4 (blockquote / quote markers / fence), because
# C7 false-positived on its OWN write-up within minutes of shipping: the table
# recording its sensitivity tests quotes the trigger phrases verbatim.
# MECHANISM DIFFERS FROM C4 ON PURPOSE. C4's hits and its fences come from two
# separate greps, so it has to convert fences into line ranges. C7's hits and
# fences come from ONE grep in file order, so it can just track open/closed as
# it walks — and that also gives PROJECT-STATUS.md fence support for free,
# without a fourth grep.
if [ "${TD_RULED:-0}" -gt 0 ] && [ -n "$BLANKET_DENIALS" ]; then
    cur_f=""; ig=0
    while IFS= read -r hit; do
        [ -z "$hit" ] && continue
        f=${hit%%:*}
        rest=${hit#*:}
        ln=${rest%%:*}
        txt=${rest#*:}
        if [ "$f" != "$cur_f" ]; then cur_f=$f; ig=0; fi
        case "$txt" in
            "<!-- doc-consistency: ignore -->"*)     ig=1; continue ;;
            "<!-- doc-consistency: end-ignore -->"*) ig=0; continue ;;
        esac
        [ "$ig" -eq 1 ] && continue
        case "$txt" in
            \>*) continue ;;
            *原文寫*|*原登記為*|*原本寫*|*此前寫*|*原寫*) continue ;;
        esac
        add_err "$f:$ln asserts no ruling exists, but docs/tech-debt-register.md records $TD_RULED ruled item(s). Handoff docs are read first — a stale blanket denial sends the next session to re-ask a decided question. If the line only QUOTES the wording, fence the block with <!-- doc-consistency: ignore --> / end-ignore."
    done <<< "$BLANKET_DENIALS"
fi

# ── Report ──────────────────────────────────────────────────────────────────
# 2026-09-03: [ERROR]s print FIRST, in their own counted block. Measured cause —
# the single [ERROR] was the 7th of 21 lines, buried inside a same-class warning
# block. Ordering is the one fix here that keeps working even if the warning set
# grows again later.
ERRS=""; WARNS=""; N_ERR=0; N_WARN=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
        *"[ERROR]"*) ERRS="$ERRS$line
"; N_ERR=$((N_ERR + 1)) ;;
        *) WARNS="$WARNS$line
"; N_WARN=$((N_WARN + 1)) ;;
    esac
done <<< "$FINDINGS"

if [ "$N_ERR" -gt 0 ]; then HAS_ERR=1; else HAS_ERR=0; fi

if [ "$N_ERR" -eq 0 ] && [ "$N_WARN" -eq 0 ]; then
    [ "$MODE" = "report" ] && echo "=== Doc Consistency: no cross-file drift detected ==="
    exit 0
fi

{
    echo "=== Doc Consistency Check ==="
    if [ "$N_ERR" -gt 0 ]; then
        echo "--- CONTRADICTIONS ($N_ERR) — two docs disagree; one of them is wrong ---"
        printf '%s' "$ERRS"
    else
        echo "--- no contradictions ---"
    fi
    if [ "$N_WARN" -gt 0 ]; then
        echo "--- judgement calls ($N_WARN) — not necessarily wrong, needs a human ---"
        printf '%s' "$WARNS"
    fi
    echo "============================="
    # NOTE: this legend deliberately avoids the literal marker strings. An earlier
    # version spelled them out, so `... | grep -c '\[ERROR\]'` counted the legend
    # itself and reported a finding on a clean repo — the output has to be safely
    # greppable, because grepping it is exactly how anyone will consume it.
    echo "Cross-file fact agreement. Escape hatch: SKIP_DOC_CONSISTENCY=1"
} >&2

if [ "$MODE" = "gate" ] && [ "$HAS_ERR" = "1" ]; then
    echo "BLOCKED: resolve the cross-file contradictions above, or set SKIP_DOC_CONSISTENCY=1 to override." >&2
    exit 2
fi

exit 0
