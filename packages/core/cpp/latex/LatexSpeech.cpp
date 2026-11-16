#include "LatexSpeech.hpp"

#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

namespace Markdown {

namespace {

using Words = std::vector<std::string>;

enum class TokenKind { Command, Symbol, Number, Letters };

struct Token {
  TokenKind kind;
  std::string text;

  bool operator==(const Token &other) const {
    return kind == other.kind && text == other.text;
  }
  bool operator!=(const Token &other) const {
    return !(*this == other);
  }
};

bool isAsciiLetter(unsigned char c) {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

bool isDigit(unsigned char c) {
  return c >= '0' && c <= '9';
}

bool isLetterStart(unsigned char c) {
  return isAsciiLetter(c) || c >= 0x80;
}

size_t utf8SequenceLength(unsigned char lead) {
  if (lead < 0x80)
    return 1;
  if (lead >= 0xF0)
    return 4;
  if (lead >= 0xE0)
    return 3;
  return 2;
}

size_t firstCharacterLength(std::string_view text) {
  if (text.empty())
    return 0;
  size_t length = utf8SequenceLength(static_cast<unsigned char>(text[0]));
  return length > text.size() ? text.size() : length;
}

std::vector<Token> tokenize(std::string_view latex) {
  std::vector<Token> tokens;
  size_t index = 0;
  auto take = [&](auto predicate) {
    size_t start = index;
    while (index < latex.size() && predicate(static_cast<unsigned char>(latex[index])))
      index++;
    return std::string(latex.substr(start, index - start));
  };

  while (index < latex.size()) {
    unsigned char c = static_cast<unsigned char>(latex[index]);
    if (c == '\\') {
      index++;
      if (index >= latex.size())
        break;
      if (isAsciiLetter(static_cast<unsigned char>(latex[index]))) {
        tokens.push_back({TokenKind::Command, take(isAsciiLetter)});
      } else {
        size_t length = firstCharacterLength(latex.substr(index));
        tokens.push_back({TokenKind::Command, std::string(latex.substr(index, length))});
        index += length;
      }
    } else if (isDigit(c)) {
      tokens.push_back({TokenKind::Number, take([](unsigned char ch) { return isDigit(ch) || ch == '.'; })});
    } else if (isLetterStart(c)) {
      tokens.push_back({TokenKind::Letters, take(isLetterStart)});
    } else if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      index++;
    } else {
      tokens.push_back({TokenKind::Symbol, std::string(1, static_cast<char>(c))});
      index++;
    }
  }
  return tokens;
}

struct Argument {
  Words words;
  int items = 0;
  bool nested = false;

  bool isSimple() const {
    return items == 1 && !nested;
  }

