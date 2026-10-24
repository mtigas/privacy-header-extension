import Foundation
import Observation
import SafariServices

/// What the app can find out about its Safari extension, and the one thing it can do
/// about it (send the user to Safari's extension settings).
@MainActor @Observable final class ExtensionStatus {

    /// The extension's position on the status indicator. Safari only reports whether
    /// the extension is enabled, not which websites it is allowed on, so "on, but not
    /// for all websites" can't be told apart from on.
    enum State: String {
        case unknown, off, on
    }

    static let extensionIdentifier = "com.miketigas.GPCSwitch.Extension"

    private(set) var state: State = .unknown

    /// Whether a query has come back from Safari yet. Until then `.unknown` means
    /// "still checking", not "the check failed".
    private(set) var hasChecked = false

    /// A description of the last failed query, if any.
    private(set) var lastError: String?

    /// A description of the last failed attempt to open Safari's settings, if any. A
    /// refresh doesn't clear it; the next attempt does.
    private(set) var settingsError: String?

    /// Whether `openSafariSettings()` can do anything on this system.
    var canOpenSettings: Bool {
#if os(macOS)
        return true
#else
        if #available(iOS 26.2, *) {
            return true
        }
        return false
#endif
    }

    /// Asks Safari whether the extension is enabled.
    func refresh() async {
#if DEBUG
        if ScreenshotMode.isOn {
            apply(.enabled(true))
            return
        }
#endif
#if os(macOS)
        startDeadline()
        apply(await Self.probe())
#else
        if #available(iOS 26.2, *) {
            startDeadline()
            apply(await Self.probe())
        } else {
            state = .unknown
            lastError = nil
        }
#endif
    }

    /// Stops showing "checking" if Safari hasn't answered the first query in a few
    /// seconds. A late answer still replaces this.
    private func startDeadline() {
        guard !hasChecked else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard !hasChecked else { return }
            hasChecked = true
            lastError = "Safari didn't answer."
        }
    }

    /// Opens Safari's settings for this extension. The app stays open.
    func openSafariSettings() {
        settingsError = nil
        Task {
            do {
#if os(macOS)
                try await SFSafariApplication.showPreferencesForExtension(withIdentifier: Self.extensionIdentifier)
#else
                if #available(iOS 26.2, *) {
                    try await SFSafariSettings.openExtensionsSettings(forIdentifiers: [Self.extensionIdentifier])
                }
#endif
            } catch {
                settingsError = error.localizedDescription
            }
        }
    }

    // MARK: - Querying Safari

    /// The outcome of one state query.
    private enum Probe {
        case enabled(Bool)
        case failed(String)
    }

    private func apply(_ probe: Probe) {
        hasChecked = true
        switch probe {
        case .enabled(true):
            state = .on
            lastError = nil
            settingsError = nil
        case .enabled(false):
            state = .off
            lastError = nil
        case .failed(let message):
            state = .unknown
            lastError = message
        }
    }

    // The async forms rather than the completion-handler ones: the macOS SDK marks
    // getStateOfSafariExtension's handler NS_SWIFT_UI_ACTOR, but SafariServices calls
    // it on its XPC queue, so a hand-written closure trips Swift 6's main-actor check.
    // The compiler-generated bridge behind the async form has no such check.
#if os(macOS)
    private static func probe() async -> Probe {
        do {
            let state = try await SFSafariExtensionManager.stateOfSafariExtension(withIdentifier: extensionIdentifier)
            return .enabled(state.isEnabled)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
#else
    @available(iOS 26.2, *)
    private static func probe() async -> Probe {
        do {
            let state = try await SFSafariExtensionManager.stateOfExtension(withIdentifier: extensionIdentifier)
            return .enabled(state.isEnabled)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
#endif

}
