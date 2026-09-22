#!/bin/bash
# Drives the real bin/fm-dispatch-resolve.sh (real /usr/bin/curl over HTTP to a local
# TypeSafe stand-in, real quota-axi snapshot) in a throwaway FM_HOME.
set -u
W=/Users/xphoid/.no-mistakes/worktrees/dcd741e74588/01M33V1SAN31J0DJPB4W4ZSRFM; LAB=/Users/xphoid/.no-mistakes/evidence/01M33V1SAN31J0DJPB4W4ZSRFM/lab
export PATH="$LAB/bin:$PATH"
HOME_DIR=$LAB/home; mkdir -p "$HOME_DIR/config" "$HOME_DIR/data/t1"
BRIEF=$HOME_DIR/data/t1/brief.md
cat > "$BRIEF" <<'B'
Write a nightly job that summarizes vault notes and emails the summary to the team unattended.
B
GOOD_RULES='{"rules":[
 {"when":"Unattended automation that writes into the vault or sends something outward","strongest_reasoning":true,"confidence_floor":0.3,"use":[{"harness":"claude","model":"opus","effort":"high"}]},
 {"when":"Simple fact reporting or reading","use":[{"harness":"codex","model":"gpt-5.5","effort":"medium"}]}],
 "default":[{"harness":"codex","model":"gpt-5.5","effort":"medium"}]}'
stakes_ok='{"type":"choice","choice":"stakes_required","confidence":0.93,"probabilities":{"not_required":0.03,"stakes_required":0.93,"unclear":0.04}}'
cfg() { # rule choice, confidence(or null), stakes answer json, stakes http, stakes delay
  jq -n --arg c "$1" --argjson conf "$2" --argjson s "$3" --argjson h "${4:-200}" --argjson d "${5:-0}" '
   {rule:{type:"choice",choice:$c,confidence:$conf,
     probabilities:(if $c=="rule_1" then {rule_1:0.62,rule_2:0.3,default:0.08} elif $c=="rule_2" then {rule_1:0.3,rule_2:0.62,default:0.08} else {rule_1:0.1,rule_2:0.1,default:0.8} end)},
    stakes:{answer:$s,http:$h,delay:$d}}' > "$LAB/server.json"
}
run() { # title, rules json
  printf '%s\n' "$2" > "$HOME_DIR/config/crew-dispatch.json"
  echo "===== $1"
  local t0=$(python3 -c 'import time;print(int(time.time()*1000))')
  ( cd "$HOME_DIR/data/t1" && FM_HOME="$HOME_DIR" TYPESAFE_API_KEY=test-key "$W/bin/fm-dispatch-resolve.sh" "$BRIEF" --project demo ); echo "exit=$?"
  local t1=$(python3 -c 'import time;print(int(time.time()*1000))')
  echo "wall_ms=$((t1-t0))"
}
