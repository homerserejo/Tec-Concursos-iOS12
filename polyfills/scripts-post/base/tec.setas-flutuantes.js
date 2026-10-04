// Nos cadernos, "Anterior" e "Próxima" são botões de 40px no fim de cada questão, então é preciso
// rolar até o fim a cada uma. Duas setas grandes fixas nos cantos inferiores repassam o toque aos
// botões originais (ng-click do Tec), ficam sempre ao alcance do polegar e não dependem do layout.
(function () {
  if (!/(^|\.)tecconcursos\.com\.br$/.test(location.hostname)) return;
  if (!/^\/questoes\/cadernos\//.test(location.pathname)) return;
  if (document.getElementById('tec-setas')) return;

  var BUTTONS = { anterior: '.questao-navegacao-botao-anterior', proxima: '.questao-navegacao-botao-proxima' };

  // O swipe do layout estreito mantém vizinhas fora da tela; vale o botão da questão visível.
  function target(kind) {
    var all = document.querySelectorAll(BUTTONS[kind]);
    for (var i = 0; i < all.length; i++) {
      var box = all[i].getBoundingClientRect();
      if (box.width && box.left >= 0 && box.left < window.innerWidth) return all[i];
    }
    return null;
  }

  function arrow(kind, glyph, side) {
    var b = document.createElement('button');
    b.type = 'button';
    b.textContent = glyph;
    b.setAttribute('aria-label', kind === 'anterior' ? 'Questão anterior' : 'Próxima questão');
    b.style.cssText =
      'position:fixed;bottom:16px;' + side + ':12px;z-index:1000;width:56px;height:56px;padding:0 0 4px;' +
      'border:0;border-radius:50%;background:rgba(56,64,71,.6);color:#fff;font-size:40px;line-height:1;' +
      '-webkit-tap-highlight-color:transparent;display:none';
    b.addEventListener('click', function () {
      var original = target(kind);
      if (original) original.click();
    });
    return b;
  }

  var box = document.createElement('div');
  box.id = 'tec-setas';
  var prev = arrow('anterior', '‹', 'left');
  var next = arrow('proxima', '›', 'right');
  box.appendChild(prev);
  box.appendChild(next);
  document.body.appendChild(box);

  // A questão chega por XHR depois do carregamento; uma consulta por segundo é mais barata que
  // observar os milhares de nós do caderno.
  function sync() {
    [[prev, 'anterior'], [next, 'proxima']].forEach(function (pair) {
      var original = target(pair[1]);
      pair[0].style.display = original ? 'block' : 'none';
      pair[0].style.opacity = original && /desabilitado/.test(original.className) ? '0.25' : '1';
    });
  }
  sync();
  setInterval(sync, 1000);
})();
