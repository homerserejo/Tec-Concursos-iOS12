#!/usr/bin/env bash
# Gera o .ipa do TecDuck, para instalar com AppSync Unified (sem loja de tweaks).
# Uso: tools/build-ipa.sh  ->  packages/TecDuck_<versão>.ipa
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

"$root/tools/stage-app.sh" "$stage/Payload"

mkdir -p "$root/packages"
out="$root/packages/TecDuck_$(cat "$root/VERSION").ipa"
rm -f "$out"
(cd "$stage" && zip -qry "$out" Payload)
echo "$out"
