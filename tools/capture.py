#!/usr/bin/env python3
"""Captura o console e a rede de uma aba do Tec no Safari do iPad, pelo USB.

Liga o Web Inspector remoto (pymobiledevice3), recarrega a aba, imprime as
mensagens do console com a origem (arquivo:linha), as requisições que falharam
e, no fim, um diagnóstico do AngularJS. Cabeçalhos e cookies nunca são impressos.

Requisitos: `pip install -r tools/requirements.txt`; iPad ligado pelo USB e
confiando no computador; Ajustes > Safari > Avançado > Web Inspector ligado;
a aba do Tec aberta no Safari.

Para ler um CSS/JS do site, baixe com curl usando o User-Agent do Safari (sem ele o servidor
responde 403). Use --match 'TecDuck(' para inspecionar o app TecDuck em vez do Safari.

Uso: tools/capture.py [--wait 25] [--no-reload] [--all-requests] [--eval JS|@arquivo.js [--settle 5]] [--match tecconcursos]
"""

import argparse
import asyncio
import logging
from collections import Counter

from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.webinspector import WebinspectorService

DIAG = """(function(){
  var r = {};
  r.url = location.href;
  r.angular = typeof angular === 'undefined' ? 'ausente' : angular.version.full;
  var app = document.querySelector('[ng-app],[data-ng-app]');
  r.ngApp = app ? (app.getAttribute('ng-app') || app.getAttribute('data-ng-app')) : null;
  r.ngCloak = document.querySelectorAll('[ng-cloak],.ng-cloak').length;
  r.ngScope = document.querySelectorAll('.ng-scope').length;
  r.bodyText = document.body ? document.body.innerText.length : 0;
  r.scripts = document.scripts.length;
  r.iframes = Array.prototype.map.call(document.querySelectorAll('iframe'), function (f) { return f.src; });
  return JSON.stringify(r);
})()"""

URL_MAX = 160


def short(url: str) -> str:
    return url if len(url) <= URL_MAX else url[: URL_MAX - 1] + "…"


def guarded(handler):
    def run(message: dict) -> None:
        try:
            handler(message)
        except Exception as e:  # noqa: BLE001
            print(f"(evento {message.get('method')} ignorado: {e!r})", flush=True)

    return run


class Capture:
    """Handlers dos eventos do Web Inspector, registrados na sessão."""

    def __init__(self, all_requests: bool):
        self.all_requests = all_requests
        self.requests: dict[str, tuple[str, str]] = {}  # requestId -> (tipo, url)
        self.types: Counter[str] = Counter()
        self.failures = 0

    def install(self, session) -> None:
        # Uma exceção num handler mata o laço de recepção da pymobiledevice3 sem aviso, e toda
        # chamada seguinte espera para sempre; por isso cada handler é protegido.
        session.response_methods.update(
            {
                "Console.messageAdded": guarded(self.console),
                "Network.requestWillBeSent": guarded(self.request),
                "Network.responseReceived": guarded(self.response),
                "Network.loadingFailed": guarded(self.failed),
                # O handler da biblioteca relê a última mensagem guardada por ela, que fica vazia
                # porque o console é tratado aqui; o KeyError derrubava o laço de recepção.
                "Console.messageRepeatCountUpdated": guarded(self.repeated),
            }
        )
        # Eventos de rede sem interesse; sem handler, a biblioteca os despeja inteiros no log.
        for method in (
            "Canvas.canvasMemoryChanged",
            "Network.dataReceived",
            "Network.loadingFinished",
            "Network.requestServedFromMemoryCache",
            "Network.webSocketCreated",
            "Page.frameNavigated",
            "Page.frameStartedLoading",
            "Page.frameStoppedLoading",
            "Page.domContentEventFired",
            "Page.loadEventFired",
        ):
            session.response_methods.setdefault(method, lambda _: None)

    def console(self, message: dict) -> None:
        body = message["params"]["message"]
        params = body.get("parameters")
        if params:
            text = " ".join(
                str(p["value"]) if "value" in p else p.get("description", p.get("type", ""))
                for p in params
            )
        else:
            text = body.get("text", "")
        where = ""
        if body.get("url"):
            where = f"  [{short(body['url'])}:{body.get('line', '?')}:{body.get('column', '?')}]"
        print(f"console.{body.get('level', 'log')}: {text}{where}", flush=True)

    def repeated(self, message: dict) -> None:
        print(f"console: (última mensagem repetida {message['params'].get('count', '?')}x)", flush=True)

    def request(self, message: dict) -> None:
        params = message["params"]
        kind = params.get("type", "Other")
        self.requests[params["requestId"]] = (kind, params["request"]["url"])
        self.types[kind] += 1

    def response(self, message: dict) -> None:
        params = message["params"]
        status = params["response"].get("status", 0)
        if self.all_requests or status >= 400:
            kind = params.get("type", "Other")
            print(f"rede {status} {kind}: {short(params['response']['url'])}", flush=True)

    def failed(self, message: dict) -> None:
        params = message["params"]
        if params.get("canceled") and not self.all_requests:
            return
        self.failures += 1
        kind, url = self.requests.get(params["requestId"], ("?", "?"))
        print(f"rede FALHOU {kind}: {short(url)} ({params.get('errorText', '')})", flush=True)

    def summary(self) -> str:
        kinds = ", ".join(f"{k} {n}" for k, n in self.types.most_common())
        return f"{sum(self.types.values())} requisições ({kinds}); {self.failures} falhas"