  Words closed(const char *marker) const {
    if (isSimple())
      return words;
    Words result = words;
    result.push_back(marker);
    return result;
  }
};

Words operator+(Words left, const Words &right) {
  left.insert(left.end(), right.begin(), right.end());
  return left;
}

Words operator+(Words left, const char *word) {
  left.push_back(word);
  return left;
}

Words &operator+=(Words &left, const Words &right) {
  left.insert(left.end(), right.begin(), right.end());
  return left;
}

struct Environment {
  const char *open;
  const char *row;
  const char *close;
  bool hasColumnSpec;
};

const Environment kMatrix{"matrix", "next row", "end matrix", false};
const Environment kCases{"cases", "next case", "end cases", false};
const Environment kArray{"", "next row", "", true};
const Environment kAligned{"", "next line", "", false};
const Environment kUnknown{"", "next row", "", false};

const Environment &environment(const std::string &name) {
  static const std::unordered_map<std::string, const Environment *> kEnvironments = {
      {"matrix", &kMatrix},   {"pmatrix", &kMatrix},   {"bmatrix", &kMatrix},     {"Bmatrix", &kMatrix},
      {"vmatrix", &kMatrix},  {"Vmatrix", &kMatrix},   {"smallmatrix", &kMatrix}, {"cases", &kCases},
      {"dcases", &kCases},    {"array", &kArray},      {"aligned", &kAligned},    {"align", &kAligned},
      {"align*", &kAligned},  {"alignat", &kAligned},  {"gather", &kAligned},     {"gathered", &kAligned},
      {"split", &kAligned},   {"equation", &kAligned}, {"equation*", &kAligned},  {"multline", &kAligned},
      {"eqnarray", &kAligned}};
  auto found = kEnvironments.find(name);
  return found == kEnvironments.end() ? kUnknown : *found->second;
}

const std::unordered_map<char, std::string> kSymbolWords = {{'+', "plus"},
                                                            {'-', "minus"},
                                                            {'=', "equals"},
                                                            {'<', "less than"},
                                                            {'>', "greater than"},
                                                            {'/', "over"},
                                                            {'*', "times"},
                                                            {'!', "factorial"},
                                                            {'\'', "prime"},
                                                            {',', "comma"},
                                                            {'.', "point"},
                                                            {'(', "open paren"},
                                                            {')', "close paren"},
                                                            {'[', "open bracket"},
                                                            {']', "close bracket"},
                                                            {'|', "vertical bar"},
                                                            {':', "colon"},
                                                            {';', ""},
                                                            {'&', ""},
                                                            {'~', ""},
                                                            {'^', ""},
                                                            {'_', ""},
                                                            {'}', ""}};

const std::unordered_map<std::string, std::string> kBigOperators = {
    {"prod", "product"}, {"int", "integral"}, {"iint", "double integral"}, {"oint", "contour integral"},
    {"lim", "limit"},    {"bigcup", "union"}, {"bigcap", "intersection"}};

const std::unordered_map<std::string, std::string> kDecorations = {{"overline", "bar"}, {"ddot", "double dot"}};

std::unordered_map<std::string, std::string> buildCommandWords() {
  std::unordered_map<std::string, std::string> words = {{",", ""},
                                                        {";", ""},
                                                        {":", ""},
                                                        {"!", ""},
                                                        {" ", ""},
                                                        {"quad", ""},
                                                        {"qquad", ""},
                                                        {"displaystyle", ""},
                                                        {"textstyle", ""},
                                                        {"nonumber", ""},
                                                        {"limits", ""},
                                                        {"nolimits", ""},
                                                        {"{", "open brace"},
                                                        {"}", "close brace"},
                                                        {"|", "double bar"},
                                                        {"%", "percent"},
                                                        {"_", "underscore"},
                                                        {"infty", "infinity"},
                                                        {"hbar", "h bar"},
                                                        {"cdots", "dot dot dot"},
                                                        {"ldots", "dot dot dot"},
                                                        {"dots", "dot dot dot"},
                                                        {"vdots", "dot dot dot"},
                                                        {"degree", "degrees"},
                                                        {"emptyset", "empty set"},
                                                        {"neq", "not equal to"},
                                                        {"ne", "not equal to"},
                                                        {"leq", "less than or equal to"},
                                                        {"le", "less than or equal to"},
                                                        {"geq", "greater than or equal to"},
                                                        {"ge", "greater than or equal to"},
                                                        {"approx", "approximately equal to"},
                                                        {"equiv", "is equivalent to"},
                                                        {"sim", "similar to"},
                                                        {"propto", "proportional to"},
                                                        {"cdot", "times"},
                                                        {"div", "divided by"},
                                                        {"pm", "plus or minus"},
                                                        {"mp", "minus or plus"},
                                                        {"rightarrow", "to"},
                                                        {"leftarrow", "from"},
                                                        {"Rightarrow", "implies"},
                                                        {"Leftrightarrow", "if and only if"},
                                                        {"mapsto", "maps to"},
                                                        {"notin", "not in"},
                                                        {"subset", "subset of"},
                                                        {"subseteq", "subset of or equal to"},
                                                        {"supset", "superset of"},
                                                        {"cup", "union"},
                                                        {"cap", "intersection"},
                                                        {"forall", "for all"},
                                                        {"exists", "there exists"},
                                                        {"perp", "perpendicular to"},
                                                        {"parallel", "parallel to"},
                                                        {"mid", "given"},
                                                        {"circ", "composed with"},
                                                        {"sin", "sine"},
                                                        {"cos", "cosine"},
                                                        {"tan", "tangent"},
                                                        {"cot", "cotangent"},
                                                        {"sec", "secant"},
                                                        {"csc", "cosecant"},
                                                        {"arcsin", "arc sine"},
                                                        {"arccos", "arc cosine"},
                                                        {"arctan", "arc tangent"},
                                                        {"sinh", "hyperbolic sine"},
                                                        {"cosh", "hyperbolic cosine"},
                                                        {"tanh", "hyperbolic tangent"},
                                                        {"ln", "natural log"},
                                                        {"exp", "exponential"},
                                                        {"det", "determinant"},
                                                        {"dim", "dimension"},
                                                        {"sup", "supremum"},
                                                        {"inf", "infimum"},
                                                        {"ker", "kernel"},
                                                        {"Re", "real part"},
                                                        {"Im", "imaginary part"}};
  static const char *const kGreek[] = {
      "alpha", "beta",     "gamma",  "delta",   "epsilon", "varepsilon", "zeta", "eta",   "theta", "vartheta",
      "iota",  "kappa",    "lambda", "mu",      "nu",      "xi",         "pi",   "varpi", "rho",   "varrho",
      "sigma", "varsigma", "tau",    "upsilon", "phi",     "varphi",     "chi",  "psi",   "omega"};
  for (std::string letter : kGreek) {
    std::string spoken = letter.compare(0, 3, "var") == 0 ? letter.substr(3) : letter;
    words[letter] = spoken;
    std::string capital = letter;
    capital[0] = static_cast<char>(capital[0] - 'a' + 'A');
    words[capital] = "cap " + spoken;
  }
  return words;
}

const std::unordered_map<std::string, std::string> &commandWords() {
  static const std::unordered_map<std::string, std::string> kWords = buildCommandWords();
  return kWords;
}

Words spoken(const std::unordered_map<std::string, std::string> &table, const std::string &key) {
  auto found = table.find(key);
  if (found == table.end())
    return {key};
  return found->second.empty() ? Words{} : Words{found->second};
}

class Parser {
public:
  explicit Parser(std::vector<Token> tokens) : tokens_(std::move(tokens)) {}

