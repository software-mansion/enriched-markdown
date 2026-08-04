# Shared tree-sitter code-highlighting wiring for both podspecs
# (EnrichedMarkdownCore in the monorepo, ReactNativeEnrichedMarkdown when
# published without the core pod). Podspecs are imperative Ruby that own their
# own source_files/defines/header paths, so unlike Android there is no build
# ownership problem: this computes exactly what to add.
#
# Only lib.c (the runtime) and each selected grammar's parser.c/scanner.c are
# compiled; every other vendored .c/.h is include-only and resolves through
# quoted relative includes, so the shared HEADER_SEARCH_PATHS never carries a
# grammar dir or tree-sitter/src (which would collide grammar parser.h files).
#
# The default grammar set is NOT hardcoded here: it is derived from the single
# source of truth, vendor/grammar-versions.json (every grammar with default:true),
# so the compiled sources always match the registry that gen-registry generates
# from the same manifest. The Android build derives it the same way.

require 'json'

module EnrichedMarkdownCodeHighlight
  # Locate grammar-versions.json in both layouts, mirroring how gen-registry.mjs
  # is resolved below: "<podspec_dir>/../../vendor" in the monorepo, and the copy
  # dropped into "<podspec_dir>/cpp/highlight" by prepare-npm-publish.sh when
  # published.
  def self.manifest_path(podspec_dir)
    [
      File.join(podspec_dir, '../../vendor/grammar-versions.json'),
      File.join(podspec_dir, 'cpp/highlight/grammar-versions.json'),
    ].find { |p| File.exist?(p) }
  end

  # The default language set: every grammar flagged default:true in the manifest.
  def self.default_languages(podspec_dir)
    manifest = manifest_path(podspec_dir)
    raise '[code-highlight] grammar-versions.json not found; cannot resolve the ' \
          'default language set. Build from the monorepo or a published tarball.' unless manifest
    grammars = JSON.parse(File.read(manifest))['grammars'] || {}
    grammars.select { |_id, spec| spec['default'] }.keys
  end

  # podspec_dir is the directory of the including podspec; cpp is reached at
  # "<podspec_dir>/cpp" (a symlink in the monorepo, real files when published).
  def self.config(podspec_dir)
    return disabled if ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT'] == '0'

    defaults = default_languages(podspec_dir)
    langs = (ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES'] || '')
            .split(',').map(&:strip).reject(&:empty?)
    langs = defaults.dup if langs.empty?
    return disabled if langs.empty?

    vendor = File.join(podspec_dir, 'cpp/highlight/vendor')
    # A custom language set regenerates its registry into a SEPARATE dir so it never
    # clobbers the committed default-set registry in vendor/generated. That committed
    # dir is the shared source of truth other default builds -- and the Android build
    # -- rely on staying the default set; overwriting it in place with a custom set
    # leaves the next default build linking a mismatched grammar list.
    custom = langs.sort != defaults.sort
    generated_rel = custom ? 'cpp/highlight/vendor/generated-custom' : 'cpp/highlight/vendor/generated'
    generated = File.join(podspec_dir, generated_rel)
    ensure_registry(podspec_dir, vendor, generated, langs, custom)

    sources = [
      'cpp/highlight/vendor/tree-sitter/src/lib.c',
      "#{generated_rel}/generated_registry.cpp",
    ]
    langs.each do |lang|
      sources << "cpp/highlight/vendor/grammars/#{lang}/parser.c"
      if File.exist?(File.join(vendor, "grammars/#{lang}/scanner.c"))
        sources << "cpp/highlight/vendor/grammars/#{lang}/scanner.c"
      end
    end

    {
      enabled: true,
      source_files: sources,
      defines: ' ENRICHED_MARKDOWN_CODE_HIGHLIGHT=1',
      header_paths: [
        'cpp/highlight/vendor/tree-sitter/include',
        generated_rel,
      ],
    }
  end

  def self.disabled
    { enabled: false, source_files: [], defines: '', header_paths: [] }
  end

  # The committed default-set registry ships in-tree, so the default case needs no
  # codegen. A custom set (or a missing default registry) regenerates into `generated`
  # from the vendored .scm files.
  def self.ensure_registry(podspec_dir, vendor, generated, langs, custom)
    return if !custom && File.exist?(File.join(generated, 'generated_registry.cpp'))

    script = [
      File.join(podspec_dir, '../../vendor/gen-registry.mjs'),
      File.join(podspec_dir, 'cpp/highlight/gen-registry.mjs'),
    ].find { |p| File.exist?(p) }
    raise '[code-highlight] ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES is customized but ' \
          'vendor/gen-registry.mjs was not found. Use the default set or build from the monorepo.' unless script

    # Canonicalize before handing the path to node: in the monorepo the package is
    # a workspace symlink, so the "../.." above resolves correctly for File.exist?
    # (which follows the symlink physically) but node would normalize ".." lexically
    # from the symlink location and miss the file. Android already does this via
    # File#canonicalPath.
    script = File.realpath(script)

    ok = system('node', script, '--vendor-dir', vendor, '--languages', langs.join(','), '--out', generated)
    raise '[code-highlight] gen-registry.mjs failed' unless ok
  end
end
