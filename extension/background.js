// Badges the toolbar icon on sites where the signals are deliberately off.
//
// This is the extension's only background code, and it exists only for the
// badge: the headers come from the static ruleset and the navigator values
// from the manifest content script, neither of which needs it. It is a
// non-persistent background *page* (manifest `background.scripts`), not a
// service worker, because Lockdown Mode kills service-worker backgrounds but
// leaves pages alone. If it ever fails to run, only the badge is lost.
//
// It makes no network requests: the site list is read from the bundle, via
// popup/exceptions.js (listed before this file in the manifest).

(function () {
  "use strict";

  var api = (typeof browser !== "undefined") ? browser : chrome;
  var BADGE = "OFF";

  // Safari only exposes tab.url when the extension has access to that site,
  // so a tab without a url simply gets no badge.
  async function updateBadge(tab) {
    if (!tab || typeof tab.id !== "number") {
      return;
    }
    var hostname = tab.url ? GPCSwitchExceptions.hostnameOf(tab.url) : null;
    var text = (await GPCSwitchExceptions.isExcluded(hostname)) ? BADGE : "";
    try {
      await api.action.setBadgeText({ tabId: tab.id, text: text });
    } catch (e) {
      // The tab may have closed; nothing to do.
    }
  }

  async function updateAllTabs() {
    try {
      var tabs = await api.tabs.query({});
      await Promise.all(tabs.map(updateBadge));
    } catch (e) {
      // Without tabs access there is nothing to badge.
    }
  }

  // It returns a promise, so an engine that rejects it is caught here too.
  Promise.resolve()
    .then(function () { return api.action.setBadgeBackgroundColor({ color: "#D6A21E" }); })
    .catch(function () { /* the default colour is fine */ });

  api.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
    if (changeInfo.url !== undefined || changeInfo.status === "loading" || changeInfo.status === "complete") {
      updateBadge(tab);
    }
  });

  api.tabs.onActivated.addListener(async function (info) {
    try {
      updateBadge(await api.tabs.get(info.tabId));
    } catch (e) {
      // Tab gone.
    }
  });

  if (api.runtime.onStartup) {
    api.runtime.onStartup.addListener(updateAllTabs);
  }
  if (api.runtime.onInstalled) {
    api.runtime.onInstalled.addListener(updateAllTabs);
  }
  updateAllTabs();
}());
