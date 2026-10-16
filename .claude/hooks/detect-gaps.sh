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

        # 🔴 2026-10-16(管理者裁決):目錄 → 設計文件的明文對照表。
        # 沒有它的時候,Check 4 在【每一次 session 啟動】都會噴四條假警告 ——
        # 因為這四個系統【都有】設計文件,只是檔名跟目錄名對不起來。
        # 當天逐檔查證過:
        #   src/gameplay/affinity/      → design/gdd/affinity-position-chain.md
        #   src/gameplay/affinity_pool/ → design/gdd/affinity-data-pool.md
        #   src/gameplay/battle/        → design/gdd/tactical-combat-system.md
        #   src/gameplay/cards/         → design/gdd/skill-card-system.md
        #
        # 為什麼這比「那四行字很煩」重要:一個每次都誤報的偵測器,用的人第二次
        # 看到就會開始無視它,然後真的有缺口時也不會被看見。這個失效形狀本專案
        # 已經登記過很多次。
        #
        # ⚠️ 已知代價,管理者在選它而非其他方案時知情接受:這張表自己會漂。
        # 以後在 src/gameplay/ 新增一個目錄、而它的設計文件檔名又對不起來,
        # Check 4 就會再噴一條假警告,直到有人來補一列。
        # 被跳過的替代方案(改成 grep 設計文件裡有沒有提到該目錄路徑)之所以
        # 不採用:協調者【沒有查證過】設計文件裡到底有沒有寫那些路徑 ——
        # 如果沒寫,那個做法會連真的缺口一起消音,比現在更糟。
        design_doc_mapped=""
        case "$system_name" in
          affinity)      design_doc_mapped="design/gdd/affinity-position-chain.md" ;;
          affinity_pool) design_doc_mapped="design/gdd/affinity-data-pool.md" ;;
          battle)        design_doc_mapped="design/gdd/tactical-combat-system.md" ;;
          cards)         design_doc_mapped="design/gdd/skill-card-system.md" ;;
        esac

        # 對照表指到的檔案不見了 -> 這是真的缺口,而且要指出對照表可能已過期
        if [ -n "$design_doc_mapped" ] && [ ! -f "$design_doc_mapped" ]; then
          echo "⚠️  GAP: Gameplay system 'src/gameplay/$system_name/' maps to"
          echo "    $design_doc_mapped -- but that file does NOT exist."
          echo "    Either the doc was deleted/renamed, or this mapping in"
          echo "    .claude/hooks/detect-gaps.sh Check 4 is now stale."
        fi

        if [ -z "$design_doc_mapped" ] && [ ! -f "$design_doc_1" ] && [ ! -f "$design_doc_2" ]; then
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
