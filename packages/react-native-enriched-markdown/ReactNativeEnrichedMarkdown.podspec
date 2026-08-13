require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

monorepo = File.exist?(File.expand_path("../core/EnrichedMarkdownCore.podspec", __dir__))
cpp_root = monorepo ? "$(PODS_TARGET_SRCROOT)/../core/cpp" : "$(PODS_TARGET_SRCROOT)/cpp"

require File.join(__dir__, "cpp/highlight/code_highlight_podspec.rb")
# In the monorepo the C++ (including tree-sitter highlighting) compiles in the
# EnrichedMarkdownCore pod; only the published, core-less build compiles it here.
code_highlight = monorepo ? EnrichedMarkdownCodeHighlight.disabled : EnrichedMarkdownCodeHighlight.config(__dir__)

Pod::Spec.new do |s|
  s.name         = "ReactNativeEnrichedMarkdown"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported, :osx => '14.0' }
  s.source       = { :git => "https://github.com/software-mansion/react-native-enriched-markdown.git", :tag => "#{s.version}" }

  if monorepo
    s.private_header_files = "ios/**/*.h"
    s.source_files = "ios/**/*.{h,m,mm,cpp,swift}"
    s.dependency "EnrichedMarkdownCore"
  else
    s.private_header_files = "ios/**/*.h", "cpp/**/*.{h,hpp}"
    s.source_files = ["ios/**/*.{h,m,mm,cpp,swift}", "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}", "cpp/highlight/*.{hpp,cpp}"] + code_highlight[:source_files]
    s.preserve_paths = "cpp/highlight/vendor/**/*" if code_highlight[:enabled]
  end

  # LaTeX math rendering (RaTeX, iOS only). RaTeX ships as a prebuilt static XCFramework
  # vendored under ios/vendor (restored by vendor/vendor-ratex.mjs at postinstall); it
  # links under CocoaPods default static linkage and needs neither `use_frameworks!` nor
  # SPM interop.
  #
  # Resolution: ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] forces the choice ('0' off, '1' on).
  # Otherwise math tracks whether the consumer actually downloaded the framework, so a
  # package.json opt-out (`enriched-markdown`.enableMath = false skips the postinstall
  # download) yields a clean build with no Podfile edit. To disable explicitly, set
  # ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '0' in your Podfile.
  ratex_present = File.directory?(File.join(__dir__, 'ios/vendor/RaTeX.xcframework'))
  math_flag = ENV['ENRICHED_MARKDOWN_ENABLE_MATH']
  enable_math = math_flag == '1' || (math_flag != '0' && ratex_present)
  if !enable_math && math_flag != '0' && !ratex_present
    Pod::UI.warn '[ReactNativeEnrichedMarkdown] LaTeX math disabled: the vendored RaTeX ' \
      'XCFramework was not found at ios/vendor/RaTeX.xcframework. If this is unintended, re-run ' \
      '`node node_modules/react-native-enriched-markdown/postinstall.mjs` ' \
      "(or set ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '1' in your Podfile)."
  end

  # The RaTeX XCFramework bundles its own module.modulemap and headers; never let the
  # broad ios/**/*.h and ios/**/*.swift globs treat its internals as pod sources.
  exclude = ["ios/vendor/RaTeX.xcframework/**/*"]
  # ios/math holds the RaTeX bridge; ios/vendor/*.swift are RaTeX's vendored core Swift
  # sources. Both compile into this pod's module only when math is enabled.
  exclude += ["ios/math/**/*.swift", "ios/vendor/*.swift"] unless enable_math
  s.exclude_files = exclude

  preprocessor_defs = "$(inherited) MD4C_USE_UTF8=1#{code_highlight[:defines]}"
  if enable_math
    preprocessor_defs += ' ENRICHED_MARKDOWN_MATH=1'
    # Reachable only when math is force-enabled (ENRICHED_MARKDOWN_ENABLE_MATH='1') but the
    # vendored tree is missing; the unforced path already auto-disables above. ios/vendor is
    # kept out of the npm tarball and restored on the consumer's machine by postinstall (or
    # by `yarn prepare` in the monorepo), so fail early with an actionable message instead of
    # a confusing missing-file error.
    unless ratex_present
      raise '[ReactNativeEnrichedMarkdown] LaTeX math is enabled but the vendored RaTeX ' \
        'XCFramework is missing at ios/vendor/RaTeX.xcframework. ' \
        'For published installs, re-run: node node_modules/react-native-enriched-markdown/postinstall.mjs ' \
        'For monorepo development, run `yarn prepare` (or `node vendor/vendor-ratex.mjs`). ' \
        "To disable math, set ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '0' in your Podfile. See docs/LATEX_MATH.md."
    end
    # Prebuilt static XCFramework (device + simulator[arm64,x86_64] + macOS). Vendored
    # rather than pulled via spm_dependency, which compiled RaTeX's Swift wrapper per
    # requested arch (breaking universal simulator builds, #527) and double-collected
    # its XCFramework signature during archive assembly (#491).
    s.vendored_frameworks = 'ios/vendor/RaTeX.xcframework'
    # RaTeXFontLoader.loadFromCocoaPodsBundle() resolves "RaTeXCoreFonts.bundle" by name,
    # so this resource-bundle name is load-bearing -- keep it exactly RaTeXCoreFonts.
    s.resource_bundles = { 'RaTeXCoreFonts' => ['ios/vendor/Fonts/*.ttf'] }
  end

  pod_xcconfig = {
    'HEADER_SEARCH_PATHS' => ([
      "\"#{cpp_root}/md4c\"", "\"#{cpp_root}/parser\"", "\"#{cpp_root}/highlight\"",
      "\"$(PODS_TARGET_SRCROOT)/ios/internals\"", "\"$(PODS_TARGET_SRCROOT)/ios/input/internals\""
    ] + code_highlight[:header_paths].map { |p| "\"$(PODS_TARGET_SRCROOT)/#{p}\"" }).join(" "),
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_defs,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'DEFINES_MODULE' => 'YES'
  }

  # No EXCLUDED_ARCHS dance: the vendored simulator slice (ios-arm64_x86_64-simulator)
  # already contains x86_64, so universal simulator builds resolve on both arches.
  s.pod_target_xcconfig = pod_xcconfig

  # No script phases: vendoring a single prebuilt XCFramework means there is no
  # spm_dependency-generated duplicate RaTeXFFI modulemap to strip, and only one
  # signature is collected during archive assembly, so nothing collides.

  install_modules_dependencies(s)
end
