import SwiftUI

extension Image {
    /// A PNG shipped as a loose bundle resource rather than an asset-catalog
    /// entry, which is how the article's figures travel — the same files the
    /// markdown itself references by name.
    init?(bundledPNG name: String) {
        guard let image = Bundle.main.pngImage(named: name) else { return nil }
        self.init(uiImage: image)
    }
}
