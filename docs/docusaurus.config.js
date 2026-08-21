// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

import { topbarBannerReservationScript } from '@swmansion/t-rex-ui/topbar-banner';
import { TOP_BAR_BANNER } from './src/components/topbarBanner.config.ts';
import { PLATFORMS, DEFAULT_PLATFORM } from './src/platform/config.ts';

// Static placeholder for the navbar platform selector, matching the collapsed
// look of <PlatformNavbarItem> for the default platform. Rendered at SSR so the
// slot is correct on first paint; src/clientModules/platformNavbar.tsx then
// hydrates the interactive widget into it with identical markup (no flash).
const defaultPlatform =
  PLATFORMS.find(p => p.id === DEFAULT_PLATFORM) ?? PLATFORMS[0];
const platformNavbarSlot =
  '<div class="rnem-platform-navbar-slot">' +
  '<div class="navbar__item dropdown dropdown--hoverable dropdown--right">' +
  '<a class="navbar__link" href="#" aria-haspopup="true">' +
  defaultPlatform.label +
  '<span style="opacity:0.6;margin-left:6px">v' +
  defaultPlatform.version +
  '</span></a></div></div>';

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
          sidebarCollapsible: false,
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
    require.resolve('./src/clientModules/platformNavbar.tsx'),
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
            // Prototype: mount node for the global platform selector, replacing
            // the version dropdown. The React widget is hydrated into this node
            // by src/clientModules/platformNavbar.tsx (t-rex-ui's navbar does
            // not honor custom navbar item types, so we use an `html` slot).
            type: 'html',
            position: 'right',
            value: platformNavbarSlot,
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
