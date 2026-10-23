// Status-only popup. The extension has no settings: the header rules are a
// static ruleset and the navigator shim is a manifest content script, so
// turning the extension off in Safari is the on/off switch.
//
// It shows one thing: whether the signals go out on the current site. Safari
// only shows this popup when the extension is enabled and allowed on the
// site, so the answer is "enabled" unless the site is on the exception list
// (rules/site-exceptions.json). The popup doesn't try to report website
// access itself: Safari's permissions API doesn't reliably say whether the
// user chose "Always Allow on Every Website".

(function () {
  "use strict";

  var api = (typeof browser !== "undefined") ? browser : chrome;

  function setRow(id, state, text) {
    var row = document.getElementById(id);
    row.classList.remove("ok", "bad", "warn");
    if (state) {
      row.classList.add(state);
    }
    row.querySelector(".value").textContent = text;
  }

  function showHint(text) {
    var hint = document.getElementById("hint");
    hint.textContent = text;
    hint.hidden = !text;
  }

  // Safari only exposes tab.url when the extension has access to the site,
  // and pages such as the start page have no web URL at all.
  async function activeTabHostname() {
    try {
      var tabs = await api.tabs.query({ active: true, currentWindow: true });
      var tab = tabs && tabs[0];
      if (!tab || !tab.url) {
        return null;
      }
      return GPCSwitchExceptions.hostnameOf(tab.url);
    } catch (e) {
      return null;
    }
  }

  async function run() {
    var hostname = await activeTabHostname();

    if (!hostname) {
      setRow("signals", null, "not on this page");
      showHint("GPC Switch does not run on special pages, like the Safari home page.");
      return;
    }

    if (await GPCSwitchExceptions.isExcluded(hostname)) {
      setRow("signals", "bad", "disabled");
      showHint("GPC Switch is disabled on this site: " + hostname + " has known issues when using the GPC privacy signals. For further information on disabled sites, open the GPC Switch app.");
      return;
    }

    setRow("signals", "ok", "enabled");
    showHint("");
  }

  run();
}());
