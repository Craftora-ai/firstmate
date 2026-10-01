#!/usr/bin/env bash
# Manual real-entrypoint transcript for bin/fm-merge-local.sh knowledge landing.
# Usage: manual-landing-transcript.sh <worktree-root>
# Every fixture lives in a fresh mktemp directory outside the worktree.
set -u
ROOT=$1
MERGE="$ROOT/bin/fm-merge-local.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/fm-knowledge-manual.XXXXXX")
export GIT_CEILING_DIRECTORIES="$T"
unset FM_CONFIG_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE NO_MISTAKES_GATE
echo "worktree head: $(git -C "$ROOT" rev-parse HEAD)"

fixture() {  # <name> <project-rel> <opt-in yes|no> <checker yes|no>
  H="$T/$1/home"; P="$H/$2"; ID=demo-task
  mkdir -p "$H/state" "$H/config" "$H/data/approvals" "$P/tools"
  if [ "$3" = yes ]; then
    printf '%s\n' 'checker=tools/check.py' 'approvals=data/approvals' 'ok=OK clean: ' > "$H/config/knowledge-landing"
  fi
  git -C "$P" init -q -b main; git -C "$P" config user.name demo; git -C "$P" config user.email demo@example.invalid
  if [ "$4" = yes ]; then
    cat > "$P/tools/check.py" <<'PY'
import subprocess, sys
base, head, _, root = sys.argv[1:]
names = subprocess.run(["git", "-C", root, "diff", "--name-only", base, head],
                       capture_output=True, text=True, check=True).stdout.split()
print("demo-check: base %s head %s merge-base %s" % (base, head, base))
bad = [n for n in names if n.endswith(".py")]
for n in bad:
    print("FAIL %s: code in knowledge repo" % n)
if bad:
    print("REFUSED %d finding(s)" % len(bad)); sys.exit(2)
print("OK clean: %d change(s)" % len(names))
PY
  fi
  echo base > "$P/base"; git -C "$P" add .; git -C "$P" commit -qm base
  BASE=$(git -C "$P" rev-parse HEAD)
  git -C "$P" checkout -qb "fix/$ID"
  echo "$5" > "$P/$6"; git -C "$P" add .; git -C "$P" commit -qm change
  HEAD_OID=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
  printf 'project=%s\nmode=local-only\nbranch=fix/%s\n' "$P" "$ID" > "$H/state/$ID.meta"
}
land() {  # <fm-home>
  echo "\$ FM_HOME=${1#$T/} FM_STATE_OVERRIDE=${H#$T/}/state fm-merge-local.sh $ID"
  env FM_HOME="$1" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$H/state" "$MERGE" "$ID" 2>&1 | sed "s#$T/##g; s/^/  | /"
  rc=${PIPESTATUS[0]}; echo "  exit=$rc  main=$(git -C "$P" rev-parse main | cut -c1-12) base=${BASE:0:12} head=${HEAD_OID:0:12}"
}
section() { echo; echo "=== $* ==="; }

section "S7 mismatched FM_HOME, no FM_CONFIG_OVERRIDE, owning home opted in -> refused"
fixture s7 projects/notes yes yes 'print(1)' forbidden.py; mkdir -p "$T/elsewhere/state" "$T/elsewhere/data"; land "$T/elsewhere"
section "S8 mismatched FM_HOME, exact approval in owning home -> lands"
echo "$HEAD_OID" > "$H/data/approvals/$ID"; land "$T/elsewhere"

rm -rf "$T"
