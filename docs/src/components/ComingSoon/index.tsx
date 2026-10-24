import React from 'react';
import Admonition from '@theme/Admonition';

// Placeholder for a per-platform code example that hasn't been written yet.
//
// It currently has ZERO consumers. Every previous usage sat in an iOS or
// Android <Tab> describing a feature those packages do not have, and the copy
// below asserts the opposite - that the feature ships and only the example is
// missing. Before reaching for this again, check that the claim is true: when
// the feature itself is absent, write a sentence saying so instead (see
// user-experience/rtl.md and rich-text-formatting/mentions.md for the house
// pattern).
export default function ComingSoon({
  platform,
}: {
  platform?: string;
}): React.ReactElement {
  return (
    <Admonition type="info" title="Coming soon">
      {platform
        ? `The ${platform} example for this feature is on the way.`
        : 'This example is on the way.'}
    </Admonition>
  );
}
