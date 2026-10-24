import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {

    @State private var status = ExtensionStatus()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollViewReader { proxy in
            form
#if DEBUG
                .task {
                    // Screenshot mode: give the list a moment to lay out first.
                    guard let target = ScreenshotMode.scrollTarget else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    proxy.scrollTo(target, anchor: .top)
                }
#endif
        }
    }

    private var form: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Image("LargeIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .accessibilityHidden(true)
                    Text("GPC Switch")
                        .font(.title.weight(.semibold))

                    VStack(spacing: 6) {
                        Text(statusHeadline.text)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(statusHeadline.color)
                            .padding(.top, 8)
                            .accessibilityLabel("Extension status: \(statusHeadline.text)")
                        Text(statusMessage.primary)
                        if let secondary = statusMessage.secondary {
                            Text(secondary)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                    if status.canOpenSettings {
                        Button(openSettingsTitle) {
                            status.openSafariSettings()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 4)

                        if let settingsError = status.settingsError {
                            Text("Couldn't open Safari's settings: \(settingsError)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Text("This Safari extension sends the 'Global Privacy Control' (GPC) and 'Do Not Track' (DNT) privacy signals to websites you visit in\u{00A0}Safari.\n\nOn sites that honor it, GPC registers your opt-out of the sale or sharing of your data without your having to find each site's 'Do Not Sell or Share' link. Several US states require businesses to honor GPC, and regulators have taken enforcement action against companies that ignored\u{00A0}it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Link("What is Global Privacy Control?",
                     destination: URL(string: "https://globalprivacycontrol.org/")!)
                    .id("links")
                Link("List of GPC-related enforcement actions",
                     destination: URL(string: "https://en.wikipedia.org/wiki/Global_Privacy_Control#Enforcement_actions")!)
                Link("Global Privacy Control Tester",
                     destination: URL(string: "https://gpc.webiterate.dev")!)
            } footer: {
                Text("Learn more about the Global Privacy Control, and test that you've enabled the extension properly above. Open the tester in\u{00A0}Safari.")
            }

            if let exceptions = SiteExceptions.shipped {
                Section {
                    DisclosureGroup {
                        ForEach(exceptions.sites) { site in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(site.domain)
                                    .font(.callout.monospaced())
                                if let url = site.reasonURL {
                                    Link("Reported breakage", destination: url)
                                        .font(.footnote)
                                        .accessibilityLabel("Reported breakage on \(site.domain)")
                                } else if !site.reason.isEmpty {
                                    Text(site.reason)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            // macOS forms center a row's content when it doesn't fill the row.
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } label: {
                        Text("Disabled Sites (\(exceptions.sites.count))")
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sites where the privacy signals cause known issues (login errors, endless reloads, buttons that stop working). GPC Switch turns the GPC/DNT signals off while you're on these sites or their subdomains. This list is derived from DuckDuckGo's open-source privacy configuration as of \(exceptions.fetched), used under the \(exceptions.license) license.")
                        if let source = URL(string: exceptions.source) {
                            Link("Source: DuckDuckGo's privacy configuration", destination: source)
                                .font(.footnote)
                        }
                    }
                }
            }

            TipJarView()

            Section {
                Link("Source Code on GitHub",
                     destination: URL(string: "https://github.com/mtigas/privacy-header-extension")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://github.com/mtigas/privacy-header-extension/blob/main/PRIVACY.md")!)
                Link("License",
                     destination: URL(string: "https://github.com/mtigas/privacy-header-extension/blob/main/LICENSE")!)
                Link("Additional licenses and notices",
                     destination: URL(string: "https://github.com/mtigas/privacy-header-extension/blob/main/NOTICE")!)
            } header: {
                Text("GPC Switch")
            } footer: {
                // A string literal here is Markdown, so the links are tappable in place.
                VStack(spacing: 2) {
                    Text(versionText)
                    Text("Made in Chicago by [Mike Tigas](https://mike.tig.as/). Want something more anonymous? [Try Onion\u{00A0}Browser](https://onionbrowser.com/).")
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .formStyle(.grouped)
#if os(macOS)
        .frame(minWidth: 440, maxWidth: 440, minHeight: 560)
#endif
        .task {
            await status.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await status.refresh()
            }
        }
#if os(macOS)
        // The window stays on screen while Safari's settings are in front, so the scene
        // never leaves .active; refresh when the app comes back to the front instead.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await status.refresh()
            }
        }
#endif
    }

    // MARK: - Copy

    private var openSettingsTitle: String {
#if os(macOS)
        "Open Safari Extensions Settings…"
#else
        "Open Safari Extensions Settings"
#endif
    }

    /// The one-line verdict above the explanation. Safari only says whether the extension
    /// is enabled, so that is the only thing stated boldly.
    private var statusHeadline: (text: String, color: Color) {
        switch status.state {
        case .on:
            return ("Enabled", .green)
        case .off:
            return ("Not Enabled", .primary)
        case .unknown:
            guard status.canOpenSettings else {
                // iOS before 26.2: not a failure, the system just doesn't say.
                return ("Status Not Available", .secondary)
            }
            return (status.hasChecked ? "Unknown" : "Checking…", .secondary)
        }
    }

    private var statusMessage: (primary: String, secondary: String?) {
        switch status.state {
        case .on:
            return ("The GPC Switch extension is turned on in Safari. It only sends the GPC signals to websites you've allowed it on, so make sure you've \(allowedEverywhere).",
                    nil)
        case .off:
            return ("GPC Switch is turned off. Turn it on in Safari's extension settings, then \(allowEverywhere).",
                    nil)
        case .unknown:
            if status.canOpenSettings {
                guard status.hasChecked else {
                    return ("Checking Safari…", nil)
                }
                // The query itself failed; say so and point at the settings anyway.
                return ("Couldn't check whether the extension is on.", status.lastError ?? settingsPath)
            }
            return ("This version of iOS doesn't let apps see whether the extension is on. Open Settings › Apps › Safari › Extensions, turn on GPC Switch, and set 'All Websites' to\u{00A0}'Allow'.",
                    nil)
        }
    }

    /// How to grant access to every website, in each platform's own words.
    private var allowEverywhere: String {
#if os(macOS)
        "click 'Always Allow on Every\u{00A0}Website…'"
#else
        "set 'All Websites' to\u{00A0}'Allow'"
#endif
    }

    private var allowedEverywhere: String {
#if os(macOS)
        "clicked 'Always Allow on Every\u{00A0}Website…'"
#else
        "set 'All Websites' to\u{00A0}'Allow'"
#endif
    }

    private var settingsPath: String {
#if os(macOS)
        "Safari › Settings › Extensions › GPC Switch"
#else
        "Settings › Apps › Safari › Extensions › GPC Switch"
#endif
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

}

#Preview {
    ContentView()
}
