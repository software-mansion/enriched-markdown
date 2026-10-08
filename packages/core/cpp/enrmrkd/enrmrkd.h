/*
 * MD4C: Markdown parser for C
 * (https://github.com/mity/md4c)
 *
 * Copyright (c) 2016-2026 Martin Mitáš
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#ifndef ENRMRKD_H
#define ENRMRKD_H

#ifdef __cplusplus
    extern "C" {
#endif

#if defined ENRMRKD_USE_UTF16
    /* Magic to support UTF-16. Note that in order to use it, you have to define
     * the macro ENRMRKD_USE_UTF16 both when building MD4C as well as when
     * including this header in your code. */
    #ifdef _WIN32
        #include <windows.h>
        typedef WCHAR       ENRMRKD_CHAR;
    #else
        #error ENRMRKD_USE_UTF16 is only supported on Windows.
    #endif
#else
    typedef char            ENRMRKD_CHAR;
#endif

typedef unsigned ENRMRKD_SIZE;
typedef unsigned ENRMRKD_OFFSET;


/* Block represents a part of document hierarchy structure like a paragraph
 * or list item.
 */
typedef enum ENRMRKD_BLOCKTYPE {
    /* <body>...</body> */
    ENRMRKD_BLOCK_DOC = 0,

    /* <blockquote>...</blockquote> */
    ENRMRKD_BLOCK_QUOTE,

    /* <ul>...</ul>
     * Detail: Structure ENRMRKD_BLOCK_UL_DETAIL. */
    ENRMRKD_BLOCK_UL,

    /* <ol>...</ol>
     * Detail: Structure ENRMRKD_BLOCK_OL_DETAIL. */
    ENRMRKD_BLOCK_OL,

    /* <li>...</li>
     * Detail: Structure ENRMRKD_BLOCK_LI_DETAIL. */
    ENRMRKD_BLOCK_LI,

    /* <hr> */
    ENRMRKD_BLOCK_HR,

    /* <h1>...</h1> (for levels up to 6)
     * Detail: Structure ENRMRKD_BLOCK_H_DETAIL. */
    ENRMRKD_BLOCK_H,

    /* <pre><code>...</code></pre>
     * Note the text lines within code blocks are terminated with '\n'
     * instead of explicit ENRMRKD_TEXT_BR. */
    ENRMRKD_BLOCK_CODE,

    /* Raw HTML block. This itself does not correspond to any particular HTML
     * tag. The contents of it _is_ raw HTML source intended to be put
     * in verbatim form to the HTML output. */
    ENRMRKD_BLOCK_HTML,

    /* <p>...</p> */
    ENRMRKD_BLOCK_P,

    /* <table>...</table> and its contents.
     * Detail: Structure ENRMRKD_BLOCK_TABLE_DETAIL (for ENRMRKD_BLOCK_TABLE),
     *         structure ENRMRKD_BLOCK_TD_DETAIL (for ENRMRKD_BLOCK_TH and ENRMRKD_BLOCK_TD)
     * Note all of these are used only if extension ENRMRKD_FLAG_TABLES is enabled. */
    ENRMRKD_BLOCK_TABLE,
    ENRMRKD_BLOCK_THEAD,
    ENRMRKD_BLOCK_TBODY,
    ENRMRKD_BLOCK_TR,
    ENRMRKD_BLOCK_TH,
    ENRMRKD_BLOCK_TD,

    /* Container for all referenced footnote definitions, rendered at the end
     * of the document.
     * Detail: NULL.
     * Note: Used only if extension ENRMRKD_FLAG_FOOTNOTES is enabled, and only when
     * at least one footnote definition is referenced. */
    ENRMRKD_BLOCK_FOOTNOTE_DEF_SECTION,

    /* A single footnote definition, rendered at the end of the document.
     * Detail: Structure ENRMRKD_BLOCK_FOOTNOTE_DEF_DETAIL.
     * Note: Used only if extension ENRMRKD_FLAG_FOOTNOTES is enabled.
     * Only definitions that are actually referenced in the document are
     * emitted, in order of first reference. */
    ENRMRKD_BLOCK_FOOTNOTE_DEF,

    /* Adminition extension.
     * Detail ENRMRKD_BLOCK_ADMONITION_DETAIL.
     * Note: Recognized only when ENRMRKD_FLAG_ADMONITIONS is enabled. */
    ENRMRKD_BLOCK_ADMONITION,

    /* A run of blank lines separating two blocks. Has no contents.
     * Detail: Structure ENRMRKD_BLOCK_BLANK_DETAIL.
     * Note: Emitted only when ENRMRKD_FLAG_PRESERVEBLANKLINES is enabled. */
    ENRMRKD_BLOCK_BLANK
} ENRMRKD_BLOCKTYPE;

