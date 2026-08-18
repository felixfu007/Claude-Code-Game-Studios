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
#   SKIP_DOC_CONSISTENCY=1 ...                                # escape hatch
#
# Cross-platform: Windows Git Bash compatible (grep -E only, never grep -P).

set +e

MODE="report"
[ "$1" = "--gate" ] && MODE="gate"
[ "$SKIP_DOC_CONSISTENCY" = "1" ] && exit 0

cd "$(dirname "$0")/../.." 2>/dev/null || exit 0

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

# ── Batched greps (each one spawn, all outside any loop) ─────────────────────
STATUS_LINES=$(grep -H -m1 '^> \*\*Status\*\*' $GDDS 2>/dev/null)
IDX_ROWS=$(grep '^|' design/gdd/systems-index.md 2>/dev/null)
LOG_COUNTS=$(grep -Hc '^## Review —' design/gdd/reviews/*-review-log.md 2>/dev/null)
AC_HITS=$(grep -HoE '^[-*[:space:]]*\*\*AC-[0-9]+[a-z]?' $GDDS 2>/dev/null)
STATED_TOTALS=$(grep -HoE 'AC ?[0-9]+ ?條' $GDDS 2>/dev/null)
PLACEHOLDER_FILES=$(grep -lE '\[No ADRs yet|尚無 ADR|No ADRs yet' \
    .claude/docs/technical-preferences.md docs/registry/architecture.yaml 2>/dev/null)
ADR_PLACEHOLDERS=$(grep -rn '\[ADR:' --include='*.md' design docs/architecture 2>/dev/null)
GIT_DIRTY=$(git status --porcelain 2>/dev/null)
ACTIVE_CLAIM=$(grep -lE '尚未 ?commit|待提交|待 ?commit|uncommitted|not yet committed' \
    production/session-state/active.md 2>/dev/null)

# ── C1: GDD header approval class vs systems-index Status column ─────────────
for gdd in $GDDS; do
    base=${gdd##*/}
    hdr=""
    while IFS= read -r line; do
        case "$line" in "$gdd":*) hdr=${line#*: }; break ;; esac
    done <<< "$STATUS_LINES"

    if [ -z "$hdr" ]; then
        add_warn "$base — no '> **Status**:' header line found (cannot cross-check against systems-index)"
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

# ── C4: active.md's commit claims vs the actual git tree ────────────────────
if [ -z "$GIT_DIRTY" ] && [ -n "$ACTIVE_CLAIM" ]; then
    add_err "production/session-state/active.md claims work is uncommitted, but the git tree is clean. Stale claim — the next session will act on a false premise."
fi

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
# certainly a line number, not a table row. Single grep|awk pipeline; only the
# NUMBER is printed because awk on Git Bash mangles the multibyte 列/行 char.
# docs/engine-reference is excluded: a curated upstream API snapshot, not a doc
# governed by this project's cross-reference discipline.
LINE_REFS=$(grep -rnoE '第 ?[0-9]+(/[0-9]+)* ?[列行]|see line [0-9]+|見第 ?[0-9]+' \
    --include='*.md' design docs/architecture docs/registry 2>/dev/null \
  | awk -F: '
      { file=$1; ln=$2; text=$0; sub(/^[^:]*:[^:]*:/, "", text);
        if (match(text, /[0-9]+/)) {
            n = substr(text, RSTART, RLENGTH) + 0;
            if (n > 14) { k=file":"ln":"n; if (seen[k]++) next; total++;
                if (total <= 8)
                    printf "  [warn]  %s:%s cites number %d as a location (>14, so not a systems-table row) — likely a line-number self-reference, banned by .claude/rules/design-docs.md. Use a stable handle instead.\n", file, ln, n; } } }
      END { if (total > 8)
              printf "  [warn]  ... and %d more suspected line-number self-references (showing 8 of %d).\n", total-8, total; }')
[ -n "$LINE_REFS" ] && FINDINGS="$FINDINGS$LINE_REFS
"

# ── Report ──────────────────────────────────────────────────────────────────
case "$FINDINGS" in
    *"[ERROR]"*) HAS_ERR=1 ;;
    *) HAS_ERR=0 ;;
esac

if [ -z "${FINDINGS// /}" ] || [ -z "$FINDINGS" ]; then
    [ "$MODE" = "report" ] && echo "=== Doc Consistency: no cross-file drift detected ==="
    exit 0
fi

{
    echo "=== Doc Consistency Check ==="
    printf '%s' "$FINDINGS"
    echo "============================="
    echo "Cross-file fact agreement. [ERROR] = two docs contradict each other."
    echo "[warn] = needs human judgement. Escape hatch: SKIP_DOC_CONSISTENCY=1"
} >&2

if [ "$MODE" = "gate" ] && [ "$HAS_ERR" = "1" ]; then
    echo "BLOCKED: resolve the cross-file contradictions above, or set SKIP_DOC_CONSISTENCY=1 to override." >&2
    exit 2
fi

exit 0