  Argument group(const std::optional<Token> &closer) {
    Argument result;
    while (position_ < tokens_.size() && (!closer || tokens_[position_] != *closer)) {
      Argument member = item();
      if (!member.words.empty()) {
        result.words += member.words;
        result.items++;
        result.nested = result.nested || member.nested;
      }
    }
    position_++;
    return result;
  }

private:
  enum class Mode { Math, Text, Limit };

  static const Token kOpenBrace;
  static const Token kCloseBrace;
  static const Token kOpenBracket;
  static const Token kCloseBracket;
  static const Token kCaret;
  static const Token kUnderscore;

  const Token *current() const {
    return position_ < tokens_.size() ? &tokens_[position_] : nullptr;
  }

  Argument item() {
    Argument base = operand(false);
    auto [sub, sup] = scripts();
    Argument result;
    result.words = base.words + index(sub) + power(sup);
    result.items = result.words.empty() ? 0 : 1;
    result.nested = base.nested || base.items > 1 || (sub && !sub->isSimple()) || (sup && !isTightPower(*sup));
    return result;
  }

  Argument operand(bool single) {
    const Token *token = current();
    if (!token)
      return {};
    if (*token == kOpenBrace) {
      position_++;
      return group(kCloseBrace);
    }
    Token head = *token;
    if (single && (token->kind == TokenKind::Number || token->kind == TokenKind::Letters)) {
      size_t length = firstCharacterLength(token->text);
      if (length < token->text.size()) {
        head.text = token->text.substr(0, length);
        tokens_[position_].text.erase(0, length);
        return atom(head);
      }
    }
    position_++;
    return atom(head);
  }

