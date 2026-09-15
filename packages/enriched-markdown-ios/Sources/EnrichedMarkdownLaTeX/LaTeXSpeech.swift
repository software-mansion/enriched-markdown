import Foundation

/// Spoken English for a LaTeX formula ("x squared over 2" rather than
/// "x caret 2 slash 2"). Covers fractions, roots, powers and indices, big
/// operators with bounds, Greek letters, relations, decorations, and
/// text; an unmapped command is read by name so nothing is dropped.
/// Compound arguments are closed with "end fraction", "end power", etc.
public enum LaTeXSpeech {
    public static func spokenForm(of latex: String) -> String {
        var parser = Parser(tokens: Tokenizer.tokenize(latex))
        return parser.group(until: nil).words.joined(separator: " ")
    }
}

// MARK: - Tokens

private enum Token: Equatable {
    /// Name without the backslash; a single non-letter for `\,`, `\{`, …
    case command(String)
    case symbol(Character)
    case number(String)
    case letters(String)
}

private enum Tokenizer {
    static func tokenize(_ latex: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(latex)
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "\\" {
                index += 1
                guard index < chars.count else { break }
                if chars[index].isLetter {
                    tokens.append(.command(run(in: chars, from: &index) { $0.isLetter }))
                } else {
                    tokens.append(.command(String(chars[index])))
                    index += 1
                }
            } else if char.isNumber {
                tokens.append(.number(run(in: chars, from: &index) { $0.isNumber || $0 == "." }))
            } else if char.isLetter {
                tokens.append(.letters(run(in: chars, from: &index) { $0.isLetter }))
            } else if char.isWhitespace {
                index += 1
            } else {
                tokens.append(.symbol(char))
                index += 1
            }
        }
        return tokens
    }

    private static func run(in chars: [Character], from index: inout Int, while predicate: (Character) -> Bool) -> String {
        var text = ""
        while index < chars.count, predicate(chars[index]) {
            text.append(chars[index])
            index += 1
        }
        return text
    }
}

// MARK: - Parser

/// Recursive descent over the token stream, producing spoken words.
private struct Parser {
    /// A command argument: its words plus how many items produced them, so
    /// wording can tell `n^2` (one item) from `a+b` (three) and close the
    /// latter with an end marker.
    struct Argument {
        var words: [String] = []
        var itemCount: Int = 0

        var isSimple: Bool { itemCount == 1 }

        func closed(with marker: String) -> [String] {
            itemCount > 1 ? words + [marker] : words
        }
    }

    private enum Mode {
        case math
        /// Inside `\text{…}`: letter runs stay words.
        case text
        /// Inside a `\lim` bound: `\to` reads "approaches".
        case limit
    }

    private let tokens: [Token]
    private var position: Int = 0
    private var mode: Mode = .math

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    private var current: Token? {
        position < tokens.count ? tokens[position] : nil
    }

    private mutating func advance() {
        position += 1
    }

    /// Items up to `closer`, which is consumed; nil reads to the end.
    mutating func group(until closer: Token?) -> Argument {
        var group = Argument()
        while let token = current, token != closer {
            let words = item()
            if !words.isEmpty {
                group.words += words
                group.itemCount += 1
            }
        }
        advance()
        return group
    }

    /// One atom plus its `^` / `_` scripts.
    private mutating func item() -> [String] {
        let base = argument().words
        let (sub, sup) = scripts()
        return base + Self.index(sub) + Self.power(sup)
    }

    /// A braced group or a single atom, as TeX reads command arguments.
    private mutating func argument() -> Argument {
        guard let token = current else { return Argument() }
        advance()
        if token == .symbol("{") {
            return group(until: .symbol("}"))
        }
        let words = atom(token)
        return Argument(words: words, itemCount: words.isEmpty ? 0 : 1)
    }

    private mutating func argument(in mode: Mode) -> Argument {
        let outer = self.mode
        self.mode = mode
        defer { self.mode = outer }
        return argument()
    }

