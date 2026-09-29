# Live lab: long busy Claude turn after an idle gap (FM_BUSY_TURN_MAX_SECS=60, FM_STALE_ESCALATE_SECS=15, FM_POLL=3)

Setup: a disposable marked lab home (bin/fm-lab-home.sh) and a private tmux socket. A real interactive Claude Code 2.1.284
ran in window crew:long, with the same UserPromptSubmit/Stop/StopFailure/SessionEnd busy hooks that fm-spawn.sh writes
(real bin/fm-busy-event.sh). The real bin/fm-watch.sh ran in a loop that drained and acked each wake with bin/fm-wake-drain.sh,
as a firstmate primary would.
Each long turn ran `./build.sh 110`, a foreground 110s step.

HEAD (7d0c765), turn C: submitted at 1790668681, previous turn-ended at 1790668594 (87s idle gap).
  No wake for the first 77s. The first "possible wedge" came at 1790668759 (77s into the turn = 60s bound + 15s timer).
BASE (b5fdf74), turn D: submitted at 1790668888, previous turn-ended at 1790668799 (89s idle gap).
  "possible wedge" escalations came at +22s, +42s (demand-deep-inspection), and +61s: false alarms on a healthy busy turn.
Idle control (HEAD): an idle, non-busy pane surfaced "stale: crew:long", then "stale ... possible wedge" after 15s.
Interrupt (HEAD): turn E opened at 1790669033. Escape at +64s fired no hook, so the record stayed busy with ts=1790669033.
  The new UserPromptSubmit at 1790669100 rewrote ts=1790669100 (seq 11, busy->busy). Turn F then ran with no wedge wake.
