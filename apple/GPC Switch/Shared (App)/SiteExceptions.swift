import Foundation

/// The sites the extension stays silent on, because they break when they receive the
/// signals. Read from the copy that ships inside the extension bundle
/// (extension/rules/site-exceptions.json, which also generates the header rules and the
/// content-script exclusions), so the app can never show a list the rules don't use.
struct SiteExceptions: Decodable {

    struct Site: Decodable, Identifiable {
        /// A domain; the rules cover it and its subdomains.
        let domain: String
        /// Why it is excluded: a link to the report, or a sentence.
        let reason: String

        var id: String { domain }

        /// The reason as a link, when it is one.
        var reasonURL: URL? {
            guard reason.hasPrefix("https://") else { return nil }
            return URL(string: reason)
        }
    }

    /// Where the list came from (DuckDuckGo's privacy configuration).
    let source: String
    let license: String
    /// The date the snapshot was taken, ISO 8601.
    let fetched: String
    let sites: [Site]

    static let shipped: SiteExceptions? = load()

    private static func load() -> SiteExceptions? {
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let appex = Bundle(url: plugIns.appendingPathComponent("GPC Switch Extension.appex")),
              let url = appex.url(forResource: "site-exceptions", withExtension: "json", subdirectory: "rules"),
              let data = try? Data(contentsOf: url) else {
            // In Release the Disabled Sites section just doesn't appear; say why in Debug.
            assertionFailure("rules/site-exceptions.json not found in the extension bundle")
            return nil
        }
        do {
            return try JSONDecoder().decode(SiteExceptions.self, from: data)
        } catch {
            assertionFailure("rules/site-exceptions.json did not decode: \(error)")
            return nil
        }
    }

}
