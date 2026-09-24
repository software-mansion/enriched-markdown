import React from 'react';
import Admonition from '@theme/Admonition';

// Placeholder for a per-platform code example that hasn't been written yet.
// Used inside <CodeTabs>/<Tab> for the iOS and Android tabs while only the
// React Native example exists. Swap the <Tab> body for a real code block when
// the native example lands.
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