/* Span represents an in-line piece of a document which should be rendered with
 * the same font, color and other attributes. A sequence of spans forms a block
 * like paragraph or list item. */
typedef enum ENRMRKD_SPANTYPE {
    /* <em>...</em> */
    ENRMRKD_SPAN_EM,

    /* <strong>...</strong> */
    ENRMRKD_SPAN_STRONG,

    /* <a href="xxx">...</a>
     * Detail: Structure ENRMRKD_SPAN_A_DETAIL. */
    ENRMRKD_SPAN_A,

    /* <img src="xxx">...</a>
     * Detail: Structure ENRMRKD_SPAN_IMG_DETAIL.
     * Note: Image text can contain nested spans and even nested images.
     * If rendered into ALT attribute of HTML <IMG> tag, it's responsibility
     * of the caller to deal with it.
     */
    ENRMRKD_SPAN_IMG,

    /* <code>...</code> */
    ENRMRKD_SPAN_CODE,

    /* <ins>...</ins>
     * Syntax: ++insert++
     * Note: Recognized only when ENRMRKD_FLAG_INSERT is enabled. */
    ENRMRKD_SPAN_INS,

    /* <del>...</del>
     * Note: Recognized only when ENRMRKD_FLAG_STRIKETHROUGH is enabled.
     */
    ENRMRKD_SPAN_DEL,

    /* For recognizing inline ($) and display ($$) equations
     * Note: Recognized only when ENRMRKD_FLAG_LATEXMATHSPANS is enabled.
     */
    ENRMRKD_SPAN_LATEXMATH,
    ENRMRKD_SPAN_LATEXMATH_DISPLAY,

    /* Wiki links
     * Note: Recognized only when ENRMRKD_FLAG_WIKILINKS is enabled.
     */
    ENRMRKD_SPAN_WIKILINK,

    /* <u>...</u>
     * Note: Recognized only when ENRMRKD_FLAG_UNDERLINE is enabled. */
    ENRMRKD_SPAN_U,

    /* Spoiler (hidden content revealed on interaction).
     * Syntax: ||hidden text||
     * Note: Recognized only when ENRMRKD_FLAG_SPOILERS is enabled. */
    ENRMRKD_SPAN_SPOILER,

    /* <sup>...</sup>
     * Syntax: ^superscript^
     * Note: Recognized only when ENRMRKD_FLAG_SUPERSCRIPTS is enabled. */
    ENRMRKD_SPAN_SUPERSCRIPT,

    /* <sub>...</sub>
     * Syntax: ~subscript~
     * Note: Recognized only when ENRMRKD_FLAG_SUBSCRIPTS is enabled. */
    ENRMRKD_SPAN_SUBSCRIPT,

    /* Footnote reference, e.g. [^1] or [^note].
     * Syntax: [^label]
     * Note: Recognized only when ENRMRKD_FLAG_FOOTNOTES is enabled.
     * The span is self-contained: no ENRMRKD_TEXT callbacks fire between enter and
     * leave. All needed information is in ENRMRKD_SPAN_FOOTNOTE_REF_DETAIL. */
    ENRMRKD_SPAN_FOOTNOTE_REF,

    /* <mark>...</mark>
     * Syntax: ==highlight==
     * Note: Recognized only when ENRMRKD_FLAG_HIGHLIGHT is enabled. */
    ENRMRKD_SPAN_MARK
} ENRMRKD_SPANTYPE;

