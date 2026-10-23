# GPC Switch privacy policy

Effective 2026-10-23.

GPC Switch (App Store name: GPC Privacy Switch) is a Safari extension and a small app that
goes with it. It collects no data. This page explains what it does and what it doesn't.

## What the extension does

When you turn it on and allow it on websites, the extension adds two headers to the web
requests Safari sends:

- `Sec-GPC: 1`, the [Global Privacy Control](https://globalprivacycontrol.org/) signal
- `DNT: 1`, the older [Do Not Track](https://www.w3.org/TR/tracking-dnt/) signal

It also makes `navigator.globalPrivacyControl` report `true` and `navigator.doNotTrack`
report `"1"` to scripts on those pages.

About sixty sites are excluded, because they are known to break when they receive the
signals; while you are on those sites the extension sends nothing. The list is copied from
DuckDuckGo's open-source privacy configuration and ships inside the app, where you can see it
along with a link to each report. It is not fetched while you browse.

Those signals are the whole point: they tell the websites you visit, and the third parties on
those sites, that you don't want your data sold or shared and don't want to be tracked. Any
site that receives a request from Safari can see them. Whether a site honors them is up to the
site.

## What it does not do

- It does not collect, store, log or transmit your browsing history, the pages you visit, page
  content, or anything else about you.
- It makes no network requests of its own. It has no server, no account and no sign-in.
- It has no analytics, crash reporting, advertising or third-party SDKs.
- The headers come from a fixed set of rules that Safari applies itself, and the page script
  only sets those two `navigator` values.
- To show the "OFF" badge on excluded sites, the extension's background code compares each
  tab's address with the built-in list as pages load, and the toolbar popup does the same for
  the current tab. This happens on your device; nothing is stored or sent. The list is bundled
  with the extension, and this code makes no requests.
- The extension asks Safari for access to "All Websites" so that the signal reaches the
  sites you visit. That access is used only to add the headers and set the two values described above.

## The app

The app shows whether the extension is on, links to Safari's extension settings, and has an
optional tip jar. The app does not collect personal data or contact any server of mine.

- **Tips.** Tips are one-time in-app purchases processed entirely by Apple through the App
  Store. They unlock nothing. I never see your name, Apple Account, payment method or any other
  personal detail; Apple gives me only aggregated sales reports that don't identify you. Apple's
  own privacy policy governs the purchase.
- **Data on your device.** The app remembers your most recent tip, using the system's
  `UserDefaults` storage, so it can show it later. This stays on your device. It is never sent
  to me or to anyone else.
- **Links.** The app links to the source code, this policy, the licence and third-party notices, information about
  GPC and a GPC test page, the developer's site and Onion Browser. Those open in your browser,
  and those sites have their own policies.

Apple's App Privacy label for GPC Switch reads "Data Not Collected". The app's privacy
manifest declares no tracking and no collected data.

## Open source

The extension and the app are open source under the MPL-2.0 license, so you can check all of
this: <https://github.com/mtigas/privacy-header-extension>

## Children

The app collects no personal information from anyone, including children.

## Changes to this policy

If this policy changes, the new version will be published at this address with a new effective
date, and the earlier versions stay in the repository's history.

## Contact

Mike Tigas. Open an issue at
<https://github.com/mtigas/privacy-header-extension/issues>.