async def main(args: argparse.Namespace) -> None:
    lockdown = await create_using_usbmux()
    inspector = WebinspectorService(lockdown=lockdown)
    await inspector.connect()
    async with inspector:
        pages = await inspector.get_open_application_pages(timeout=5)
        target = next((p for p in pages if args.match in str(p)), None)
        if target is None:
            print(f"nenhuma aba com '{args.match}' aberta:", pages)
            return
        print("aba:", target)
        session = await inspector.inspector_session(target.application, target.page)
        try:
            capture = Capture(args.all_requests)
            capture.install(session)
            await session.console_enable()
            await session.runtime_enable()
            try:
                await session.send_command("Network.enable")
            except Exception as e:  # noqa: BLE001
                print("Network.enable falhou:", e)
            if args.reload:
                print("== recarregando a página")
                await session.send_command("Page.reload", ignoreCache=False)
            await asyncio.sleep(args.wait)
            print("== rede:", capture.summary())
            print("== diagnóstico:", await session.runtime_evaluate(DIAG, return_by_value=True))
            for n, expr in enumerate(args.eval):
                if n and args.settle:
                    await asyncio.sleep(args.settle)
                if expr.startswith("@"):
                    expr = open(expr[1:], encoding="utf-8").read()
                print("== eval:", await session.runtime_evaluate(expr, return_by_value=True))
        finally:
            # Eventos que chegam depois que o inspetor sai (ex.: um fetch disparado por --eval)
            # deixam a página surda para a próxima sessão; desliga os domínios antes de sair.
            for domain in ("Network.disable", "Console.disable"):
                try:
                    await asyncio.wait_for(session.send_command(domain), timeout=3)
                except Exception:  # noqa: BLE001
                    pass
            # Sem isto o webinspectord acha que a sessão segue ativa e ignora a próxima captura.
            await asyncio.wait_for(
                inspector.teardown_inspector_socket(session.protocol.id_, target.application.id_, target.page.id_),
                timeout=5,
            )
    await inspector.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--wait", type=float, default=25, help="segundos de captura (padrão: 25)")
    parser.add_argument("--no-reload", dest="reload", action="store_false", help="não recarregar a aba")
    parser.add_argument("--all-requests", action="store_true", help="imprimir todas as respostas, não só >= 400")
    parser.add_argument("--eval", action="append", default=[], help="JS a avaliar na aba no fim (@arquivo.js lê de um arquivo); pode repetir")
    parser.add_argument("--settle", type=float, default=0, help="segundos de espera entre um --eval e o seguinte")
    parser.add_argument("--match", default="tecconcursos", help="trecho da URL/título da aba (padrão: tecconcursos)")
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    for noisy in ("asyncio", "pymobiledevice3.lockdown", "pymobiledevice3.service_connection", "webinspector.console"):
        logging.getLogger(noisy).setLevel(logging.WARNING)
    args = parser.parse_args()
    try:
        asyncio.run(asyncio.wait_for(main(args), timeout=args.wait + args.settle * len(args.eval) + 30))
    except asyncio.TimeoutError:
        raise SystemExit("o iPad não respondeu; volte à tela de início, reabra o Safari e tente de novo")
