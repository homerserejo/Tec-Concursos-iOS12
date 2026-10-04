# TecDuck

[English](README.md) · **Português**

Deixa o [Tec Concursos](https://www.tecconcursos.com.br) usável num iPad com jailbreak preso no iOS 12
(testado num iPad mini 2, A7, 1 GB de RAM, iOS 12.5.8, jailbreak Amethyst). São duas entregas que
compartilham as mesmas correções em JavaScript:

- **TecDuck** (`com.romerson.tecduck`): um app WebKit de propósito único, compilado no Linux com o Theos.
- **TecDuck para Safari** (`com.romerson.tecfixes`): as mesmas correções no Safari, pelo tweak
  Polyfills.

## Instalar

No Cydia, no Sileo ou no Zebra, adicione estas duas fontes e instale o **TecDuck**:

1. `https://poomsmart.github.io/repo/` (Polyfills, uma dependência que a loja instala junto);
2. `https://homerserejo.github.io/TecDuck/`, ou abra esse endereço no iPad para usar os botões.

Cada [release](https://github.com/homerserejo/TecDuck/releases) também traz os `.deb` e um
`TecDuck_<versão>.ipa` para o AppSync Unified. O `.deb` e o `.ipa` usam o mesmo identificador:
apague um antes de instalar o outro.

## O que corrige

| Problema no iOS 12 | Correção |
|---|---|
| Pastas e cadernos abrem em branco: `postMessage` sem `targetOrigin` lança erro e aborta o AngularJS | Polyfill que assume `"/"` como origem (mesma origem, como na especificação) e aceita `{ targetOrigin, transfer }`; também proposto ao Polyfills ([#29](https://github.com/PoomSmart/Polyfills/pull/29)) |
| Texto das aulas se sobrepõe com o zoom de texto do site (altura da linha fixa em `rem`) | Alturas de linha sem unidade, que acompanham a fonte |
| Cada videoaula embute o player do YouTube (~18 MB de JS) | Cartão que abre o vídeo no Opaline (`ytlite://`) |
| Banner de cookies em toda página | Respondido sozinho com "Somente essenciais", sem recarregar |
| "Questão aleatória não resolvida" é um botão de 40 px no fim de cada questão (só no app) | Botão **Aleatória** na barra inferior do app |
| Texto e botões pequenos, sem zoom de página no iOS 12 (só no app) | Zoom de 130% pela viewport, como o Ctrl + "+" |
| Rastreadores e requisições de terceiros sem uso (só no app) | Allowlist com `WKContentRuleList` |

## Requisitos

**iPad**: iOS 12 com jailbreak e o [Polyfills](https://poomsmart.github.io/repo/depictions/polyfills.html);
o Filza para instalar um `.deb` a partir de Downloads, ou o [AppSync Unified](https://github.com/akemin-dayo/AppSync)
para o `.ipa`; o Opaline (opcional) para os vídeos das aulas.

**Computador Linux** (x86_64): `git`, `curl`, `make`, `python3`, `dpkg-deb`, `zip`; `node` é opcional
(confere a sintaxe dos scripts). Não precisa de `sudo`. Ligue o iPad pelo USB e toque em "Confiar".

## Compilar do código-fonte

### 1. Clonar e preparar as ferramentas de USB

```bash
git clone https://github.com/homerserejo/TecDuck.git
cd TecDuck
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
source .venv/bin/activate   # coloca o pymobiledevice3 no PATH
```

### 2. Instalar o Theos, a toolchain iOS para Linux e o SDK

```bash
export THEOS=~/theos
git clone --recursive https://github.com/theos/theos.git $THEOS
mkdir -p $THEOS/toolchain
curl -L https://github.com/L1ghtmann/llvm-project/releases/download/test-210562a/iOSToolchain-x86_64.tar.xz \
  | tar -xJ -C $THEOS/toolchain
$THEOS/bin/install-sdk iPhoneOS12.4
```

O SDK do iOS 12.4 é o último da série 12 (o 12.5.x não teve SDK), então a compilação não consegue
usar por engano APIs do iOS 13+. Acrescente `export THEOS=~/theos` ao perfil do seu shell.

### 3. Compilar e instalar o TecDuck

```bash
tools/build-app-deb.sh    # -> packages/com.romerson.tecduck_<versão>_iphoneos-arm.deb
tools/build-ipa.sh        # -> packages/TecDuck_<versão>.ipa
tools/install.sh packages/com.romerson.tecduck_*.deb   # copia para Downloads; instale pelo Filza
tools/install.sh packages/TecDuck_*.ipa                # ou: instala pelo USB, via AppSync
```

Abra o **TecDuck** no iPad e faça login. Páginas do Tec e do reCAPTCHA ficam no app, links do
YouTube vão para o Opaline e o resto abre no Safari.

### 4. (Opcional) Pacote do Safari

```bash
tools/install.sh    # gera o .deb e o copia para /var/mobile/Media/Downloads
```

No iPad, abra o `.deb` no Filza e instale. O Safari é fechado para os scripts carregarem.

### 5. Configuração recomendada dos tweaks

Os tweaks são injetados no processo de conteúdo web de todos os apps. Em Choicy → Daemons →
`com.apple.WebKit.WebContent`, deixar só o **Polyfills** ligado economiza memória e evita efeitos
colaterais; o `tlsfix` não faz nada ali (o TLS roda no `com.apple.WebKit.Networking`).

## Publicar uma versão

A versão fica em [VERSION](VERSION); os scripts de build a gravam nos dois pacotes e no app.

```bash
echo 1.0.1 > VERSION
git commit -am "..." && git tag v1.0.1 && git push && git push --tags
```

O [workflow de release](.github/workflows/release.yml) compila no Ubuntu com o mesmo commit do Theos,
a mesma toolchain e o mesmo SDK, anexa os `.deb` e o `.ipa` à Release do GitHub e publica o
repositório APT (`tools/build-repo.py`) no GitHub Pages. Ele falha se a tag não bater com o
`VERSION`. Uma vez por repositório: Settings → Pages → Source: **GitHub Actions**. Rodar o workflow
à mão só compila e guarda os pacotes como artefato.

## Personalizar

- **Zoom**: `kPageZoom` em [app/TWViewController.m](app/TWViewController.m).
- **Hosts liberados**: [app/Resources/content-rules.json](app/Resources/content-rules.json). Um
  recurso bloqueado aparece no console como "Content blocker prevented…".
- **Ícone**: troque [app/icon.png](app/icon.png) e rode `tools/make-icons.py`.
- **Novas correções do site**: adicione um script em `polyfills/scripts-post/base/` (ou numa pasta de
  versão como `scripts/13.4/`, aplicada quando o iOS é mais antigo que ela). O app e o `.deb` o
  incluem.

## Diagnóstico

`tools/capture.py` se conecta ao Web Inspector pelo USB, recarrega a página e mostra as mensagens do
console, as requisições que falharam e um diagnóstico do AngularJS:

```bash
python tools/capture.py                       # aba do Safari em tecconcursos.com.br
python tools/capture.py --match 'TecDuck('    # o app
python tools/capture.py --no-reload --eval 'document.title'
```

Relatórios de crash: `pymobiledevice3 crash ls` e `pymobiledevice3 crash pull <pasta> --match WebContent`.
As decisões de projeto e as investigações estão em [docs/PLANO.md](docs/PLANO.md).

## Projetos usados

- [Theos](https://github.com/theos/theos) e [theos/sdks](https://github.com/theos/sdks): sistema de build e SDKs do iOS.
- [L1ghtmann/llvm-project](https://github.com/L1ghtmann/llvm-project): toolchain iOS para Linux (clang, ld64, ldid).
- [pymobiledevice3](https://github.com/doronz88/pymobiledevice3): instalação pelo USB, transferência de arquivos, Web Inspector e relatórios de crash.
- [Polyfills](https://poomsmart.github.io/repo/depictions/polyfills.html), do PoomSmart: injeção de scripts no Safari; o app segue as mesmas regras de carregamento.
- [AppSync Unified](https://github.com/akemin-dayo/AppSync): instalação de apps com assinatura falsa.
- [Choicy](https://github.com/opa334/Choicy): controle de tweaks por processo.
- Opaline: cliente leve de YouTube para iOS antigo.

## Observações

Sem vínculo com o Tec Concursos. Psyduck é © Nintendo / Creatures / GAME FREAK / The Pokémon
Company; o ícone é para uso pessoal. Licença [GPL-2.0](LICENSE).
