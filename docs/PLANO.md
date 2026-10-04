# Tec no iPad Mini 2: plano (WebKit + Polyfills + correções)

## Contexto
O objetivo é usar o Tec Concursos (`https://www.tecconcursos.com.br/questoes/pastas`) de forma estável e
leve num **iPad Mini 2 (A7, 1 GB de RAM, iOS 12.5.8, jailbreak Amethyst)**. O fork do Blinker Fluid
(Chromium) foi deixado de lado: exige um build de 10–20 h numa VM macOS e roda o JS sem JIT. Em 2026-10-03,
a investigação mostrou que **o WebKit do próprio iOS 12 roda o Tec**, desde que dois problemas sejam
tratados:

1. **Travamento no login:** um tweak injetado no processo WebContent (entre `tlsfix`, `libsonar` e
   `base_hook`; **não** o Polyfills) derruba a página com `EXC_BAD_ACCESS`. Contorno atual: Choicy desliga
   esses tweaks no Safari.
2. **Pastas e cadernos vazios:** `caderno.controller.js:115` chama
   `window.parent.postMessage({ type: 'CONTENT_READY' })` sem `targetOrigin`. O WebKit do iOS 12 lança
   `Not enough arguments`, e o controlador AngularJS aborta. Correção: um polyfill que usa `'*'` como
   origem padrão, instalado em `/Library/Application Support/Polyfills/scripts/13.0/`. Validado pelo
   Web Inspector: de 1 para 49 escopos Angular, sem erro.

O que se sabe do site (HAR + análise): página montada no servidor em Java atrás de nginx/AWS ALB; jQuery
1.11, Bootstrap 3.1, AngularJS 1.4.4, MathJax 2.7 (cdnjs), Chart.js 2.9, CKEditor 4 (604 KB) e Jodit 3.2
(411 KB). A página de pastas carrega ~6 MB de JS; cada aula embute `youtube.com/embed/<ID>?enablejsapi=1`
(~18 MB de JS do player). Não há polling nem WebSocket. O login usa reCAPTCHA v2, e o `JSESSIONID` é um
cookie de sessão.

