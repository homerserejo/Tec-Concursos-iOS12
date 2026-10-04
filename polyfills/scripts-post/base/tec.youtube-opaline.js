// Cada videoaula do Tec embute youtube.com/embed/<ID>, que puxa ~18 MB de JS do player e anúncios
// por vídeo, pesado demais para 1 GB de RAM. O Tec não acompanha o progresso do vídeo (o player só
// recebe comandos de velocidade), então trocar o iframe por um botão que abre o Opaline
// (ytlite://) não perde nada. "Carregar o player aqui" devolve o iframe original se precisar.
(function () {
  if (!/(^|\.)tecconcursos\.com\.br$/.test(location.hostname)) return;

  var EMBED = /^https?:\/\/(?:www\.)?youtube(?:-nocookie)?\.com\/embed\/([\w-]{11})/;
  var KEEP = 'data-tec-player';

  function videoId(iframe) {
    var m = EMBED.exec(iframe.getAttribute('src') || iframe.getAttribute('ng-src') || '');
    return m && m[1];
  }

  function card(iframe, id) {
    var box = document.createElement('div');
    box.className = 'tec-opaline';
    box.style.cssText =
      'position:absolute;top:0;left:0;width:100%;height:100%;display:flex;flex-direction:column;' +
      'align-items:center;justify-content:center;background:#000 center/cover no-repeat;' +
      "background-image:url('https://i.ytimg.com/vi/" + id + "/hqdefault.jpg')";

    var open = document.createElement('a');
    open.href = 'ytlite://watch?v=' + id;
    open.textContent = '▶ Abrir no Opaline';
    open.style.cssText =
      'padding:12px 24px;border-radius:6px;background:rgba(204,0,0,.92);color:#fff;' +
      'font-size:20px;font-weight:bold;text-decoration:none';

    var here = document.createElement('a');
    here.href = '#';
    here.textContent = 'Carregar o player aqui';
    here.style.cssText =
      'margin-top:12px;padding:4px 8px;border-radius:4px;background:rgba(0,0,0,.6);color:#fff;font-size:14px';
    here.addEventListener('click', function (event) {
      event.preventDefault();
      iframe.setAttribute(KEEP, '');
      box.parentNode.replaceChild(iframe, box);
    });

    box.appendChild(open);
    box.appendChild(here);
    return box;
  }

  function replace(iframe) {
    if (iframe.tagName !== 'IFRAME' || iframe.hasAttribute(KEEP) || !iframe.parentNode) return;
    var id = videoId(iframe);
    if (!id) return;
    iframe.parentNode.replaceChild(card(iframe, id), iframe);
  }

  function scan(root) {
    if (root.tagName === 'IFRAME') return replace(root);
    if (!root.querySelectorAll) return;
    var frames = root.querySelectorAll('iframe');
    for (var i = 0; i < frames.length; i++) replace(frames[i]);
  }

  // O Angular cria o iframe depois do carregamento e preenche o src em seguida; o observer troca o
  // iframe no mesmo microtask, antes que o player comece a carregar.
  new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var m = mutations[i];
      if (m.type === 'attributes') replace(m.target);
      else for (var j = 0; j < m.addedNodes.length; j++) scan(m.addedNodes[j]);
    }
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src'] });

  scan(document.documentElement);
})();
