#!/usr/bin/env python3
"""Monta o repositório APT (Cydia, Sileo, Zebra) em <saída> a partir dos .deb de packages/.

Gera Packages (texto, gz, bz2, xz), Release com hashes, CydiaIcon.png, as páginas de descrição
(packaging/repo/depictions) e a página inicial. É o conteúdo publicado no GitHub Pages.

Uso: tools/build-repo.py <saída>     (REPO_URL ajusta o endereço público do repositório)
"""

import bz2
import gzip
import hashlib
import lzma
import os
import shutil
import subprocess
import sys
from email.utils import formatdate
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
REPO_URL = os.environ.get("REPO_URL", "https://homerserejo.github.io/tecduck/")
VERSION = (ROOT / "VERSION").read_text().strip()


def control(deb: Path) -> str:
    return subprocess.run(["dpkg-deb", "-f", str(deb)], check=True, capture_output=True, text=True).stdout.strip()


def digests(data: bytes) -> dict[str, str]:
    return {name: hashlib.new(name, data).hexdigest() for name in ("md5", "sha1", "sha256")}


def main(out: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    (out / "debs").mkdir(parents=True)

    entries = []
    for deb in sorted((ROOT / "packages").glob("*.deb")):
        shutil.copy2(deb, out / "debs" / deb.name)
        data = deb.read_bytes()
        h = digests(data)
        entries.append(
            f"{control(deb)}\n"
            f"Filename: ./debs/{deb.name}\n"
            f"Size: {len(data)}\n"
            f"MD5sum: {h['md5']}\nSHA1: {h['sha1']}\nSHA256: {h['sha256']}\n"
        )
    if not entries:
        sys.exit("nenhum .deb em packages/; rode build-deb.sh e build-app-deb.sh antes")

    packages = ("\n".join(entries)).encode()
    indexes = {
        "Packages": packages,
        "Packages.gz": gzip.compress(packages, mtime=0),
        "Packages.bz2": bz2.compress(packages),
        "Packages.xz": lzma.compress(packages),
    }
    for name, data in indexes.items():
        (out / name).write_bytes(data)

    release = [
        "Origin: TecDuck",
        "Label: TecDuck",
        "Suite: stable",
        f"Version: {VERSION}",
        "Codename: ios",
        f"Date: {formatdate(usegmt=True)}",
        "Architectures: iphoneos-arm",
        "Components: main",
        "Description: TecDuck, o Tec Concursos leve para o iOS 12",
    ]
    for field, algo in (("MD5Sum", "md5"), ("SHA1", "sha1"), ("SHA256", "sha256")):
        release.append(f"{field}:")
        release += [f" {digests(d)[algo]} {len(d)} {n}" for n, d in indexes.items()]
    (out / "Release").write_text("\n".join(release) + "\n")

    Image.open(ROOT / "app" / "icon.png").convert("RGB").resize((120, 120), Image.LANCZOS).save(out / "CydiaIcon.png")

    site = ROOT / "packaging" / "repo"
    for page in site.rglob("*.html"):
        target = out / page.relative_to(site)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(page.read_text().replace("@VERSION@", VERSION).replace("@REPO_URL@", REPO_URL))

    print(f"{len(entries)} pacotes em {out}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]).resolve())
