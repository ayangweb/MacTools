#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  sign-plugin-package.sh --package Demo.mactoolsplugin --identity "Developer ID Application: ..." [--keychain build.keychain-db]

Signs the bundle declared by plugin.json.bundleRelativePath. Debug builds may use
an Apple Development identity; release packages should use Developer ID.
USAGE
}

PACKAGE=""
IDENTITY="${CODE_SIGN_IDENTITY:-}"
KEYCHAIN="${CODE_SIGN_KEYCHAIN:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --package)
            PACKAGE="${2:-}"
            shift 2
            ;;
        --identity)
            IDENTITY="${2:-}"
            shift 2
            ;;
        --keychain)
            KEYCHAIN="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$PACKAGE" || -z "$IDENTITY" ]]; then
    usage >&2
    exit 1
fi

BUNDLE_RELATIVE_PATH="$(python3 - "$PACKAGE/plugin.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1]))["bundleRelativePath"])
PY
)"
BUNDLE_PATH="$PACKAGE/$BUNDLE_RELATIVE_PATH"
[[ -d "$BUNDLE_PATH" ]] || { echo "Bundle not found: $BUNDLE_PATH" >&2; exit 1; }

sign_args=(--force --options runtime --timestamp --sign "$IDENTITY")
if [[ -n "$KEYCHAIN" ]]; then
    sign_args+=(--keychain "$KEYCHAIN")
fi

codesign "${sign_args[@]}" "$BUNDLE_PATH"
codesign --verify --strict --deep "$BUNDLE_PATH"
