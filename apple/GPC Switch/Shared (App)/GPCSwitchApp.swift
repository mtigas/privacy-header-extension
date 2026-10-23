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
