import React from 'react';
import { useLocation } from '@docusaurus/router';
import { Navbar, TopbarBanner, isBannerHidden } from '@swmansion/t-rex-ui';
import { TOP_BAR_BANNER } from '@site/src/components/topbarBanner.config';

export default function NavbarWrapper(props) {
  const location = useLocation();
  const bannerHidden = isBannerHidden(
    location.pathname,
    TOP_BAR_BANNER.hiddenPaths,
  );

  return (
    // Stick the banner + navbar to the top so the navbar (and its platform
    // selector) stays visible on scroll. Making the wrapper itself sticky keeps
    // its box intact — unlike `display: contents`, which can disturb the t-rex
    // navbar's own layout.
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        flexShrink: 0,
        position: 'sticky',
        top: 0,
        zIndex: 'var(--ifm-z-index-fixed, 200)',
      }}>
      {!bannerHidden && (
        <TopbarBanner
          zones={TOP_BAR_BANNER.zones}
          rotateIntervalMs={TOP_BAR_BANNER.rotateIntervalMs}
        />
      )}
      <Navbar
        useLandingLogoDualVariant={true}
        isAlgoliaActive={false}
        {...props}
      />
    </div>
  );
}
