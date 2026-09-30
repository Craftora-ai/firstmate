#!/usr/bin/env bash
# drive-stale-churn.sh <bin-dir> <label> <status-text> <churn-count>
# Live drive: real bin/fm-watch.sh + real fm-crew-state.sh against a disposable
# lab FM_HOME and a real tmux pane (private TMUX_TMPDIR) whose idle shell pane
# repaints (keystrokes typed into the prompt, no command run). After each
# surfaced wake the driver drains+acks exactly as main would, then re-arms.
set -u
BIN=$1 LABEL=$2 STATUS=$3 CHURN=$4
WT=/Users/xphoid/.no-mistakes/worktrees/dcd741e74588/01M3RN8AXZ0ZK5XXW0ZXBG7D31
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX"); rmdir "$LAB"
"$WT/bin/fm-lab-home.sh" create "$LAB" >/dev/null
mkdir -p "$LAB/tmux"
export TMUX_TMPDIR="$LAB/tmux"; unset TMUX
T() { env -u FM_STATE_OVERRIDE tmux "$@"; }
cleanup() { kill "${WPID:-0}" 2>/dev/null; wait "${WPID:-0}" 2>/dev/null; tmux kill-server 2>/dev/null; rm -rf "$LAB"; }
trap cleanup EXIT
tmux new-session -d -s crew -n fm-scout1 -x 120 -y 30 "env -i HOME=$LAB PATH=/bin:/usr/bin PS1='scout> ' /bin/zsh -f"
sleep 1
S="$LAB/state"
cp "$WT/.tasks.toml" "$LAB/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$LAB/data/backlog.md"
(cd "$LAB" && tasks-axi add scout1 'meta plan summary' --file data/backlog.md) >/dev/null 2>&1
git init -q "$LAB/projects/wt" && git -C "$LAB/projects/wt" -c user.email=l@l -c user.name=l commit -q --allow-empty -m init
printf "window=crew:fm-scout1\nkind=scout\nharness=claude\nbackend=tmux\nworktree=%s\n" "$LAB/projects/wt" > "$S/scout1.meta"
printf '%b\n' "$STATUS" > "$S/scout1.status"
# prime the status suppressor so only the stale path is exercised
. "$BIN/fm-classify-lib.sh"
size_of() { LC_ALL=C wc -c < "$1" | tr -d '[:space:]'; }
printf 'v2\t%s\t%s@%s' "$(status_observed_signature "$S/scout1.status")" "$(size_of "$S/scout1.status")" "$(_fm_open_decisions_file_ident "$S/scout1.status")" > "$S/.seen-scout1_status"
arm() {
  FM_HOME="$LAB" FM_WATCH_HANDLING_SUCCESSOR=1 FM_POLL=1 FM_SIGNAL_GRACE=1 \
    FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 FM_PAUSE_RESURFACE_SECS=${RESURFACE:-999} \
    "$BIN/fm-watch.sh" >> "$LAB/watch.out" 2>&1 &
  WPID=$!
}
ack() {
  local err="$LAB/drain.err" seq gen
  FM_HOME="$LAB" "$BIN/fm-wake-drain.sh" > "$LAB/drain.out" 2> "$err"
  seq=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9]*\) --recovery-generation .*/\1/p' "$err")
  gen=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--recovery-generation \([A-Za-z0-9._-]*\)$/\1/p' "$err")
  [ -n "$seq" ] && FM_HOME="$LAB" "$BIN/fm-wake-drain.sh" --ack-through "$seq" --recovery-generation "$gen" >/dev/null 2>&1
}
turns=0
arm
for i in $(seq 1 "$CHURN"); do
  [ "$i" = "${APPEND_AT:-0}" ] && { echo "  (repaint $i: scout appends: $APPEND_LINE)"; printf "%s\n" "$APPEND_LINE" >> "$S/scout1.status"; }
  tmux send-keys -t crew:fm-scout1 -l "x"
  for _ in 1 2 3 4 5 6; do
    sleep 1
    if ! kill -0 "$WPID" 2>/dev/null; then
      turns=$((turns + 1)); echo "  repaint $i: watcher exited -> main woken (turn $turns): $(tail -1 "$LAB/watch.out")"
      ack; arm; break
    fi
  done
done
sleep 3; kill -0 "$WPID" 2>/dev/null || { turns=$((turns+1)); echo "  late exit: $(tail -1 "$LAB/watch.out")"; }
stale=$(awk -F '\t' '$3 == "stale" { n++ } END { print n + 0 }' "$S/.wake-queue" 2>/dev/null)
echo "[$LABEL] pane repaints=$CHURN  main turns forced=$turns  stale wakes queued=$stale"
echo "  crew-state: $(FM_HOME="$LAB" "$BIN/fm-crew-state.sh" scout1 2>/dev/null)"
echo "  triage log:"; grep -i 'stale' "$S/.watch-triage.log" 2>/dev/null | sed 's/^/    /' | sort | uniq -c | sort -rn | head -6
