#!/usr/bin/env bash
# Compila app/ com o Theos e gera o .ipa com os scripts de polyfills/ dentro do app.
# Instalação: AppSync Unified no iPad (assinatura falsa do ldid, sem Apple ID).
# Uso: tools/build-ipa.sh  ->  packages/TecDuck_<versão>.ipa
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
export THEOS="${THEOS:-$HOME/theos}"

make -C "$root/app" FINALPACKAGE=1 >/dev/null

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload"
cp -R "$root/app/.theos/obj/TecDuck.app" "$stage/Payload/"
app="$stage/Payload/TecDuck.app"

mkdir -p "$app/polyfills"
cp -R "$root/polyfills/." "$app/polyfills/"
find "$app/polyfills" -type f ! -name '*.js' -delete
if command -v node >/dev/null; then
  find "$app/polyfills" -name '*.js' -print0 | while IFS= read -r -d '' js; do node --check "$js" || exit 1; done
fi
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$app/content-rules.json"

"$THEOS/toolchain/linux/iphone/bin/ldid" -S"$root/app/entitlements.plist" "$app/TecDuck"

version="$(plutil -extract CFBundleShortVersionString raw "$app/Info.plist" 2>/dev/null \
  || python3 -c "import plistlib,sys; print(plistlib.load(open(sys.argv[1],'rb'))['CFBundleShortVersionString'])" "$app/Info.plist")"
mkdir -p "$root/packages"
out="$root/packages/TecDuck_${version}.ipa"
rm -f "$out"
(cd "$stage" && zip -qry "$out" Payload)
echo "$out"
