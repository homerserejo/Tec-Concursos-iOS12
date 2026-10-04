// Sem consentimento registrado, o Tec mostra um banner de cookies em toda página. A escolha mais
// leve é "Somente essenciais": nada de GTM, Analytics nem remarketing. O script esconde o banner e
// envia essa escolha como o próprio botão faria, mas sem o location.reload() que ele dispara.
(function () {
  if (!/(^|\.)tecconcursos\.com\.br$/.test(location.hostname)) return;
  var banner = document.getElementById('tec-cookie-banner');
  if (!banner || banner.getAttribute('data-tec-respondido')) return;
  banner.setAttribute('data-tec-respondido', '');
  banner.style.display = 'none';

  var xhr = new XMLHttpRequest();
  xhr.open('POST', '/cookie-consent/salvar');
  xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
  xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
  xhr.send('analitica=false&marketing=false');
})();
