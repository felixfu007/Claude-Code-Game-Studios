#!/bin/bash
# Literal-anchor document editor with a mandatory self-check.
#
# WHY THIS EXISTS (2026-09-07):
#   A doc fix was applied to production/epics/.../story-006-*.md by counting the
#   anchor with `grep -c` (which read `(` `?` literally) and then editing with
#   `awk /regex/` (which read them as regex metacharacters). The count said 1,
#   the edit changed NOTHING, and there was no error message. It was caught only
#   because the "after" state happened to be printed. The project's own
#   `docs/consistency-failures.md` pattern D is this shape.
#
#   The root cause was NOT carelessness: the VERIFY step and the EDIT step used
#   two different matchers, so verification was structurally incapable of
#   predicting the edit. This script removes that class of error by construction:
#     1. Count and edit use the SAME literal, full-line matcher (awk index()).
#     2. Refuses to touch the file unless the anchor matches EXACTLY once.
#     3. After editing, re-counts the anchor and ABORTS if it is still present
#        -- i.e. it proves the edit landed rather than assuming it.
#     4. Always prints before/after context. A silent success is not possible.
#
# USAGE
#   safe_doc_edit.sh --file F --anchor "LINE" --replacement-file R
#   safe_doc_edit.sh --file F --anchor "LINE" --through "LINE2" --replacement-file R
#   safe_doc_edit.sh --file F --anchor "LINE" --delete
#
#   --anchor / --through are matched as EXACT, COMPLETE lines (leading and
#   trailing whitespace included). They are never treated as patterns.
#   --replacement-file may be `-` to read the replacement from stdin.
#   --through replaces the anchor line THROUGH that line, inclusive.
#
# EXIT CODES
#   0 = edited and verified   1 = usage error   2 = anchor not exactly once
#   3 = post-edit verification failed (file left untouched)
set -u

FILE="" ANCHOR="" THROUGH="" REPL_FILE="" DELETE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --file)             FILE="$2";      shift 2 ;;
        --anchor)           ANCHOR="$2";    shift 2 ;;
        --through)          THROUGH="$2";   shift 2 ;;
        --replacement-file) REPL_FILE="$2"; shift 2 ;;
        --delete)           DELETE=1;       shift   ;;
        *) echo "safe_doc_edit: unknown argument: $1" >&2; exit 1 ;;
    esac
done

[ -n "$FILE" ] && [ -n "$ANCHOR" ] || { echo "safe_doc_edit: --file and --anchor are required" >&2; exit 1; }
[ -f "$FILE" ] || { echo "safe_doc_edit: no such file: $FILE" >&2; exit 1; }
if [ "$DELETE" -eq 0 ] && [ -z "$REPL_FILE" ]; then
    echo "safe_doc_edit: need --replacement-file or --delete" >&2; exit 1
fi

# --- Step 1: count with the SAME matcher the edit will use -------------------
count_exact() {  # $1 = needle
    awk -v n="$1" 'index($0,n)==1 && length($0)==length(n){c++} END{print c+0}' "$FILE"
}
report_lines() { # $1 = needle
    awk -v n="$1" 'index($0,n)==1 && length($0)==length(n){printf "    line %d\n", NR}' "$FILE"
}

A_COUNT=$(count_exact "$ANCHOR")
if [ "$A_COUNT" -ne 1 ]; then
    echo "safe_doc_edit: REFUSING -- anchor matched $A_COUNT times (need exactly 1) in $FILE" >&2
    echo "  anchor: $ANCHOR" >&2
    [ "$A_COUNT" -gt 0 ] && report_lines "$ANCHOR" >&2
    exit 2
fi
if [ -n "$THROUGH" ]; then
    T_COUNT=$(count_exact "$THROUGH")
    if [ "$T_COUNT" -ne 1 ]; then
        echo "safe_doc_edit: REFUSING -- --through matched $T_COUNT times (need exactly 1) in $FILE" >&2
        exit 2
    fi
