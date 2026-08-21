import React from 'react';
import { usePlatform } from '@site/src/platform/context';
import { getPlatform } from '@site/src/platform/config';

// Inline text of the currently selected platform's name (React Native / iOS /
// Android / …). Reacts live to the navbar platform selector.
//
// Usage in MDX:  ## What is <PlatformName /> Enriched Markdown?
export default function PlatformName() {
  const { platform } = usePlatform();
  return <>{getPlatform(platform).label}</>;
}
