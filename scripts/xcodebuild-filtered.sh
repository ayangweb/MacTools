#!/usr/bin/env bash
set -o pipefail

tmp_stderr="$(mktemp "${TMPDIR:-/tmp}/mactools-xcodebuild-stderr.XXXXXX")"
trap 'rm -f "$tmp_stderr"' EXIT

xcodebuild "$@" 2> "$tmp_stderr"
status=$?

python3 - "$tmp_stderr" <<'PY'
import re
import sys

path = sys.argv[1]
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except OSError:
    sys.exit(0)

patterns = [
    re.compile(
        r"(?m)^[^\n]*DVTErrorPresenter: Unable to load simulator devices\.\n"
        r"Domain: DVTCoreSimulatorAdditionsErrorDomain\n"
        r"Code: 3\n"
        r"Failure Reason: The version of the CoreSimulator framework installed on this Mac is out-of-date[^\n]*\n"
        r"(?:Recovery Suggestion: [^\n]*\n)?"
        r"--\n"
        r"CoreSimulator is out of date\. Current version [^\n]*\n"
        r"Domain: DVTCoreSimulatorAdditionsErrorDomain\n"
        r"Code: 3\n"
        r"--\n\n?"
    ),
    re.compile(
        r"(?m)^.*iOSSimulator: \[SimServiceContext sharedServiceContextForDeveloperDir:error:\] "
        r"returned nil \(Error Domain=DVTCoreSimulatorAdditionsErrorDomain Code=3 "
        r"\"CoreSimulator is out of date\..*?Simulator device support disabled\.\n?"
    ),
]

filtered = text
for pattern in patterns:
    filtered = pattern.sub("", filtered)

if filtered != text:
    open(path, "w", encoding="utf-8").write(filtered)
PY

cat "$tmp_stderr" >&2
exit "$status"
