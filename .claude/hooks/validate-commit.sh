#!/bin/bash
# Claude Code PreToolUse hook: Validates git commit commands
# Receives JSON on stdin with tool_input.command
# Exit 0 = allow, Exit 2 = block (stderr shown to Claude)
#
# Input schema (PreToolUse for Bash):
# { "tool_name": "Bash", "tool_input": { "command": "git commit -m ..." } }

INPUT=$(cat)

# Parse command -- use jq if available, fall back to grep
if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

# Only process git commit commands
if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
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
        {
            echo "=== Unproven completion claims in staged docs ==="
            echo "$UNPROVEN"
            echo "Each line above says something is done without naming a checkable artifact"
            echo "on the same line (a path, a test count, an exit code, or 測試/證據/spike)."
            echo "If it IS done, cite the proof. If it is not, say what it is waiting on."
            echo "================================================"
        } >&2
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
    bash .claude/hooks/validate-doc-consistency.sh --gate
    DOC_RC=$?
    if [ "$DOC_RC" -eq 2 ]; then
        exit 2
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
