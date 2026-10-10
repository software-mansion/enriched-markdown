import EnrichedMarkdown
import EnrichedMarkdownSyntaxHighlighting
import SwiftUI

private let sampleCodeMarkdown = #"""
# Syntax Highlighting

A fence's info string picks the grammar.

## Python

```python
from dataclasses import dataclass

@dataclass
class User:
    name: str
    age: int = 0

    def greet(self, other: "User") -> str:
        # Adults get the long form
        if other.age >= 18:
            return f"Hello, {other.name}!"
        return "Hi"
```

## TSX

```tsx
type Props = { count: number; onPress: () => void };

export function Counter({ count, onPress }: Props) {
  const label = count === 0 ? "Start" : `Count: ${count}`;
  return <Button title={label} onPress={onPress} />;
}
```

## JSON

```json
{
  "name": "enriched-markdown",
  "private": true,
  "retries": 3,
  "tags": ["markdown", "ios"]
}
```

## Shell

```sh
# Install and build
yarn install && yarn workspace @enriched-markdown/ios build
echo "Done in ${SECONDS}s"
```

## Plain blocks

A block with no language, or one no bundled grammar covers, keeps the code block color:

```
no language here
```
"""#

private let customSyntaxTheme = MarkdownTheme {
    CodeBlock()
        .foregroundStyle(Color.oneDarkText)
        .backgroundStyle(Color.oneDarkBackground)

    SyntaxToken(.keyword).foregroundStyle(Color.oneDarkPurple)
    SyntaxToken(.string).foregroundStyle(Color.oneDarkGreen)
    SyntaxToken(.number).foregroundStyle(Color.oneDarkOrange)
    SyntaxToken(.constant).foregroundStyle(Color.oneDarkOrange)
    SyntaxToken(.comment).foregroundStyle(Color.oneDarkComment)
    SyntaxToken(.function).foregroundStyle(Color.oneDarkBlue)
    SyntaxToken(.type).foregroundStyle(Color.oneDarkYellow)
    SyntaxToken(.property).foregroundStyle(Color.oneDarkRed)
    SyntaxToken(.tag).foregroundStyle(Color.oneDarkRed)
    SyntaxToken(.attribute).foregroundStyle(Color.oneDarkOrange)
    SyntaxToken(.operator).foregroundStyle(Color.oneDarkCyan)
}

private let noOverrides = MarkdownTheme {}

struct CodeScreen: View {
    @State private var highlightsSyntax: Bool = true
    @State private var usesCustomTheme: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Syntax highlighting", isOn: $highlightsSyntax)
                    .accessibilityIdentifier("code-highlighting-toggle")

                Toggle("Custom token colors", isOn: $usesCustomTheme)
                    .accessibilityIdentifier("code-custom-theme-toggle")

                EnrichedMarkdownText(sampleCodeMarkdown)
                    .markdownSyntaxHighlighting(highlightsSyntax)
                    .markdownTheme(usesCustomTheme ? customSyntaxTheme : noOverrides)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: -

#Preview {
    CodeScreen()
}
