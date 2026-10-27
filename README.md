# GPC Switch

A minimal Safari web extension for macOS and iOS that sends the
[Global Privacy Control](https://globalprivacycontrol.org/) and
[Do Not Track](https://www.w3.org/TR/tracking-dnt/) signals, and does nothing else.

On the App Store as [GPC Privacy Switch](https://apps.apple.com/app/gpc-privacy-switch/id6826449971), for iPhone, iPad and Mac.

<a href="https://apps.apple.com/app/gpc-privacy-switch/id6826449971">
<img src="design/app-store-badge/download-on-the-app-store-black.svg" alt="Download on the App Store" height="48">
</a>

| | |
|---|---|
| Requires | iOS 18 / macOS 15 or later; one universal App Store record for both |
| Privacy | Collects nothing, sends nothing: [`PRIVACY.md`](PRIVACY.md) |
| Support | Setup help, FAQ and contact: [`SUPPORT.md`](SUPPORT.md) |
| License | MPL-2.0 |

- Page, subresource, iframe, fetch/XHR and redirect requests from sites the extension is
  allowed on get `Sec-GPC: 1` and `DNT: 1`.
- Pages on those sites get `navigator.globalPrivacyControl === true` and
  `navigator.doNotTrack === "1"`, in the top frame and in iframes (including `about:blank`
  and `srcdoc` frames).

Those are the same headers and `navigator` values Privacy Badger sets, without its tracker
blocking, and with DuckDuckGo's site-exception list instead of Privacy Badger's. The idea is
[OptMeowt](https://github.com/privacy-tech-lab/gpc-optmeowt)-style signalling for Safari.

## How it works

The signals themselves are entirely declarative; the only background code is a tiny page that
badges the toolbar icon:

| Piece | Mechanism | File |
|---|---|---|
| Request headers | A static `declarativeNetRequest` ruleset with two `modifyHeaders` rules: one for `main_frame`, one with no `resourceTypes` (which in DNR means "every type except `main_frame`"); both carry the site exceptions as `excludedDomains`. | [`extension/rules/privacy-signal-headers.json`](extension/rules/privacy-signal-headers.json) |
| JS signal | A manifest `content_scripts` entry that runs in the page's **main world** at `document_start` in all frames and defines accessors on `Navigator.prototype`. | [`extension/signal.js`](extension/signal.js) |
| Toolbar badge | A non-persistent background *page* (`background.scripts`, not a service worker, so it survives Lockdown Mode) watches tab navigations and shows an "OFF" badge on the toolbar icon on excluded sites. It reads the site list from the bundle and makes no requests; if it fails to run, only the badge is lost. | [`extension/background.js`](extension/background.js) |
| Toolbar popup | Status only: "Sending GPC signals: enabled" on the current site, or "disabled" (with the reason) on a site from the exception list. Safari only shows the popup where the extension is enabled and allowed, and its permissions API doesn't reliably report "Always Allow on Every Website", so the popup doesn't try to report access. | [`extension/popup/`](extension/popup/) |
| Site exceptions | A list of sites that break when they receive the signals, with a reason for each, copied from DuckDuckGo's privacy configuration (`features/gpc.json`, Apache-2.0). It becomes `excludedDomains` on the two header rules (WebKit matches the top-level page, host and subdomains); a third, higher-priority rule removes both headers from documents whose own URL is an excluded site, because a redirect into one keeps the headers set on the first hop. `signal.js` carries the same host list and, like the header rules, decides by the top-level page (`location.ancestorOrigins`), so frames get the script signal exactly when they get the headers. The app, popup and badge read the same file. Refresh it deliberately with `uv run python3 tools/update-site-exceptions.py`; nothing fetches at build or run time. | [`extension/rules/site-exceptions.json`](extension/rules/site-exceptions.json), [`tools/update-site-exceptions.py`](tools/update-site-exceptions.py) |

Turning the extension off in Safari is the on/off switch. There are no settings.

The extension makes no network requests of its own and collects no data; see [`PRIVACY.md`](PRIVACY.md).

California's AB 566 requires browsers to offer an opt-out preference signal, effective January 1, 2027. Safari does not yet have a GPC setting as of October 2026. This extension fills that gap, and will continue to do so for Safari versions prior to the built-in becoming available.

## License

MPL-2.0, see [LICENSE](LICENSE). Copyright Mike Tigas.

The site-exception list is derived from DuckDuckGo's privacy configuration (Apache-2.0); see
[NOTICE](NOTICE).
