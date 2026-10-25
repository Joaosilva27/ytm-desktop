(function () {
  'use strict';
  if (window.__ytmAdBlock) { return; }

  var playerPath = /\/youtubei\/v1\/player(?:\?|$)/;
  var adStateSelector =
    '#movie_player.ad-showing, #movie_player.ad-interrupting, ' +
    'ytmusic-player.ad-showing, ytmusic-player[is-advertisement]';
  var skipSelector =
    '#movie_player .ytp-ad-skip-button, ' +
    '#movie_player .ytp-ad-skip-button-modern, ' +
    '#movie_player .ytp-skip-ad-button, ' +
    '#movie_player button[aria-label*="Skip ad"]';

  var messageHandler = null;
  try {
    messageHandler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytm;
  } catch (e) {}

  function send(payload) {
    if (!messageHandler) { return; }
    try { messageHandler.postMessage(payload); } catch (e) {}
  }

  var initialResponsePruned = false;

  function prune(value, depth) {
    if (!value || typeof value !== 'object' || depth > 12) { return false; }
    var changed = false;

    if (Object.prototype.hasOwnProperty.call(value, 'adPlacements')) {
      if (!Array.isArray(value.adPlacements) || value.adPlacements.length > 0) {
        value.adPlacements = [];
        changed = true;
      }
    }
    if (Object.prototype.hasOwnProperty.call(value, 'adSlots')) {
      if (!Array.isArray(value.adSlots) || value.adSlots.length > 0) {
        value.adSlots = [];
        changed = true;
      }
    }
    if (Object.prototype.hasOwnProperty.call(value, 'playerAds')) {
      if (!Array.isArray(value.playerAds) || value.playerAds.length > 0) {
        value.playerAds = [];
        changed = true;
      }
    }
    if (Object.prototype.hasOwnProperty.call(value, 'adBreakHeartbeatParams')) {
      try { delete value.adBreakHeartbeatParams; } catch (e) { value.adBreakHeartbeatParams = null; }
      changed = true;
    }

    for (var key in value) {
      if (!Object.prototype.hasOwnProperty.call(value, key)) { continue; }
      var child = value[key];
      if (child && typeof child === 'object') {
        if (prune(child, depth + 1)) { changed = true; }
      }
    }
    return changed;
  }

  function prunedFetchResponse(response) {
    if (!response || !response.ok || response.status === 0 ||
        (response.type !== 'basic' && response.type !== 'cors')) {
      return response;
    }

    return response.clone().json().then(function (json) {
      if (!prune(json, 0)) { return response; }

      var headers = new Headers(response.headers);
      // The body is being re-encoded as plain JSON; stale encoding headers would break parsing.
      headers.delete('content-length');
      headers.delete('content-encoding');

      var modified = new Response(JSON.stringify(json), {
        status: response.status,
        statusText: response.statusText,
        headers: headers
      });
      try { Object.defineProperty(modified, 'url', { value: response.url }); } catch (e) {}
      try { Object.defineProperty(modified, 'redirected', { value: response.redirected }); } catch (e) {}
      return modified;
    }).catch(function () { return response; });
  }

  if (typeof window.fetch === 'function') {
    var nativeFetch = window.fetch;
    window.fetch = function (input, init) {
      var result = nativeFetch.apply(this, arguments);
      var url = '';
      try {
        url = typeof input === 'string' ? input : (input && input.url) || '';
      } catch (e) {}
      if (!playerPath.test(url)) { return result; }
      return result.then(prunedFetchResponse);
    };
  }

  (function () {
    if (typeof XMLHttpRequest === 'undefined') { return; }

    var proto = XMLHttpRequest.prototype;
    var nativeOpen = proto.open;
    var nativeSend = proto.send;
    var responseTextGetter = Object.getOwnPropertyDescriptor(proto, 'responseText');
    var responseGetter = Object.getOwnPropertyDescriptor(proto, 'response');
    if (!nativeOpen || !nativeSend || !responseTextGetter || !responseTextGetter.get ||
        !responseGetter || !responseGetter.get) {
      return;
    }

    proto.open = function (method, url) {
      try { this.__ytmPlayerRequest = playerPath.test(String(url)); }
      catch (e) { this.__ytmPlayerRequest = false; }
      return nativeOpen.apply(this, arguments);
    };

    proto.send = function (body) {
      if (this.__ytmPlayerRequest) { installPruningGetters(this); }
      return nativeSend.apply(this, arguments);
    };

    function installPruningGetters(xhr) {
      var computed = false;
      var textValue;
      var jsonValue;
      try {
        Object.defineProperty(xhr, 'responseText', {
          configurable: true,
          get: function () {
            if (!computed) { compute(xhr); }
            return textValue !== undefined ? textValue : responseTextGetter.get.call(xhr);
          }
        });
        Object.defineProperty(xhr, 'response', {
          configurable: true,
          get: function () {
            if (!computed) { compute(xhr); }
            if (jsonValue !== undefined) { return jsonValue; }
            if (textValue !== undefined) { return textValue; }
            return responseGetter.get.call(xhr);
          }
        });
      } catch (e) {}
    }

    function compute(xhr) {
      if (computed || xhr.readyState !== 4 || xhr.status !== 200) { return; }
      computed = true;
      try {
        var type = xhr.responseType;
        if (type === '' || type === 'text') {
          var raw = responseTextGetter.get.call(xhr);
          var json = JSON.parse(raw);
          if (prune(json, 0)) { textValue = JSON.stringify(json); }
        } else if (type === 'json') {
          var value = responseGetter.get.call(xhr);
          if (value && prune(value, 0)) { jsonValue = value; }
        }
      } catch (e) {}
    }
  })();

  (function () {
    var stored;
    try {
      Object.defineProperty(window, 'ytInitialPlayerResponse', {
        configurable: true,
        enumerable: true,
        get: function () { return stored; },
        set: function (value) {
          if (value && typeof value === 'object' && prune(value, 0)) {
            initialResponsePruned = true;
          }
          stored = value;
        }
      });
    } catch (e) {}
  })();

  var adActive = false;
  var savedMuted = null;
  var savedRate = null;

  function adShowing() {
    return !!document.querySelector(adStateSelector);
  }

  function startAd() {
    if (adActive) { return; }
    adActive = true;
    var video = document.querySelector('video');
    if (video) {
      savedMuted = video.muted;
      savedRate = video.playbackRate || 1;
      try { video.muted = true; } catch (e) {}
    }
    send({ type: 'adblock', event: 'start' });
  }

  function endAd() {
    if (!adActive) { return; }
    adActive = false;
    var video = document.querySelector('video');
    if (video) {
      if (savedMuted !== null && video.muted) {
        try { video.muted = savedMuted; } catch (e) {}
      }
      if (savedRate !== null && Math.abs(video.playbackRate - 16) < 0.01) {
        try { video.playbackRate = savedRate; } catch (e) {}
      }
    }
    savedMuted = null;
    savedRate = null;
    send({ type: 'adblock', event: 'end' });
  }

  function skipAd() {
    var video = document.querySelector('video');
    if (video) {
      try { if (video.playbackRate < 16) { video.playbackRate = 16; } } catch (e) {}
      try {
        if (isFinite(video.duration) && video.duration > 0) {
          video.currentTime = Math.max(0, video.duration - 0.05);
        }
      } catch (e) {}
    }
    var button = document.querySelector(skipSelector);
    if (button) {
      try { button.click(); } catch (e) {}
    }
  }

  function tick() {
    if (adShowing()) {
      startAd();
      skipAd();
    } else {
      endAd();
    }
  }

  setInterval(tick, 250);
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', tick);
  } else {
    tick();
  }

  window.__ytmAdBlock = {
    version: 1,
    prune: function (value) { return prune(value, 0); },
    initialResponsePruned: function () { return initialResponsePruned; }
  };
})();
