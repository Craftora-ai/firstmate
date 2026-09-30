#!/usr/bin/env bash
# Live lab driver for fm-tool-update-check.sh (new at target commit, old at base
# 65c75b0 for before/after comparison). Every home, repo, and fixture command
# lives under /tmp/fm-lab-tuc01; published probes hit the real public npm
# registry and GitHub releases API.
set -u
L=/tmp/fm-lab-tuc01
NEW=/Users/xphoid/.no-mistakes/worktrees/dcd741e74588/01M3SG64VSQF27KV2QF8NJ50A0/bin/fm-tool-update-check.sh
OLD=$L/old/bin/fm-tool-update-check.sh
export GIT_AUTHOR_NAME=lab GIT_AUTHOR_EMAIL=lab@example.invalid GIT_COMMITTER_NAME=lab GIT_COMMITTER_EMAIL=lab@example.invalid
BASEPATH=/usr/bin:/bin:/opt/homebrew/bin

say() { printf '\n### %s\n' "$*"; }

# run <script> <home> <extra env...>: one `check` sweep, as the watcher would run it.
run() {
  local script=$1 home=$2; shift 2
  local label; label=$([ "$script" = "$NEW" ] && echo NEW || echo OLD)
  local t0 t1 out
  t0=$(date +%s)
  out=$(env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_DATA_OVERRIDE \
    FM_HOME="$home" FM_TOOL_UPDATE_INTERVAL=0 PATH="$home/tools:$BASEPATH" "$@" "$script" check 2>&1)
  t1=$(date +%s)
  printf '[%s %ss] %s\n' "$label" "$((t1 - t0))" "${out:-<silent>}"
}

mkhome() { rm -rf "$L/$1"; mkdir -p "$L/$1/state" "$L/$1/config" "$L/$1/tools"; }

# mkrepo <home> <name>: bare upstream, a dev clone that pushes, and a watched copy one commit behind.
mkrepo() {
  local h=$1 n=$2 r="$L/$1/repos/$2"
  mkdir -p "$r"
  git init -q --bare -b main "$r/up.git"
  git clone -q "$r/up.git" "$r/dev" 2>/dev/null
  git -C "$r/dev" commit -q --allow-empty -m c1 && git -C "$r/dev" push -q origin HEAD:main
  git clone -q "$r/up.git" "$r/copy"
  git -C "$r/dev" commit -q --allow-empty -m c2 && git -C "$r/dev" push -q origin HEAD:main
}
upstream_commit() { git -C "$L/$1/repos/$2/dev" commit -q --allow-empty -m "c$RANDOM" && git -C "$L/$1/repos/$2/dev" push -q origin HEAD:main; }

# tool <home> <cmd> <script body>
tool() { printf '#!/usr/bin/env bash\n%s\n' "$3" > "$L/$1/tools/$2"; chmod 0755 "$L/$1/tools/$2"; }

s1() {
  say "S1 slow first tools no longer leave the last tool unchecked (budget 20s)"
  for v in NEW OLD; do
    mkhome s1$v; mkrepo s1$v firstmate; mkrepo s1$v treehouse
    # firstmate's remote is slow to answer, like the real fetch that is first in the list.
    printf '#!/bin/sh\nsleep 4\nexec git-upload-pack "$@"\n' > "$L/s1$v/slow-upload-pack"; chmod 0755 "$L/s1$v/slow-upload-pack"
    git -C "$L/s1$v/repos/firstmate/copy" config remote.origin.uploadpack "$L/s1$v/slow-upload-pack"
    tool s1$v kimi 'sleep 13; echo "kimi 1.2.3"'
    tool s1$v higgsfield 'sleep 13; echo "higgsfield 2.0.0"'
    cat > "$L/s1$v/config/watched-tools.json" <<J
{"tools":[
 {"name":"firstmate","git":{"repo":"$L/s1$v/repos/firstmate/copy","remote":"origin","branch":"main"}},
 {"name":"kimi","command":"kimi","probe_secs":15},
 {"name":"higgsfield-skills","command":"higgsfield","probe_secs":15},
 {"name":"treehouse","git":{"repo":"$L/s1$v/repos/treehouse/copy","remote":"origin","branch":"main"}}
]}
J
  done
  run "$NEW" "$L/s1NEW" FM_TOOL_UPDATE_PROBE_SECS=15
  run "$OLD" "$L/s1OLD" FM_TOOL_UPDATE_PROBE_SECS=15
}

