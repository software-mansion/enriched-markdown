import CoreText
import UIKit

enum ExampleFontRegistrar {
    private static let fontFilenames = [
        "Montserrat-Regular",
        "Montserrat-Bold",
        "Montserrat-SemiBold",
        "Montserrat-Medium",
        "Montserrat-Italic",
        "Montserrat-BoldItalic",
        "CourierPrime-Regular",
        // Article screen: Newsreader for prose (a 16pt text cut plus a 48pt
        // display cut for the headline), Space Grotesk for small labels.
        "Newsreader-Regular",
        "Newsreader-Italic",
        "Newsreader-SemiBold",
        "Newsreader-Bold",
        "Newsreader-BoldItalic",
        "NewsreaderDisplay-Regular",
        "SpaceGrotesk-Regular",
        "SpaceGrotesk-Medium",
    ]

    /// Registers example fonts from the app bundle before any markdown is rendered.
    static func registerBundledFonts() {
        var registeredCount = 0
        for filename in fontFilenames where registerFont(filename: filename) {
            registeredCount += 1
        }

        #if DEBUG
        if registeredCount == 0 {
            assertionFailure(
                """
                No bundled fonts were found in EnrichedMarkdownExample.app.
                Delete the app from the simulator, Product > Clean Build Folder, then run again.
                """
            )
        } else if registeredCount < fontFilenames.count {
            print("ExampleFontRegistrar: registered \(registeredCount)/\(fontFilenames.count) fonts")
        }
        #endif
    }

    @discardableResult
    private static func registerFont(filename: String) -> Bool {
        guard let url = fontURL(for: filename) else { return false }

        var error: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !didRegister, let error {
            #if DEBUG
            print("ExampleFontRegistrar: failed to register \(filename): \(error.takeRetainedValue())")
            #endif
        }
        return didRegister
    }

    private static func fontURL(for filename: String) -> URL? {
        Bundle.main.url(forResource: filename, withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: filename, withExtension: "ttf")
    }
}
