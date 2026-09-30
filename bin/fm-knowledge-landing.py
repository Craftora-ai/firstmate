#!/usr/bin/env python3
"""Knowledge-check protocol for fm-merge-local.sh's protected vault landing.

Usage: python3 fm-knowledge-landing.py <project> <base-oid> <head-oid> <approval>
The caller pins both commits, checks ancestry and cleanliness, and merges only
head-oid after success. This helper never merges or grants merge authority.
It runs the current clean checkout's
06 AI Team/AI Team Knowledge/Scripts/check-knowledge-landing.py with
<base-oid> <head-oid> --root <project>, with a 90-second deadline.

A complete verdict must name the requested base, head and merge-base (base,
because this entrypoint only fast-forwards). Exit 0 plus a recognized final OK
line and no FAIL/ERROR lines passes. Exit 2 plus FAIL lines and a final REFUSED
line requires a regular, non-symlink approval file whose first line is exactly
head-oid. This is the existing ticket-21 approval record, written only after
explicit approval of that commit. A missing checker, timeout, unexpected exit,
ERROR, incomplete or mismatched verdict always refuses, even with approval.
The checker owns note/WiP content policy; this helper owns only this protocol.
No shell command text or harness hook participates in the landing decision.
Exit 0 permits the caller to continue; exit 1 refuses.
"""

import os
from pathlib import Path
import re
import stat
import subprocess
import sys


GATE = "06 AI Team/AI Team Knowledge/Scripts/check-knowledge-landing.py"
OID = r"(?:[0-9a-f]{40}|[0-9a-f]{64})"
HEADER = re.compile(
    r"check-knowledge-landing: base (" + OID + r") head (" + OID
    + r") merge-base (" + OID + r"); \d+ change\(s\); \d+ migration target\(s\) in \d+ slice\(s\)"
)
OK = (
    "OK knowledge-note additions only (PRD K22): ",
    "OK new dated WiP folders only (B1:A, 2026-09-29): ",
)


def approved(path, head):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            return (stat.S_ISREG(os.fstat(fd).st_mode)
                    and os.read(fd, 1024).split(b"\n", 1)[0] == head.encode("ascii"))
        finally:
            os.close(fd)
    except OSError:
        return False


def main(args):
    if len(args) != 4 or any(re.fullmatch(OID, oid) is None for oid in args[1:3]):
        raise ValueError("expected project, full base/head commit IDs and approval path")
    project, base, head, approval = args
    gate = Path(project) / GATE
    if not gate.is_file() or gate.is_symlink():
        raise ValueError("knowledge checker is missing or is not a regular file")
    result = subprocess.run(
        [sys.executable, "-B", str(gate), base, head, "--root", project],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=90,
    )
    output = result.stdout.decode("utf-8", "strict")
    lines = output.splitlines()
    header = HEADER.fullmatch(lines[0]) if lines else None
    if (header is None or header.groups() != (base, head, base)
            or any(line.startswith("ERROR") for line in lines)):
        raise ValueError("knowledge checker returned an incomplete, failed or mismatched verdict")
    failures = [line for line in lines if line.startswith("FAIL ")]
    if result.returncode == 0 and lines[-1].startswith(OK) and not failures:
        print(output, end="")
        return 0
    if result.returncode == 2 and failures and lines[-1].startswith("REFUSED "):
        print(output, end="")
        if approved(approval, head):
            print("knowledge landing: explicit approval matches " + head)
            return 0
        raise ValueError("knowledge landing requires explicit approval of " + head + " in " + approval)
    raise ValueError("knowledge checker did not return a complete pass or policy refusal")


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("error: local merge refused: " + str(error), file=sys.stderr)
        sys.exit(1)
