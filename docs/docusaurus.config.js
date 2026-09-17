// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

import { topbarBannerReservationScript } from '@swmansion/t-rex-ui/topbar-banner';
import { TOP_BAR_BANNER } from './src/components/topbarBanner.config.ts';

const path = require('path');
const webpack = require('webpack');

// Interactive examples import the library's web build directly from the
// monorepo (this docs folder is a standalone yarn project that does not
// depend on the workspace package). Alias the bare specifier to the
// prebuilt web bundle so `EnrichedMarkdownText` renders live in the browser.
// KaTeX is a real docs dependency (`loadKaTeX` requires it at runtime) so the
// `latexMath` playground renders math; its stylesheet is loaded via a client
// module (`src/clientModules/katexStyles.ts`).
const enrichedMarkdownWebEntry = path.resolve(
  __dirname,
  '../packages/react-native-enriched-markdown/lib/module/index.web.js',
);

const lightCodeTheme = require('./src/theme/CodeBlock/highlighting-light.js');
const darkCodeTheme = require('./src/theme/CodeBlock/highlighting-dark.js');

const firstBannerZone = TOP_BAR_BANNER.zones[0];
const bannerReservationHeadTags = firstBannerZone
  ? [
      {
        tagName: 'script',
        attributes: { type: 'text/javascript' },
        innerHTML: topbarBannerReservationScript(
          firstBannerZone.zoneId,
          firstBannerZone.contentId,
          TOP_BAR_BANNER.hiddenPaths,
        ),
      },
    ]
  : [];

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Enriched Markdown',
  favicon: 'img/favicon.png',

  url: 'https://docs.swmansion.com',

  baseUrl: '/enriched-markdown/',

  organizationName: 'software-mansion',
  projectName: 'enriched-markdown',

  // TODO: remove once the site is ready for public traffic. Until then,
  // keep the deploy hidden from search engines.
  noIndex: true,

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
    mermaid: true,
  },

  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          breadcrumbs: false,
          sidebarPath: require.resolve('./sidebars.js'),
          // Categories are non-collapsible by default; the per-platform
          // sections opt back in via `collapsible: true` in their
          // `_category_.json` so they render as collapsible ("burger") groups.
          sidebarCollapsible: false,
          // iOS and Android are not released yet, so their docs are excluded
          // from the build by default. Set SHOW_UNRELEASED_PLATFORMS=1 to
          // include them (e.g. to preview locally or at launch).
          exclude: [
            '**/_*.{js,jsx,ts,tsx,md,mdx}',
            '**/_*/**',
            '**/*.test.{js,jsx,ts,tsx}',
            '**/__tests__/**',
            ...(process.env.SHOW_UNRELEASED_PLATFORMS === '1'
              ? []
              : ['ios/**', 'android/**']),
          ],
          editUrl:
            'https://github.com/software-mansion/enriched-markdown/edit/main/docs/',
          lastVersion: 'current',
        },
        theme: {
          customCss: require.resolve('./src/css/index.css'),
        },
      }),
    ],
  ],

  headTags: bannerReservationHeadTags,

  clientModules: [
    require.resolve('./src/clientModules/topbarBannerRefresh.ts'),
    require.resolve('./src/clientModules/katexStyles.ts'),
  ],

  plugins: [
    process.env.NODE_ENV === 'production' && [
      '@docusaurus/plugin-google-tag-manager',
      {
        containerId: 'GTM-N5QK8TMT',
      },
    ],
    function enrichedMarkdownAliasPlugin() {
      return {
        name: 'enriched-markdown-web-alias',
        configureWebpack(config) {
          return {
            plugins: [
              // React Native code (reached through the library's web build)
              // references the `__DEV__` global that Metro/babel injects but
              // webpack does not, so define it here to match the bundle mode.
              new webpack.DefinePlugin({
                __DEV__: JSON.stringify(config.mode !== 'production'),
              }),
            ],
            resolve: {
              alias: {
                // The library's web build reaches into react-native
                // (Platform/processColor via styleUtils), so it needs the
                // standard react-native-web alias to bundle for the browser.
                'react-native$': 'react-native-web',
                'react-native-enriched-markdown': enrichedMarkdownWebEntry,
                // The web build's `require('katex')` lives under packages/, so
                // webpack would resolve it from there and miss the copy
                // installed in this docs project. Alias it to the docs katex so
                // the resolution succeeds wherever the require sits.
                katex: path.dirname(require.resolve('katex/package.json')),
              },
            },
            module: {
              rules: [
                {
                  // The web build's markdown parser does a dynamic
                  // `import('./wasm/md4c')` without a file extension; the lib
                  // is ESM ("type": "module"), so webpack otherwise rejects
                  // the non-fully-specified request.
                  test: /\.m?js$/,
                  resolve: { fullySpecified: false },
                },
                {
                  // The emscripten glue (md4c.js) is a UMD/CommonJS file, but it
                  // ships inside the library's ESM build (lib/module,
                  // "type": "module"). Parsed as ESM its `module.exports`
                  // factory is dropped, so `import('./wasm/md4c').default` is
                  // undefined and parsing silently falls back to raw text.
                  // Force CJS interop so the factory resolves as `.default`.
                  test: /md4c\.js$/,
                  type: 'javascript/auto',
                },
                {
                  // The web build loads KaTeX with a CommonJS `require('katex')`
                  // inside `lib/module/web/katex.js`. Because lib/module is
                  // strict ESM ("type": "module"), webpack leaves that `require`
                  // untransformed - at runtime `require` is undefined, the
                  // throw is swallowed, and math silently falls back to raw
                  // text. Forcing this file to `javascript/auto` lets webpack
                  // process the `require` (resolved via the `katex` alias above)
                  // while its `export` still works.
                  test: /lib[/\\]module[/\\]web[/\\]katex\.js$/,
                  type: 'javascript/auto',
                },
              ],
            },
          };
        },
      };
    },
  ].filter(Boolean),

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/og-image.png',
      metadata: [
        { name: 'og:image:width', content: '1200' },
        { name: 'og:image:height', content: '630' },
      ],
      colorMode: {
        respectPrefersColorScheme: true,
      },
      navbar: {
        hideOnScroll: false,
        logo: {
          alt: 'Enriched Markdown logo',
          src: 'img/logo.svg',
          srcDark: 'img/logo-dark.svg',
        },
        items: [
          {
            to: '/getting-started',
            label: 'Docs',
            position: 'right',
          },
          {
            href: 'https://github.com/software-mansion/enriched-markdown/',
            position: 'right',
            className: 'header-github',
            'aria-label': 'GitHub repository',
          },
        ],
      },
      footer: {
        style: 'light',
        links: [],
        copyright:
          'All trademarks and copyrights belong to their respective owners.',
      },
      prism: {
        theme: lightCodeTheme,
        darkTheme: darkCodeTheme,
        additionalLanguages: ['bash', 'diff', 'json', 'mermaid'],
      },
      // TODO: replace placeholders with real DocSearch credentials once
      // Algolia approval lands. Required so preset-classic activates
      // @docusaurus/theme-search-algolia and `@theme/SearchTranslations`
      // alias resolves during build.
      algolia: {
        appId: 'PLACEHOLDER_APP_ID',
        apiKey: 'PLACEHOLDER_API_KEY',
        indexName: 'react-native-enriched-markdown',
      },
    }),
};

module.exports = config;
