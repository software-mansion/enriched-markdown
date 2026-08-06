import XCTest
@testable import EnrichedMarkdown

/// Pixel-level rendering coverage for the display pipeline, replacing the
/// Maestro screenshot assertions that captured the playground preview on-device.
///
/// Goldens are recorded on the same pinned simulator the Maestro suite uses
/// (created by .maestro/scripts/setup-ios-simulator.sh). Boot it, then:
///   xcodebuild test -scheme EnrichedMarkdown \
///     -destination "platform=iOS Simulator,id=$(xcrun simctl list devices | awk -F'[()]' '/iPhone17-iOS26.5-Enriched-Markdown/{print $2; exit}')" \
///     -only-testing:EnrichedMarkdownTests/MarkdownRenderingSnapshotTests \
///     TEST_RUNNER_RECORD_SNAPSHOTS=1
@MainActor
final class MarkdownRenderingSnapshotTests: XCTestCase {
    func testRenderingMatchesGoldens() {
        continueAfterFailure = true
        for snapshotCase in RenderSnapshotCases.all {
            Snapshot.verify(snapshotCase)
        }
    }
}
