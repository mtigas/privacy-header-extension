import StoreKit
import SwiftUI

/// A one-time tip jar. It unlocks nothing and gates nothing; Apple handles the whole
/// transaction, so the app learns only that a tip happened and how much it showed.
struct TipJarView: View {

    /// The consumable tip product. A list, so a second tier can be added without touching
    /// the purchase handling.
    static let productIDs = [
        "com.miketigas.GPCSwitch.tip.small",
    ]

    private static let blurb = """
        GPC Switch is free and open source. If it's useful to you, you can show your appreciation with a one-time tip. It's not a subscription, and no extra features are\u{00A0}unlocked.\n\n(Privacy: Tipping is via in-app purchase, and handled through Apple. The developer cannot see who tipped within the app, and only aggregate sales numbers are received from\u{00A0}Apple.)
        """

    private enum Availability {
        case loading
        case available([Product])
        case unavailable
#if DEBUG
        /// Screenshot mode: the product as App Store Connect and GPC Switch.storekit define it.
        case screenshot
#endif
    }

    @State private var availability = Availability.loading
    @State private var purchaseMessage: String?
    @State private var lastTip = Self.initialLastTip

    var body: some View {
        Section {
            Group {
                switch availability {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .available(let products):
                    ForEach(products, id: \.id) { product in
                        ProductView(product)
                            .productViewStyle(TipRowStyle())
                    }
                    if let purchaseMessage {
                        Text(purchaseMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                case .unavailable:
                    Text("Tips aren't available right now.")
                        .foregroundStyle(.secondary)
#if DEBUG
                case .screenshot:
                    TipRow(name: "Small Tip", detail: "A one-time thank-you.", price: "$0.99") {}
#endif
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: LastTip.didChange)) { _ in
                lastTip = Self.initialLastTip
                purchaseMessage = nil
            }
            .onInAppPurchaseCompletion { product, result in
                await handle(product: product, result: result)
            }
        } header: {
            // The header is the one stable view in this section, so it owns the load.
            Text("Tip Jar")
                .task {
                    await loadProducts()
                }
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.blurb)
                if let lastTip {
                    Text("You last tipped \(lastTip.amount) on \(lastTip.date.formatted(date: .abbreviated, time: .omitted)). Thank you!")
                }
            }
        }
    }

    /// The last tip to show in the footer; none in screenshot mode, so a tip made while
    /// testing on the same device doesn't appear in the App Store images.
    private static var initialLastTip: LastTip? {
#if DEBUG
        if ScreenshotMode.isOn {
            return nil
        }
#endif
        return LastTip.load()
    }

    // MARK: - StoreKit

    private func loadProducts() async {
#if DEBUG
        if ScreenshotMode.isOn {
            availability = .screenshot
            return
        }
#endif
        do {
            let products = try await Product.products(for: Self.productIDs)
            let ordered = products.sorted { lhs, rhs in
                (Self.productIDs.firstIndex(of: lhs.id) ?? .max) < (Self.productIDs.firstIndex(of: rhs.id) ?? .max)
            }
            availability = ordered.isEmpty ? .unavailable : .available(ordered)
        } catch {
            availability = .unavailable
        }
    }

    private func handle(product: Product, result: Result<Product.PurchaseResult, any Error>) async {
        switch result {
        case .success(let purchase):
            switch purchase {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    let tip = LastTip(transaction: transaction) ?? LastTip(date: .now, amount: product.displayPrice)
                    tip.save()
                    lastTip = tip
                    purchaseMessage = nil
                case .unverified(let transaction, _):
                    // A tip unlocks nothing, so there is nothing to withhold; finish it
                    // so StoreKit stops redelivering it, but don't record it.
                    await transaction.finish()
                    purchaseMessage = "Thanks! Apple couldn't confirm this purchase on this device."
                }
            case .pending:
                purchaseMessage = "Waiting for approval. Thanks!"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        case .failure:
            purchaseMessage = "The tip didn't go through. You can try again later."
        }
    }

    // MARK: - Remembering the last tip

    struct LastTip {
        static let dateKey = "lastTipDate"
        static let amountKey = "lastTipAmount"
        /// Posted after a tip is saved, so a tip approved later (Ask to Buy) shows without a relaunch.
        static let didChange = Notification.Name("GPCSwitchLastTipDidChange")

        let date: Date
        let amount: String

        init(date: Date, amount: String) {
            self.date = date
            self.amount = amount
        }

        static func load() -> LastTip? {
            let defaults = UserDefaults.standard
            guard let date = defaults.object(forKey: dateKey) as? Date,
                  let amount = defaults.string(forKey: amountKey) else {
                return nil
            }
            return LastTip(date: date, amount: amount)
        }

        /// A tip that completed outside the purchase flow, such as an approved Ask to Buy
        /// request. Returns nil for anything that isn't a tip or has no price.
        init?(transaction: StoreKit.Transaction) {
            guard TipJarView.productIDs.contains(transaction.productID),
                  let price = transaction.price,
                  let currency = transaction.currency else {
                return nil
            }
            self.init(date: transaction.purchaseDate,
                      amount: price.formatted(.currency(code: currency.identifier)))
        }

        func save() {
            let defaults = UserDefaults.standard
            defaults.set(date, forKey: Self.dateKey)
            defaults.set(amount, forKey: Self.amountKey)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

}

/// A product row without the icon slot: name and description on the left, the price as
/// the buy button on the right. StoreKit's built-in styles reserve space for a promotional
/// image, which shows as an empty square when the product has none.
struct TipRowStyle: ProductViewStyle {

    func makeBody(configuration: Configuration) -> some View {
        switch configuration.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .success(let product):
            TipRow(name: product.displayName, detail: product.description, price: product.displayPrice) {
                configuration.purchase()
            }
        case .failure, .unavailable:
            Text("Tips aren't available right now.")
                .foregroundStyle(.secondary)
        @unknown default:
            EmptyView()
        }
    }

}

/// One tip: name and description on the left, the price as the buy button on the right.
struct TipRow: View {

    let name: String
    let detail: String
    let price: String
    let buy: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(price, action: buy)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Tip \(price)")
        }
        .padding(.vertical, 4)
    }

}

#Preview {
    Form {
        TipJarView()
    }
    .formStyle(.grouped)
}
