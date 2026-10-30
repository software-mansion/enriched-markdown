import XCTest
@testable import EnrichedMarkdownLaTeX

final class LaTeXSpeechTests: XCTestCase {
    func testFormulaIsSpokenByTheSharedCore() {
        XCTAssertEqual(LaTeXSpeech.spokenForm(of: "\\frac{e^x}{2}"), "fraction e to the power x over 2 end fraction")
        XCTAssertEqual(LaTeXSpeech.spokenForm(of: "\\text{über}"), "über")
        XCTAssertEqual(LaTeXSpeech.spokenForm(of: ""), "")
    }

    func testLabelTemplateResolvesBothPlaceholders() {
        let label = LaTeXRenderPlugin.label(template: "Formel: {speech} ({latex})")
        XCTAssertEqual(label("x^2"), "Formel: x squared (x^2)")
        XCTAssertEqual(LaTeXRenderPlugin.label(template: "Math: {latex}")("x^2"), "Math: x^2")
    }
}
