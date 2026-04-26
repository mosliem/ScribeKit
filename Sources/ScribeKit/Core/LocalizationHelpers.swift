import SwiftUI

// MARK: - Module-bundle localization helpers
//
// iOS filters a package bundle's localizations through the host app's declared
// languages AND through the bundle's own Info.plist CFBundleLocalizations key.
// SPM-generated resource bundles omit that key, so Bundle.module.localizations
// only returns ["en"]. To always respect the user's device language we resolve
// the correct .lproj sub-bundle ourselves at launch by walking
// Locale.preferredLanguages and probing for a matching directory.

extension String {
    /// Returns the localised string for `key` from the ScribeKit module bundle,
    /// using the user's preferred device language.
    static func localized(_ key: String) -> String {
        Self.resolvedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Resolved once per process — walks the user's language list and returns
    /// the first .lproj sub-bundle that exists inside Bundle.module.
    private static let resolvedBundle: Bundle = {
        for language in Locale.preferredLanguages {
            // Try full tag first ("ar-EG"), then base language ("ar").
            let base = language.components(separatedBy: "-").first ?? language
            for candidate in [language, base] {
                if let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
                   let bundle = Bundle(path: path) {
                    return bundle
                }
            }
        }
        return Bundle.module
    }()
}

extension Text {
    /// Creates a `Text` view whose content is looked up from the ScribeKit
    /// module bundle using the device language.
    init(localized key: String) {
        self.init(verbatim: String.localized(key))
    }
}