fi

A_LINE=$(awk -v n="$ANCHOR" 'index($0,n)==1 && length($0)==length(n){print NR; exit}' "$FILE")

echo "=== BEFORE (${FILE}, around line ${A_LINE}) ==="
awk -v s="$((A_LINE>3?A_LINE-3:1))" -v e="$((A_LINE+4))" 'NR>=s&&NR<=e{printf "%5d| %s\n", NR, $0}' "$FILE"

# --- Step 2: edit ------------------------------------------------------------
TMP="${FILE}.safe_doc_edit.$$"
REPL_TMP=""
if [ "$DELETE" -eq 0 ]; then
    REPL_TMP="${FILE}.safe_doc_repl.$$"
    if [ "$REPL_FILE" = "-" ]; then cat > "$REPL_TMP"; else cat "$REPL_FILE" > "$REPL_TMP"; fi
fi

awk -v anchor="$ANCHOR" -v through="$THROUGH" -v repl="${REPL_TMP:-}" -v del="$DELETE" '
  function emit_repl() {
      if (del == 1 || repl == "") return
      while ((getline line < repl) > 0) print line
      close(repl)
  }
  !done && index($0,anchor)==1 && length($0)==length(anchor) {
      emit_repl(); done=1
      if (through != "") { skipping=1 }
      next
  }
  skipping {
      if (index($0,through)==1 && length($0)==length(through)) { skipping=0 }
      next
  }
  { print }
' "$FILE" > "$TMP" || { echo "safe_doc_edit: awk failed, file untouched" >&2; rm -f "$TMP" "$REPL_TMP"; exit 3; }

# --- Step 3: prove the edit landed (this is the step the 2026-09-07 miss lacked)
# The anchor is EXPECTED to survive when the replacement deliberately re-emits
# it -- that is how "insert before this line" is expressed. So the expected
# post-state is DERIVED FROM THE REPLACEMENT, not hardcoded to zero.
#   Found 2026-09-07 by using this tool on itself: its first real edit was an
#   insert-before, a hardcoded 0 rejected it, and fixing that in the wrong
#   order briefly left the tool referencing an unset variable. Both are
#   recorded here because both were caught by the tool refusing to act rather
#   than by anyone noticing -- which is the entire point of the file.
EXPECT=0
if [ -n "${REPL_TMP:-}" ] && [ -f "$REPL_TMP" ]; then
    EXPECT=$(awk -v n="$ANCHOR" 'index($0,n)==1 && length($0)==length(n){c++} END{print c+0}' "$REPL_TMP")
fi
STILL=$(awk -v n="$ANCHOR" 'index($0,n)==1 && length($0)==length(n){c++} END{print c+0}' "$TMP")
if [ "$STILL" -ne "$EXPECT" ] || cmp -s "$FILE" "$TMP"; then
    if cmp -s "$FILE" "$TMP"; then
        echo "safe_doc_edit: POST-EDIT CHECK FAILED -- result is byte-identical to the original." >&2
    else
        echo "safe_doc_edit: POST-EDIT CHECK FAILED -- anchor count is $STILL, expected $EXPECT." >&2
    fi
    echo "  $FILE was NOT modified." >&2
    rm -f "$TMP" "$REPL_TMP"; exit 3
fi
if [ ! -s "$TMP" ]; then
    echo "safe_doc_edit: POST-EDIT CHECK FAILED -- result is empty. $FILE was NOT modified." >&2
    rm -f "$TMP" "$REPL_TMP"; exit 3
fi

mv "$TMP" "$FILE"
rm -f "$REPL_TMP"

echo "=== AFTER (${FILE}, around line ${A_LINE}) ==="
awk -v s="$((A_LINE>3?A_LINE-3:1))" -v e="$((A_LINE+8))" 'NR>=s&&NR<=e{printf "%5d| %s\n", NR, $0}' "$FILE"
echo "=== safe_doc_edit: OK -- anchor matched once, edit applied and verified ==="
