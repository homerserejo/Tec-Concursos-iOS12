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
  scripts/13.0/postMessage.targetOrigin.js
  scripts-post/base/tec.*.js  # otimizações do Tec; cada script checa o host *.tecconcursos.com.br
packaging/                  # control, postinst e postrm do .deb
tools/
  capture.py                # captura o console/rede do Safari pelo USB (pymobiledevice3)
  build-deb.sh              # empacota polyfills/ como .deb (dpkg-deb, no Linux)
  install.sh                # envia o .deb pelo USB (AFC) para instalar no Filza/Sileo
  requirements.txt
hosts/                      # bloqueio de rastreadores via /etc/hosts (opcional)
app/                        # Fase 2: app Theos
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
   - Aulas: trocar cada `iframe` do `youtube.com/embed/<ID>` por um botão "Abrir no Opaline"
     (`ytlite://`). Corta ~18 MB de JS e o vídeo por aula. Verificar se o Tec ainda marca a aula como vista.
   - Consentimento de cookies: recusar Análise e Marketing (`/cookie-consent/salvar`), para o servidor
     parar de injetar GTM e remarketing.
   - Experimento: impedir que CKEditor, Jodit e Chart.js carreguem na página de pastas. Fica só se não
     quebrar o AngularJS; medir antes e depois.
4. **Rastreadores:** entradas em `/etc/hosts` (googletagmanager, google-analytics, doubleclick,
   activecampaign...). Nunca bloquear `www.google.com` nem `www.gstatic.com`, por causa do reCAPTCHA.
5. **Isolar o tweak que trava o login** (ligar `tlsfix`, `libsonar` e `base_hook` um de cada vez), para
   deixar a configuração do Choicy mínima e documentada.

## Fase 2: app WebKit próprio (Theos no Linux)
- **Toolchain:** Theos + toolchain iOS para Linux + SDK do `theos/sdks`; alvo `arm64`, iOS 12.0; assinatura
  com `ldid` e instalação via AppSync (ou `.deb`).
- **App:** um único `WKWebView` com homepage fixa; barra mínima (voltar, avançar, recarregar, Home);
  `WKUserScript`s com os mesmos arquivos de `polyfills/` (sem depender do tweak); `WKContentRuleList`
  com a allowlist (`www`/`cdn.tecconcursos.com.br`, `s3-sa-east-1.amazonaws.com`, MathJax no cdnjs, Google
  Fonts, reCAPTCHA); política de navegação (Tec e reCAPTCHA ficam no app, YouTube vai para o Opaline,
  o resto para o Safari); `webViewWebContentProcessDidTerminate` recarrega a página; cookies persistentes
  (`WKWebsiteDataStore` padrão).
- **Risco:** os tweaks são injetados no WebContent de **todos** os apps, não só do Safari. O tweak que
  trava o login precisa ser desligado para o processo WebContent (Choicy → Daemons) ou removido.

## Verificação
- Fase 1: com o `.deb` instalado, fazer login, abrir pastas, resolver 50 questões seguidas, abrir
  comentários e estatísticas, e entrar numa aula com o vídeo indo para o Opaline. `capture.py` sem erros
  novos (exceto os 404 que o site também dá no desktop: `poster-videoaula.png`, `{{mapa.url}}`).
- Memória: `JetsamEvent` ausente em Ajustes → Privacidade → Análises numa sessão de 1 h.
- Fase 2: o mesmo roteiro no app, comparando estabilidade e memória com o Safari.
- `git log --format='%an %ae%n%b'` sem menção ao Claude.