  Argument operand(bool single, Mode mode) {
    Mode outer = mode_;
    mode_ = mode;
    Argument result = operand(single);
    mode_ = outer;
    return result;
  }

  std::pair<std::optional<Argument>, std::optional<Argument>> scripts() {
    std::optional<Argument> sub;
    std::optional<Argument> sup;
    while (const Token *script = current()) {
      if (*script != kCaret && *script != kUnderscore)
        break;
      bool isPower = *script == kCaret;
      position_++;
      (isPower ? sup : sub) = operand(true);
    }
    return {sub, sup};
  }

  Argument atom(const Token &token) {
    Words words;
    switch (token.kind) {
      case TokenKind::Symbol: {
        auto found = kSymbolWords.find(token.text[0]);
        if (found == kSymbolWords.end())
          words = {token.text};
        else if (!found->second.empty())
          words = {found->second};
        break;
      }
      case TokenKind::Number:
        words = {token.text};
        break;
      case TokenKind::Letters:
        words = letters(token.text);
        break;
      case TokenKind::Command:
        return command(token.text);
    }
    Argument result;
    result.words = words;
    result.items = words.empty() ? 0 : 1;
    return result;
  }

  Words letters(const std::string &run) {
    std::vector<std::string> characters;
    for (size_t index = 0; index < run.size();) {
      size_t length = firstCharacterLength(run.substr(index));
      characters.push_back(run.substr(index, length));
      index += length;
    }
    if (mode_ == Mode::Text || characters.size() > 2)
      return {run};
    return characters;
  }

  Argument command(const std::string &name) {
    Argument result;
    result.items = 1;
    if (name == "frac" || name == "dfrac" || name == "tfrac") {
      Argument numerator = operand(true);
      result.words = fraction(numerator, operand(true));
      result.nested = true;
    } else if (name == "binom") {
      Argument top = operand(true);
      result.words = top.words + "choose" + operand(true).words;
      result.nested = true;
    } else if (name == "sqrt") {
      Argument degree;
      if (const Token *token = current(); token && *token == kOpenBracket) {
        position_++;
        degree = group(kCloseBracket);
      }
      result.words = root(degree, operand(true));
      result.nested = true;
    } else if (name == "text" || name == "textrm" || name == "textbf" || name == "textit" || name == "mathrm" ||
               name == "mathbf" || name == "mathit" || name == "mathsf" || name == "mathtt" || name == "mbox" ||
               name == "operatorname") {
      if (const Token *token = current(); name == "operatorname" && token && *token == Token{TokenKind::Symbol, "*"})
        position_++;
      result.words = operand(true, Mode::Text).words;
    } else if (name == "mathbb" || name == "mathcal" || name == "mathfrak" || name == "boldsymbol" || name == "bm") {
      result.words = operand(true).words;
    } else if (name == "vec") {
      result.words = Words{"vector"} + operand(true).words;
    } else if (name == "hat" || name == "bar" || name == "overline" || name == "tilde" || name == "dot" ||
               name == "ddot") {
      auto decoration = kDecorations.find(name);
      result.words = operand(true).words + (decoration == kDecorations.end() ? name : decoration->second).c_str();
    } else if (name == "left" || name == "right") {
      if (const Token *token = current(); token && *token == Token{TokenKind::Symbol, "."})
        position_++;
    } else if (name == "sum" || name == "prod" || name == "int" || name == "iint" || name == "oint" || name == "lim" ||
               name == "bigcup" || name == "bigcap") {
      result.words = bigOperator(name);
    } else if ((name == "to" || name == "rightarrow") && mode_ == Mode::Limit) {
      result.words = {"approaches"};
    } else if (name == "begin") {
      result.words = beginEnvironment();
    } else if (name == "end") {
      environmentName();
      if (!environments_.empty()) {
        const char *close = environments_.back()->close;
        environments_.pop_back();
        if (*close)
          result.words = {close};
      }
    } else if (name == "\\") {
      if (!environments_.empty())
        result.words = {environments_.back()->row};
    } else {
      result.words = spoken(commandWords(), name);
    }
    if (result.words.empty())
      result.items = 0;
    return result;
  }

