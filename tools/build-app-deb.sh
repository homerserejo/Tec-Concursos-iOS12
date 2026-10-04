#!/usr/bin/env bash
# Gera o .deb do TecDuck, que instala o app em /Applications (lojas de tweaks, sem AppSync).
# Uso: tools/build-app-deb.sh  ->  packages/com.romerson.tecduck_<versão>_iphoneos-arm.deb
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

"$root/tools/stage-app.sh" "$stage/Applications"
"$root/tools/deb-control.sh" tecduck "$stage/DEBIAN"

# A partição de origem marca tudo como executável; só o binário do app deve ser.
find "$stage" -type d -exec chmod 0755 {} +
find "$stage/Applications" -type f -exec chmod 0644 {} +
chmod 0755 "$stage/Applications/TecDuck.app/TecDuck"
mkdir -p "$root/packages"
out="$root/packages/com.romerson.tecduck_$(cat "$root/VERSION")_iphoneos-arm.deb"
# gzip: o dpkg dos jailbreaks do iOS 12 não abre zstd.
dpkg-deb -Zgzip --root-owner-group --build "$stage" "$out" >/dev/null
echo "$out"
