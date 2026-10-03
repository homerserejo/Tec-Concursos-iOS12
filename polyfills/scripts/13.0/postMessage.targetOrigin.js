// iOS 12 WebKit requires postMessage's targetOrigin; modern browsers default it.
// Tec Concursos calls window.parent.postMessage({ type: 'CONTENT_READY' }), which
// throws "Not enough arguments" and aborts the AngularJS caderno controller.
(function () {
  var nativePostMessage = window.postMessage;
  if (typeof nativePostMessage !== 'function') return;
  window.postMessage = function (message, targetOrigin) {
    if (arguments.length < 2) return nativePostMessage.call(this, message, '*');
    return nativePostMessage.apply(this, arguments);
  };
})();
