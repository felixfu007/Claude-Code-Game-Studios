#!/bin/bash
# Hook: detect-gaps.sh
# Event: SessionStart
# Purpose: Detect missing documentation when code/prototypes exist
# Cross-platform: Windows Git Bash compatible (uses grep -E, not -P)
#
# 🔴 2026-09-04 — THIS HOOK WAS SILENTLY DEAD, AND THE CAUSE APPLIES TO EVERY
#    HOOK IN THIS DIRECTORY.
#
#    Measured: it took 20.5s against the 10s timeout declared for it in
#    .claude/settings.json. It was therefore killed on every single session
#    start and its output never reached anyone. Nothing reported this — a
#    killed hook looks exactly like a hook with nothing to say.
#
#    The cause was NOT the work it does. Measured on this machine:
#      - each `find` in this script:            ~0.28s
#      - 30 trivial forked subshells:           11.3s  (~370ms per process)
#    i.e. the cost is process creation, not computation. The old Check 2 loop
#    ran `echo | sed` (two forks) once per prototype directory — 27 of them —
#    which is ~20s by itself.
#
#    Fixed by replacing forked helpers with bash parameter expansion:
#      $(echo "$x" | sed 's|\\|/|g')  ->  "${x//\\//}"
#      $(basename "$x")               ->  "${x##*/}"
#      $(echo "$x" | tr -d ' ')       ->  "${x// /}"
#      echo "$x" | grep -q "y"        ->  [ "${x#*y}" = "$x" ]
#    Result: 20.5s -> 6.47s, output byte-for-byte identical (diff verified).
#    settings.json was NOT touched.
#
# ⚠️ BUDGET WARNING FOR WHOEVER EDITS THIS NEXT: at ~370ms per forked process,
#    a 10s timeout buys roughly 27 external commands. This script now sits at
#    6.47s — about 65% of its budget, i.e. ~10 spare forks. **Adding one
#    innocuous `$(...)` inside a loop can kill this hook again, and it will
#    fail the same silent way.** Prefer bash builtins over forks here, and
#    re-time the hook after any change: `time bash .claude/hooks/detect-gaps.sh`

# Exit on error for debugging (but don't fail the session)
set +e

echo "=== Checking for Documentation Gaps ==="

# --- Check 0: Fresh project detection (suggests /start) ---
FRESH_PROJECT=true

# Check if engine is configured
if [ -f ".claude/docs/technical-preferences.md" ]; then
  ENGINE_LINE=$(grep -E "^\- \*\*Engine\*\*:" .claude/docs/technical-preferences.md 2>/dev/null)
  if [ -n "$ENGINE_LINE" ] && [ "${ENGINE_LINE#*TO BE CONFIGURED}" = "$ENGINE_LINE" ]; then
    FRESH_PROJECT=false
  fi
fi

# Check if game concept exists
if [ -f "design/gdd/game-concept.md" ]; then
  FRESH_PROJECT=false
fi

# Check if source code exists
if [ -d "src" ]; then
  SRC_CHECK=$(find src -type f \( -name "*.gd" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) 2>/dev/null | head -1)
  if [ -n "$SRC_CHECK" ]; then
    FRESH_PROJECT=false
  fi
fi

if [ "$FRESH_PROJECT" = true ]; then
  echo ""
  echo "🚀 NEW PROJECT: No engine configured, no game concept, no source code."
  echo "   This looks like a fresh start! Run: /start"
  echo ""
  echo "💡 To get a comprehensive project analysis, run: /project-stage-detect"
  echo "==================================="
  exit 0
fi

# --- Check 1: Substantial codebase but sparse design docs ---
if [ -d "src" ]; then
  # Count source files (cross-platform, handles Windows paths)
  SRC_FILES=$(find src -type f \( -name "*.gd" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) 2>/dev/null | wc -l)
else
  SRC_FILES=0
fi

if [ -d "design/gdd" ]; then
  DESIGN_FILES=$(find design/gdd -type f -name "*.md" 2>/dev/null | wc -l)
else
  DESIGN_FILES=0
fi

# Normalize whitespace from wc output
SRC_FILES="${SRC_FILES// /}"
DESIGN_FILES="${DESIGN_FILES// /}"

if [ "$SRC_FILES" -gt 50 ] && [ "$DESIGN_FILES" -lt 5 ]; then
  echo "⚠️  GAP: Substantial codebase ($SRC_FILES source files) but sparse design docs ($DESIGN_FILES files)"
  echo "    Suggested action: /reverse-document design src/[system]"
  echo "    Or run: /project-stage-detect to get full analysis"
