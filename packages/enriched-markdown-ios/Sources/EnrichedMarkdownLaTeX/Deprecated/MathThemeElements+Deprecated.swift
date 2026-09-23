import SwiftUI

// Shim for the 0.1 modifier name. Delete this file when it is removed.

public extension MathBlock {
    @available(*, deprecated, renamed: "multilineTextAlignment(_:)")
    func textAlignment(_ alignment: TextAlignment) -> Self {
        multilineTextAlignment(alignment)
    }
}
