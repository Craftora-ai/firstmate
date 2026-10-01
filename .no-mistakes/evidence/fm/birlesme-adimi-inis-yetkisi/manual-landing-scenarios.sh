#!/usr/bin/env bash
# Independent manual drive of bin/fm-merge-local.sh against disposable homes.
set -u
REPO=${REPO:?}
MERGE="$REPO/bin/fm-merge-local.sh"
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-know-manual.XXXXXX")
export GIT_CEILING_DIRECTORIES="$LAB"
unset FM_CONFIG_OVERRIDE FM_DATA_OVERRIDE FM_PROJECTS_OVERRIDE FM_ROOT_OVERRIDE
say() { printf '\n=== %s\n' "$*"; }

mkproj() { # <home> <relpath> <with-checker yes|no> -> sets P BASE HEAD
  local home=$1 rel=$2 chk=$3
  P="$home/$rel"; mkdir -p "$P/qa" "$home/state" "$home/config" "$home/data"
  git -C "$P" init -q -b main; git -C "$P" config user.name m; git -C "$P" config user.email m@example.invalid
  if [ "$chk" = yes ]; then cat > "$P/qa/check.py" <<'PY'
import subprocess, sys
base, head, _, root = sys.argv[1:]
mb = subprocess.check_output(["git","-C",root,"merge-base",base,head]).decode().strip()
names = subprocess.check_output(["git","-C",root,"diff","--name-only",base,head]).decode().split()
print("qa-check: base %s head %s merge-base %s; %d change(s)" % (base, head, mb, len(names)))
bad = [n for n in names if not n.endswith(".md")]
for n in bad: print("FAIL code %s: non-note change needs approval" % n)
if bad: print("REFUSED %d finding(s)" % len(bad)); sys.exit(2)
print("OK notes only: %d change(s)" % len(names))
PY
  fi
  echo base > "$P/README.md"; git -C "$P" add .; git -C "$P" commit -qm base
  BASE=$(git -C "$P" rev-parse HEAD)
}
branch() { # <id> <file> -> HEAD ; writes meta
  local id=$1 f=$2 home=$3
  git -C "$P" checkout -qb "fix/$id"; echo x > "$P/$f"; git -C "$P" add .; git -C "$P" commit -qm "$f"
  HEAD=$(git -C "$P" rev-parse HEAD); git -C "$P" checkout -q main
  printf 'project=%s\nmode=local-only\nbranch=fix/%s\n' "$P" "$id" > "$home/state/$id.meta"
}
show() { echo "main now: $(git -C "$P" rev-parse main)  (base $BASE, head $HEAD)"; }
cfg() { printf 'checker=qa/check.py\napprovals=data/approvals\nok=OK notes only:\nproject=projects/notes\n' > "$1/config/knowledge-landing"; }

H="$LAB/home"; mkdir -p "$H"

say "S1 default-off: home without config, project named vault carrying a checker, code change"
mkproj "$H" projects/vault yes; branch s1 code.py "$H"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s1; echo "exit=$?"; show

cfg "$H"
say "S2 opted-in, notes-only change: lands exact checked OID"
mkproj "$H" projects/notes yes; branch s2 note.md "$H"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s2; echo "exit=$?"; show

say "S3 opted-in, code change, no approval: refused, main unchanged"
BASE=$(git -C "$P" rev-parse main); branch s3 code.py "$H"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s3; echo "exit=$?"; show

say "S4 stale approval (names base, not head): still refused"
mkdir -p "$H/data/approvals"; echo "$BASE" > "$H/data/approvals/s3"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s3; echo "exit=$?"; show

say "S5 exact-head approval: lands that head"
echo "$HEAD" > "$H/data/approvals/s3"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s3; echo "exit=$?"; show

say "S6 mismatched FM_HOME, no FM_CONFIG_OVERRIDE: owning home config still applies (refused)"
E="$LAB/elsewhere"; mkdir -p "$E/state" "$E/data" "$E/config"
BASE=$(git -C "$P" rev-parse main); branch s6 evil.sh "$H"
FM_HOME="$E" FM_STATE_OVERRIDE="$H/state" "$MERGE" s6; echo "exit=$?"; show

say "S7 mismatched FM_HOME: owning home's exact approval is found"
echo "$HEAD" > "$H/data/approvals/s6"
FM_HOME="$E" FM_STATE_OVERRIDE="$H/state" "$MERGE" s6; echo "exit=$?"; show

say "S8 opted-in home, ordinary project without checker: unaffected"
mkproj "$H" projects/ordinary no; branch s8 code.py "$H"
FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" "$MERGE" s8; echo "exit=$?"; show

say "S9 configured project directory is a plain non-Git folder: ordinary landing not broken"
H2="$LAB/home2"; mkdir -p "$H2/projects/notes" "$H2/state" "$H2/config" "$H2/data"; cfg "$H2"
mkproj "$H2" projects/other no; branch s9 code.py "$H2"
FM_HOME="$H2" FM_STATE_OVERRIDE="$H2/state" "$MERGE" s9; echo "exit=$?"; show

say "S10 configured project whose checker was removed from base: refused (missing checker)"
H3="$LAB/home3"; mkdir -p "$H3"; mkproj "$H3" projects/notes no; mkdir -p "$H3/config"; cfg "$H3"; branch s10 note.md "$H3"
FM_HOME="$H3" FM_STATE_OVERRIDE="$H3/state" "$MERGE" s10; echo "exit=$?"; show

rm -rf "$LAB"
echo; echo "lab removed: $([ -e "$LAB" ] && echo no || echo yes)"