    /// Trailing `^` / `_` scripts in either order.
    private mutating func scripts() -> (sub: Argument?, sup: Argument?) {
        var sub: Argument?
        var sup: Argument?
        while let script = current, script == .symbol("^") || script == .symbol("_") {
            advance()
            if script == .symbol("^") {
                sup = argument()
            } else {
                sub = argument()
            }
        }
        return (sub, sup)
    }

    private mutating func atom(_ token: Token) -> [String] {
        switch token {
        case .symbol(let char):
            return Self.spoken(Self.symbolWords[char], fallback: String(char))
        case .number(let number):
            return [number]
        case .letters(let run):
            // Short runs are juxtaposed variables ("dx"); longer ones are
            // words ("max").
            return mode == .text || run.count > 2 ? [run] : run.map { String($0) }
        case .command(let name):
            return command(name)
        }
    }

    private mutating func command(_ name: String) -> [String] {
        switch name {
        case "frac", "dfrac", "tfrac":
            let numerator = argument()
            return Self.fraction(numerator, over: argument())
        case "binom":
            let top = argument()
            return top.words + ["choose"] + argument().words
        case "sqrt":
            let degree = current == .symbol("[") ? { advance(); return group(until: .symbol("]")) }() : Argument()
            return Self.root(degree: degree, of: argument())
        case "text", "textrm", "textbf", "textit", "mathrm", "mathbf", "mathit", "mathsf", "mathtt", "operatorname", "mbox":
            return argument(in: .text).words
        case "mathbb", "mathcal", "mathfrak", "boldsymbol", "bm":
            return argument().words
        case "vec":
            return ["vector"] + argument().words
        case "hat", "bar", "overline", "tilde", "dot", "ddot":
            return argument().words + [Self.decorations[name] ?? name]
        case "left", "right":
            // The delimiter that follows is read as a plain symbol; `\left.`
            // is the invisible one.
            if current == .symbol(".") {
                advance()
            }
            return []
        case "sum", "prod", "int", "iint", "oint", "lim", "bigcup", "bigcap":
            return bigOperator(name)
        case "to" where mode == .limit, "rightarrow" where mode == .limit:
            return ["approaches"]
        default:
            return Self.spoken(Self.commandWords[name], fallback: name)
        }
    }

    /// `\sum_{a}^{b}` → "sum from a to b of"; `\lim_{x \to 0}` → "limit as
    /// x approaches 0 of".
    private mutating func bigOperator(_ name: String) -> [String] {
        let outer = mode
        mode = name == "lim" ? .limit : mode
        let (lower, upper) = scripts()
        mode = outer

        var words = [Self.bigOperators[name] ?? name]
        if let lower {
            words += [name == "lim" ? "as" : "from"] + lower.words
        }
        if let upper {
            words += ["to"] + upper.words
        }
        return words + ["of"]
    }

    // MARK: Wording

    private static func power(_ exponent: Argument?) -> [String] {
        guard let exponent, !exponent.words.isEmpty else { return [] }
        switch exponent.words {
        case ["2"]: return ["squared"]
        case ["3"]: return ["cubed"]
        default: return exponent.isSimple
            ? ["to the power"] + exponent.words
            : ["to the power of"] + exponent.closed(with: "end power")
        }
    }

    private static func index(_ sub: Argument?) -> [String] {
        guard let sub, !sub.words.isEmpty else { return [] }
        return ["sub"] + sub.closed(with: "end sub")
    }

    private static func fraction(_ numerator: Argument, over denominator: Argument) -> [String] {
        if numerator.isSimple, denominator.isSimple {
            return numerator.words + ["over"] + denominator.words
        }
        return ["fraction"] + numerator.words + ["over"] + denominator.words + ["end fraction"]
    }