/* Text is the actual textual contents of span. */
typedef enum ENRMRKD_TEXTTYPE {
    /* Normal text. */
    ENRMRKD_TEXT_NORMAL = 0,

    /* NULL character. CommonMark requires replacing NULL character with
     * the replacement char U+FFFD, so this allows caller to do that easily. */
    ENRMRKD_TEXT_NULLCHAR,

    /* Line breaks.
     * Note these are not sent from blocks with verbatim output (ENRMRKD_BLOCK_CODE
     * or ENRMRKD_BLOCK_HTML). In such cases, '\n' is part of the text itself. */
    ENRMRKD_TEXT_BR,         /* <br> (hard break) */
    ENRMRKD_TEXT_SOFTBR,     /* '\n' in source text where it is not semantically meaningful (soft break) */

    /* Entity.
     * (a) Named entity, e.g. &nbsp; 
     *     (Note MD4C does not have a list of known entities.
     *     Anything matching the regexp /&[A-Za-z][A-Za-z0-9]{1,47};/ is
     *     treated as a named entity.)
     * (b) Numerical entity, e.g. &#1234;
     * (c) Hexadecimal entity, e.g. &#x12AB;
     *
     * As MD4C is mostly encoding agnostic, application gets the verbatim
     * entity text into the ENRMRKD_PARSER::text_callback(). */
    ENRMRKD_TEXT_ENTITY,

    /* Text in a code block (inside ENRMRKD_BLOCK_CODE) or inlined code (`code`).
     * If it is inside ENRMRKD_BLOCK_CODE, it includes spaces for indentation and
     * '\n' for new lines. ENRMRKD_TEXT_BR and ENRMRKD_TEXT_SOFTBR are not sent for this
     * kind of text. */
    ENRMRKD_TEXT_CODE,

    /* Text is a raw HTML. If it is contents of a raw HTML block (i.e. not
     * an inline raw HTML), then ENRMRKD_TEXT_BR and ENRMRKD_TEXT_SOFTBR are not used.
     * The text contains verbatim '\n' for the new lines. */
    ENRMRKD_TEXT_HTML,

    /* Text is inside an equation. This is processed the same way as inlined code
     * spans (`code`). */
    ENRMRKD_TEXT_LATEXMATH
} ENRMRKD_TEXTTYPE;


/* Alignment enumeration. */
typedef enum ENRMRKD_ALIGN {
    ENRMRKD_ALIGN_DEFAULT = 0,   /* When unspecified. */
    ENRMRKD_ALIGN_LEFT,
    ENRMRKD_ALIGN_CENTER,
    ENRMRKD_ALIGN_RIGHT
} ENRMRKD_ALIGN;


/* String attribute.
 *
 * This wraps strings which are outside of a normal text flow and which are
 * propagated within various detailed structures, but which still may contain
 * string portions of different types like e.g. entities.
 *
 * So, for example, lets consider this image:
 *
 *     ![image alt text](http://example.org/image.png 'foo &quot; bar')
 *
 * The image alt text is propagated as a normal text via the ENRMRKD_PARSER::text()
 * callback. However, the image title ('foo &quot; bar') is propagated as
 * ENRMRKD_ATTRIBUTE in ENRMRKD_SPAN_IMG_DETAIL::title.
 *
 * Then the attribute ENRMRKD_SPAN_IMG_DETAIL::title shall provide the following:
 *  -- [0]: "foo "   (substr_types[0] == ENRMRKD_TEXT_NORMAL; substr_offsets[0] == 0)
 *  -- [1]: "&quot;" (substr_types[1] == ENRMRKD_TEXT_ENTITY; substr_offsets[1] == 4)
 *  -- [2]: " bar"   (substr_types[2] == ENRMRKD_TEXT_NORMAL; substr_offsets[2] == 10)
 *  -- [3]: (n/a)    (n/a                              ; substr_offsets[3] == 14)
 *
 * Note that these invariants are always guaranteed:
 *  -- substr_offsets[0] == 0
 *  -- substr_offsets[LAST+1] == size
 *  -- Currently, only ENRMRKD_TEXT_NORMAL, ENRMRKD_TEXT_ENTITY, ENRMRKD_TEXT_NULLCHAR
 *     substrings can appear. This could change only if the specification
 *     changes.
 */
