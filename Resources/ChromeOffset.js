(function () {
  'use strict';
  try {
    if (document.getElementById('ytm-native-chrome')) { return; }

    if (location.hostname !== 'music.youtube.com') {
      document.documentElement.setAttribute('data-ytm-external', '');
    }

    var style = document.createElement('style');
    style.id = 'ytm-native-chrome';
    style.textContent =
      ':root{--ytm-chrome-inset:28px;}' +
      'ytmusic-app{margin-top:var(--ytm-chrome-inset)!important;height:calc(100vh - var(--ytm-chrome-inset))!important;}' +
      'html[data-ytm-external] body{padding-top:var(--ytm-chrome-inset)!important;}';

    (document.head || document.documentElement).appendChild(style);
  } catch (e) {}
})();
