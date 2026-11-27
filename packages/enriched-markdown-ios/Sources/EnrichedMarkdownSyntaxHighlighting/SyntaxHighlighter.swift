import CryptoKit
import EnrichedMarkdownTreeSitter
import Foundation

enum SyntaxHighlighter {
    struct Token: Equatable {
        let range: NSRange
        let type: SyntaxTokenType
    }

    static func tokens(in code: [UInt8], language: String) -> [Token] {
        let key = cacheKey(for: code, language: language)
        if let cached = cache.object(forKey: key) {
            return cached.tokens
        }

        let tokens = tokenize(code, language: language)
        cache.setObject(TokenList(tokens), forKey: key, cost: tokens.count * MemoryLayout<Token>.stride)
        return tokens
    }

    private static let cache: NSCache<NSData, TokenList> = {
        let cache = NSCache<NSData, TokenList>()
        cache.countLimit = 128
        cache.totalCostLimit = 4 * 1024 * 1024
        return cache
    }()

    private static func cacheKey(for code: [UInt8], language: String) -> NSData {
        var digest = SHA256()
        digest.update(data: Data("\(language)\n".utf8))
        digest.update(data: code)
        return Data(digest.finalize()) as NSData
    }

    private static func tokenize(_ code: [UInt8], language: String) -> [Token] {
        var count = 0
        guard let tokens = code.withUnsafeBytes({ bytes in
            em_highlight_code(bytes.baseAddress?.assumingMemoryBound(to: CChar.self), bytes.count, language, &count)
        }) else {
            return []
        }
        defer { em_highlight_tokens_release(tokens) }

        return UnsafeBufferPointer(start: tokens, count: count).compactMap { token in
            guard let type = SyntaxTokenType(rawValue: token.type) else { return nil }
            return Token(range: NSRange(location: Int(token.start), length: Int(token.end - token.start)), type: type)
        }
    }
}

private final class TokenList {
    let tokens: [SyntaxHighlighter.Token]

    init(_ tokens: [SyntaxHighlighter.Token]) {
        self.tokens = tokens
    }
}