typedef struct ENRMRKD_ATTRIBUTE {
    const ENRMRKD_CHAR* text;
    ENRMRKD_SIZE size;
    const ENRMRKD_TEXTTYPE* substr_types;
    const ENRMRKD_OFFSET* substr_offsets;
} ENRMRKD_ATTRIBUTE;


/* Detailed info for ENRMRKD_BLOCK_UL. */
typedef struct ENRMRKD_BLOCK_UL_DETAIL {
    int is_tight;               /* Non-zero if tight list, zero if loose. */
    ENRMRKD_CHAR mark;               /* Item bullet character in MarkDown source of the list, e.g. '-', '+', '*'. */
} ENRMRKD_BLOCK_UL_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_OL. */
typedef struct ENRMRKD_BLOCK_OL_DETAIL {
    unsigned start;             /* Start index of the ordered list. */
    int is_tight;               /* Non-zero if tight list, zero if loose. */
    ENRMRKD_CHAR mark_delimiter;     /* Character delimiting the item marks in MarkDown source, e.g. '.' or ')' */
} ENRMRKD_BLOCK_OL_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_LI. */
typedef struct ENRMRKD_BLOCK_LI_DETAIL {
    int is_task;                /* Can be non-zero only with ENRMRKD_FLAG_TASKLISTS */
    ENRMRKD_CHAR task_mark;          /* If is_task, then one of 'x', 'X' or ' '. Undefined otherwise. */
    ENRMRKD_OFFSET task_mark_offset; /* If is_task, then offset in the input of the char between '[' and ']'. */
} ENRMRKD_BLOCK_LI_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_H. */
typedef struct ENRMRKD_BLOCK_H_DETAIL {
    unsigned level;             /* Header level (1 - 6) */
} ENRMRKD_BLOCK_H_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_CODE. */
typedef struct ENRMRKD_BLOCK_CODE_DETAIL {
    ENRMRKD_ATTRIBUTE info;
    ENRMRKD_ATTRIBUTE lang;
    ENRMRKD_CHAR fence_char;         /* The character used for fenced code block; or zero for indented code block. */
} ENRMRKD_BLOCK_CODE_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_TABLE. */
typedef struct ENRMRKD_BLOCK_TABLE_DETAIL {
    unsigned col_count;         /* Count of columns in the table. */
    unsigned head_row_count;    /* Count of rows in the table header (currently always 1) */
    unsigned body_row_count;    /* Count of rows in the table body */
} ENRMRKD_BLOCK_TABLE_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_TH and ENRMRKD_BLOCK_TD. */
typedef struct ENRMRKD_BLOCK_TD_DETAIL {
    ENRMRKD_ALIGN align;
} ENRMRKD_BLOCK_TD_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_ADMONITION. */
typedef struct ENRMRKD_BLOCK_ADMONITION_DETAIL {
    ENRMRKD_ATTRIBUTE type;          /* One of "note", "tip", "important", "warning", "caution" */
} ENRMRKD_BLOCK_ADMONITION_DETAIL;

/* Detailed info for ENRMRKD_SPAN_A. */
typedef struct ENRMRKD_SPAN_A_DETAIL {
    ENRMRKD_ATTRIBUTE href;
    ENRMRKD_ATTRIBUTE title;
    int is_autolink;            /* nonzero if this is an autolink */
} ENRMRKD_SPAN_A_DETAIL;

/* Detailed info for ENRMRKD_SPAN_IMG. */
typedef struct ENRMRKD_SPAN_IMG_DETAIL {
    ENRMRKD_ATTRIBUTE src;
    ENRMRKD_ATTRIBUTE title;
} ENRMRKD_SPAN_IMG_DETAIL;

/* Detailed info for ENRMRKD_SPAN_WIKILINK. */
typedef struct ENRMRKD_SPAN_WIKILINK {
    ENRMRKD_ATTRIBUTE target;
} ENRMRKD_SPAN_WIKILINK_DETAIL;

