#pragma once

// Reads the shared fixture files in fixtures/input: a JSON object whose "cases"
// array holds strings, or [markdown, expected] pairs of strings. Just enough
// JSON for that, so the host tests need no library; the Jest suites read the
// same files with JSON.parse.
#include "Utf16.hpp"
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace FixtureFile {

struct Json {
  enum Kind { String, Array, Object } kind = String;
  std::u16string string;
  std::vector<Json> items;
  std::vector<std::pair<std::string, Json>> members;
};

class Reader {
public:
  explicit Reader(std::string text) : text_(std::move(text)) {}

  Json value() {
    skipSpace();
    const char c = peek();
    if (c == '"') {
      Json json;
      json.string = string();
      return json;
    }
    if (c == '[') {
      pos_++;
      Json json;
      json.kind = Json::Array;
      for (skipSpace(); peek() != ']'; skipSpace()) {
        json.items.push_back(value());
        skipSpace();
        if (peek() == ',') {
          pos_++;
        }
      }
      pos_++;
      return json;
    }
    if (c == '{') {
      pos_++;
      Json json;
      json.kind = Json::Object;
      for (skipSpace(); peek() != '}'; skipSpace()) {
        const std::string key = Markdown::toUtf8(string());
        skipSpace();
        expect(':');
        json.members.emplace_back(key, value());
        skipSpace();
        if (peek() == ',') {
          pos_++;
        }
      }
      pos_++;
      return json;
    }
    if (c == '-' || (c >= '0' && c <= '9')) {
      // A number stays text: callers that want one convert it.
      Json json;
      while (pos_ < text_.size() && std::string("+-.eE0123456789").find(text_[pos_]) != std::string::npos) {
        json.string.push_back(static_cast<char16_t>(text_[pos_++]));
      }
      return json;
    }
    throw std::runtime_error("unsupported JSON value in a fixture file");
  }

private:
  char peek() const {
    if (pos_ >= text_.size()) {
      throw std::runtime_error("unexpected end of a fixture file");
    }
    return text_[pos_];
  }

  void expect(char c) {
    if (peek() != c) {
      throw std::runtime_error(std::string("expected '") + c + "' in a fixture file");
    }
    pos_++;
  }

  void skipSpace() {
    while (pos_ < text_.size() &&
           (text_[pos_] == ' ' || text_[pos_] == '\n' || text_[pos_] == '\r' || text_[pos_] == '\t')) {
      pos_++;
    }
  }

  std::u16string string() {
    expect('"');
    std::u16string out;
    std::string raw; // UTF-8 bytes between escapes
    const auto flush = [&] {
      out += Markdown::toUtf16(raw);
      raw.clear();
    };
    while (peek() != '"') {
      char c = text_[pos_++];
      if (c != '\\') {
        raw.push_back(c);
        continue;
      }
      flush();
      c = text_[pos_++];
      switch (c) {
        case 'n':
          out.push_back(u'\n');
          break;
        case 't':
          out.push_back(u'\t');
          break;
        case 'r':
          out.push_back(u'\r');
          break;
        case 'b':
          out.push_back(u'\b');
          break;
        case 'f':
          out.push_back(u'\f');
          break;
        case 'u':
          out.push_back(static_cast<char16_t>(std::stoi(text_.substr(pos_, 4), nullptr, 16)));
          pos_ += 4;
          break;
        default: // " \ /
          out.push_back(static_cast<char16_t>(c));
      }
    }
    flush();
    pos_++;
    return out;
  }

  std::string text_;
  size_t pos_ = 0;
};

inline Json read(const std::string &name) {
  std::ifstream file(std::string(INPUT_FIXTURES_DIR) + "/" + name, std::ios::binary);
  if (!file) {
    throw std::runtime_error("cannot open fixture " + name);
  }
  std::stringstream buffer;
  buffer << file.rdbuf();
  return Reader(buffer.str()).value();
}

// A member of an object, or null.
inline const Json *member(const Json &object, const std::string &key) {
  for (const auto &entry : object.members) {
    if (entry.first == key) {
      return &entry.second;
    }
  }
  return nullptr;
}

// The "cases" of a fixture file: one string per case, or two for a pair.
inline std::vector<std::vector<std::u16string>> load(const std::string &name) {
  const Json root = read(name);
  std::vector<std::vector<std::u16string>> cases;
  for (const auto &member : root.members) {
    if (member.first != "cases") {
      continue;
    }
    for (const Json &item : member.second.items) {
      if (item.kind == Json::String) {
        cases.push_back({item.string});
      } else {
        std::vector<std::u16string> parts;
        for (const Json &part : item.items) {
          parts.push_back(part.string);
        }
        cases.push_back(std::move(parts));
      }
    }
  }
  if (cases.empty()) {
    throw std::runtime_error("fixture " + name + " has no cases");
  }
  return cases;
}

} // namespace FixtureFile
