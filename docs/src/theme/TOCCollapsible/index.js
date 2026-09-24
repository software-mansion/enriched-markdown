import { useMemo } from 'react';
import { TOCCollapsible } from '@swmansion/t-rex-ui';
import { withPlatformDots } from '@site/src/components/PlatformBadge/tocDots';

// t-rex-ui's TOCCollapsible renders its own TOCItems, bypassing the
// @theme/TOCItems override - so the dots have to be added here too.
export default function TOCCollapsibleWrapper({ toc, ...props }) {
  const tocWithDots = useMemo(() => withPlatformDots(toc), [toc]);

  return <TOCCollapsible toc={tocWithDots} {...props} />;
}
