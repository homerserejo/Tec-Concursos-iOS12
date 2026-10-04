#!/usr/bin/env python3
"""Gera os ícones do app (PNG RGB, sem alfa) a partir de app/icon.png para app/Resources/."""
from pathlib import Path

from PIL import Image

app = Path(__file__).resolve().parent.parent / "app"
# nome do arquivo -> lado em pixels (Info.plist cita os nomes sem o sufixo @Nx)
SIZES = {
    "Icon-29@2x.png": 58,
    "Icon-40@2x.png": 80,
    "Icon-60@2x.png": 120,
    "Icon-60@3x.png": 180,
    "Icon-76.png": 76,
    "Icon-76@2x.png": 152,
    "Icon-83.5@2x.png": 167,
}

source = Image.open(app / "icon.png").convert("RGB")
for name, side in SIZES.items():
    source.resize((side, side), Image.LANCZOS).save(app / "Resources" / name)
print(f"{len(SIZES)} ícones em {app / 'Resources'}")
