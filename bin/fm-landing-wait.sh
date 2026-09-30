#!/usr/bin/env bash
# fm-landing-wait.sh - firstmate-owned wait for a finished ship's landing.
# Usage:
#   FM_HOME=<home> fm-landing-wait.sh set <id> --reason <external-condition>
#   FM_HOME=<home> fm-landing-wait.sh show <id>
#   FM_HOME=<home> fm-landing-wait.sh clear <id>
#
# A set requires a ship with a done status, a clean committed worktree on its
# recorded branch, and a nonempty one-line condition. This is a supervisor
# attestation, not a worker status, captain hold, merge approval, or proof that
# validation passed. Set only when the worker has no remaining work; clear
# before resuming it or when the named condition clears. Dependency checks and
# ordinary fleet review remain responsible for observing that condition.
#
# state/<id>.landing-wait is one tab-separated v1 record: version, status-file
# identity, status byte length, prefix checksum, metadata binding checksum,
# commit, reason. The metadata binding covers kind, worktree, branch, window,
# terminal (Orca's endpoint), backend, and harness.
# Readers accept it only while these bindings hold. Later resolved events are
# bookkeeping and preserve it; any other appended event, changed commit, branch,
# or worktree edit invalidates it. Invalid records never suppress wakes.
# Idle stale and routine turn-end wakes are quiet indefinitely, with no invented
# deadline; actionable status, steering delivery, PR checks, and busy detection
# retain their normal paths. Neither set nor clear writes the worker status log.
# Repeating set with the same active reason is a no-op; clear is idempotent.
# Show prints the reason and returns 0 only for an active wait, otherwise 1.
# FM_STATE_OVERRIDE selects a test/alternate state directory. Mutations require
# an explicit FM_HOME or FM_STATE_OVERRIDE and never select the code root's home.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"
# shellcheck source=bin/fm-pr-lib.sh
. "$SCRIPT_DIR/fm-pr-lib.sh"

usage() { sed -n '2,6s/^# \{0,1\}//p' "$0"; }
case "${1:-}" in -h|--help) usage; exit 0 ;; esac
COMMAND=${1:-}; ID=${2:-}
fm_pr_task_id_valid "$ID" || { usage >&2; exit 2; }
STATE=${FM_STATE_OVERRIDE-${FM_HOME:+$FM_HOME/state}}
[ -n "$STATE" ] && [ -d "$STATE" ] && [ ! -L "$STATE" ] || {
  echo 'error: explicit existing FM_HOME/state or FM_STATE_OVERRIDE required' >&2; exit 1;
}
RECORD="$STATE/$ID.landing-wait"
if [ -L "$RECORD" ] || { [ -e "$RECORD" ] && [ ! -f "$RECORD" ]; }; then
  echo 'error: landing wait record is not an ordinary file' >&2; exit 1
fi
case "$COMMAND" in
  show)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    fm_landing_wait_read "$STATE" "$ID"
    ;;
  clear)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    rm -f -- "$RECORD"
    printf 'landing wait cleared: %s\n' "$ID"
    ;;
  set)
    [ "$#" -eq 4 ] && [ "$3" = --reason ] || { usage >&2; exit 2; }
    REASON=$4
    case "$REASON" in
      *$'\n'*|*$'\r'*|*$'\t'*|'') echo 'error: reason must be a nonempty single line' >&2; exit 2 ;;
    esac
    case "$REASON" in *[![:space:]]*) ;; *) echo 'error: reason is blank' >&2; exit 2 ;; esac
    if [ "$(fm_landing_wait_read "$STATE" "$ID" || true)" = "$REASON" ]; then
      printf 'landing wait: %s: %s\n' "$ID" "$REASON"; exit 0
    fi
    STATUS="$STATE/$ID.status"
    # Capture the prefix before checking its terminal declaration: a worker
    # append during the slower Git reads must fall outside this prefix.
    IDENT=$(_fm_open_decisions_file_ident "$STATUS") || exit 1
    BYTES=$(LC_ALL=C wc -c < "$STATUS" | tr -d '[:space:]')
    PREFIX=$(cksum < "$STATUS")
    [ "$(status_line_verb "$(last_status_line "$STATUS")")" = "done" ] || {
      echo 'error: landing wait requires a done declaration' >&2; exit 1;
    }
    BINDING=$(fm_landing_wait_binding "$STATE" "$ID") || {
      echo 'error: landing wait requires a clean committed ship on its recorded branch' >&2; exit 1;
    }
    TMP=$(mktemp "$STATE/.landing-wait-$ID.XXXXXX")
    trap 'rm -f -- "$TMP"' EXIT
    printf 'v1\t%s\t%s\t%s\t%s\t%s\n' "$IDENT" "$BYTES" "$PREFIX" "$BINDING" "$REASON" > "$TMP"
    # Re-read before publishing so a worker that resumed during set cannot park.
    fm_landing_wait_read "$STATE" "$ID" "$TMP" >/dev/null || {
      echo 'error: task changed while recording its landing wait' >&2; exit 1;
    }
    mv -f -- "$TMP" "$RECORD"
    printf 'landing wait: %s: %s\n' "$ID" "$REASON"
    ;;
  *) usage >&2; exit 2 ;;
esac
