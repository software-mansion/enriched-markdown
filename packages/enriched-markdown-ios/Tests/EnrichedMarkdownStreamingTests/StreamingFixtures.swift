import UIKit
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownStreaming

enum StreamingFixtures {
    static let answer = """
    # Photosynthese einfach erklärt

    Pflanzen wandeln **Lichtenergie** in *chemische Energie* um. Dabei entsteht \
    aus `CO₂` und Wasser Traubenzucker — und als Nebenprodukt Sauerstoff. Ein \
    Kilo Äpfel kostet übrigens 3$ und eine Tüte 5 $ pro Stück.

    ## Die zwei Phasen

    1. **Lichtreaktion**: findet in den *Thylakoiden* statt.
       - Wasser wird gespalten
       - ATP und NADPH entstehen
    2. **Calvin-Zyklus**: im Stroma wird CO₂ fixiert.

    > **Merke:** Ohne Licht keine Lichtreaktion — der Calvin-Zyklus läuft \
    > aber auch kurz im Dunkeln weiter.

    ### Vergleich

    | Phase | Ort | Produkte |
    |---|---|---|
    | Licht | Thylakoid | ATP, NADPH, O₂ |
    | Calvin | Stroma | Glucose |

    - [x] Begriffe gelernt
    - [ ] Aufgaben gemacht

    ```python
    def bilanz(co2, h2o):
        # 6 CO2 + 6 H2O -> C6H12O6 + 6 O2
        return min(co2, h2o) / 6
    ```

    ---

    Mehr dazu findest du im [Lehrbuch](https://example.com/bio?kapitel=3) oder \
    bei ~~Wikipedia~~ deiner Lehrkraft. Viel Erfolg!
    """

    static let extendedAnswer = """
    # Mixed syntax

    Water is H~2~O and E = mc^2^, ==highlighted== and ||concealed|| text.

    > [!NOTE]
    > Admonitions keep their **title** and bar.
    >
    > - A list inside the note
    > - With a second item

    שלום עולם, זהו משפט בעברית עם **הדגשה** בתוכו.

    مرحبا بالعالم، هذه جملة عربية.

    1. First
       > A quote inside an item
       > with two lines
    2. Second with `code` and 123

    ```
    plain fence
    ```

    ___

    Final paragraph with a [link](https://example.com) and *emphasis*.
    """

    static let sampleAnswer = """
    # Streaming markdown

    This answer arrives a few characters at a time, the way a language model writes one. Unfinished **bold**, *italic*, \
    `code` and [links](https://swmansion.com) never show their syntax, and every new piece of text fades in.

    ## Blocks that wait

    A table renders row by row once its header and delimiter row are in:

    | Area | Behavior |
    | --- | --- |
    | Text | Streams and fades in |
    | Tables | Rows appear as they complete |
    | Code | Streams line by line, highlighted once closed |
    | Math | Shown once the closing `$$` arrives |

    Code streams in under its header, and the copy button turns on when the fence closes:

    ```python
    def tokens(answer):
        for word in answer.split():
            yield word + " "
    ```

    Display math is all or nothing:

    $$
    \\int_0^1 x^2 \\, dx = \\frac{1}{3}
    $$

    > [!NOTE]
    > Finished blocks are rendered once and kept. Only the open tail of the document is parsed again on each update.

    - [x] Repair unfinished syntax
    - [x] Hold back half-written blocks
    - [ ] Ship it

    Inline math like $E = mc^2$ waits for its closing dollar too, and prices like 5$ or 3 $ stay text. That is the whole \
    story — *fin*.
    """

    static func chunks(of markdown: String, sizes: [Int] = [3, 7, 4, 11, 5, 2, 9]) -> [String] {
        var prefixes: [String] = []
        var index = markdown.startIndex
        var step = 0
        while index < markdown.endIndex {
            index = markdown.index(index, offsetBy: sizes[step % sizes.count], limitedBy: markdown.endIndex)
                ?? markdown.endIndex
            prefixes.append(String(markdown[..<index]))
            step += 1
        }
        return prefixes
    }

    static func session(
        config: MarkdownStyleConfiguration = .baseline(),
        options: MarkdownParsingOptions = .commonMark,
        plugins: [any MarkdownRenderPlugin] = [],
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
    ) -> StreamingRenderSession {
        StreamingRenderSession(inputs: MarkdownRenderInputs(
            markdown: "",
            config: config,
            options: options,
            plugins: RenderPluginList(values: plugins),
            codeBlockLayout: codeBlockLayout
        ))
    }

    static let extendedOptions = MarkdownParsingOptions(
        superscript: true,
        subscript: true,
        highlight: true,
        admonitions: true
    )
}
