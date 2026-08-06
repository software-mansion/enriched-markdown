@testable import EnrichedMarkdown

struct RenderSnapshotCase {
    let name: String
    let markdown: String
    var flags: Md4cFlags = .commonMark
}

/// Ported from the retired Maestro screenshot flows in
/// .maestro/iosExample/enrichedMarkdownText/flows — one case per flow, same markdown.
enum RenderSnapshotCases {
    static let all: [RenderSnapshotCase] = [
        RenderSnapshotCase(
            name: "blockquote_code_block_combo",
            markdown: #"""
            > From the docs:

            ```
            npm install my-package
            ```

            > Then import it:

            ```js
            import pkg from 'my-package'
            ```
            """#
        ),
        RenderSnapshotCase(
            name: "blockquote_image_combo",
            markdown: #"""
            > A quoted line before the image.

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "blockquote_list_combo",
            markdown: #"""
            > Key principles:

            - Keep it simple
            - Be consistent
            - Test everything

            > Avoid:

            1. Over-engineering
            2. Premature optimization
            """#
        ),
        RenderSnapshotCase(
            name: "code_block_image_combo",
            markdown: #"""
            ```
            print("hello world")
            ```

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "header_blockquote_combo",
            markdown: #"""
            ## Famous Quote

            > The only way to do great work is to love what you do.

            ## Another Quote

            > In the middle of difficulty lies opportunity.
            """#
        ),
        RenderSnapshotCase(
            name: "header_code_block_combo",
            markdown: #"""
            ## Installation

            ```
            npm install
            ```

            ## Usage

            ```js
            import { run } from './app'
            run()
            ```
            """#
        ),
        RenderSnapshotCase(
            name: "header_image_combo",
            markdown: #"""
            ## Logo

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "header_list_combo",
            markdown: #"""
            ## Ingredients

            - Flour
            - Eggs
            - Butter

            ## Steps

            1. Mix dry ingredients
            2. Add wet ingredients
            3. Bake at 180C
            """#
        ),
        RenderSnapshotCase(
            name: "header_paragraph_combo",
            markdown: #"""
            # Section One
            Short intro paragraph.

            ## Subsection
            Another short paragraph.

            ### Deep section
            Final paragraph.
            """#
        ),
        RenderSnapshotCase(
            name: "list_image_combo",
            markdown: #"""
            - Item one
            - Item two
            - Item three

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "paragraph_blockquote_combo",
            markdown: #"""
            A paragraph before a quote.

            > This is a blockquote.

            A paragraph after the quote.

            > Another blockquote at the end.
            """#
        ),
        RenderSnapshotCase(
            name: "paragraph_code_block_combo",
            markdown: #"""
            Call the function like this:

            ```
            result = add(1, 2)
            print(result)
            ```

            Then check the output above.
            """#
        ),
        RenderSnapshotCase(
            name: "paragraph_image_combo",
            markdown: #"""
            A short paragraph before the image.

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "paragraph_list_combo",
            markdown: #"""
            Pick a fruit:

            - Apple
            - Banana
            - Mango

            Then pick a number:

            1. One
            2. Two
            3. Three

            Done.
            """#
        ),
        RenderSnapshotCase(
            name: "thematic_break_combo",
            markdown: #"""
            A paragraph before a break.

            ---

            > A blockquote after a break.

            ---

            - List item one
            - List item two

            ---

            ```
            code block
            ```

            ---

            ## Header after break
            """#
        ),
        RenderSnapshotCase(
            name: "thematic_break_image_combo",
            markdown: #"""
            Content above the break.

            ---

            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "blockquote",
            markdown: #"""
            > this is a text inside a blockquote

             >this is also a text inside a blockquote

            .>this isn't
            """#
        ),
        RenderSnapshotCase(
            name: "code_block",
            markdown: #"""
            ```
            sum = 0
            for i in range(20):
              print(i % 3)
              sum += i % 3
            print(sum)
            ```
            """#
        ),
        RenderSnapshotCase(
            name: "header",
            markdown: #"""
            # H1
            ## H2
            ### H3
            #### H4
            ##### H5
            ###### H6
            ####### H not existing
            """#
        ),
        RenderSnapshotCase(
            name: "image",
            markdown: #"""
            ![logo]({{IMAGE}})
            """#
        ),
        RenderSnapshotCase(
            name: "mixed_nested_list",
            markdown: #"""
            - Frontend
              - React
                - Hooks
                - Components
              - Vue
            - Backend
              - Node.js
              - Python
                1. Django
                2. FastAPI
            """#
        ),
        RenderSnapshotCase(
            name: "nested_blockquote",
            markdown: #"""
            > top-level blockquote
            >> nested blockquote inside the first
            >>> deeply nested blockquote

            > outer
            >> nested
            >
            > outer
            """#
        ),
        RenderSnapshotCase(
            name: "nested_ordered_list",
            markdown: #"""
            1. First
               1. Nested
                  1. Deep nested
                  2. Deep nested
               2. Nested
            2. First
            """#
        ),
        RenderSnapshotCase(
            name: "nested_unordered_list",
            markdown: #"""
            - Item
              - Nested
                - Deep nested
                - Deep nested
              - Nested
            - Item
            """#
        ),
        RenderSnapshotCase(
            name: "ordered_list",
            markdown: #"""
            1. Preheat oven to 180C
            2. Mix flour, sugar, and butter
            3. Add eggs and vanilla extract
            4. Pour into a greased tin
            5. Bake for 30 minutes
            """#
        ),
        RenderSnapshotCase(
            name: "paragraph",
            markdown: #"""
            Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
            """#
        ),
        RenderSnapshotCase(
            name: "thematic_break",
            markdown: #"""
            Above the first break

            ---

            Between the breaks

            ***

            Below the last break
            """#
        ),
        RenderSnapshotCase(
            name: "unordered_list",
            markdown: #"""
            - Apples
            - Bananas
            - Mango
            * Dragonfruit
            * Guava
            * Fig
            """#
        ),
        RenderSnapshotCase(
            name: "bold",
            markdown: #"""
            **Bold text** and normal text and __more bold__.
            """#
        ),
        RenderSnapshotCase(
            name: "inline_code",
            markdown: #"""
            Use `pthread*` to debug and `null` to clear.
            """#
        ),
        RenderSnapshotCase(
            name: "inline_image",
            markdown: #"""
            Enriched Markdown is a library for ![icon]({{ICON}}) React Native.
            """#
        ),
        RenderSnapshotCase(
            name: "italic",
            markdown: #"""
            *Italic text* and normal text and _also italic_.
            """#
        ),
        RenderSnapshotCase(
            name: "link",
            markdown: #"""
            Visit [React Native](https://reactnative.dev) for docs.
            """#
        ),
        RenderSnapshotCase(
            name: "underline_flag",
            markdown: #"""
            _single underscores_ and __double underscores__ with the underline extension.
            """#,
            flags: Md4cFlags(underline: true)
        ),
        RenderSnapshotCase(
            name: "strikethrough",
            markdown: #"""
            Text with ~~strikethrough~~ and **bold ~~struck~~** together.
            """#
        ),
    ]
}
