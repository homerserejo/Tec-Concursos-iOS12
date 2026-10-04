#!/usr/bin/env bash
# Envia ao iPad pelo USB.
#   .deb (padrão, gerado na hora): vai para Media/Downloads; instalar pelo Filza.
#   .ipa: instalado direto pelo installd (o AppSync Unified aceita a assinatura do ldid).
# Uso: tools/install.sh [arquivo.deb|arquivo.ipa]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pkg="${1:-$("$root/tools/build-deb.sh")}"

case "$pkg" in
  *.ipa)
    pymobiledevice3 apps install "$pkg"
    echo "instalado: $(basename "$pkg")"
    ;;
  *)
    pymobiledevice3 afc push "$pkg" "Downloads/$(basename "$pkg")"
    echo "enviado: /var/mobile/Media/Downloads/$(basename "$pkg")"
    ;;
esac
