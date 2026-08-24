// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

import { topbarBannerReservationScript } from '@swmansion/t-rex-ui/topbar-banner';
import { TOP_BAR_BANNER } from './src/components/topbarBanner.config.ts';

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
  ],

  plugins: [
    process.env.NODE_ENV === 'production' && [
      '@docusaurus/plugin-google-tag-manager',
      {
        containerId: 'GTM-N5QK8TMT',
      },
    ],
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
