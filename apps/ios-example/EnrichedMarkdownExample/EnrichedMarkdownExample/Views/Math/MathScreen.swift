import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

private let sampleMathMarkdown = #"""
# LaTeX Math

Inline math flows with the text: the roots of $ax^2 + bx + c = 0$ are
$x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}$, and Euler's identity is $e^{i\pi} + 1 = 0$.

## Display math

$$\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}$$

Sums work too:

$$\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}$$

## Inside other blocks

> Blockquotes can carry $E = mc^2$ inline.

- Pythagorean theorem: $a^2 + b^2 = c^2$
- Golden ratio: $\varphi = \frac{1+\sqrt{5}}{2}$

## Fallback

Source that fails to typeset falls back to plain text: $\frac{1}{$
"""#

struct MathScreen: View {
    var body: some View {
        ScrollView {
            EnrichedMarkdownText(sampleMathMarkdown)
                .markdownLaTeX()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        }
        .background(Color.white)
    }
}

// MARK: -

#Preview {
    MathScreen()
}
