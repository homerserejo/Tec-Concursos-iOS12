#!/usr/bin/env bash
# Empacota polyfills/ como o .deb "TecDuck for Safari", que instala os scripts em
# /Library/Application Support/Polyfills (pacote com.ps.polyfills).
# Uso: tools/build-deb.sh  ->  packages/com.romerson.tecfixes_<versão>_iphoneos-arm.deb
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

dest="$stage/Library/Application Support/Polyfills"
mkdir -p "$dest" "$stage/DEBIAN"
cp -R "$root/polyfills/." "$dest/"
find "$dest" -type f ! -name '*.js' -delete

# Um erro de sintaxe num script derruba os demais do mesmo bloco injetado.
if command -v node >/dev/null; then
  find "$dest" -name '*.js' -print0 | while IFS= read -r -d '' js; do node --check "$js" || exit 1; done
fi

"$root/tools/deb-control.sh" tecfixes "$stage/DEBIAN"
find "$stage" -type d -exec chmod 0755 {} +
find "$dest" -type f -exec chmod 0644 {} +

version="$(cat "$root/VERSION")"
mkdir -p "$root/packages"
out="$root/packages/com.romerson.tecfixes_${version}_iphoneos-arm.deb"
# gzip: o dpkg dos jailbreaks do iOS 12 não abre zstd.
dpkg-deb -Zgzip --root-owner-group --build "$stage" "$out" >/dev/null
echo "$out"