/* Detailed info for ENRMRKD_SPAN_FOOTNOTE_REF. */
typedef struct ENRMRKD_SPAN_FOOTNOTE_REF_DETAIL {
    unsigned int id;            /* 1-based identifier of the referenced footnote */
    unsigned int ref_id;        /* 1-based identifier of this reference among references to the same footnote */
    ENRMRKD_ATTRIBUTE label;         /* Raw label text, e.g. "1" or "note" */
} ENRMRKD_SPAN_FOOTNOTE_REF_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_FOOTNOTE_DEF. */
typedef struct ENRMRKD_BLOCK_FOOTNOTE_DEF_DETAIL {
    unsigned int id;            /* 1-based identifier of this footnote */
    unsigned int ref_count;     /* Number of references to this footnote */
    ENRMRKD_ATTRIBUTE label;         /* Raw label text */
} ENRMRKD_BLOCK_FOOTNOTE_DEF_DETAIL;

/* Detailed info for ENRMRKD_BLOCK_BLANK. */
typedef struct ENRMRKD_BLOCK_BLANK_DETAIL {
    unsigned line_count;        /* Count of blank lines forming the block separation */
} ENRMRKD_BLOCK_BLANK_DETAIL;

/* Flags specifying extensions/deviations from CommonMark specification.
 *
 * By default (when ENRMRKD_PARSER::flags == 0), we follow CommonMark specification.
 * The following flags may allow some extensions or deviations from it.
 */
#define ENRMRKD_FLAG_COLLAPSEWHITESPACE          0x1      /* In ENRMRKD_TEXT_NORMAL, collapse non-trivial whitespace into single ' ' */
#define ENRMRKD_FLAG_PERMISSIVEATXHEADERS        0x2      /* Do not require space in ATX headers ( ###header ) */
#define ENRMRKD_FLAG_PERMISSIVEURLAUTOLINKS      0x4      /* Recognize URLs as autolinks even without '<', '>' */
#define ENRMRKD_FLAG_PERMISSIVEEMAILAUTOLINKS    0x8      /* Recognize e-mails as autolinks even without '<', '>' and 'mailto:' */
#define ENRMRKD_FLAG_NOINDENTEDCODEBLOCKS        0x10     /* Disable indented code blocks. (Only fenced code works.) */
#define ENRMRKD_FLAG_NOHTMLBLOCKS                0x20     /* Disable raw HTML blocks. */
#define ENRMRKD_FLAG_NOHTMLSPANS                 0x40     /* Disable raw HTML (inline). */
#define ENRMRKD_FLAG_TABLES                      0x100    /* Enable tables extension. */
#define ENRMRKD_FLAG_STRIKETHROUGH               0x200    /* Enable strikethrough extension. */
#define ENRMRKD_FLAG_PERMISSIVEWWWAUTOLINKS      0x400    /* Enable WWW autolinks (even without any scheme prefix, if they begin with 'www.') */
#define ENRMRKD_FLAG_TASKLISTS                   0x800    /* Enable task list extension. */
#define ENRMRKD_FLAG_LATEXMATHSPANS              0x1000   /* Enable $ and $$ containing LaTeX equations. */
#define ENRMRKD_FLAG_WIKILINKS                   0x2000   /* Enable wiki links extension. */
#define ENRMRKD_FLAG_UNDERLINE                   0x4000   /* Enable underline extension (and disables '_' for normal emphasis). */
#define ENRMRKD_FLAG_HARD_SOFT_BREAKS            0x8000   /* Force all soft breaks to act as hard breaks. */
#define ENRMRKD_FLAG_SPOILERS                    0x10000  /* Enable ||hidden text|| spoiler spans. */
#define ENRMRKD_FLAG_SUPERSCRIPTS                0x20000  /* Enable ^superscript^ spans. */
#define ENRMRKD_FLAG_SUBSCRIPTS                  0x40000  /* Enable ~subscript~ spans. */
#define ENRMRKD_FLAG_ADMONITIONS                 0x80000  /* Enable admonitions extension. */
#define ENRMRKD_FLAG_FOOTNOTES                   0x100000 /* Enable [^label] footnote references. */
#define ENRMRKD_FLAG_HIGHLIGHT                   0x200000 /* Enable ==highlight== spans. */
#define ENRMRKD_FLAG_PRESERVEBLANKLINES          0x400000 /* Report blank line runs as ENRMRKD_BLOCK_BLANK. */
#define ENRMRKD_FLAG_INSERT                      0x800000 /* Enable insert extension. */