## Decisões
| Tema | Decisão |
|---|---|
| Entrega | Fase 1: scripts do Polyfills no Safari. Fase 2: app WebKit próprio (Theos, compilado no Linux) reaproveitando os mesmos scripts |
| Repositório | [homerserejo/Tec-Concursos-iOS12](https://github.com/homerserejo/Tec-Concursos-iOS12) (GPL-2.0); o Tec-Blinker e a VM ficam parados como plano B |
| Vídeos do YouTube | Abrir no Opaline: `ytlite://watch?v=<ID>[&t=<s>]` |
| Commits | Autoria só de **Romerson Serejo**; sem `Co-Authored-By` do Claude, sem URL de sessão |
| Mensagens de commit e PR | Narrativa do porquê: o problema, a intenção e o que a mudança corrigiu. Não listar o que foi feito; o diff já mostra |

## Estrutura do repositório
```
polyfills/                  # espelha /Library/Application Support/Polyfills
  scripts/13.4/postMessage.options.js  # targetOrigin opcional ("/"), igual ao PR para o Polyfills
  scripts-post/base/tec.*.js  # otimizações do Tec; cada script checa o host *.tecconcursos.com.br
packaging/                  # control, postinst e postrm do .deb
app/                        # Fase 2: app TecDuck (Theos, Objective-C)
  Resources/content-rules.json  # allowlist de subrecursos (WKContentRuleList)
  icon.png                  # fonte dos ícones (tools/make-icons.py)
tools/
  capture.py                # console/rede do Safari ou do app pelo USB (pymobiledevice3)
  build-deb.sh              # empacota polyfills/ como .deb (dpkg-deb, no Linux)
  build-ipa.sh              # compila app/ e gera o .ipa com polyfills/ dentro
  install.sh                # .deb -> Media/Downloads (Filza); .ipa -> instalação direta (AppSync)
  make-icons.py
  requirements.txt
docs/PLANO.md
```
O Polyfills só lê `base/` e pastas com nome de versão (`^\d+\.\d+$`, aplicadas quando o iOS é mais
antigo que ela); por isso os scripts do Tec ficam em `base/` com prefixo `tec.` e testam o host.

## Fase 1: Safari + Polyfills
1. **Base do repo:** a correção do `postMessage`; `tools/capture.py` (o script de captura usado em
   2026-10-03: recarrega a aba, junta `Console`/`Network` e roda um diagnóstico do Angular);
   `tools/build-deb.sh`, que gera `com.romerson.tecfixes.deb` instalando os arquivos no caminho do
   Polyfills (depende de `com.ps.polyfills`). Instalar e desinstalar fica limpo, sem copiar arquivos à
   mão no Filza.
2. **Teste de uso real:** pastas → caderno → resolver questões em sequência → comentários → grifar →
   estatísticas → aula. Cada erro novo é capturado com `capture.py` e vira um script em
   `polyfills/` com um comentário explicando a causa.
3. **Otimizações (scripts restritos ao host do Tec):**
   - Aulas: feito em `tec.youtube-opaline.js`. Cada `iframe` do `youtube.com/embed/<ID>` vira um cartão
     "Abrir no Opaline" (`ytlite://`), com "Carregar o player aqui" como alternativa. O Tec não acompanha
     o progresso do vídeo (o player só recebe `setPlaybackRate`), então nada se perde.
   - Consentimento de cookies: já resolvido na conta. Uma captura completa de aula (2026-10-03) só
     acessa Tec, S3, cdnjs e Google Fonts; nada de GTM nem remarketing.
   - Bloquear CKEditor, Jodit e Chart.js: **descartado**. `tec.questao` depende do módulo `chart.js`
     (sem Chart.js o AngularJS não inicia), e CKEditor/Jodit são chamados de forma síncrona pelos
     editores de comentários, post-its, anotações e fórum. Só valeria com carga sob demanda, frágil a
     cada atualização do site, e sem medição de memória que justifique. Reavaliar na Fase 2.
4. **Rastreadores:** entradas em `/etc/hosts` (googletagmanager, google-analytics, doubleclick,
   activecampaign...). Nunca bloquear `www.google.com` nem `www.gstatic.com`, por causa do reCAPTCHA.
5. **Isolar o tweak que trava o login:** feito em 2026-10-04, sem reproduzir o crash.
   - `libsonar` e `base_hook` ficam em `/usr/lib`, fora do `TweakInject`, e aparecem nos relatórios
     ao lado do `dyld_patch`: são do jailbreak, não do Choicy. O Choicy só controla AppSync Unified,
     Polyfills, Safari Plus e tlsfix.
   - O crash é no processo `com.apple.WebKit.WebContent` (Choicy → Daemons), não no app Safari.
     Login testado com Polyfills + tlsfix, Polyfills + Safari Plus e os três juntos: todos passaram.
   - Os 25 relatórios de 02 e 03/10 têm a mesma assinatura (`EXC_BAD_ACCESS` em `libsystem_platform`
     chamado pelo WebKit a partir de JS, endereço terminado em `…468`) e nenhum tweak na pilha.
   - Em nenhum teste o reCAPTCHA mostrou o desafio de imagens; esse caminho segue sem teste.
   - Configuração recomendada para o WebContent: **só o Polyfills**. O tlsfix não serve ali (no iOS 12
     o TLS fica no processo `com.apple.WebKit.Networking`) e, quanto menos dylibs, menos memória e risco.
   - Se o crash voltar: `pymobiledevice3 crash ls`/`crash pull --match WebContent`. A lista de
     *Binary Images* do relatório mostra exatamente quais tweaks estavam carregados.

### Contribuição ao Polyfills (2026-10-04)
O `targetOrigin` obrigatório não é só do iOS 12: até o WebKit 608 (iOS 13.3) ele é exigido, e a forma
`postMessage(msg, { targetOrigin, transfer })` só chegou no WebKit 609 (iOS 13.4). A correção virou um
polyfill genérico, proposto ao PoomSmart/Polyfills no [PR #29](https://github.com/PoomSmart/Polyfills/pull/29) como `scripts/13.4/Window.postMessage.options.js`:
padrão `"/"` (só a mesma origem, como na especificação; o `'*'` anterior entregava a qualquer origem),
objeto de opções aceito e detecção por `postMessage.length`. Testado em 10 casos no iPad. Aqui ele vive
como `postMessage.options.js`, com outro nome para não conflitar no dpkg com o pacote do Polyfills.
As demais soluções (altura de linha, cookies, Opaline, zoom) são específicas do Tec ou do app.

## Fase 2: app TecDuck (Theos no Linux)
Feito em 2026-10-04; instalado no iPad e em uso.
- **Toolchain:** Theos em `~/theos`, toolchain iOS para Linux do L1ghtmann (clang 11, ld64 e `ldid`
  próprios, sem `sudo`) e o **SDK 12.4**, o último da série 12: o 12.5.x não teve SDK, e compilar contra
  ele impede usar por engano uma API do iOS 13+. Alvo `arm64`, iOS 12.0. Sem `fakeroot`: o `.ipa` é
  montado por `tools/build-ipa.sh`.
- **Instalação:** `.ipa` com assinatura falsa do `ldid` (`get-task-allow`, para o Web Inspector) pelo
  `installd` com AppSync Unified, direto do Linux (`pymobiledevice3 apps install`). Bundle
  `com.romerson.tecduck`, nome **TecDuck**, ícone do Psyduck.
- **App:** um `WKWebView` abrindo `/questoes/pastas`; barra ‹ › ⟳ Aleatória Pastas (Aleatória aciona "Questão aleatória
  não resolvida" da questão visível e só fica ativo nos cadernos); User-Agent com o sufixo do
  Safari 12 (o Tec só trata como app dele o UA `tec-app…`); `alert`/`confirm`/`prompt` nativos;
  `webViewWebContentProcessDidTerminate` recarrega; cookies no `WKWebsiteDataStore` padrão.
  `UILaunchStoryboardName` sem storyboard basta para o app usar a tela inteira (768×1024).
- **Scripts:** os arquivos de `polyfills/` vão dentro do app e são injetados com as regras do tweak
  (`base/` + pastas de versão), cada um num `try/catch`. Como o tweak Polyfills também injeta no app,
  os scripts do Tec são idempotentes.
- **Zoom de 130%** (só no app): a meta viewport passa a `width=tela/1,3, initial-scale=1,3`; o WebKit
  escala texto, botões e toques juntos, como o Ctrl + "+" do desktop. Abaixo de 768 px o Tec usa o
  layout de celular, com swipe entre questões.
- **Allowlist** (`content-rules.json`): bloqueia subrecursos fora de Tec, S3, MathJax, Google Fonts,
  WebFont Loader, reCAPTCHA e miniaturas do YouTube. A navegação de topo fica no app só para Tec e
  reCAPTCHA; YouTube vai para o Opaline e o resto para o Safari.
- **Melhorias de uso** (valem também no Safari pelo `.deb`): banner de cookies respondido com
  "Somente essenciais" sem recarregar; cartão do Opaline sem o fallback do player (que não carregava
  no app). As setas flutuantes ‹ › foram testadas e removidas: ficavam onde os dedos tocam sem querer.
- **Página de estrutura do curso:** 4.360 elementos, 3.721 watchers, `$digest` de 19 ms; o
  `DOMContentLoaded` em 5,8 s é a execução dos 66 scripts do Tec. O observer do cartão do YouTube
  fazia uma busca por nó inserido; uma varredura por lote resolveu o travamento percebido.
- **Risco que segue:** os tweaks são injetados no WebContent de todos os apps; o crash do login não se
  reproduziu (passo 5 da Fase 1).

## Verificação
- Fase 1: com o `.deb` instalado, fazer login, abrir pastas, resolver 50 questões seguidas, abrir
  comentários e estatísticas, e entrar numa aula com o vídeo indo para o Opaline. `capture.py` sem erros
  novos (exceto os 404 que o site também dá no desktop: `poster-videoaula.png`, `{{mapa.url}}`).
- Memória: `JetsamEvent` ausente em Ajustes → Privacidade → Análises numa sessão de 1 h.
- Fase 2: o mesmo roteiro no app, comparando estabilidade e memória com o Safari.
- `git log --format='%an %ae%n%b'` sem menção ao Claude.
