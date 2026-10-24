import StoreKit
import SwiftUI

@main
struct GPCSwitchApp: App {

    /// Finishes every transaction that arrives outside the purchase flow (a tip
    /// interrupted before `finish()`, an Ask to Buy approval) so StoreKit never keeps
    /// redelivering it, and remembers verified tips. A tip unlocks nothing, so an
    /// unverified one is finished too. Held in a static so it starts exactly once no
    /// matter how often SwiftUI initialises the App value.
    private static let transactionListener = Task.detached {
        for await update in Transaction.updates {
            switch update {
            case .verified(let transaction):
                await TipJarView.LastTip(transaction: transaction)?.save()
                await transaction.finish()
            case .unverified(let transaction, _):
                await transaction.finish()
            }
        }
    }

    init() {
        _ = Self.transactionListener
    }

    var body: some Scene {
#if os(macOS)
        // A single-window utility. A `Window` scene never offers File > New Window, is
        // listed in the Window menu, and quits the app when it is closed.
        Window("GPC Switch", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 640)
#else
        WindowGroup {
            ContentView()
        }
#endif
    }

}

#if DEBUG
/// Launch arguments for taking App Store screenshots, read from the arguments domain of
/// `UserDefaults` (`-GPCSwitchScreenshots YES`). Debug builds only.
///
/// A simulator launched from the command line has no StoreKit configuration and an
/// unreliable Safari extension switch, so this mode shows what a user with the extension
/// on would see: the status reads Enabled and the tip row shows the real product's name
/// and price without asking StoreKit.
enum ScreenshotMode {
    static var isOn: Bool {
        UserDefaults.standard.bool(forKey: "GPCSwitchScreenshots")
    }

    /// `-GPCSwitchScrollTo links` scrolls the links section to the top, which brings the
    /// tip jar into view. (Scrolling any further runs into the end of the list, which
    /// leaves rows under the status bar.)
    static var scrollTarget: String? {
        isOn ? UserDefaults.standard.string(forKey: "GPCSwitchScrollTo") : nil
    }
}
#endif
