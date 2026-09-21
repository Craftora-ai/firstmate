#!/usr/bin/env bash
# Live driver: spawn real Codex scouts via bin/fm-spawn.sh into an isolated
# fm-lab-* Herdr session from a throwaway FM_HOME, then read the running Codex
# process environment and the worker's own pane report.
set -u
ROOT=/Users/xphoid/.no-mistakes/worktrees/dcd741e74588/01M3242TBWNW1PVCKVR2FXHHPZ
EVD=/Users/xphoid/.no-mistakes/evidence/01M3242TBWNW1PVCKVR2FXHHPZ
. "$ROOT/tests/herdr-test-safety.sh"
herdr_forget_inherited_pane
LAB="$ROOT/bin/fm-herdr-lab.sh"
S=$("$LAB" name codexhome) || exit 1
export HERDR_SESSION="$S"
echo "lab session: $S"
TMP=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-codexhome-live.XXXXXX")
WTS=()
cleanup() {
  for wt in ${WTS[@]+"${WTS[@]}"}; do treehouse return --force "$wt" >/dev/null 2>&1; done
  "$LAB" teardown "$S" && echo "teardown ok (default-session tripwire intact)"
  rm -rf "$TMP"
}
trap cleanup EXIT
"$LAB" provision "$S" || exit 1
lab() { "$LAB" run "$S" "$@"; }
SOCK=$(lab session list --json | jq -r --arg s "$S" '.sessions[]|select(.name==$s)|.socket_path')

PROJ="$TMP/proj"; mkdir -p "$PROJ"; git -C "$PROJ" init -q; echo x > "$PROJ/README.md"
git -C "$PROJ" add README.md; git -C "$PROJ" -c user.name=t -c user.email=t@e.invalid commit -qm init
git clone -q --bare "$PROJ" "$PROJ.origin.git"; git -C "$PROJ" remote add origin "file://$PROJ.origin.git"

HOME_FM="$TMP/fmhome"; mkdir -p "$HOME_FM/state" "$HOME_FM/config" "$HOME_FM/data"
printf 'off\n' > "$HOME_FM/config/herdr-presentation-spaces"

brief() { # id
  mkdir -p "$HOME_FM/data/$1"
  cat > "$HOME_FM/data/$1/brief.md" <<B
# Task
## Captain's intent
Report which Codex configuration directory this worker process runs on.

## Firstmate spec
Run exactly these shell commands and nothing else, then stop and do not edit any file:
1. printf 'REPORT CODEX_HOME=%s\n' "\${CODEX_HOME-unset}"
2. codex mcp list
3. ls "\${CODEX_HOME:-\$HOME/.codex}/skills/" | wc -l
Then reply with one line: DONE CODEX_HOME=<value from step 1>.
B
}

spawn() { # id
  env HERDR_SESSION="$S" HERDR_SOCKET_PATH="$SOCK" FM_SPAWN_NO_GUARD=1 FM_HOME="$HOME_FM" FM_ROOT_OVERRIDE="$ROOT" \
    "$ROOT/bin/fm-spawn.sh" "$1" "$PROJ" --scout --harness codex --backend herdr
}

codex_env_of_pane() { # pane
  local pid pids
  pids=$(lab pane process-info "$1" 2>/dev/null | jq -r '[.. | .pid? // empty] | .[]' 2>/dev/null)
  for pid in $(pgrep -f 'codex' ); do
    ps -E -o command= -p "$pid" 2>/dev/null | grep -q "FM_TASK_ID=$2" || continue
    ps -o pid=,comm= -p "$pid"
    ps -E -o command= -p "$pid" | tr ' ' '\n' | grep -E '^(CODEX_HOME|FM_TASK_ID)=' || echo "  (CODEX_HOME absent from process env)"
  done
}

run_case() { # id  label
  local id=$1 out rc pane
  brief "$id"
  out=$(spawn "$id" 2>&1); rc=$?
  echo "== spawn $id ($2): rc=$rc"; echo "$out" | tail -5
  [ -f "$HOME_FM/state/$id.meta" ] && { WTS+=("$(grep '^worktree=' "$HOME_FM/state/$id.meta" | cut -d= -f2-)"); grep -E '^(window|backend|harness|kind)=' "$HOME_FM/state/$id.meta"; }
  return $rc
}

pane_of() { grep -E '^window=' "$HOME_FM/state/$1.meta" | head -1 | cut -d= -f2- | sed "s/^$S://" ; }

mkhome() { # dir trust-path
  mkdir -p "$1"; grep -v -e '^\[projects' -e '^trust_level' "$HOME/.codex-alfred/config.toml" > "$1/config.toml"
  printf '\n[projects."%s"]\ntrust_level = "trusted"\n' "$2" >> "$1/config.toml"
  ln -s "$HOME/.codex-alfred/auth.json" "$1/auth.json"; ln -s "$HOME/.codex-alfred/skills" "$1/skills"
}
# --- Case D: docs followed - trust the dispatched repository's primary checkout ---
mkhome "$TMP/cx-primary" "$PROJ"
echo "== cx-primary config.toml:"; sed 's/^/   /' "$TMP/cx-primary/config.toml" | grep -v -i key
printf '%s\n' "$TMP/cx-primary" > "$HOME_FM/config/codex-home"
run_case cxhD "trust primary checkout $PROJ"
# --- Case E: adversarial - trust only the worktree root ---
mkhome "$TMP/cx-wtroot" "$HOME/.treehouse"
printf '%s\n' "$TMP/cx-wtroot" > "$HOME_FM/config/codex-home"
run_case cxhE "trust only $HOME/.treehouse"
for i in $(seq 1 30); do
  PD=$(pane_of cxhD); txt=$(lab pane read "$PD" --source recent-unwrapped --lines 300 --format text 2>/dev/null)
  echo "$txt" | grep -q 'DONE CODEX_HOME' && break
  sleep 10
done
for id in cxhD cxhE; do
  echo "== running Codex process env for $id"; codex_env_of_pane "" "$id" | grep -E '^ *[0-9]|^(CODEX_HOME=/|FM_TASK_ID|  \()'
  P=$(pane_of "$id")
  lab pane read "$P" --source recent-unwrapped --lines 300 --format text > "$EVD/r3-pane-$id.txt" 2>&1
  echo "== pane $id ($P) saved"
  grep -E -i 'trust|REPORT CODEX_HOME|DONE CODEX_HOME|^ *(brave|dfs-mcp|exa|firecrawl) |^ *[0-9]+$' "$EVD/r3-pane-$id.txt" | sed 's/^/   /' | head -20
done
