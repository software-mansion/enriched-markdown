require "json"
require File.join(__dir__, "cpp/highlight/code_highlight_podspec.rb")

package = JSON.parse(File.read(File.join(__dir__, "package.json")))
code_highlight = EnrichedMarkdownCodeHighlight.config(__dir__)

Pod::Spec.new do |s|
  s.name         = "EnrichedMarkdownCore"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/software-mansion/react-native-enriched-markdown"
  s.license      = { :type => "MIT" }
  s.authors      = "Software Mansion"
  s.source       = { :git => "https://github.com/software-mansion/react-native-enriched-markdown.git" }

  s.platforms    = { :ios => min_ios_version_supported, :osx => "14.0" }

  s.source_files = ["cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}", "cpp/highlight/*.{hpp,cpp}"] + code_highlight[:source_files]
  s.private_header_files = "cpp/**/*.{h,hpp}"
  # Include-only vendored sources (schema.*.c, tree_sitter/*.h, other runtime .c)
  # must ship even though they are not compiled, so quoted relative includes resolve.
  s.preserve_paths = "cpp/highlight/vendor/**/*" if code_highlight[:enabled]

  header_paths = ['"$(PODS_TARGET_SRCROOT)/cpp/md4c"', '"$(PODS_TARGET_SRCROOT)/cpp/parser"', '"$(PODS_TARGET_SRCROOT)/cpp/highlight"']
  header_paths += code_highlight[:header_paths].map { |p| "\"$(PODS_TARGET_SRCROOT)/#{p}\"" }

  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => header_paths.join(" "),
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) MD4C_USE_UTF8=1#{code_highlight[:defines]}",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
