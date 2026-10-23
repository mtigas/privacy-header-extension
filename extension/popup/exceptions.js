// The site-exception lookup shared by the popup and the background page.
//
// The list is the same file the header rules and signal.js's host list are
// generated from (tools/update-site-exceptions.py), read from the extension
// bundle.

var GPCSwitchExceptions = (function () {
  "use strict";

  var api = (typeof browser !== "undefined") ? browser : chrome;
  var hostsPromise = null;

  function hosts() {
    if (!hostsPromise) {
      hostsPromise = fetch(api.runtime.getURL("rules/site-exceptions.json"))
        .then(function (response) { return response.json(); })
        .then(function (data) {
          return Array.isArray(data.sites) ? data.sites.map(function (site) { return site.domain; }) : [];
        })
        .catch(function () { return []; });
    }
    return hostsPromise;
  }

  // The hostname of an http(s) URL, or null.
  function hostnameOf(url) {
    try {
      var parsed = new URL(url);
      if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
        return null;
      }
      return parsed.hostname;
    } catch (e) {
      return null;
    }
  }

  // The rules exclude a host and its subdomains.
  async function isExcluded(hostname) {
    if (!hostname) {
      return false;
    }
    var list = await hosts();
    return list.some(function (host) {
      return hostname === host || hostname.endsWith("." + host);
    });
  }

  return { hostnameOf: hostnameOf, isExcluded: isExcluded };
}());
