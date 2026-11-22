#!/usr/bin/env bash
# Proves the template's central claim: a repo generated from it can drop the demo resource and
# still pass its gate, without editing anything in scripts/.
#
#   scripts/recipe-check.sh [target]     # default: a fresh temp dir
#
# Template-only: scaffold.sh deletes this file from generated repos (they get strip-demo.sh).
set -euo pipefail

TARGET="${1:-$(mktemp -d)/recipe-check}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "refusing to delete a non-empty target: $TARGET" >&2
  exit 1
fi

CI_FLAG=""
if [ -n "${CI:-}" ]; then CI_FLAG="--ci"; fi

rm -rf "$TARGET"
"$HERE/scaffold.sh" "$TARGET" >/dev/null
"$TARGET/scripts/strip-demo.sh"

echo "== gate, after stripping the demo"
cd "$TARGET" && ./scripts/preflight.sh $CI_FLAG