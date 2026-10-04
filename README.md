# TecDuck

**English** · [Português](README.pt-BR.md)

Makes [Tec Concursos](https://www.tecconcursos.com.br) usable on a jailbroken iPad stuck on iOS 12
(tested on an iPad mini 2, A7, 1 GB RAM, iOS 12.5.8, Amethyst jailbreak). It ships two things that
share the same JavaScript fixes:

- **TecDuck** (`com.romerson.tecduck`): a single-purpose WebKit app built on Linux with Theos.
- **TecDuck for Safari** (`com.romerson.tecfixes`): the same fixes in Safari through the Polyfills
  tweak.

## Install

In Cydia, Sileo or Zebra, add these two sources, then install **TecDuck**:

1. `https://poomsmart.github.io/repo/` (Polyfills, a dependency the package manager installs for you);
2. `https://homerserejo.github.io/TecDuck/`, or open that address on the iPad for one-tap buttons.

Each [release](https://github.com/homerserejo/TecDuck/releases) also carries the `.deb` files and a
`TecDuck_<version>.ipa` for AppSync Unified. The `.deb` and the `.ipa` share the bundle ID: delete
one before installing the other.

## What it fixes

| Problem on iOS 12 | Fix |
|---|---|
| Folders and notebooks open blank: `postMessage` without `targetOrigin` throws and aborts AngularJS | Polyfill that defaults the origin to `"/"` (same origin, as in the spec) and accepts `{ targetOrigin, transfer }`; also proposed to Polyfills ([#29](https://github.com/PoomSmart/Polyfills/pull/29)) |
| Lesson text overlaps with the site's text zoom (line height fixed in `rem`) | Unitless line heights that follow the font size |
| Each video lesson embeds the YouTube player (~18 MB of JS) | Card that opens the video in Opaline (`ytlite://`) |
| Cookie banner on every page | Answered automatically with "essential only", without a reload |
| "Random unsolved question" is a 40 px button at the bottom of each question (app only) | **Aleatória** button in the app's bottom bar |
| Small text and buttons, no page zoom on iOS 12 (app only) | 130% page zoom through the viewport, like Ctrl + "+" |
| Trackers and unused third-party requests (app only) | `WKContentRuleList` allowlist |

## Requirements

**iPad**: jailbroken iOS 12 with [Polyfills](https://poomsmart.github.io/repo/depictions/polyfills.html);
Filza to install a `.deb` from Downloads, or [AppSync Unified](https://github.com/akemin-dayo/AppSync)
for the `.ipa`; Opaline (optional) for the lessons' videos.

**Linux computer** (x86_64): `git`, `curl`, `make`, `python3`, `dpkg-deb`, `zip`; `node` is optional
(syntax check of the scripts). No `sudo` needed. Connect the iPad by USB and tap "Trust".

## Building from source

### 1. Clone and prepare the USB tools

```bash
git clone https://github.com/homerserejo/TecDuck.git
cd TecDuck
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
source .venv/bin/activate   # puts pymobiledevice3 on PATH
```

### 2. Install Theos, the Linux iOS toolchain and the SDK

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/toolchain
curl -L https://github.com/L1ghtmann/llvm-project/releases/download/test-210562a/iOSToolchain-x86_64.tar.xz \
  | tar -xJ -C $THEOS/toolchain
$THEOS/bin/install-sdk iPhoneOS12.4
```

The iOS 12.4 SDK is the last one of the 12 series (12.5.x shipped no SDK), so the build can't use
iOS 13+ APIs by mistake. Add `export THEOS=~/theos` to your shell profile.

### 3. Build and install TecDuck

```bash
tools/build-app-deb.sh    # -> packages/com.romerson.tecduck_<version>_iphoneos-arm.deb
tools/build-ipa.sh        # -> packages/TecDuck_<version>.ipa
tools/install.sh packages/com.romerson.tecduck_*.deb   # copies to Downloads; install with Filza
tools/install.sh packages/TecDuck_*.ipa                # or: installs over USB through AppSync
```

Open **TecDuck** on the iPad and log in. Tec and reCAPTCHA pages stay in the app, YouTube links go to
Opaline and everything else opens in Safari.

### 4. (Optional) Safari package

```bash
tools/install.sh    # builds the .deb and copies it to /var/mobile/Media/Downloads
```

On the iPad, open the `.deb` in Filza and install it. Safari is closed so the scripts load.

### 5. Recommended tweak setup

Tweaks are injected into the web content process of every app. In Choicy → Daemons →
`com.apple.WebKit.WebContent`, keeping only **Polyfills** enabled saves memory and avoids side
effects; `tlsfix` does nothing there (TLS runs in `com.apple.WebKit.Networking`).

## Releasing

The version lives in [VERSION](VERSION); the build scripts write it into both packages and the app.

```bash
echo 1.0.1 > VERSION
git commit -am "..." && git tag v1.0.1 && git push && git push --tags
```

The [Release workflow](.github/workflows/release.yml) builds on Ubuntu with the same Theos commit,
toolchain and SDK, attaches the `.deb` and `.ipa` files to the GitHub Release and publishes the APT
repository (`tools/build-repo.py`) to GitHub Pages. It fails if the tag doesn't match `VERSION`.
Once per repository: Settings → Pages → Source: **GitHub Actions**. Running the workflow by hand
only builds and keeps the packages as an artifact.

## Customizing

- **Zoom**: `kPageZoom` in [app/TWViewController.m](app/TWViewController.m).
- **Allowed hosts**: [app/Resources/content-rules.json](app/Resources/content-rules.json). A blocked
  resource shows up in the console as "Content blocker prevented…".
- **Icon**: replace [app/icon.png](app/icon.png) and run `tools/make-icons.py`.
- **New site fixes**: add a script to `polyfills/scripts-post/base/` (or a version folder such as
  `scripts/13.4/`, applied when iOS is older than it). Both the app and the `.deb` pick it up.

## Debugging

`tools/capture.py` attaches to the Web Inspector over USB, reloads the page and prints console
messages, failed requests and an AngularJS diagnosis:

```bash
python tools/capture.py                       # Safari tab on tecconcursos.com.br
python tools/capture.py --match 'TecDuck('    # the app
python tools/capture.py --no-reload --eval 'document.title'
```

Crash reports: `pymobiledevice3 crash ls` and `pymobiledevice3 crash pull <dir> --match WebContent`.
The design decisions and investigation notes are in [docs/PLANO.md](docs/PLANO.md) (Portuguese).

## Projects used

- [Theos](https://github.com/theos/theos) and [theos/sdks](https://github.com/theos/sdks): build system and iOS SDKs.
- [L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project): iOS toolchain for Linux (clang, ld64, ldid).
- [pymobiledevice3](https://github.com/doronz88/pymobiledevice3): USB install, file transfer, Web Inspector and crash reports.
- [Polyfills](https://poomsmart.github.io/repo/depictions/polyfills.html) by PoomSmart: script injection into Safari; its loading rules are mirrored by the app.
- [AppSync Unified](https://github.com/akemin-dayo/AppSync): installing fakesigned apps.
- [Choicy](https://github.com/opa334/Choicy): per-process tweak control.
- Opaline: lightweight YouTube client for old iOS.

## Notes

Not affiliated with Tec Concursos. Psyduck is © Nintendo / Creatures / GAME FREAK / The Pokémon
Company; the icon is for personal use. Licensed under the [GPL-2.0](LICENSE).
