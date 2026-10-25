(function () {
  'use strict';
  if (window.__ytmAudioOnly) { return; }

  var STYLE_ID = 'ytm-audio-only-style';
  var ROOT_CLASS = 'ytm-audio-only';
  var VIDEO_TYPES = {
    MUSIC_VIDEO_TYPE_OMV: true,
    MUSIC_VIDEO_TYPE_UGC: true,
    MUSIC_VIDEO_TYPE_OFFICIAL_SOURCE_MUSIC: true
  };

  var lastVideoID = '';
  var preferredVideoID = null;
  var forcedAudioID = '';
  var fallbackAudioID = '';
  var audioLoadInFlight = false;
  var loadPending = false;
  var pendingPause = false;
  var pendingStart = 0;
  var retryCount = 0;
  var lastReportedSignature = '';
  var lastShownVideo = false;

  var playerApiObject = null;
  var lastLoadVars = null;
  var apiHooked = false;
  var hookTimer = null;

  function qs(selector, root) {
    try { return (root || document).querySelector(selector); } catch (e) { return null; }
  }

  function movie() {
    return qs('#movie_player');
  }

  function video() {
    return qs('video');
  }

  function playerElement() {
    return qs('ytmusic-player');
  }

  function playerApi() {
    try {
      var element = playerElement();
      return element && element.inst && element.inst.playerApi;
    } catch (e) {
      return null;
    }
  }

  function cloneObject(object) {
    var copy = {};
    if (!object) { return copy; }
    for (var key in object) {
      if (Object.prototype.hasOwnProperty.call(object, key)) {
        copy[key] = object[key];
      }
    }
    return copy;
  }

  function currentVideoID() {
    // The player updates before the URL during autoplay, so prefer the live player data.
    var player = movie();
    try {
      var data = player && player.getVideoData ? player.getVideoData() : null;
      if (data && data.video_id) { return data.video_id; }
    } catch (e) {}

    try {
      var fromURL = new URL(location.href).searchParams.get('v');
      if (fromURL) { return fromURL; }
    } catch (e) {}

    var link = qs('ytmusic-player-bar .title a');
    if (link && link.href) {
      try { return new URL(link.href).searchParams.get('v') || ''; } catch (e) {}
    }
    return '';
  }

  function playerResponse() {
    var player = movie();
    try {
      return player && player.getPlayerResponse ? player.getPlayerResponse() : null;
    } catch (e) {
      return null;
    }
  }

  function videoType() {
    var response = playerResponse();
    return (response && response.videoDetails && response.videoDetails.musicVideoType) || '';
  }

  function hasVideo() {
    var type = videoType();
    if (type) { return !!VIDEO_TYPES[type]; }
    var element = video();
    return !!element && element.readyState >= 1 && element.videoWidth > 0;
  }

  function audioOnlyAllowed() {
    var response = playerResponse();
    if (!response) { return true; }
    var status = response.playabilityStatus;
    var audioOnly = status && status.audioOnlyPlayability;
    var renderer = audioOnly && audioOnly.audioOnlyPlayabilityRenderer;
    return !renderer || renderer.audioOnlyAvailability !== 'FEATURE_AVAILABILITY_BLOCKED';
  }

  function isAdPlaying() {
    var player = movie();
    if (!player) { return false; }
    try {
      if (typeof player.getAdState === 'function' && player.getAdState() > 0) { return true; }
    } catch (e) {}
    return player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting');
  }

  function mediaReady() {
    var element = video();
    return !!element && element.readyState >= 1 && isFinite(element.duration) && element.duration > 0;
  }

  function isAudioOnlyStream() {
    var element = video();
    return mediaReady() && element.videoWidth === 0 && element.videoHeight === 0;
  }

  function isVideoStream() {
    var element = video();
    return mediaReady() && element.videoWidth > 0 && element.videoHeight > 0;
  }

  function currentTime() {
    var player = movie();
    try {
      if (player && typeof player.getCurrentTime === 'function') {
        var time = player.getCurrentTime();
        if (isFinite(time) && time >= 0) { return time; }
      }
    } catch (e) {}
    var element = video();
    return element && isFinite(element.currentTime) ? element.currentTime : 0;
  }

  function isPlaying() {
    var element = video();
    return !!element && !element.paused && !element.ended;
  }

  function ensureStyle() {
    if (qs('#' + STYLE_ID)) { return; }
    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = [
      'html.' + ROOT_CLASS + ' #song-video,',
      'html.' + ROOT_CLASS + ' #song-video.ytmusic-player { display: none !important; }',
      'html.' + ROOT_CLASS + ' #song-image { display: block !important; background: #030303; }',
      'html.' + ROOT_CLASS + ' #song-image yt-img-shadow,',
      'html.' + ROOT_CLASS + ' #song-image img {',
      '  width: 100% !important; height: 100% !important; object-fit: cover !important;',
      '}'
    ].join('\n');
    (document.head || document.documentElement).appendChild(style);
  }

  function artworkURL() {
    try {
      var meta = navigator.mediaSession && navigator.mediaSession.metadata;
      if (meta && meta.artwork && meta.artwork.length) {
        for (var i = meta.artwork.length - 1; i >= 0; i--) {
          var artwork = meta.artwork[i];
          var source = artwork && artwork.src;
          if (source && source.indexOf('data:') !== 0) { return source; }
        }
      }
    } catch (e) {}

    var image = qs('ytmusic-player-bar img.image') || qs('ytmusic-player-bar img');
    var source = image && (image.currentSrc || image.src);
    if (source && source.indexOf('data:') !== 0) { return source; }
    return '';
  }

  function applyArtwork() {
    var image = qs('#song-image');
    if (!image) { return; }
    var img = qs('img', image);
    if (!img) { return; }
    var url = artworkURL();
    if (!url) { return; }
    if (img.currentSrc === url || img.getAttribute('src') === url) { return; }
    try {
      img.removeAttribute('srcset');
      img.src = url;
    } catch (e) {}
  }

  function refreshNativeState() {
    if (window.__ytm && typeof window.__ytm.refreshState === 'function') {
      window.__ytm.refreshState();
    }
  }

  function reflowVideo() {
    var player = qs('ytmusic-player');
    try {
      if (player && typeof player.forceVideoReflow === 'function') {
        player.forceVideoReflow();
      }
    } catch (e) {}

    var page = qs('ytmusic-player-page');
    try {
      var controller = page && (page.polymerController || page.inst || page);
      if (controller && typeof controller.updatePlayerWidth === 'function') {
        controller.updatePlayerWidth();
      }
    } catch (e) {}

    try { window.dispatchEvent(new Event('resize')); } catch (e) {}
  }

  function reportState(videoID, available, videoVisible) {
    var audioOnlyVisual = document.documentElement.classList.contains(ROOT_CLASS);
    var signature = [videoID || '', available ? '1' : '0', videoVisible ? '1' : '0', audioOnlyVisual ? '1' : '0'].join('|');
    if (signature !== lastReportedSignature) {
      lastReportedSignature = signature;
      refreshNativeState();
    }
  }

  /// The music app calls playerApi.loadVideoByPlayerVars for every queue item.
  /// Adding YouTube's own `audio_only=1` there switches the same video to the
  /// audio track without replacing the queue, the position, or the track.
  function hookPlayerApi() {
    var api = playerApi();
    if (!api || typeof api.loadVideoByPlayerVars !== 'function') { return false; }
    if (api.__ytmAudioOnlyHooked === api.loadVideoByPlayerVars) {
      playerApiObject = api;
      apiHooked = true;
      return true;
    }

    var originalLoad = api.loadVideoByPlayerVars;
    var originalCue = api.cueVideoByPlayerVars;
    var originalPreload = api.preloadVideoByPlayerVars;

    function modifiedVars(vars, capture) {
      if (!vars || !vars.video_id) { return null; }
      var copy = cloneObject(vars);
      if (copy.video_id !== preferredVideoID) {
        copy.audio_only = '1';
        forcedAudioID = copy.video_id;
      } else {
        delete copy.audio_only;
      }
      if (capture) { lastLoadVars = cloneObject(copy); }
      return copy;
    }

    api.loadVideoByPlayerVars = function (vars) {
      var modified = modifiedVars(vars, true);
      return modified ? originalLoad.call(this, modified) : originalLoad.apply(this, arguments);
    };
    if (typeof originalCue === 'function') {
      api.cueVideoByPlayerVars = function (vars) {
        var modified = modifiedVars(vars, true);
        return modified ? originalCue.call(this, modified) : originalCue.apply(this, arguments);
      };
    }
    if (typeof originalPreload === 'function') {
      api.preloadVideoByPlayerVars = function (vars) {
        var modified = modifiedVars(vars, false);
        return modified ? originalPreload.call(this, modified) : originalPreload.apply(this, arguments);
      };
    }

    api.__ytmAudioOnlyHooked = api.loadVideoByPlayerVars;
    playerApiObject = api;
    apiHooked = true;
    return true;
  }

  function startHooking() {
    if (hookPlayerApi()) { return; }
    if (hookTimer) { return; }
    hookTimer = setInterval(function () {
      if (hookPlayerApi()) {
        clearInterval(hookTimer);
        hookTimer = null;
      }
    }, 50);
    setTimeout(function () {
      if (hookTimer) {
        clearInterval(hookTimer);
        hookTimer = null;
      }
    }, 15000);
  }

  function settleAfterLoad() {
    if (!loadPending) { return; }
    loadPending = false;
    audioLoadInFlight = false;

    var player = movie();
    if (!player) { return; }
    if (pendingStart > 0.25) {
      try { player.seekTo(pendingStart, true); } catch (e) {}
    }
    if (pendingPause) {
      try { player.pauseVideo(); } catch (e) {}
    }
    pendingPause = false;
    pendingStart = 0;
    setTimeout(apply, 120);
  }

  function loadVarsForCurrent(videoID) {
    var vars = (lastLoadVars && lastLoadVars.video_id === videoID) ? cloneObject(lastLoadVars) : {};
    vars.video_id = videoID;
    vars.external_list = true;

    var player = movie();
    if (!vars.list && player) {
      try {
        var list = player.getPlaylistId();
        var index = player.getPlaylistIndex();
        if (list) {
          vars.list = list;
          if (isFinite(index) && index >= 0) { vars.playlist_index = index; }
        }
      } catch (e) {}
    }
    return vars;
  }

  function reloadCurrent(wantAudioOnly, start, shouldPlay) {
    var videoID = currentVideoID();
    var api = playerApi();
    var player = movie();
    if (!videoID || (!api && !player) || audioLoadInFlight) { return false; }

    var vars = loadVarsForCurrent(videoID);
    vars.start = Math.max(0, start || 0);
    if (wantAudioOnly) {
      vars.audio_only = '1';
      forcedAudioID = videoID;
    } else {
      delete vars.audio_only;
      forcedAudioID = '';
    }
    vars.pause_at_start = !shouldPlay;
    if (shouldPlay) { vars.autoplay = 1; }

    lastLoadVars = cloneObject(vars);
    audioLoadInFlight = true;
    loadPending = true;
    pendingPause = !shouldPlay;
    pendingStart = vars.start;

    try {
      if (api && typeof api.loadVideoByPlayerVars === 'function') {
        api.loadVideoByPlayerVars(vars);
      } else if (player && typeof player.loadVideoByPlayerVars === 'function') {
        player.loadVideoByPlayerVars(vars);
      } else {
        audioLoadInFlight = false;
        loadPending = false;
        return false;
      }
    } catch (e) {
      audioLoadInFlight = false;
      loadPending = false;
      return false;
    }

    // Fallbacks in case the player does not emit the media events we expect.
    setTimeout(function () {
      audioLoadInFlight = false;
      if (loadPending && pendingPause) {
        try { movie().pauseVideo(); } catch (e) {}
      }
    }, 2000);
    setTimeout(function () {
      if (loadPending) {
        loadPending = false;
        pendingPause = false;
        pendingStart = 0;
      }
      audioLoadInFlight = false;
      apply();
    }, 5000);
    return true;
  }

  function hookVideo() {
    var element = video();
    if (!element || element.__ytmAudioOnlyHooked) { return; }
    element.__ytmAudioOnlyHooked = true;
    ['loadedmetadata', 'durationchange', 'playing', 'pause', 'seeked'].forEach(function (name) {
      try {
        element.addEventListener(name, function () {
          if (name === 'loadedmetadata' || name === 'durationchange') { settleAfterLoad(); }
          setTimeout(apply, 80);
        }, { passive: true });
      } catch (e) {}
    });
  }

  function observePlayer() {
    var player = movie();
    if (player && !player.__ytmAudioOnlyObserved) {
      player.__ytmAudioOnlyObserved = true;
      ['videodatachange', 'onStateChange', 'loadedmetadata', 'durationchange'].forEach(function (name) {
        try {
          player.addEventListener(name, function () {
            if (name === 'loadedmetadata' || name === 'durationchange') { settleAfterLoad(); }
            setTimeout(apply, 80);
          }, true);
        } catch (e) {}
      });
    }
    hookVideo();
  }

  function apply() {
    ensureStyle();
    observePlayer();
    hookPlayerApi();

    var id = currentVideoID();
    if (id && id !== lastVideoID) {
      var wasForced = forcedAudioID === id;
      lastVideoID = id;
      preferredVideoID = null;
      if (!wasForced) { forcedAudioID = ''; }
      fallbackAudioID = '';
      audioLoadInFlight = false;
      loadPending = false;
      pendingPause = false;
      pendingStart = 0;
      retryCount = 0;
    }

    var available = !!id && hasVideo();
    if (!available) {
      // The player briefly reports no video data while it reloads. Keep the
      // user's video preference for the current track instead of dropping it.
      document.documentElement.classList.remove(ROOT_CLASS);
      lastShownVideo = false;
      reportState(id, false, false);
      return;
    }

    var wantVideo = preferredVideoID === id;

    // Never reload the player underneath an advertisement.
    if (isAdPlaying()) {
      reportState(id, true, isVideoStream());
      return;
    }

    if (!mediaReady()) {
      // Keep the artwork over the black player area while the track loads.
      document.documentElement.classList.toggle(ROOT_CLASS, !wantVideo);
      if (!wantVideo) { applyArtwork(); }
      reportState(id, true, false);
      return;
    }

    if (!wantVideo) {
      if (isVideoStream() && !audioLoadInFlight && forcedAudioID !== id) {
        forcedAudioID = id;
        fallbackAudioID = id;
        retryCount = 0;
        reloadCurrent(true, currentTime(), isPlaying());
      } else if (isVideoStream() && !audioLoadInFlight && fallbackAudioID === id && retryCount < 1) {
        // One retry in case the first fallback load raced the player's startup.
        retryCount += 1;
        reloadCurrent(true, currentTime(), isPlaying());
      }
      document.documentElement.classList.add(ROOT_CLASS);
      applyArtwork();
    } else {
      if (isAudioOnlyStream() && !audioLoadInFlight) {
        reloadCurrent(false, currentTime(), isPlaying());
      }
      document.documentElement.classList.remove(ROOT_CLASS);
    }

    var videoVisible = isVideoStream() && !document.documentElement.classList.contains(ROOT_CLASS);
    if (videoVisible !== lastShownVideo) {
      setTimeout(reflowVideo, 30);
      setTimeout(reflowVideo, 200);
      lastShownVideo = videoVisible;
    }
    reportState(id, true, videoVisible);
  }

  function isVideoVisible() {
    var id = currentVideoID();
    return !!id && preferredVideoID === id && isVideoStream() &&
           !document.documentElement.classList.contains(ROOT_CLASS);
  }

  function setVideoVisible(visible) {
    var id = currentVideoID();
    if (!id || !hasVideo()) { return; }
    var player = movie();
    if (!player) { return; }

    var start = currentTime();
    var play = isPlaying();

    if (visible) {
      preferredVideoID = id;
      forcedAudioID = '';
      fallbackAudioID = '';
      retryCount = 0;
      document.documentElement.classList.remove(ROOT_CLASS);
      reloadCurrent(false, start, play);
    } else {
      preferredVideoID = null;
      forcedAudioID = '';
      fallbackAudioID = id;
      retryCount = 0;
      document.documentElement.classList.add(ROOT_CLASS);
      applyArtwork();
      reloadCurrent(true, start, play);
    }

    setTimeout(apply, 80);
    setTimeout(apply, 1000);
  }

  function toggleVideo() {
    if (isVideoVisible()) {
      setVideoVisible(false);
    } else {
      setVideoVisible(true);
    }
  }

  window.__ytmAudioOnly = {
    version: 3,
    apply: apply,
    hasVideo: hasVideo,
    isVideoVisible: isVideoVisible,
    setVideoVisible: setVideoVisible,
    toggle: toggleVideo,
    isAudioOnlyStream: isAudioOnlyStream,
    audioOnlyAllowed: audioOnlyAllowed,
    debug: function () {
      return {
        apiHooked: apiHooked,
        hasPlayerApi: !!playerApi(),
        preferredVideoID: preferredVideoID,
        forcedAudioID: forcedAudioID,
        fallbackAudioID: fallbackAudioID,
        lastLoadVideoID: lastLoadVars && lastLoadVars.video_id,
        lastLoadAudioOnly: lastLoadVars && lastLoadVars.audio_only,
        classAudioOnly: document.documentElement.classList.contains(ROOT_CLASS)
      };
    }
  };

  startHooking();

  document.addEventListener('yt-navigate-finish', function () { setTimeout(apply, 60); }, true);
  document.addEventListener('yt-page-data-updated', function () { setTimeout(apply, 60); }, true);
  document.addEventListener('yt-player-updated', function () { setTimeout(apply, 60); }, true);
  document.addEventListener('durationchange', function () { setTimeout(apply, 60); }, true);
  document.addEventListener('loadedmetadata', function () { setTimeout(apply, 60); }, true);

  setInterval(apply, 1000);
  // The player API object is recreated on some SPA navigations. Keep checking
  // so the next queue load is wrapped as early as possible.
  setInterval(hookPlayerApi, 500);
  apply();
})();
