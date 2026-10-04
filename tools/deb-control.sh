#!/usr/bin/env bash
# Copia o control e os scripts de packaging/<pacote>/ para <DEBIAN>, com a versão de VERSION e o
# endereço do repositório APT (REPO_URL) preenchidos.
# Uso: tools/deb-control.sh <tecduck|tecfixes> <DEBIAN>
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/packaging/$1"
debian="$2"
repo_url="${REPO_URL:-https://homerserejo.github.io/TecDuck/}"

mkdir -p "$debian"
sed -e "s|@VERSION@|$(cat "$root/VERSION")|g" -e "s|@REPO_URL@|$repo_url|g" "$src/control" > "$debian/control"
for script in preinst postinst prerm postrm; do
  if [ -f "$src/$script" ]; then
    cp "$src/$script" "$debian/$script"
    chmod 0755 "$debian/$script"
  fi
done
