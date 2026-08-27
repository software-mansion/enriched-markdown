# EnrichedMarkdownTextInput — Web Support Research

Internal research & implementation plan for bringing `EnrichedMarkdownTextInput` to web. Not user-facing docs.

> **Revision note (2026-07-07):** An earlier version of this doc claimed the native buffer *is* the markdown string with delimiters visible, and rejected the whole WYSIWYG library family (Lexical, TipTap, Slate, ProseMirror) on that basis. **That premise was wrong** — the native input is a WYSIWYG editor that *strips* delimiters and serializes markdown on export (verified against the iOS source, see [The native editing model](#the-native-editing-model-ground-truth)). This revision corrects the facts, sets the product intent to **match native (WYSIWYG, no visible delimiters)**, and **reopens** the rich-model libraries as the architecture-aligned candidates. The library recommendation is now **OPEN pending a spike** — see [Recommendation](#recommendation-open--decide-with-a-spike).

## TL;DR

The native input is a **WYSIWYG rich-text editor that serializes to markdown**, not a source editor. On iOS the editable buffer holds *plain text with delimiters stripped* (`bold`, not `**bold**`); styling lives in **parallel range stores**; the `NSAttributedString` is a derived render layer; and `getMarkdown()` is a **serialization pass** that reconstructs delimiters. Selection offsets are positions in the *plain text*, not the markdown.

Product intent for web: **match native.** Bold renders bold, headings render large — no visible `**` / `#`. That places web in the **rich-model-plus-serializer** category, which is exactly what **Lexical / TipTap / ProseMirror / Slate** do. These are now the architecture-aligned candidates.

**CodeMirror 6 is still viable but no longer the obvious pick.** CM6's headline advantage was "the document *is* the markdown string, so `getMarkdown()` is free." To match native's hidden-delimiter UX on CM6 you must either (a) keep markdown in the doc and *hide* delimiters with atomic/replaced decorations — the Obsidian-style technique this doc previously said we *didn't* want — which reintroduces atomic-range cursor management and makes selection offsets diverge from native (markdown offsets vs native's plaintext offsets); or (b) keep plain text in the doc and add a serializer — at which point the "doc is markdown" edge is gone and CM6 is just a plaintext-buffer-with-decorations. Either way the edge that justified CM6 is undercut.

**Recommendation: OPEN.** Decide Lexical (leading, architecture-aligned) vs CM6 (viable) with a focused spike on the two things that actually differentiate them for *our* model — byte-identical serializer parity with the native `ENRMMarkdownSerializer`, and mapping the editor's selection model to native's plaintext offsets. Estimated effort to parity is comparable for both (~3–4 weeks); the spike de-risks the choice in 2–3 days.

## The native editing model (ground truth)

Verified against the iOS input source (`packages/react-native-enriched-markdown/ios/input/`). Android is not yet re-verified here, but its recent commits (e.g. #508 "exclude block spans from inline formatting pass") indicate the analogous `Spannable` + spans model — **confirm before finalizing**.

The native input is **not** a "buffer is markdown with visible delimiters" editor. It is WYSIWYG:

| Aspect | Native reality | File / evidence |
| --- | --- | --- |
| **Buffer** | Plain text, **delimiters stripped** (`**bold**` → `bold`, `# H` → `H`). What's on screen has no `**`/`#`. | `ENRMInputParser.mm:454`, `:493–508` (syntax indexes removed to build `plainText`) |
| **TextKit stack** | TextKit 1: `NSTextStorage` ← `ENRMInputLayoutManager` (an **empty** `NSLayoutManager` subclass, placeholder) ← `NSTextContainer` ← `ENRMInputTextView` (a `UITextView` subclass) | `EnrichedMarkdownTextInput.mm:182–189`; `ENRMInputLayoutManager.mm` (no overrides) |
| **Style source of truth** | Two **parallel range stores** — `ENRMFormattingStore` (`ENRMFormattingRange {type, plaintext-range, url}`) for inline; a block store (`ENRMBlockRange {type, level}`) for headings. Not the attributes. | `ENRMFormattingStore.h`, `ENRMInputStyledRange.h` |
| **Attributes** | Derived/ephemeral — recomputed from the stores on each line-scoped formatting pass (font traits, heading font size, colors, underline/strike, link/spoiler background, `NSParagraphStyle`, custom `ENRMBlockTypeAttributeName`/`ENRMBlockLevelAttributeName`), then invalidated. Never read back as truth. | formatter pass in `EnrichedMarkdownTextInput.mm` (`applyFormattingScopedToRange:`) |
| **Toggle** | `toggleBold` → `toggleInlineStyle:` adds a **range to the store** over the selection; **does not insert delimiters** into the buffer. | `EnrichedMarkdownTextInput.mm:836–837` |
| **Parsing** | md4c (+ a "remend" pass completing half-typed delimiters) runs **only on import/paste** (`importMarkdown:`/`pasteMarkdown:`), stripping syntax into `{plainText, ranges}`. Ordinary typing never re-parses; ranges are shifted by offset math (`adjustForEditAtLocation:`). | `EnrichedMarkdownTextInput.mm:580–581`, `:656–657`; `ENRMInputParser.mm:286` |
| **Selection** | `setSelection`/`onChangeSelection` use **plaintext-buffer offsets** — `_textView.selectedRange`, no markdown conversion. | `EnrichedMarkdownTextInput.mm:758–764` |
| **Export** | `getMarkdown()` is a **serialization pass** — walks ranges, re-inserts delimiters/block prefixes, trims whitespace at emphasis boundaries. `onChangeText` emits the raw plaintext buffer. **Buffer ≠ markdown.** | `ENRMMarkdownSerializer.mm:168–216` |

**One-line model:** a WYSIWYG `UITextView` whose `NSTextStorage` is delimiter-free plain text, styled live from parallel range stores, with markdown produced only on serialization.

## What this means for web

Because web must **match native**, the target is: styled inline rendering, no visible delimiters, markdown produced by a serializer, selection in plaintext offsets. That is the **rich-document-plus-markdown-serializer** shape. The libraries built for exactly this shape are the WYSIWYG family — the category the previous revision wrongly excluded.

### Why the earlier "WYSIWYG doesn't fit" argument was wrong

The old reasoning was: *"markdown must be in the text and byte-identical; a structured document only has markdown as an import/export format; selection offsets are positions in the markdown string."* Every clause describes **native's own behavior**:

- Native does **not** keep markdown in the text — it strips it.
- Native markdown **is** an export format produced by `ENRMMarkdownSerializer`.
- Native selection offsets are **not** markdown-string positions — they're plaintext positions.

So a structured/rich editor that hides syntax and serializes markdown is *aligned* with native, not in conflict with it. The properties the old doc listed as disqualifiers for Lexical are the properties native already has.

## Library landscape

### Architecture-aligned: the rich-model family (now the leading candidates)

These store a document model, render styling inline (no visible delimiters), and serialize markdown on export — mirroring native.

#### Lexical — leading candidate

| Need | Lexical answer |
| --- | --- |
| WYSIWYG buffer, no visible delimiters | Node tree (`EditorState`); `TextNode` with format flags; styling via node `createDOM`, not literal `**` in text |
| Styling as a model, attributes derived | Format flags + custom nodes (`ExtendedTextNode` pattern extends `TextNode` for per-run style) — same "style is model state, DOM is derived" shape as native's range stores |
| `getMarkdown()` = serialize | `$convertToMarkdownString(TRANSFORMERS)`; import via `$convertFromMarkdownString` — matches native's serializer-on-export exactly |
| Custom dialect (spoiler, `_underline_`, mentions) | Custom `TextMatchTransformer` / `ElementTransformer` + custom nodes; mentions have strong precedent (`@lexical/react` + community mention plugins, atomic/`token`-mode nodes for whole-mention deletion) |
| Mobile / IME | Built by Meta for cross-platform incl. mobile web; solid IME/Android story |
| React integration | First-class `@lexical/react`; headless mode (`@lexical/headless`) for tests/SSR-safe serialization |

Open engineering questions (these are what the spike must answer, not blockers):
- **Serializer parity:** Lexical's markdown output must match `ENRMMarkdownSerializer` byte-for-byte, including our dialect and its whitespace-boundary trimming. Custom transformers are the mechanism; parity is real work but it's the *same* work any web approach needs.
- **Selection mapping:** Lexical selection is `(NodeKey, offset)`; our public API is flat plaintext offsets. Needs a tree-position ↔ flat-offset mapping (Lexical exposes text-offset utilities). Native already does an analogous mapping internally, so this is tractable.
- **Atomic mentions:** `token`-mode nodes give whole-node deletion — matches native atomic-range behavior.

#### TipTap / ProseMirror — also aligned

Same category as Lexical (schema-based rich document, markdown as serialization). TipTap ships a markdown-ish story and a large extension ecosystem; ProseMirror is the lower-level engine. Viable; main reason to prefer Lexical is its mobile/IME focus and lighter React ergonomics. Keep as fallback if Lexical's dialect/serializer work proves awkward.

#### Slate — aligned, lighter-weight

Rich framework with a React-native (small-r) model; `decorate` supports range-based styling and it can render plain-text leaves with derived styling. Fits the model. Historically weaker Android/IME than Lexical/ProseMirror — weigh in the spike if bundle size pushes us here.

### CodeMirror 6 — viable, but the edge is undercut

CM6 is a plain-string buffer + decoration layer (the web's TextKit). Its appeal was that the document *is* the markdown string, so `getMarkdown()` is free and there's no serializer. Under **match-native (hidden delimiters)** that appeal weakens:

- To hide delimiters you use replaced/atomic decorations (Obsidian "Live Preview" style). Every reference project below does this; the previous revision explicitly rejected the technique, but matching native *requires* it.
- Sub-approach (a) — keep markdown in the doc, hide delimiters: `getMarkdown()` stays free, but **selection offsets are now markdown offsets** (they count the hidden `**`), which **diverges from native's plaintext offsets** → you must map offsets anyway, plus manage caret motion across atomic hidden ranges, plus strip delimiters for `onChangeText`.
- Sub-approach (b) — keep plaintext in the doc, decorate + serialize: mirrors native, but the "doc is markdown / free serialization" edge is **gone**.

CM6 remains a legitimate option (excellent IME/mobile, mature) — it's just no longer *strictly* simpler than the rich-model family for our specific model. If chosen, the reference projects become required reading, not anti-patterns:

- [codemirror-rich-markdoc](https://github.com/segphault/codemirror-rich-markdoc) — minimal CM6 hybrid-markdown plugin
- [atomic-editor](https://github.com/kenforthewin/atomic-editor) — CM6 + React, layout-stable inline decorations
- [codemirror-live-markdown](https://github.com/blueberrycongee/codemirror-live-markdown) — modular plugins + [design doc](https://github.com/blueberrycongee/codemirror-live-markdown/blob/main/CODEMIRROR_LIVE_PREVIEW_DESIGN.md)
- [ink-mde](https://github.com/davidmyersdev/ink-mde) — polished CM6 markdown editor
- Production: **Obsidian** (Live Preview), **Joplin**, **Zettlr** — all hide delimiters, which is now the behavior we want

### Rejected

| Option | Verdict |
| --- | --- |
| **OverType / textarea overlay** ([overtype.dev](https://overtype.dev)) | Invisible `<textarea>` over a styled preview; native undo/IME, tiny. Rejected: requires uniform font metrics — our per-level heading font sizes break caret alignment. |
| **CSS Custom Highlight API** | Styles ranges without touching the DOM (keeps native undo/IME) — but `::highlight()` cannot change `font-weight` or `font-size`, so no bold and no headings. Dead end as the main mechanism (possible minor accent only). |
| **Hand-rolled contenteditable** | Viable but expensive — see [DIY assessment](#diy-contenteditable-assessment). Would naturally re-implement native's plaintext-buffer + parallel-store + serializer model. |

### Native-alignment at a glance

| Property (from native) | Lexical | TipTap/ProseMirror | Slate | CM6 |
| --- | :---: | :---: | :---: | :---: |
| Hidden delimiters (WYSIWYG) | native | native | native | needs atomic-range hiding |
| Style as model, DOM derived | ✅ | ✅ | ✅ (decorate) | decorations over string |
| Markdown via serializer | ✅ | ✅ | ✅ | free *only* if doc=markdown (then offset divergence) |
| Selection = plaintext offsets | needs node↔offset map | needs map | needs map | markdown offsets if doc=markdown |
| Mobile / IME maturity | ✅ | ✅ | ⚠️ | ✅ |

## Recommendation: OPEN — decide with a spike

Do **not** commit to a library yet. Run a **2–3 day spike** on the two differentiators that dominate the risk for our model, primarily on **Lexical** (leading), with a thin CM6-hide-delimiters comparison:

1. **Serializer parity.** Load a fixture covering the full dialect (bold/italic, `_underline_`, `~~strike~~`, `||spoiler||`, `[t](url)`, `[@Alice](user://u_1)`, H1–H6, nested/adjacent styles, whitespace-at-boundary cases). Round-trip through the candidate and diff its markdown output against the native `ENRMMarkdownSerializer` output. Byte-identical is the bar.
2. **Selection offset mapping.** Confirm you can expose/consume flat **plaintext** offsets (`setSelection`/`onChangeSelection`) that agree with native, including with emoji (UTF-16 units). For Lexical this is the node↔offset map; for CM6-hide-delimiters it's markdown↔plaintext.
3. **(Cheap, still open) Android IME sanity** — type with Gboard autocorrect into each candidate; confirm composition + undo survive. Lexical and CM6 both claim this; verify for our config.

Whichever wins ships behind the shared `EnrichedMarkdownTextInputInstance` type, so the loser stays a drop-in swap later.

## DIY (contenteditable) assessment

Favorable factors: our syntax subset is small and line-oriented (a port of the native formatter/serializer logic covers it); inputs hold chat-sized content, so full re-tokenize is cheap; the uncontrolled + ref contract suits a hand-rolled component; dependency-free ~10–20 KB bundle. A DIY build would essentially re-implement native's model on web: a plaintext contenteditable + parallel range store + serializer.

The cost is concentrated in four problems that don't show up in a demo:

1. **IME/composition, especially Android** — `insertCompositionText` is not cancelable; must let the browser mutate the DOM during composition and reconcile on `compositionend`. Gboard uses composition for ordinary English typing, so this is the main Android path.
2. **Undo/redo** — programmatic DOM restructuring poisons the native undo stack; we'd own a history stack with selection snapshots and edit grouping, forever.
3. **Selection mapping through restyling** — every formatter pass splits/replaces text nodes the selection is anchored in; DOM-position ↔ string-offset mapping across engines.
4. **Paste/copy sanitization** — HTML paste → markdown, Safari clipboard quirks.

Estimates: happy-path prototype ~1–2 weeks; library-grade parity across Chrome/Safari/Firefox + iOS Safari + Android Chrome ~2–3 months plus a permanent quirk-maintenance tax. (Precedent: Meta's Draft.js years led to Lexical; CM6's changelog is substantially a browser/IME workaround catalog.) DIY stays open as a later drop-in swap behind the same component contract.

## Integration with the current web setup

Applies to whichever engine is chosen (CM6 or a rich-model lib); specifics noted where they differ.

- The library's web code has **no react-native-web coupling** — `src/web/` renders plain DOM; RNW exists only in consumer apps. Any editor engine mounts into a `<div>`; an RNW `View` is just a `div`, so embedding is unremarkable.
- New sibling component `src/web/EnrichedMarkdownTextInput.tsx`, exported from `src/index.web.tsx` next to the renderer. `EnrichedMarkdownText` (md4c/WASM pipeline) stays untouched; the input and renderer are two parsers doing different jobs.
- Shape: `useLayoutEffect` constructs the editor (`new EditorView({parent})` for CM6, or a Lexical editor + React root), destroys on unmount; `useImperativeHandle` implements the shared `EnrichedMarkdownTextInputInstance` type so TS enforces API parity with native.
- **Bundle isolation**: keep the input in its own module and declare `sideEffects` so renderer-only consumers drop the editor engine. **Measured trap:** react-native-builder-bob emits `lib/module/package.json` (`{"type":"module"}`), and bundlers resolve `sideEffects` from the *nearest* package.json — a root-level declaration silently never applies to the built files, and renderer-only bundles ship the whole editor (verified with esbuild). The build must patch the nested file to `{"type":"module","sideEffects":["**/globalStyles.js"]}` (`globalStyles` injects CSS at import time, so plain `false` would break the renderer). Consider a subpath export (`react-native-enriched-markdown/input`) for a hard guarantee. **Applies to any heavy web dep, not just CM6.**
- **SSR**: all candidates are client-only — construct the editor in an effect, never at module scope (same pattern as our KaTeX/WASM lazy-loading). Lexical additionally offers `@lexical/headless` for server-side serialization if ever needed.
- **Behavioral parity is not enforced by types** — event ordering, `onChangeState` firing semantics, collapsed-cursor toggle behavior, and offset units (UTF-16 code units vs codepoints once emoji are involved) must be written down and mirrored in web e2e tests (Playwright) matching the native Maestro flows.

### Positioning: why the library still matters if web is "just a wrapper"

Same reason it matters on iOS/Android, where it's "just a wrapper" of TextKit/EditText: wrapping the strongest platform text primitive and building the behavior layer on top *is* the library's design. Consumers get: an RN component that exists on web at all, the dialect (spoiler, underline, mentions), toggle semantics, `onChangeState`, auto-link detection, and cross-platform guarantees (one `markdownStyle`, byte-identical `getMarkdown()`). A web-only developer might reasonably use the underlying engine directly — they were never the market.

## Measured bundle impact (CM6 spike, July 2026)

These figures are **CM6-specific**. A comparable measurement for Lexical (leaner core, but a rich framework + custom nodes/transformers) is now **missing and needed** before a final call — add it to the spike.

Method: CM6 deps + a stub `web/EnrichedMarkdownTextInput` (real planned import graph) added to the package, `npm pack`, tarball installed in a fresh npm project (`react`, `react-dom`, `react-native-web`), bundled with esbuild (`--bundle --minify --format=esm --splitting --alias:react-native=react-native-web --resolve-extensions=.web.js,...`), sizes = sum of emitted JS.

| Variant | Raw | Gzip |
| --- | ---: | ---: |
| Renderer-only consumer (baseline, after tree-shake fix) | 203 KB | 66 KB |
| Baseline + input via `@codemirror/lang-markdown`'s `markdown()` | 711 KB | 241 KB |
| CM6 floor (`view` + `state` only) | 199 KB | 65 KB |
| CM6 + `commands`/`language` + `@lezer/markdown` directly (minimal language) | 312 KB | **102 KB** |
| CM6 + full `lang-markdown` chain | 507 KB | 175 KB |

Conclusions:

- **CM6 real input cost: ~102 KB gzip** (minimal-language setup). The naive `markdown()` route costs ~175 KB — the difference is `lang-html`/`lang-javascript`/`lang-css`/`autocomplete` pulled in for embedded-HTML editing; bypass by wrapping `@lezer/markdown`'s parser in a `Language` ourselves.
- **Tree-shaking is broken by default**: before fixing, the renderer-only baseline measured *identical* to the with-input build (241 KB gzip). Root cause: bob's generated `lib/module/package.json` shadows the root `sideEffects` declaration (see Bundle isolation). After patching the nested file, baseline is clean. The fix is mandatory, needs a build step, plus a bundle-size CI check to prevent regression — **regardless of which editor engine we pick.**
- md4c WASM glue (~164 KB raw) stays a lazy-loaded chunk in all variants — unaffected by the input work.
- **TODO:** measure Lexical (`lexical` + `@lexical/react` + `@lexical/markdown` + custom nodes) under the same harness.

## Appendix: CM6 implementation mapping (only if CM6 is chosen)

Retained from the prior revision because it's still accurate *if* we land on CM6. A Lexical mapping (custom nodes for spoiler/mention, `TextMatchTransformer`s for the dialect, `$convertToMarkdownString` parity, node↔offset selection) should be produced during the spike if Lexical wins. One global CM6 note: decoration sets provided **directly** (from a `StateField`) may influence vertical layout; sets provided as functions (`ViewPlugin`) may not — heading styling (font size changes line height) must live in a StateField, inline marks can use the cheaper ViewPlugin path.

Note: to match native, the inline/heading decorations below must additionally **hide the delimiter characters** (replaced/atomic decorations), which the prior revision's tables omitted.

### Editor shell

| Feature | CM6 building block |
| --- | --- |
| Component + lifecycle | `new EditorView({parent, state})`, `view.destroy()` |
| `defaultValue`/`setValue()` | `EditorState.create({doc})` / `dispatch({changes})` |
| `placeholder`, `placeholderTextColor` | `placeholder()` extension; hide-on-empty-heading (native #515) needs a conditional variant |
| `editable`, `autoFocus` | `EditorView.editable` facet (compartment), `view.focus()` |
| `multiline`, `scrollEnabled`, `style` | wrapper div + `EditorView.theme`; keymap filter for single-line |
| `cursorColor`, `selectionColor` | theme `.cm-cursor`/`.cm-selectionBackground`; `drawSelection()` |
| `autoCapitalize` | `EditorView.contentAttributes` |
| Undo/redo | `history()` + `historyKeymap` |

### Markdown dialect (parser configuration)

| Feature | CM6 building block |
| --- | --- |
| Base parsing | build a `Language` from `@lezer/markdown`'s parser directly — **not** `@codemirror/lang-markdown`'s `markdown()` (drags in lang-html chain, +73 KB gzip) |
| `~~strikethrough~~` | GFM `Strikethrough` extension |
| `\|\|spoiler\|\|` | custom `@lezer/markdown` inline extension (model on Strikethrough source, ~40 lines) |
| `_underline_` vs `*italic*` | both parse as `Emphasis`; distinguish by delimiter char at decoration time |
| Unsupported blocks | disable/ignore list/code/table/quote node types so they render as plain text |

### Inline styles, headings, links, mentions, selection, RTL

The prior revision's detailed CM6 tables for these (decoration plugin, `toggle*` string edits, `Decoration.line` StateField for headings, `Link` nodes + `linkVariants`, auto-link detection, mention `StateField` + `atomicRanges`, `coordsAtPos` caret rects, `perLineTextDirection`/`bidiIsolates` for RTL) remain valid as a CM6 implementation guide. Key correction under match-native: everything that keeps `**`/`#` visible must instead hide them, and `getMarkdown()` / selection offsets need the markdown↔plaintext reconciliation described in [the CM6 section](#codemirror-6--viable-but-the-edge-is-undercut).

## Explicitly out of scope for web v1 (decide & document)

- **Native format bar / context menu** (`contextMenuItems`, `selectionMenuConfig`, `formatMenuConfig`) — browsers can't extend the native selection menu. Options: no-op on web (recommended v1) or later ship an optional tooltip-based format bar.
- **System-clipboard markdown pasteboard type** — plain text only on web (Android already behaves this way).
- **`allowFontScaling` etc.** — no web equivalent; no-op with a doc note.

## Suggested milestones (engine-agnostic; assumes a rich-model engine)

1. **Spike + decision** (2–3 days): serializer parity + selection mapping on Lexical (+ thin CM6 compare); pick the engine.
2. **Editor shell + inline styles** (week 1): component, theme mapping, custom nodes/decorations for bold/italic/underline/strike/spoiler, toggles, `onChangeState`, placeholder, undo. → demoable.
3. **Headings + links** (week 2): heading nodes/decorations, `toggleHeading`, empty-heading anchors, link methods + `linkVariants`, auto-link detection.
4. **Mentions + selection/caret/RTL/clipboard** (week 3): mention nodes/session, atomic deletion, caret rect, per-paragraph direction, remaining events.
5. **Parity hardening** (week 4): Playwright suite mirroring Maestro, offset-semantics tests with emoji, Android Chrome/iOS Safari passes, bundle-isolation check, docs (`WEB.md`).

## Open decisions

- **Library: Lexical vs CM6 (vs TipTap/Slate)** — resolve via the spike. Leading: Lexical (architecture-aligned with native).
- **Serializer parity** — the chosen engine's markdown output must equal `ENRMMarkdownSerializer` byte-for-byte, incl. dialect and whitespace-boundary trimming.
- **Offset unit contract** for `setSelection`/`onChangeSelection` across platforms — recommend UTF-16 code units (JS, iOS `NSString`, Android `CharSequence` all index that way); confirm native emits **plaintext** offsets (it does on iOS) so web must too.
- **Android model re-verify** — confirm Android input is `Spannable`+spans WYSIWYG like iOS (recent block-span commits imply yes).
- `__text__`: strong (CommonMark) or underline (dialect consistency)? Serializer never emits it, but users can type it.
- `copyToClipboard()` on web: markdown string (buffer-faithful on native ≠ buffer here) vs plain text. Recommend the serialized markdown string.
- Keyboard shortcuts (Cmd+B etc.): native exposes toggles via format bar; web probably ships a default keymap — additive API decision.
- Where editor packages land: `dependencies` of the main package (simple) vs optional subpath entry (hard bundle guarantee).

## Search key phrases (for future research)

"WYSIWYG markdown editor" · "markdown editor serialize to markdown" · "lexical markdown transformer custom node" · "lexical mentions node" · "prosemirror markdown serializer" · "slate markdown" · "richtext editor markdown source of truth" · plus (for the CM6 path) "obsidian-style live preview" · "hide markdown tokens" · "codemirror 6 markdown decorations" · "lezer markdown extension". Venues: [Lexical docs](https://lexical.dev) & Discord, [ProseMirror forum](https://discuss.prosemirror.net), [CodeMirror forum](https://discuss.codemirror.net); Joplin & Zettlr sources.