  Words beginEnvironment() {
    const Environment &env = environment(environmentName());
    environments_.push_back(&env);
    if (env.hasColumnSpec)
      operand(true);
    return *env.open ? Words{env.open} : Words{};
  }

  std::string environmentName() {
    const Token *token = current();
    if (!token || *token != kOpenBrace)
      return {};
    position_++;
    std::string name;
    while (const Token *part = current()) {
      position_++;
      if (*part == kCloseBrace)
        break;
      name += part->text;
    }
    return name;
  }

  Words bigOperator(const std::string &name) {
    Mode outer = mode_;
    mode_ = name == "lim" ? Mode::Limit : mode_;
    while (const Token *token = current()) {
      if (*token != Token{TokenKind::Command, "limits"} && *token != Token{TokenKind::Command, "nolimits"})
        break;
      position_++;
    }
    auto [lower, upper] = scripts();
    mode_ = outer;

    auto found = kBigOperators.find(name);
    Words words{found == kBigOperators.end() ? name : found->second};
    if (lower)
      words += Words{name == "lim" ? "as" : "from"} + lower->words;
    if (upper)
      words += Words{"to"} + upper->words;
    return words + "of";
  }

  static bool isTightPower(const Argument &exponent) {
    return exponent.words == Words{"2"} || exponent.words == Words{"3"};
  }

  static Words power(const std::optional<Argument> &exponent) {
    if (!exponent || exponent->words.empty())
      return {};
    if (exponent->words == Words{"2"})
      return {"squared"};
    if (exponent->words == Words{"3"})
      return {"cubed"};
    if (exponent->isSimple())
      return Words{"to the power"} + exponent->words;
    return Words{"to the power of"} + exponent->closed("end power");
  }

  static Words index(const std::optional<Argument> &sub) {
    if (!sub || sub->words.empty())
      return {};
    return Words{"sub"} + sub->closed("end sub");
  }

  static Words fraction(const Argument &numerator, const Argument &denominator) {
    if (numerator.isSimple() && denominator.isSimple())
      return numerator.words + "over" + denominator.words;
    return Words{"fraction"} + numerator.words + "over" + denominator.words + "end fraction";
  }

  static Words root(const Argument &degree, const Argument &radicand) {
    Words body = radicand.closed("end root");
    if (degree.words.empty())
      return Words{"square root of"} + body;
    if (degree.words == Words{"3"})
      return Words{"cube root of"} + body;
    return Words{"root"} + degree.words + "of" + body;
  }

  std::vector<Token> tokens_;
  size_t position_ = 0;
  Mode mode_ = Mode::Math;
  std::vector<const Environment *> environments_;
};

const Token Parser::kOpenBrace{TokenKind::Symbol, "{"};
const Token Parser::kCloseBrace{TokenKind::Symbol, "}"};
const Token Parser::kOpenBracket{TokenKind::Symbol, "["};
const Token Parser::kCloseBracket{TokenKind::Symbol, "]"};
const Token Parser::kCaret{TokenKind::Symbol, "^"};
const Token Parser::kUnderscore{TokenKind::Symbol, "_"};

} // namespace

std::string spokenLatex(std::string_view latex) {
  Parser parser(tokenize(latex));
  std::string result;
  for (const std::string &word : parser.group(std::nullopt).words) {
    if (!result.empty())
      result += ' ';
    result += word;
  }
  return result;
}

} // namespace Markdown
