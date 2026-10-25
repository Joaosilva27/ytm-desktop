(function () {
  'use strict';
  if (window.__ytm) { return; }

  var handler = null;
  try {
    handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytm;
  } catch (e) {}

  function send(payload) {
    if (!handler) { return; }
    try { handler.postMessage(payload); } catch (e) {}
  }

  function qs(selector, root) {
    try { return (root || document).querySelector(selector); } catch (e) { return null; }
  }

  function qsa(selector, root) {
    try { return Array.prototype.slice.call((root || document).querySelectorAll(selector)); } catch (e) { return []; }
  }

  function text(node) {
    if (!node) { return ''; }
    return (node.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function bar() { return qs('ytmusic-player-bar'); }
  function video() { return qs('video'); }

  function metadata() {
    try { return navigator.mediaSession && navigator.mediaSession.metadata; } catch (e) { return null; }
  }

  function upgradeArtwork(url) {
    if (!url) { return ''; }
    return url
      .replace(/=w\d+-h\d+/, '=w544-h544')
      .replace(/=s\d+(-[a-z0-9-]+)?$/, '=s544');
  }

  function artwork() {
    var meta = metadata();
    var url = '';
    if (meta && meta.artwork && meta.artwork.length) {
      var best = meta.artwork[meta.artwork.length - 1];
      url = (best && best.src) || '';
    }
    if (!url) {
      var img = qs('ytmusic-player-bar img.image') || qs('ytmusic-player-bar img');
      url = (img && (img.currentSrc || img.src)) || '';
    }
    return upgradeArtwork(url);
  }

  function likeElements() {
    var root = bar();
    if (!root) { return { renderer: null, button: null }; }
    var renderer = qs('ytmusic-like-button-renderer', root);
    var button = qs('#button-shape-like button', renderer) ||
                 qs('button[aria-label="Like"]', renderer) ||
                 qs('button[aria-label="Unlike"]', renderer) ||
                 qs('button[aria-pressed]', renderer);
    return { renderer: renderer, button: button };
  }

  function isLiked() {
    var parts = likeElements();
    if (parts.renderer) {
      var status = (parts.renderer.getAttribute('like-status') || '').toUpperCase();
      if (status === 'LIKE') { return true; }
      if (status === 'INDIFFERENT' || status === 'DISLIKE') { return false; }
    }
    if (parts.button) {
      if (parts.button.getAttribute('aria-pressed') === 'true') { return true; }
      if ((parts.button.getAttribute('aria-label') || '').toLowerCase() === 'unlike') { return true; }
    }
    return false;
  }

  function enabled(element) {
    if (!element) { return false; }
    if (element.hasAttribute('disabled')) { return false; }
    if (element.getAttribute('aria-disabled') === 'true') { return false; }
    if (element.disabled === true) { return false; }
    return true;
  }

  function playPauseButton() {
    var root = bar();
    return root && (qs('#play-pause-button button', root) ||
                    qs('button[aria-label="Play"]', root) ||
                    qs('button[aria-label="Pause"]', root));
  }

  function nextButton() {
    var root = bar();
    return root && (qs('.next-button button', root) || qs('button[aria-label="Next"]', root));
  }

  function previousButton() {
    var root = bar();
    return root && (qs('.previous-button button', root) || qs('button[aria-label="Previous"]', root));
  }

  function background() {
    var bg = '';
    try { bg = getComputedStyle(document.body).backgroundColor; } catch (e) {}
    if (!bg || bg === 'rgba(0, 0, 0, 0)' || bg === 'transparent') {
      var app = qs('ytmusic-app');
      if (app) {
        try { bg = getComputedStyle(app).backgroundColor; } catch (e) {}
      }
    }
    return (bg && bg !== 'rgba(0, 0, 0, 0)') ? bg : '#030303';
  }

  function isDarkColor(color) {
    var match = /rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)/i.exec(color || '');
    if (!match) { return true; }
    var r = parseFloat(match[1]) / 255;
    var g = parseFloat(match[2]) / 255;
    var b = parseFloat(match[3]) / 255;
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 0.5;
  }

  function videoID() {
    try {
      var fromURL = new URL(location.href).searchParams.get('v');
      if (fromURL) { return fromURL; }
    } catch (e) {}
    var link = bar() && qs('.title a', bar());
    if (link && link.href) {
      try { return new URL(link.href).searchParams.get('v') || ''; } catch (e) {}
    }
    return '';
  }

  function getState() {
    var root = bar();
    var v = video();
    var meta = metadata();
    var title = (meta && meta.title) || text(qs('.title', root)) || '';
    var artist = (meta && meta.artist) || '';
    var album = (meta && meta.album) || '';

    if ((!artist || !album) && root) {
      var links = qsa('.byline a', root);
      if (links.length) {
        if (!artist) { artist = text(links[0]); }
        if (!album && links[1]) { album = text(links[1]); }
      } else if (!artist) {
        var byline = text(qs('.byline', root));
        if (byline) { artist = byline.split('•')[0].trim(); }
      }
    }

    var duration = (v && isFinite(v.duration) && v.duration > 0) ? v.duration : 0;
    var position = (v && isFinite(v.currentTime) && v.currentTime > 0) ? v.currentTime : 0;
    var paused = v ? v.paused : true;
    var parts = likeElements();
    var bg = background();
    var id = videoID();
    var hasMedia = !!v && !!v.currentSrc && isFinite(v.duration) && v.duration > 0;

    return {
      hasTrack: !!title && (!!id || hasMedia),
      title: title,
      artist: artist,
      album: album,
      artwork: artwork(),
      videoId: id,
      isPlaying: !!v && !paused && !v.ended,
      position: position,
      duration: duration,
      canSeek: !!v && duration > 0,
      canNext: enabled(nextButton()),
      canPrevious: enabled(previousButton()),
      canLike: !!parts.button,
      liked: isLiked(),
      url: location.href,
      bg: bg,
      isDark: isDarkColor(bg)
    };
  }

  var timer = null;

  function postState() {
    if (!document.body) { return; }
    var state = getState();
    state.type = 'state';
    send(state);
  }

  function schedulePost(delay) {
    if (timer) { clearTimeout(timer); }
    timer = setTimeout(function () {
      timer = null;
      postState();
    }, delay || 100);
  }

  var hookedVideo = null;

  function hookVideo() {
    var v = video();
    if (!v || v === hookedVideo) { return; }
    hookedVideo = v;
    ['play', 'pause', 'playing', 'waiting', 'ended', 'loadedmetadata', 'durationchange', 'seeked'].forEach(function (name) {
      try {
        v.addEventListener(name, function () { schedulePost(60); }, { passive: true });
      } catch (e) {}
    });
    schedulePost(30);
  }

  function hookPlayerBar() {
    var root = bar();
    if (!root || root.__ytmObserved) { return; }
    root.__ytmObserved = true;
    try {
      var observer = new MutationObserver(function () { schedulePost(120); });
      observer.observe(root, {
        subtree: true,
        childList: true,
        characterData: true,
        attributes: true,
        attributeFilter: ['aria-label', 'aria-pressed', 'like-status', 'disabled', 'src', 'title']
      });
    } catch (e) {}
    schedulePost(60);
  }

  function clickPlayPause() {
    var button = playPauseButton();
    if (button) { button.click(); return true; }
    var v = video();
    if (!v) { return false; }
    try {
      if (v.paused) { v.play(); } else { v.pause(); }
      return true;
    } catch (e) { return false; }
  }

  function setLike(desired) {
    var parts = likeElements();
    if (!parts.button) { return false; }
    if (isLiked() !== !!desired) { parts.button.click(); }
    return true;
  }

  function seek(to) {
    var v = video();
    if (!v || !isFinite(to)) { return false; }
    try {
      var max = (isFinite(v.duration) && v.duration > 0) ? v.duration : Number(to);
      v.currentTime = Math.max(0, Math.min(Number(to), max));
      schedulePost(30);
      return true;
    } catch (e) { return false; }
  }

  function focusSearch() {
    var input = qs('ytmusic-search-box input') || qs('ytmusic-search-box #input');
    if (input) {
      try { input.focus(); input.select(); } catch (e) {}
      return true;
    }
    var box = qs('ytmusic-search-box');
    if (box) { box.click(); return true; }
    return false;
  }

  function command(name, value) {
    switch (name) {
      case 'toggle':
        return clickPlayPause();
      case 'play':
        if (!video() || video().paused) { return clickPlayPause(); }
        return true;
      case 'pause':
        if (video() && !video().paused) { return clickPlayPause(); }
        return true;
      case 'next':
        var next = nextButton();
        if (next) { next.click(); return true; }
        return false;
      case 'previous':
        var previous = previousButton();
        if (previous) { previous.click(); return true; }
        return false;
      case 'seek':
        return seek(value);
      case 'like':
        return setLike(value);
      case 'focusSearch':
        return focusSearch();
      case 'home':
        try { location.href = 'https://music.youtube.com/'; return true; } catch (e) { return false; }
      default:
        return false;
    }
  }

  window.__ytm = {
    version: 1,
    getState: getState,
    command: command
  };

  try {
    new MutationObserver(function () {
      hookPlayerBar();
      hookVideo();
    }).observe(document.documentElement, { childList: true, subtree: true });
  } catch (e) {}

  document.addEventListener('yt-navigate-finish', function () { schedulePost(150); }, true);
  document.addEventListener('yt-page-data-updated', function () { schedulePost(150); }, true);
  document.addEventListener('visibilitychange', function () { schedulePost(50); }, true);

  hookPlayerBar();
  hookVideo();

  setInterval(function () {
    hookPlayerBar();
    hookVideo();
    postState();
  }, 1000);

  send({ type: 'ready' });
  setTimeout(postState, 250);
  setTimeout(postState, 1200);
})();
