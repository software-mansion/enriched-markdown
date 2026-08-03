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

module EnrichedMarkdownCodeHighlight
  DEFAULT_LANGUAGES = %w[json html css markdown yaml go java javascript python c rust bash].freeze

  # podspec_dir is the directory of the including podspec; cpp is reached at
  # "<podspec_dir>/cpp" (a symlink in the monorepo, real files when published).
  def self.config(podspec_dir)
    enabled = ENV['ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT'] != '0'
    langs = (ENV['ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES'] || '')
            .split(',').map(&:strip).reject(&:empty?)
    langs = DEFAULT_LANGUAGES.dup if langs.empty?
    return disabled if !enabled || langs.empty?

    vendor = File.join(podspec_dir, 'cpp/highlight/vendor')
    generated = File.join(vendor, 'generated')
    ensure_registry(podspec_dir, vendor, generated, langs)

    sources = [
      'cpp/highlight/vendor/tree-sitter/src/lib.c',
      'cpp/highlight/vendor/generated/generated_registry.cpp',
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
        'cpp/highlight/vendor/generated',
      ],
    }
  end

  def self.disabled
    { enabled: false, source_files: [], defines: '', header_paths: [] }
  end

  # The committed default-set registry ships in-tree, so the common case needs no
  # codegen. Any customized language set regenerates from the vendored .scm files.
  def self.ensure_registry(podspec_dir, vendor, generated, langs)
    committed = File.exist?(File.join(generated, 'generated_registry.cpp'))
    return if langs.sort == DEFAULT_LANGUAGES.sort && committed

    script = [
      File.join(podspec_dir, '../../vendor/gen-registry.mjs'),
      File.join(podspec_dir, 'cpp/highlight/gen-registry.mjs'),
    ].find { |p| File.exist?(p) }
    raise '[code-highlight] ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES is customized but ' \
          'vendor/gen-registry.mjs was not found. Use the default set or build from the monorepo.' unless script

    ok = system('node', script, '--vendor-dir', vendor, '--languages', langs.join(','), '--out', generated)
    raise '[code-highlight] gen-registry.mjs failed' unless ok
  end
end
