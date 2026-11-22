#!/usr/bin/env bash
# newrepo — create a fresh working repo from the kit in seconds, with green tests.
#
#   newrepo rate-limiter            -> ~/Developer/rate-limiter with server/ + web/
#   newrepo ~/some/where/thing      -> exactly there
#   newrepo rate-limiter --go-only  -> Go module at the repo root, no web/ tree
#
# Copies with APFS clones (cp -c), so node_modules costs no time and no extra disk.
set -uo pipefail

# resolve symlinks so the template is found when this is linked into PATH
SELF="$0"
while [ -L "$SELF" ]; do
  HERE="$(cd -P "$(dirname "$SELF")" && pwd)"
  SELF="$(readlink "$SELF")"
  case "$SELF" in /*) ;; *) SELF="$HERE/$SELF" ;; esac
done
KIT="$(cd -P "$(dirname "$SELF")/.." && pwd)"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,8p' "$SELF" | sed 's/^# \{0,1\}//' >&2
  exit 0
fi

TARGET="${1:-}"
shift || true
GO_ONLY=0
for a in "$@"; do [ "$a" = "--go-only" ] && GO_ONLY=1; done

if [ -z "$TARGET" ]; then
  sed -n '2,8p' "$SELF" | sed 's/^# \{0,1\}//' >&2
  exit 2
fi

# a bare name lands in ~/Developer
case "$TARGET" in
  */*) ;;
  *) TARGET="$HOME/Developer/$TARGET" ;;
esac

if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "refusing: $TARGET exists and is not empty" >&2
  exit 1
fi
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
NAME="$(basename "$TARGET" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-$//')"

# APFS clones when available, plain copy otherwise
clone_tree() { cp -Rc "$1" "$2" 2>/dev/null || cp -R "$1" "$2"; }

printf 'scaffolding %s -> %s\n' "$NAME" "$TARGET"
if [ "$GO_ONLY" -eq 1 ]; then
  # module at the repo root: cmd/, internal/, go.mod at the top level
  clone_tree "$KIT/server/." "$TARGET/"
  mv "$TARGET/AGENTS.md" "$TARGET/.go-rules.md"
  GO_PATH="$TARGET"
else
  clone_tree "$KIT/server" "$TARGET/server"
  clone_tree "$KIT/web" "$TARGET/web"
  GO_PATH="$TARGET/server"
fi
clone_tree "$KIT/scripts" "$TARGET/scripts"
cp "$KIT/README.md" "$TARGET/README.md"
cp "$KIT/LICENSE" "$KIT/.editorconfig" "$KIT/.gitignore" "$TARGET/"
cp "$KIT/AGENTS.md" "$TARGET/AGENTS.md"
cp "$KIT/.mise.toml" "$TARGET/.mise.toml"
mkdir -p "$TARGET/.vscode" && cp "$KIT/.vscode/settings.json" "$TARGET/.vscode/settings.json"
mkdir -p "$TARGET/.github/workflows" && cp "$KIT/.github/workflows/ci.yml" "$TARGET/.github/workflows/ci.yml"

trim_for_go_only() {
  python3 - "$TARGET/AGENTS.md" "$TARGET/.go-rules.md" <<'PY' || exit 1
import sys
agents, rules = sys.argv[1], sys.argv[2]
s = open(agents).read()
s = s.replace("cd server && make test        # or: go test ./...", "make test                     # or: go test ./...")
s = s.replace("mise run test                 # both halves, offline",
              "mise run test                 # go tests, offline")
s = s.replace("cd web && npx vitest run      # or: npm run dev / npm run build\n", "")
s = s.replace("cd server && make lint        # golangci-lint, standard set",
              "make lint                     # golangci-lint, standard set")
s = s.replace("cd web && npm run lint        # eslint + prettier (formatting is a lint error here)\n", "")
s = s.replace("scripts/dev.sh                # api :8080 + web :5173 together",
              "make run                      # api on :8080")
s = s.replace("Language rules live next to the code: `server/AGENTS.md` and `web/AGENTS.md`.",
              open(rules).read().split("\n", 1)[1].strip())
open(agents, "w").write(s)
PY
  rm -f "$TARGET/scripts/dev.sh" "$TARGET/.go-rules.md"
}
[ "$GO_ONLY" -eq 1 ] && trim_for_go_only

# name the exercise in the generated guidance, so a blank session knows what it is looking at
perl -0pi -e "s|# Working in this repo\n|# Working in this repo\n\nExercise: \`$NAME\`. Keep it small; extend what is here.\n|" "$TARGET/AGENTS.md"
perl -pi -e "if ($. == 1) { s|^# .*|# $NAME| }" "$TARGET/README.md"

# module path and package name follow the directory, so imports read naturally in the round
perl -pi -e "s|^module interviewkit|module $NAME|" "$GO_PATH/go.mod"
grep -rl '"interviewkit/' "$GO_PATH" 2>/dev/null | while read -r f; do
  perl -pi -e "s|\"interviewkit/|\"$NAME/|g" "$f"
done
if [ "$GO_ONLY" -eq 0 ] && [ -f "$TARGET/web/package.json" ]; then
  perl -pi -e "s|\"name\": \"[^\"]+\"|\"name\": \"$NAME-web\"|" "$TARGET/web/package.json"
  [ -f "$TARGET/web/package-lock.json" ] && perl -pi -e "s|\"name\": \"web\"|\"name\": \"$NAME-web\"|g" "$TARGET/web/package-lock.json"
fi

cd "$TARGET" || exit 1

printf 'verifying green before handing over\n'
if [ -d "$TARGET/web/node_modules" ]; then
  ./scripts/preflight.sh --fast || { echo "gate failed — not committing" >&2; exit 1; }
else
  ./scripts/preflight.sh --ci || { echo "gate failed — not committing" >&2; exit 1; }
fi

git init -q
git add -A
git -c user.name="${GIT_AUTHOR_NAME:-scaffold}" -c user.email="${GIT_AUTHOR_EMAIL:-scaffold@localhost}" \
  commit -qm "scaffold: $NAME from interview kit" || { echo "git commit failed" >&2; exit 1; }

printf '\nready: %s\n' "$TARGET"
if [ "$GO_ONLY" -eq 0 ]; then
  printf '  cd %s && scripts/dev.sh\n' "$TARGET"
  printf '  go:  cd server && make run | make test      (module %s)\n' "$NAME"
  printf '  web: cd web && npm run dev | npx vitest run\n'
else
  printf '  cd %s && make run\n' "$TARGET"
  printf '  go:  make run | make test      (module %s, at the repo root)\n' "$NAME"
fi
printf '\nfirst commit is in place, so `git diff` shows only your work from here.\n'
