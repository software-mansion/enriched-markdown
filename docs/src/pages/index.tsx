import React from 'react';
import { Redirect } from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';

// The docs are served at the site root (routeBasePath: '/'), but t-rex-ui
// treats the exact root URL as a "landing" page and hides the mobile hamburger
// / doc sidebar there. So the root is just a redirect into the real docs; the
// homepage content lives at /getting-started, which is a normal navigable page.
export default function Home(): React.ReactNode {
  return <Redirect to={useBaseUrl('/getting-started')} />;
}
