#!/usr/bin/env bash
# Compila app/ com o Theos e monta o TecDuck.app em <destino>: scripts de polyfills/ dentro do
# bundle, versão do arquivo VERSION no Info.plist e assinatura falsa do ldid.
# Uso: tools/stage-app.sh <destino>   (usado por build-ipa.sh e build-app-deb.sh)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dest="$1"
export THEOS="${THEOS:-$HOME/theos}"
version="$(cat "$root/VERSION")"

make -C "$root/app" FINALPACKAGE=1 >/dev/null

mkdir -p "$dest"
app="$dest/TecDuck.app"
rm -rf "$app"
cp -R "$root/app/.theos/obj/TecDuck.app" "$app"

mkdir -p "$app/polyfills"
cp -R "$root/polyfills/." "$app/polyfills/"
find "$app/polyfills" -type f ! -name '*.js' -delete
if command -v node >/dev/null; then
  find "$app/polyfills" -name '*.js' -print0 | while IFS= read -r -d '' js; do node --check "$js" || exit 1; done
fi
python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$app/content-rules.json"

python3 - "$app/Info.plist" "$version" <<'PY'
import plistlib, sys
path, version = sys.argv[1], sys.argv[2]
with open(path, "rb") as f:
    info = plistlib.load(f)
info["CFBundleShortVersionString"] = version
info["CFBundleVersion"] = version
with open(path, "wb") as f:
    plistlib.dump(info, f, fmt=plistlib.FMT_BINARY)
PY

"$THEOS/toolchain/linux/iphone/bin/ldid" -S"$root/app/entitlements.plist" "$app/TecDuck"
