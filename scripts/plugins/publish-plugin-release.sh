#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  publish-plugin-release.sh --repo owner/repo --tag plugins-2026.05.17 --asset Demo.mactoolsplugin.zip [--asset More.mactoolsplugin.zip]

Requires GitHub CLI authenticated with release upload permissions.
USAGE
}

REPO=""
TAG=""
TITLE=""
NOTES_FILE=""
PRERELEASE=0
ASSETS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)
            REPO="${2:-}"
            shift 2
            ;;
        --tag)
            TAG="${2:-}"
            shift 2
            ;;
        --title)
            TITLE="${2:-}"
            shift 2
            ;;
        --notes-file)
            NOTES_FILE="${2:-}"
            shift 2
            ;;
        --prerelease)
            PRERELEASE=1
            shift
            ;;
        --asset)
            ASSETS+=("${2:-}")
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

if [[ -z "$REPO" || -z "$TAG" || ${#ASSETS[@]} -eq 0 ]]; then
    usage >&2
    exit 1
fi

command -v gh >/dev/null || { echo "GitHub CLI 'gh' is required." >&2; exit 1; }

for asset in "${ASSETS[@]}"; do
    [[ -f "$asset" ]] || { echo "Release asset not found: $asset" >&2; exit 1; }
done

TITLE="${TITLE:-$TAG}"

release_args=(--repo "$REPO" --title "$TITLE")
if [[ -n "$NOTES_FILE" ]]; then
    [[ -f "$NOTES_FILE" ]] || { echo "Release notes file not found: $NOTES_FILE" >&2; exit 1; }
    release_args+=(--notes-file "$NOTES_FILE")
else
    release_args+=(--notes "")
fi
if [[ "$PRERELEASE" == "1" ]]; then
    release_args+=(--prerelease)
fi

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
    gh release edit "$TAG" "${release_args[@]}"
else
    gh release create "$TAG" "${ASSETS[@]}" "${release_args[@]}"
fi
