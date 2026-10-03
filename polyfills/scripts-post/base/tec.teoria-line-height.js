// O zoom de texto do Tec grava font-size inline em .conteudo-capitulo, mas o teoria.css fixa
// line-height em rem (relativo ao <html>, que não muda). Com 180–200% a linha fica do tamanho
// da letra ou menor, e o texto das aulas se sobrepõe. Troca cada rem por um fator sem unidade:
// rem / 1,1 (o texto base é 1,1rem), idêntico em 100% e proporcional à fonte com zoom.
(function () {
  if (!/(^|\.)tecconcursos\.com\.br$/.test(location.hostname)) return;
  var BASE_REM = 1.1;
  // Contêiner do texto -> seletor dos parágrafos (o nível de espaçamento vai no contêiner).
  var containers = {
    '#assunto .assunto-teoria-conteudo': '#assunto .assunto-teoria-conteudo .conteudo-capitulo',
    '#teoria .teoria-conteudo': '#teoria .teoria-conteudo'
  };
  // Valores em rem do teoria.css: parágrafo sem nível e espacamento-1..4.
  var paragraph = { '': 1.4, '.espacamento-1': 1.4, '.espacamento-2': 1.56, '.espacamento-3': 1.75, '.espacamento-4': 2 };

  function ratio(rem) { return (rem / BASE_REM).toFixed(3); }

  var css = '';
  for (var container in containers) {
    css += container + '{line-height:' + ratio(2) + '!important}';
    for (var level in paragraph) {
      css += containers[container] + level + ' p{line-height:' + ratio(paragraph[level]) + '!important}';
    }
  }
  var style = document.createElement('style');
  style.id = 'tec-teoria-line-height';
  style.textContent = css;
  (document.head || document.documentElement).appendChild(style);
})();