#define ENRMRKD_FLAG_PERMISSIVEAUTOLINKS         (ENRMRKD_FLAG_PERMISSIVEEMAILAUTOLINKS | ENRMRKD_FLAG_PERMISSIVEURLAUTOLINKS | ENRMRKD_FLAG_PERMISSIVEWWWAUTOLINKS)
#define ENRMRKD_FLAG_NOHTML                      (ENRMRKD_FLAG_NOHTMLBLOCKS | ENRMRKD_FLAG_NOHTMLSPANS)

/* Convenient sets of flags corresponding to well-known Markdown dialects.
 *
 * Note we may only support subset of features of the referred dialect.
 * The constant just enables those extensions which bring us as close as
 * possible given what features we implement.
 *
 * ABI compatibility note: Meaning of these can change in time as new
 * extensions, bringing the dialect closer to the original, are implemented.
 */
#define ENRMRKD_DIALECT_COMMONMARK               0
#define ENRMRKD_DIALECT_GITHUB                   (ENRMRKD_FLAG_PERMISSIVEAUTOLINKS | ENRMRKD_FLAG_TABLES | ENRMRKD_FLAG_STRIKETHROUGH | ENRMRKD_FLAG_TASKLISTS | ENRMRKD_FLAG_ADMONITIONS | ENRMRKD_FLAG_FOOTNOTES)

/* Parser structure.
 */
typedef struct ENRMRKD_PARSER {
    /* Reserved. Set to zero.
     */
    unsigned abi_version;

    /* Dialect options. Bitmask of ENRMRKD_FLAG_xxxx values.
     */
    unsigned flags;

    /* Caller-provided rendering callbacks.
     *
     * For some block/span types, more detailed information is provided in a
     * type-specific structure pointed by the argument 'detail'.
     *
     * The last argument of all callbacks, 'userdata', is just propagated from
     * enrmrkd_parse() and is available for any use by the application.
     *
     * Note any strings provided to the callbacks as their arguments or as
     * members of any detail structure are generally not zero-terminated.
     * Application has to take the respective size information into account.
     *
     * Any rendering callback may abort further parsing of the document by
     * returning non-zero.
     */
    int (*enter_block)(ENRMRKD_BLOCKTYPE /*type*/, void* /*detail*/, void* /*userdata*/);
    int (*leave_block)(ENRMRKD_BLOCKTYPE /*type*/, void* /*detail*/, void* /*userdata*/);

    int (*enter_span)(ENRMRKD_SPANTYPE /*type*/, void* /*detail*/, void* /*userdata*/);
    int (*leave_span)(ENRMRKD_SPANTYPE /*type*/, void* /*detail*/, void* /*userdata*/);

    int (*text)(ENRMRKD_TEXTTYPE /*type*/, const ENRMRKD_CHAR* /*text*/, ENRMRKD_SIZE /*size*/, void* /*userdata*/);

    /* Debug callback. Optional (may be NULL).
     *
     * If provided and something goes wrong, this function gets called.
     * This is intended for debugging and problem diagnosis for developers;
     * it is not intended to provide any errors suitable for displaying to an
     * end user.
     */
    void (*debug_log)(const char* /*msg*/, void* /*userdata*/);

    /* Reserved. Set to NULL.
     */
    void (*syntax)(void);
} ENRMRKD_PARSER;


/* For backward compatibility. Do not use in new code.
 */
typedef ENRMRKD_PARSER ENRMRKD_RENDERER;


/* Parse the Markdown document stored in the string 'text' of size 'size'.
 * The parser provides callbacks to be called during the parsing so the
 * caller can render the document on the screen or convert the Markdown
 * to another format.
 *
 * Zero is returned on success. If a runtime error occurs (e.g. a memory
 * fails), -1 is returned. If the processing is aborted due any callback
 * returning non-zero, the return value of the callback is returned.
 */
int enrmrkd_parse(const ENRMRKD_CHAR* text, ENRMRKD_SIZE size, const ENRMRKD_PARSER* parser, void* userdata);


#ifdef __cplusplus
    }  /* extern "C" { */
#endif

#endif  /* ENRMRKD_H */