s2() {
  say "S2 a new upstream commit while the clone stays behind is not news"
  for v in NEW OLD; do
    mkhome s2$v; mkrepo s2$v firstmate
    printf '{"tools":[{"name":"firstmate","git":{"repo":"%s","remote":"origin","branch":"main"}}]}\n' "$L/s2$v/repos/firstmate/copy" > "$L/s2$v/config/watched-tools.json"
  done
  for v in NEW OLD; do
    s=$([ $v = NEW ] && echo "$NEW" || echo "$OLD")
    echo "-- $v sweep 1 (clone 1 behind)"; run "$s" "$L/s2$v"
    upstream_commit s2$v firstmate
    echo "-- $v sweep 2 (someone else committed upstream; clone now 2 behind)"; run "$s" "$L/s2$v"
    upstream_commit s2$v firstmate
    echo "-- $v sweep 3 (another upstream commit)"; run "$s" "$L/s2$v"
  done
  echo "-- NEW record file:"; cat "$L/s2NEW/state/.tool-updates"
  echo "-- NEW: clone catches up, then falls behind again (current -> behind is news)"
  git -C "$L/s2NEW/repos/firstmate/copy" pull -q --ff-only
  run "$NEW" "$L/s2NEW"
  upstream_commit s2NEW firstmate
  run "$NEW" "$L/s2NEW"
}

s3() {
  say "S3 a transient 'origin did not answer' failure keeps the reported update's suppression"
  for v in NEW OLD; do
    mkhome s3$v; mkrepo s3$v firstmate
    printf '{"tools":[{"name":"firstmate","git":{"repo":"%s","remote":"origin","branch":"main"}}]}\n' "$L/s3$v/repos/firstmate/copy" > "$L/s3$v/config/watched-tools.json"
    s=$([ $v = NEW ] && echo "$NEW" || echo "$OLD")
    up="$L/s3$v/repos/firstmate/up.git"
    echo "-- $v sweep 1 (behind, remote reachable)"; run "$s" "$L/s3$v"
    mv "$up" "$up.off"
    echo "-- $v sweep 2 (remote unreachable)"; run "$s" "$L/s3$v"
    mv "$up.off" "$up"
    echo "-- $v sweep 3 (remote back, same pending update)"; run "$s" "$L/s3$v"
    mv "$up" "$up.off"
    echo "-- $v sweep 4 (remote unreachable again)"; run "$s" "$L/s3$v"
    mv "$up.off" "$up"
    echo "-- $v sweep 5 (remote back again)"; run "$s" "$L/s3$v"
  done
}

s4() {
  say "S4 a sweep that flips between incomplete and complete does not re-report the pending update"
  for v in NEW OLD; do
    mkhome s4$v; mkrepo s4$v firstmate
    tool s4$v treehouse 'if [ -e '"$L/s4$v"'/slow ]; then sleep 30; fi; echo "treehouse 0.4.0"'
    printf '{"tools":[{"name":"firstmate","git":{"repo":"%s","remote":"origin","branch":"main"}},{"name":"treehouse","command":"treehouse"}]}\n' "$L/s4$v/repos/firstmate/copy" > "$L/s4$v/config/watched-tools.json"
    s=$([ $v = NEW ] && echo "$NEW" || echo "$OLD")
    touch "$L/s4$v/slow"
    echo "-- $v sweep 1 (treehouse hangs, budget 6s)"; run "$s" "$L/s4$v" FM_TOOL_UPDATE_BUDGET_SECS=6 FM_TOOL_UPDATE_PROBE_SECS=30
    rm -f "$L/s4$v/slow"
    echo "-- $v sweep 2 (sweep finishes)"; run "$s" "$L/s4$v" FM_TOOL_UPDATE_BUDGET_SECS=6 FM_TOOL_UPDATE_PROBE_SECS=30
    touch "$L/s4$v/slow"
    echo "-- $v sweep 3 (treehouse hangs again)"; run "$s" "$L/s4$v" FM_TOOL_UPDATE_BUDGET_SECS=6 FM_TOOL_UPDATE_PROBE_SECS=30
  done
}

s5() {
  say "S5 a blocked announce probe (LuLu-style) is a check failure, not silence"
  for v in NEW OLD; do
    mkhome s5$v
    tool s5$v no-mistakes 'case "$1" in --version) echo "no-mistakes v1.75.2";; --help) echo "network request blocked" >&2; exit 1;; esac'
    cat > "$L/s5$v/config/watched-tools.json" <<'J'
{"tools":[{"name":"no-mistakes","command":"no-mistakes","version_args":["--version"],"announce_args":["--help"],"announce_pattern":"A new version of no-mistakes is available: [^ ]+ -> [^ ]+"}]}
J
    s=$([ $v = NEW ] && echo "$NEW" || echo "$OLD")
    run "$s" "$L/s5$v"
  done
}

