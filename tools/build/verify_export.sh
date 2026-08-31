#!/usr/bin/env bash
# Verifies that an exported .pck actually contains every runtime data file under
# assets/data/. See tools/build/verify_pck_contents.gd for the full rationale.
#
# The expected-file list is derived from disk rather than hardcoded, so adding a
# new data file is covered automatically and nobody has to remember to update a
# list here.
#
# Usage: tools/build/verify_export.sh [pck-path] [godot-binary]
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PCK="${1:-$PROJECT_ROOT/build/windows/BlindInTheFaintLight.pck}"
GODOT="${2:-${GODOT_BIN:-godot}}"

if [ ! -f "$PCK" ]; then
  echo "verify_export: pck not found: $PCK" >&2
  exit 2
fi

# Every file under assets/data/ is a runtime data file. .import sidecars are
# build artifacts, not runtime data, so they are not required to ship.
mapfile -t DATA_FILES < <(cd "$PROJECT_ROOT" && find assets/data -type f ! -name '*.import' | sort)

if [ "${#DATA_FILES[@]}" -eq 0 ]; then
  echo "verify_export: found no files under assets/data -- refusing to pass vacuously" >&2
  exit 2
fi

RES_PATHS=()
for f in "${DATA_FILES[@]}"; do
  RES_PATHS+=("res://$f")
done

echo "verify_export: checking ${#RES_PATHS[@]} data file(s) in $PCK"

# A throwaway EMPTY project. Running the check inside the real project would make
# it pass unconditionally, because the files exist on disk there regardless of
# whether they were packaged.
TMP_PROJECT="$(mktemp -d)"
trap 'rm -rf "$TMP_PROJECT"' EXIT
printf 'config_version=5\n\n[application]\nconfig/name="pck_verify"\n' > "$TMP_PROJECT/project.godot"
cp "$PROJECT_ROOT/tools/build/verify_pck_contents.gd" "$TMP_PROJECT/verify_pck_contents.gd"

"$GODOT" --headless --path "$TMP_PROJECT" -s res://verify_pck_contents.gd -- "$PCK" "${RES_PATHS[@]}"
