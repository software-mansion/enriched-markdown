require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "EnrichedMarkdownCore"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = "https://github.com/software-mansion/react-native-enriched-markdown"
  s.license      = { :type => "MIT" }
  s.authors      = "Software Mansion"
  s.source       = { :git => "https://github.com/software-mansion/react-native-enriched-markdown.git" }

  s.platforms    = { :ios => min_ios_version_supported, :osx => "14.0" }

  s.source_files = "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}", "cpp/highlight/*.{hpp,cpp}"
  s.private_header_files = "cpp/**/*.{h,hpp}"

  s.pod_target_xcconfig = {
    "HEADER_SEARCH_PATHS" => '"$(PODS_TARGET_SRCROOT)/cpp/md4c" "$(PODS_TARGET_SRCROOT)/cpp/parser" "$(PODS_TARGET_SRCROOT)/cpp/highlight"',
    "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) MD4C_USE_UTF8=1",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17"
  }
end