s6() {
  say "S6 npm and GitHub release probes against the real public registries"
  mkhome s6
  mkdir -p "$L/s6/mcp/exa/node_modules/tasks-axi" "$L/s6/mcp/current/node_modules/tasks-axi" "$L/s6/mcp/dfs"
  echo '{"name":"tasks-axi","version":"0.2.5"}' > "$L/s6/mcp/exa/node_modules/tasks-axi/package.json"
  echo '{"name":"tasks-axi","version":"0.2.6"}' > "$L/s6/mcp/current/node_modules/tasks-axi/package.json"
  printf '#!/bin/sh\nexec npx -y lavish-axi@0.1.71 "$@"\n' > "$L/s6/mcp/dfs/launch.sh"
  tool s6 no-mistakes 'echo "no-mistakes v1.75.2"'
  cat > "$L/s6/config/watched-tools.json" <<J
{"tools":[
 {"name":"tasks-axi","published":{"source":"npm","package":"tasks-axi","installed":{"npm_dir":"$L/s6/mcp/exa"}}},
 {"name":"tasks-axi-current","published":{"source":"npm","package":"tasks-axi","installed":{"npm_dir":"$L/s6/mcp/current"}}},
 {"name":"lavish-axi","published":{"source":"npm","package":"lavish-axi","installed":{"npx_pin":"$L/s6/mcp/dfs/launch.sh"}}},
 {"name":"no-mistakes","command":"no-mistakes","published":{"source":"github","repo":"kunchenguid/no-mistakes"}}
]}
J
  echo "-- sweep 1"; run "$NEW" "$L/s6"
  echo "-- sweep 2 (nothing changed)"; run "$NEW" "$L/s6"
}

s7() {
  say "S7 announce blocked + published reports; once announce answers the same update it is not news"
  mkhome s7
  tool s7 no-mistakes 'case "$1" in --version) echo "no-mistakes v1.75.2";; --help) if [ -e '"$L"'/s7/unblocked ]; then echo "A new version of no-mistakes is available: 1.75.2 -> 1.84.0"; else exit 1; fi;; esac'
  cat > "$L/s7/config/watched-tools.json" <<'J'
{"tools":[{"name":"no-mistakes","command":"no-mistakes","version_args":["--version"],"announce_args":["--help"],"announce_pattern":"A new version of no-mistakes is available: [^ ]+ -> [^ ]+","published":{"source":"github","repo":"kunchenguid/no-mistakes"}}]}
J
  echo "-- sweep 1 (announce blocked)"; run "$NEW" "$L/s7"
  touch "$L/s7/unblocked"
  echo "-- sweep 2 (block lifted, announcement for the same update)"; run "$NEW" "$L/s7"
  cat "$L/s7/state/.tool-updates"
}

s8() {
  say "S8 a source that keeps failing does not hide the tool's next update"
  mkhome s8; mkrepo s8 firstmate
  tool s8 firstmate 'case "$1" in --version) echo "firstmate 1.0.0";; *) exit 1;; esac'
  cat > "$L/s8/config/watched-tools.json" <<J
{"tools":[{"name":"firstmate","command":"firstmate","announce_args":["--check"],"announce_pattern":"update available: [^ ]+","git":{"repo":"$L/s8/repos/firstmate/copy","remote":"origin","branch":"main"}}]}
J
  echo "-- sweep 1 (announce fails, git behind)"; run "$NEW" "$L/s8"
  git -C "$L/s8/repos/firstmate/copy" pull -q --ff-only
  echo "-- sweep 2 (update installed; announce still fails)"; run "$NEW" "$L/s8"
  upstream_commit s8 firstmate
  echo "-- sweep 3 (a newer upstream commit)"; run "$NEW" "$L/s8"
}

s9() {
  say "S9 per-tool probe_secs lets a slow binary (kimi under load) answer"
  mkhome s9
  tool s9 kimi 'sleep 7; echo "kimi 0.9.1"'
  echo '{"tools":[{"name":"kimi","command":"kimi"}]}' > "$L/s9/config/watched-tools.json"
  echo "-- without probe_secs (default 5s)"; run "$NEW" "$L/s9"
  rm -f "$L/s9/state/.tool-updates"
  echo '{"tools":[{"name":"kimi","command":"kimi","probe_secs":15}]}' > "$L/s9/config/watched-tools.json"
  echo "-- with probe_secs 15"; run "$NEW" "$L/s9"
}

s10() {
  say "S10 arm installs the watcher shim, the shim reports, disarm removes it"
  mkhome s10; mkrepo s10 treehouse
  printf '{"tools":[{"name":"treehouse","git":{"repo":"%s","remote":"origin","branch":"main"}}]}\n' "$L/s10/repos/treehouse/copy" > "$L/s10/config/watched-tools.json"
  env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_CONFIG_OVERRIDE FM_HOME="$L/s10" "$NEW" arm; echo "arm exit $?"
  ls "$L/s10/state"
  echo "-- shim run 1:"; env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_CONFIG_OVERRIDE FM_TOOL_UPDATE_INTERVAL=0 bash "$L/s10/state/tool-updates.check.sh"; echo "exit $?"
  upstream_commit s10 treehouse
  echo "-- shim run 2 (upstream advanced):"; env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_CONFIG_OVERRIDE FM_TOOL_UPDATE_INTERVAL=0 bash "$L/s10/state/tool-updates.check.sh"; echo "exit $? (silent above = pass)"
  env -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_CONFIG_OVERRIDE FM_HOME="$L/s10" "$NEW" disarm; echo "disarm exit $?"
  ls "$L/s10/state"
}

for s in "$@"; do "$s"; done