    private static func root(degree: Argument, of radicand: Argument) -> [String] {
        let body = radicand.closed(with: "end root")
        switch degree.words {
        case []: return ["square root of"] + body
        case ["3"]: return ["cube root of"] + body
        default: return ["root"] + degree.words + ["of"] + body
        }
    }

    /// Table lookup: an empty mapping is spoken as nothing (spacing and
    /// layout), a missing one as the fallback.
    private static func spoken(_ word: String?, fallback: String) -> [String] {
        guard let word else { return [fallback] }
        return word.isEmpty ? [] : [word]
    }

    private static let symbolWords: [Character: String] = [
        "+": "plus", "-": "minus", "=": "equals", "<": "less than", ">": "greater than",
        "/": "over", "*": "times", "!": "factorial", "'": "prime", ",": "comma", ".": "point",
        "(": "open paren", ")": "close paren", "[": "open bracket", "]": "close bracket",
        "|": "vertical bar", ":": "colon", ";": "", "&": "", "~": "", "^": "", "_": "", "}": ""
    ]

    private static let bigOperators: [String: String] = [
        "prod": "product", "int": "integral", "iint": "double integral", "oint": "contour integral",
        "lim": "limit", "bigcup": "union", "bigcap": "intersection"
    ]

    private static let decorations: [String: String] = ["overline": "bar", "ddot": "double dot"]

    /// Commands whose spoken form differs from their name; empty = silent.
    private static let commandWords: [String: String] = {
        var words: [String: String] = [
            ",": "", ";": "", ":": "", "!": "", " ": "", "\\": "", "quad": "", "qquad": "",
            "displaystyle": "", "textstyle": "", "nonumber": "",
            "{": "open brace", "}": "close brace", "|": "double bar", "%": "percent", "_": "underscore",
            "infty": "infinity", "hbar": "h bar",
            "cdots": "dot dot dot", "ldots": "dot dot dot", "dots": "dot dot dot", "vdots": "dot dot dot",
            "degree": "degrees", "emptyset": "empty set",
            "neq": "not equal to", "ne": "not equal to", "leq": "less than or equal to", "le": "less than or equal to",
            "geq": "greater than or equal to", "ge": "greater than or equal to", "approx": "approximately equal to",
            "equiv": "is equivalent to", "sim": "similar to", "propto": "proportional to",
            "cdot": "times", "div": "divided by", "pm": "plus or minus", "mp": "minus or plus",
            "rightarrow": "to", "leftarrow": "from", "Rightarrow": "implies", "Leftrightarrow": "if and only if",
            "mapsto": "maps to", "notin": "not in", "subset": "subset of", "subseteq": "subset of or equal to",
            "supset": "superset of", "cup": "union", "cap": "intersection", "forall": "for all", "exists": "there exists",
            "perp": "perpendicular to", "parallel": "parallel to", "mid": "given", "circ": "composed with",
            "sin": "sine", "cos": "cosine", "tan": "tangent", "cot": "cotangent", "sec": "secant", "csc": "cosecant",
            "arcsin": "arc sine", "arccos": "arc cosine", "arctan": "arc tangent",
            "sinh": "hyperbolic sine", "cosh": "hyperbolic cosine", "tanh": "hyperbolic tangent",
            "ln": "natural log", "exp": "exponential", "det": "determinant", "dim": "dimension",
            "sup": "supremum", "inf": "infimum", "ker": "kernel", "Re": "real part", "Im": "imaginary part"
        ]
        let greek = [
            "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta", "theta", "vartheta", "iota",
            "kappa", "lambda", "mu", "nu", "xi", "pi", "varpi", "rho", "varrho", "sigma", "varsigma", "tau",
            "upsilon", "phi", "varphi", "chi", "psi", "omega"
        ]
        for letter in greek {
            let spoken = letter.hasPrefix("var") ? String(letter.dropFirst(3)) : letter
            words[letter] = spoken
            words[letter.prefix(1).uppercased() + letter.dropFirst()] = "capital " + spoken
        }
        return words
    }()
}
