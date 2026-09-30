#!/usr/bin/env bash
# drive-watch.sh <label> <seconds> : run the real fm-watch.sh against the lab home
# for up to <seconds>, nudging the pane each 15s so its hash changes like a live
# idle terminal would. Prints whatever the watcher emitted.
set -u
LAB=$(cat /tmp/fmlab-path-01M3); label=$1; secs=$2
WT=/Users/xphoid/.no-mistakes/worktrees/dcd741e74588/01M3SGBEPZGDA6TGMVK693DXAE
T() { env -u TMUX TMUX_TMPDIR="$LAB/tmux" tmux "$@"; }
out=$(mktemp)
env -u TMUX -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE \
  TMUX_TMPDIR="$LAB/tmux" FM_HOME="$LAB" FM_POLL=2 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
  "$WT/bin/fm-watch.sh" > "$out" 2>"$out.err" &
pid=$!
i=0; alive=1
while [ $i -lt "$secs" ]; do
  sleep 1; i=$((i+1))
  kill -0 $pid 2>/dev/null || { alive=0; break; }
  [ $((i % 15)) -eq 0 ] && T send-keys -t fm:fm-finished "echo idle-tick-$label-$i" Enter; T send-keys -t fm:fm-pausy "echo idle-tick-$label-$i" Enter 2>/dev/null
done
if [ $alive = 1 ]; then kill $pid 2>/dev/null; wait $pid 2>/dev/null; echo "[$label] watcher still running after ${secs}s (no wake), stopped"; else wait $pid; echo "[$label] watcher exited after ${i}s with wake"; fi
echo "[$label] stdout:"; cat "$out"; echo "[$label] stderr:"; tail -5 "$out.err"
if [ $alive = 0 ]; then
  # Firstmate drains and acknowledges the wake, as a supervision turn would.
  err=$(mktemp)
  echo "[$label] drained wake queue:"; FM_HOME="$LAB" "$WT/bin/fm-wake-drain.sh" 2>"$err" | sed 's/^/  /'
  seq=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9][0-9]*\) --recovery-generation.*/\1/p' "$err")
  gen=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--recovery-generation \([A-Za-z0-9._-]*\)$/\1/p' "$err")
  [ -n "$seq" ] && FM_HOME="$LAB" "$WT/bin/fm-wake-drain.sh" --ack-through "$seq" --recovery-generation "$gen" >/dev/null 2>&1 && echo "[$label] acked through $seq"
  rm -f "$err"
fi
rm -f "$out" "$out.err"
