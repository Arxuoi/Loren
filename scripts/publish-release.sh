#!/usr/bin/env bash
# Publish already-tested packages. Authentication is supplied by gh, never stored here.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAG=${1:-v1.0.0}
REPO=${NERO_GITHUB_REPOSITORY:-Arxuoi/Loren}
TARGET=${NERO_RELEASE_TARGET:-main}
ARTIFACTS=$ROOT/artifacts
STABLE=$ARTIFACTS/nero-clang-1.0.0-linux-x86_64.tar.xz
PLUSPLUS=$ARTIFACTS/nero-clang-plusplus-1.0.0-linux-x86_64.tar.xz
SUMS=$ARTIFACTS/SHA256SUMS

command -v gh >/dev/null || { echo "GitHub CLI (gh) is required" >&2; exit 2; }
for file in "$STABLE" "$PLUSPLUS"; do
  [[ -s "$file" ]] || { echo "missing release artifact: $file" >&2; exit 2; }
  xz -t "$file"
done
(cd "$ARTIFACTS" && sha256sum "$(basename "$STABLE")" "$(basename "$PLUSPLUS")" > "$SUMS")

if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" --target "$TARGET" \
    --title "Nero Clang 1.0.0" --notes-file "$ROOT/docs/RELEASE-1.0.0.md"
fi
gh release upload "$TAG" "$STABLE" "$PLUSPLUS" "$SUMS" --repo "$REPO" --clobber
echo "Published https://github.com/$REPO/releases/tag/$TAG"
