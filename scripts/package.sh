#!/usr/bin/env bash

# set -o xtrace
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD_DIR="$ROOT/build"

VERSION="${1:-}"
PUBLISH=0
[ "${2:-}" = "--publish" ] && PUBLISH=1

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/package.sh <x.y.z> [--publish]" >&2
  exit 1
fi

APP_NAME="Dif"
TAG="v$VERSION"
APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"
TAP_REPO="dotzero/homebrew-tap"

[ -d "$APP" ] || { echo "expected app not found: $APP" >&2; exit 1; }

rm -rf "$DMG_STAGING"; mkdir -p "$DMG_STAGING"
cp -R "$APP" "$DMG_STAGING/"

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 480 560 \
  --icon "$APP_NAME.app" 240 130 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 240 380 \
		"$DMG" \
		"$DMG_STAGING"

rm -rf "$DMG_STAGING"
echo "==> built: $DMG"

if [ "$PUBLISH" != "1" ]; then
  echo "==> dry run complete (pass --publish to upload + bump the cask)"
  exit 0
fi

echo "==> publishing $TAG"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release edit "$TAG" --title "Version $VERSION" --notes-file "$ROOT/packaging/notes.md"
else
  gh release create "$TAG" --title "Version $VERSION" --notes-file "$ROOT/packaging/notes.md"
fi
gh release upload "$TAG" "$DMG" --clobber

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
TAP_DIR="$(mktemp -d)"
gh repo clone "$TAP_REPO" "$TAP_DIR" -- --depth=1 >/dev/null
CASK="$TAP_DIR/Casks/dif.rb"
mkdir -p "$TAP_DIR/Casks"
cp -f "$ROOT/packaging/dif.rb" "$CASK"
sed -i '' -E "s/^( *version )\".*\"/\1\"$VERSION\"/" "$CASK"
sed -i '' -E "s/^( *sha256 )\".*\"/\1\"$SHA\"/" "$CASK"

git profile -C "$TAP_DIR" use home
git -C "$TAP_DIR" add Casks/dif.rb
if git -C "$TAP_DIR" diff --cached --quiet; then
  echo "==> cask unchanged, nothing to push"
else
  git -C "$TAP_DIR" commit -m "$APP_NAME $VERSION"
  git -C "$TAP_DIR" push
  echo "==> cask bumped to $VERSION"
fi
rm -rf "$TAP_DIR"
echo "==> done"
