#!/usr/bin/env bash
# Gera o .deb e o envia pelo USB (AFC) para Media/Downloads do iPad.
# No iPad: Filza > /var/mobile/Media/Downloads > tocar no .deb > Instalar.
# Uso: tools/install.sh [arquivo.deb]
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
deb="${1:-$("$root/tools/build-deb.sh")}"

pymobiledevice3 afc push "$deb" "Downloads/$(basename "$deb")"
echo "enviado: /var/mobile/Media/Downloads/$(basename "$deb")"
