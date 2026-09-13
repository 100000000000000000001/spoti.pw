#!/usr/bin/env bash
# Cuts a release in two steps. No IPA is hosted anywhere: people fork the repo and build their own,
# so a release is only the version bump and the line the site and the Updates row show.
#
#   make publish VERSION=0.15.0 NOTES="..."   bump control, write the site's content/release.json with
#                                             the Spotify version read off ipa/. Nothing is committed.
#   make push                                 commit and push both repos; Coolify rebuilds spoti.pw.
#
# WEB points at the site checkout, default ../custom_spotify_web.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="${WEB:-$ROOT/../custom_spotify_web}"
RELEASE="$WEB/content/release.json"
CONTROL="$ROOT/tweak/control"

die() { echo "$*" >&2; exit 1; }
control_version() { sed -n 's/^Version: //p' "$CONTROL"; }
release_field() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$RELEASE" "$1"; }

stage() {
  local ipa="$1" version="$2" notes="$3"
  [ -f "$ipa" ] || die "no IPA: put the decrypted Spotify .ipa you tested on in ipa/, or pass one (make publish IPA=path.ipa ...)"
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "VERSION must look like 0.15.0, got '${version:-nothing}'"
  [ -n "$notes" ] || die "NOTES is empty: say what changed, it is the changelog on the site and in the app"
  [ -d "$WEB/content" ] || die "no site checkout at $WEB (set WEB=...)"
  [ "$version" = "$(control_version)" ] && echo "note: control already says $version" >&2

  sed -i '' "s/^Version: .*/Version: $version/" "$CONTROL"

  local app_dir plist spotify
  app_dir="$(unzip -Z1 "$ipa" | grep -oE '^Payload/[^/]+\.app/' | sort -u | head -1)"
  plist="$(mktemp)"
  unzip -p "$ipa" "${app_dir}Info.plist" > "$plist"
  spotify="$(plutil -extract CFBundleShortVersionString raw -o - "$plist")"
  rm -f "$plist"

  python3 - "$RELEASE" "$version" "$spotify" "$notes" <<'PY'
import json, sys
from datetime import date
path, mod, spotify, notes = sys.argv[1:]
json.dump({"mod": mod, "version": spotify, "date": date.today().isoformat(), "notes": notes}, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY

  echo "==> staged $version on Spotify $spotify in $RELEASE, then: make push"
}

commit_if_changed() {
  local repo="$1" file="$2" mod="$3"
  [ -n "$(git -C "$repo" status --porcelain -- "$file")" ] || return 0
  git -C "$repo" add "$file"
  git -C "$repo" commit -m "release: $mod"
}

push() {
  local mod
  mod="$(release_field mod)"
  [ "$mod" = "$(control_version)" ] || die "release.json says $mod but control says $(control_version); run make publish"
  # Either file may already be committed by hand; then only the push is left.
  commit_if_changed "$WEB" content/release.json "$mod"
  git -C "$WEB" push
  commit_if_changed "$ROOT" tweak/control "$mod"
  git -C "$ROOT" push
  echo "==> $mod is live once Coolify finishes"
}

case "${1:-}" in
  stage) stage "$2" "$3" "$4" ;;
  push) push ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
