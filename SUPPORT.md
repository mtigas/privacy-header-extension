# GPC Switch support

Help with GPC Switch ("GPC Privacy Switch" on the App Store): a Safari extension for iPhone,
iPad and Mac that sends the Global Privacy Control and Do Not Track privacy signals to the
websites you visit.

- [Frequently asked questions](#frequently-asked-questions)
- [Still need help?](#still-need-help)

## Frequently asked questions

### How do I turn it on (iPhone and iPad)?

Installing the app doesn't turn the extension on; Safari leaves that to you.

1. Open the **Settings** app and go to **Apps › Safari › Extensions**.
   On iOS 26.2 or later you can also open the GPC Switch app and tap
   **Open Safari Extensions Settings**.
2. Tap **GPC Switch**.
3. Turn on **Allow Extension**.
4. Under **Permissions**, tap **All Websites** and choose **Allow**.
   The default is **Ask**, and until you allow it, the extension sends nothing.
5. *(Optional)* Turn on **Allow in Private Browsing** if you want the signals sent in Private
   tabs too.
6. Reload any Safari tabs that were already open.

Safari then shows "This extension can read and alter webpages you visit and see your browsing
history on all websites." That is Safari's standard wording for any extension with website
access. GPC Switch uses that access only to add the privacy signals and to check whether the
site you're on is one where they're turned off. It doesn't read or change what's on the page,
and it collects nothing (see the [privacy policy](PRIVACY.md)).

### How do I turn it on (Mac)?

1. Open the GPC Switch app and click **Open Safari Extensions Settings…**, or in Safari choose
   **Safari › Settings… › Extensions**.
2. Tick **GPC Switch**.
3. Click **Always Allow on Every Website…** and confirm.
4. Reload any Safari tabs that were already open.

### How can I tell it's working?

- In the GPC Switch app, the status reads **Enabled** once Safari reports the extension is on.
- In Safari, open [gpc.webiterate.dev](https://gpc.webiterate.dev). With GPC Switch on, it
  shows the `Sec-GPC` header as **Detected**, the JavaScript signal as **Enabled**, and
  **Fully Configured**. Open it in Safari: the app's "Global Privacy Control Tester" link opens
  your default browser, and the extension only works in Safari.

### The app says "Status Not Available" or "Unknown"

On iOS versions before 26.2, apps can't ask Safari whether an extension is on, so the app can't
show a status. Follow the steps above and check with the tester page instead.

If the app shows "Unknown" with an error, quit and reopen it; if that doesn't help, check that
GPC Switch is turned on in Safari's extension settings.

### It isn't sending the signal on a particular site

- **The site may be on the disabled list.** A few dozen sites are known to break when they
  receive these signals (login errors, endless reloads, buttons that stop working), so GPC
  Switch turns the signals off on them and their subdomains. The app lists them under
  **Disabled Sites**, and on those sites the extension's toolbar icon shows an **OFF** badge.
  The list comes from [DuckDuckGo's privacy configuration](https://github.com/duckduckgo/privacy-configuration).
- **Check website access.** If GPC Switch is allowed on only some websites, or set to Ask, it
  sends nothing elsewhere. Set **All Websites** to **Allow** (iPhone and iPad) or use
  **Always Allow on Every Website…** (Mac).
- **Private Browsing** has its own setting: turn on **Allow in Private Browsing** for GPC Switch.

### A site breaks when GPC Switch is on

Turn the extension off for a moment to confirm, then
[report it](https://github.com/mtigas/privacy-header-extension/issues/new/choose) with the
site's address and what goes wrong, so it can be considered for the disabled list.

### Does it block ads or trackers?

No. GPC Switch only sends the opt-out signals. Each site decides whether to honor them; in
several US states, businesses are required to.

### What does it collect?

Nothing. There are no accounts, no analytics and no network requests of its own; see the
[privacy policy](PRIVACY.md).

## Still need help?

- [See issues and feedback submitted by others](https://github.com/mtigas/privacy-header-extension/issues/)
- [Use a GitHub account to report a new issue](https://github.com/mtigas/privacy-header-extension/issues/new/choose)
- For issues and questions not covered above, email
  [mtigas.appledev@mercurymail.io](mailto:mtigas.appledev@mercurymail.io).
