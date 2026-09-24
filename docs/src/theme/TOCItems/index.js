import { useMemo } from 'react';
import { TOCItems } from '@swmansion/t-rex-ui';
import { withPlatformDots } from '@site/src/components/PlatformBadge/tocDots';

export default function TOCItemsWrapper({ toc, ...props }) {
  const tocWithDots = useMemo(() => withPlatformDots(toc), [toc]);

  return <TOCItems toc={tocWithDots} {...props} />;
}
