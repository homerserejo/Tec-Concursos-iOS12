// Cada videoaula do Tec embute youtube.com/embed/<ID>, que puxa ~18 MB de JS do player e anúncios
// por vídeo, pesado demais para 1 GB de RAM. O Tec não acompanha o progresso do vídeo (o player só
// recebe comandos de velocidade), então trocar o iframe por um cartão que abre o Opaline
// (ytlite://) não perde nada.
(function () {
  if (!/(^|\.)tecconcursos\.com\.br$/.test(location.hostname)) return;
  // O app TecDuck injeta estes scripts e o tweak Polyfills também; roda uma vez só.
  if (window.__tecYoutubeOpaline) return;
  window.__tecYoutubeOpaline = true;

  var EMBED = /^https?:\/\/(?:www\.)?youtube(?:-nocookie)?\.com\/embed\/([\w-]{11})/;
  var frames = document.getElementsByTagName('iframe'); // coleção viva: sem nova busca a cada lote

  function card(id) {
    var link = document.createElement('a');
    link.className = 'tec-opaline';
    link.href = 'ytlite://watch?v=' + id;
    link.style.cssText =
      'position:absolute;top:0;left:0;width:100%;height:100%;display:flex;align-items:center;' +
      'justify-content:center;text-decoration:none;background:#000 center/cover no-repeat;' +
      "background-image:url('https://i.ytimg.com/vi/" + id + "/hqdefault.jpg')";

    var label = document.createElement('span');
    label.textContent = '▶ Abrir no Opaline';
    label.style.cssText =
      'padding:12px 24px;border-radius:6px;background:rgba(204,0,0,.92);color:#fff;' +
      'font-size:20px;font-weight:bold';

    link.appendChild(label);
    return link;
  }

  function replaceAll() {
    // De trás para frente: a coleção encolhe a cada troca.
    for (var i = frames.length - 1; i >= 0; i--) {
      var iframe = frames[i];
      var m = EMBED.exec(iframe.getAttribute('src') || iframe.getAttribute('ng-src') || '');
      if (m && iframe.parentNode) iframe.parentNode.replaceChild(card(m[1]), iframe);
    }
  }

  // O AngularJS cria o iframe depois do carregamento e preenche o src em seguida. Uma varredura por
  // lote de mutações troca o iframe no mesmo microtask, antes que o player comece a carregar, sem
  // custo proporcional aos milhares de nós que as páginas de curso inserem.
  new MutationObserver(function () {
    if (frames.length) replaceAll();
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });

  replaceAll();
})();