fi

# --- Check 2: Prototypes without documentation ---
if [ -d "prototypes" ]; then
  PROTOTYPE_DIRS=$(find prototypes -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  UNDOCUMENTED_PROTOS=()

  if [ -n "$PROTOTYPE_DIRS" ]; then
    while IFS= read -r proto_dir; do
      # Normalize path separators for Windows.
      # 🔴 Parameter expansion, NOT `echo | sed` (2026-09-04). This loop runs
      # once per prototype directory — 27 of them today — and on this machine
      # every forked process costs ~370ms, measured: 30 trivial subshells took
      # 11.3s. The old two-fork form cost ~20s here on its own and pushed the
      # whole hook to 20.5s against its declared 10s timeout, so it was killed
      # every single session and nobody ever saw its output. See this file's
      # header note.
      proto_dir="${proto_dir//\\//}"

      # Check for README.md or CONCEPT.md
      if [ ! -f "${proto_dir}/README.md" ] && [ ! -f "${proto_dir}/CONCEPT.md" ]; then
        proto_name="${proto_dir##*/}"
        UNDOCUMENTED_PROTOS+=("$proto_name")
      fi
    done <<< "$PROTOTYPE_DIRS"

    if [ ${#UNDOCUMENTED_PROTOS[@]} -gt 0 ]; then
      echo "⚠️  GAP: ${#UNDOCUMENTED_PROTOS[@]} undocumented prototype(s) found:"
      for proto in "${UNDOCUMENTED_PROTOS[@]}"; do
        echo "    - prototypes/$proto/ (no README or CONCEPT doc)"
      done
      echo "    Suggested action: /reverse-document concept prototypes/[name]"
    fi
  fi
fi

# --- Check 3: Core systems without architecture docs ---
if [ -d "src/core" ] || [ -d "src/engine" ]; then
  if [ ! -d "docs/architecture" ]; then
    echo "⚠️  GAP: Core engine/systems exist but no docs/architecture/ directory"
    echo "    Suggested action: Create docs/architecture/ and run /architecture-decision"
  else
    ADR_COUNT=$(find docs/architecture -type f -name "*.md" 2>/dev/null | wc -l)
    ADR_COUNT="${ADR_COUNT// /}"

    if [ "$ADR_COUNT" -lt 3 ]; then
      echo "⚠️  GAP: Core systems exist but only $ADR_COUNT ADR(s) documented"
      echo "    Suggested action: /reverse-document architecture src/core/[system]"
    fi
  fi
fi

# --- Check 4: Gameplay systems without design docs ---
if [ -d "src/gameplay" ]; then
  # Find major gameplay subdirectories (those with 5+ files)
  GAMEPLAY_SYSTEMS=$(find src/gameplay -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

  if [ -n "$GAMEPLAY_SYSTEMS" ]; then
    while IFS= read -r system_dir; do
      system_dir="${system_dir//\\//}"
      system_name="${system_dir##*/}"
      file_count=$(find "$system_dir" -type f 2>/dev/null | wc -l)
      file_count="${file_count// /}"

      # If system has 5+ files, check for corresponding design doc
      if [ "$file_count" -ge 5 ]; then
        # Check for design doc (allow variations: combat-system.md, combat.md)
        design_doc_1="design/gdd/${system_name}-system.md"
        design_doc_2="design/gdd/${system_name}.md"

        if [ ! -f "$design_doc_1" ] && [ ! -f "$design_doc_2" ]; then
          echo "⚠️  GAP: Gameplay system 'src/gameplay/$system_name/' ($file_count files) has no design doc"
          echo "    Expected: design/gdd/${system_name}-system.md or design/gdd/${system_name}.md"
          echo "    Suggested action: /reverse-document design src/gameplay/$system_name"
        fi
      fi
    done <<< "$GAMEPLAY_SYSTEMS"
  fi
fi

# --- Check 5: Production planning ---
if [ "$SRC_FILES" -gt 100 ]; then
  # For projects with substantial code, check for production planning
  if [ ! -d "production/sprints" ] && [ ! -d "production/milestones" ]; then
    echo "⚠️  GAP: Large codebase ($SRC_FILES files) but no production planning found"
    echo "    Suggested action: /sprint-plan or create production/ directory"
  fi
fi

# --- Summary ---
echo ""
echo "💡 To get a comprehensive project analysis, run: /project-stage-detect"
echo "==================================="

exit 0
