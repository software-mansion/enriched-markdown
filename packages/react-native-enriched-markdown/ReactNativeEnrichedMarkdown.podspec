require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

monorepo = File.exist?(File.expand_path("../core/EnrichedMarkdownCore.podspec", __dir__))
cpp_root = monorepo ? "$(PODS_TARGET_SRCROOT)/../core/cpp" : "$(PODS_TARGET_SRCROOT)/cpp"

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
    s.source_files = "ios/**/*.{h,m,mm,cpp,swift}", "cpp/md4c/*.{c,h}", "cpp/parser/*.{hpp,cpp}", "cpp/highlight/*.{hpp,cpp}"
  end

  # To disable LaTeX math rendering (RaTeX, iOS only), add ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] = '0' to your Podfile.
  # When math is enabled, consumers must use `use_frameworks! :linkage => :dynamic` (required for SPM interop).
  enable_math = ENV['ENRICHED_MARKDOWN_ENABLE_MATH'] != '0'

  # RaTeX is wired in through React Native's `spm_dependency` helper (SPM interop).
  # On React Native versions that don't provide it, disable math entirely so the
  # RaTeX-importing sources under ios/math are excluded from the build. Otherwise
  # the failure would just move from `pod install` to a build-time
  # "missing module 'RaTeX'" error.
  if enable_math && !defined?(spm_dependency)
    Pod::UI.warn '[ReactNativeEnrichedMarkdown] `spm_dependency` is unavailable in this ' \
      'React Native version; disabling LaTeX math (RaTeX). Upgrade React Native to enable it.'
    enable_math = false
  end

  unless enable_math
    s.exclude_files = "ios/math/**/*.swift"
  end

  preprocessor_defs = '$(inherited) MD4C_USE_UTF8=1'
  if enable_math
    preprocessor_defs += ' ENRICHED_MARKDOWN_MATH=1'
    spm_dependency(s,
      url: 'https://github.com/erweixin/RaTeX.git',
      requirement: {kind: 'upToNextMajorVersion', minimumVersion: '0.1.12'},
      products: ['RaTeX']
    )
  end

  pod_xcconfig = {
    'HEADER_SEARCH_PATHS' => "\"#{cpp_root}/md4c\" \"#{cpp_root}/parser\" \"#{cpp_root}/highlight\" \"$(PODS_TARGET_SRCROOT)/ios/internals\" \"$(PODS_TARGET_SRCROOT)/ios/input/internals\"",
    'GCC_PREPROCESSOR_DEFINITIONS' => preprocessor_defs,
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'DEFINES_MODULE' => 'YES'
  }

  # Detect Apple Silicon on the host running `pod install`. `sysctl hw.optional.arm64`
  # reports the real hardware even under a Rosetta-translated Ruby, unlike `uname -m`.
  apple_silicon = `sysctl -n hw.optional.arm64 2>/dev/null`.strip == '1'

  if enable_math && apple_silicon
    # RaTeX's Swift wrapper is compiled from SPM source, so its RaTeX.swiftmodule
    # is emitted only for the arch(es) the build requests. Under ONLY_ACTIVE_ARCH
    # on Apple Silicon that is arm64 only, but universal simulator builds (archive,
    # "Any iOS Simulator Device", Release) also compile this pod for x86_64 and then
    # fail with "could not find module 'RaTeX' for target 'x86_64-apple-ios-simulator'".
    # Excluding x86_64 for the simulator keeps the pod and the app target arch sets in
    # sync. Guarded to Apple Silicon so Intel Macs (which build x86_64 simulator slices)
    # are unaffected; `$(inherited)` preserves exclusions from the user project / other pods.
    pod_xcconfig['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = '$(inherited) x86_64'
    s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '$(inherited) x86_64' }
  end

  s.pod_target_xcconfig = pod_xcconfig

  if enable_math
    # React Native's spm_dependency generates a module.modulemap at
    # ${BUILT_PRODUCTS_DIR}/include/ that re-declares RaTeXFFI, but the RaTeX
    # XCFramework already ships its own definition. Strip the duplicate to
    # prevent "redefinition of module 'RaTeXFFI'" during compilation.
    s.script_phases = [
      {
        name: 'Fix RaTeXFFI Module Redefinition',
        script: <<~'SCRIPT',
          # The shared module.modulemap lives in the platform build-products dir,
          # one level above the per-target BUILT_PRODUCTS_DIR that CocoaPods sets.
          MODULEMAP="${BUILT_PRODUCTS_DIR}/../include/module.modulemap"
          [ -f "$MODULEMAP" ] || exit 0
          sed -i '' -E '/^(framework )?module RaTeXFFI /,/^\}/d' "$MODULEMAP"
        SCRIPT
        execution_position: :before_compile
      },
      {
        name: 'Dedupe RaTeX XCFramework Signature',
        script: <<~'SCRIPT',
          # Xcode 26 generates a .signature file for each signed XCFramework.
          # When the RaTeX XCFramework is consumed via spm_dependency inside a
          # CocoaPods target, both the SPM product and the pod target produce a
          # copy. During archive assembly Xcode copies all signatures into a flat
          # Signatures/ directory, and the second copy collides with the first.
          # Removing the pod-target copy prevents the collision. This is a no-op
          # on older Xcode versions or simulator builds where the file is absent.
          rm -f "${CONFIGURATION_BUILD_DIR}/RaTeX.xcframework-ios.signature"
        SCRIPT
        execution_position: :after_compile
      }
    ]
  end

  install_modules_dependencies(s)
end
