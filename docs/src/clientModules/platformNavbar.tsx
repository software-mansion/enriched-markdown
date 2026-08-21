import React from 'react';
import { createRoot } from 'react-dom/client';
import PlatformNavbarItem from '@site/src/theme/NavbarItem/PlatformNavbarItem';

// t-rex-ui's navbar ignores site-level custom navbar item types, so we expose a
// plain `html` navbar item (a mount node, class `rnem-platform-navbar-slot`) in
// docusaurus.config.js and hydrate our interactive React selector into it here.
//
// t-rex renders that html item in TWO places: the top navbar (present at SSR)
// AND, client-side when the hamburger opens, inside the mobile drawer. Both use
// the same markup, but only one can be the real interactive widget. We mount
// the top-bar copy and hide any copy the drawer spawns (a MutationObserver
// catches it on open), so the burger never shows a dead, "reset" placeholder.
//
// Timing rule: only touch the DOM AFTER hydration (onRouteDidUpdate runs in a
// layout effect post-hydration and fires on initial load; the load event backs
// it up). Mounting mid-hydration corrupts the navbar.

const SLOT = 'rnem-platform-navbar-slot';
let observer: MutationObserver | null = null;

function handleSlot(slot: HTMLElement) {
  if (slot.dataset.rnemHandled === 'true') {
    return;
  }
  slot.dataset.rnemHandled = 'true';

  // A copy rendered into the mobile hamburger drawer — hide it. The top-bar
  // copy is the single interactive selector.
  if (slot.closest('.navbar-sidebar')) {
    slot.style.display = 'none';
    const listItem = slot.closest('.menu__list-item') as HTMLElement | null;
    if (listItem) {
      listItem.style.display = 'none';
    }
    return;
  }

  createRoot(slot).render(<PlatformNavbarItem />);
}

function scan() {
  if (typeof document === 'undefined') {
    return;
  }
  document
    .querySelectorAll<HTMLElement>(`.${SLOT}`)
    .forEach((slot) => handleSlot(slot));
}

function start() {
  scan();
  if (!observer && typeof MutationObserver !== 'undefined') {
    // Watch for the drawer copy that appears when the hamburger opens.
    const target = document.querySelector('nav.navbar') ?? document.body;
    observer = new MutationObserver(() => scan());
    observer.observe(target, { childList: true, subtree: true });
  }
}

function scheduleStart() {
  if (typeof window === 'undefined') {
    return;
  }
  window.requestAnimationFrame(() => window.requestAnimationFrame(start));
  window.setTimeout(start, 50);
}

export function onRouteDidUpdate() {
  scheduleStart();
}

if (typeof window !== 'undefined') {
  if (document.readyState === 'complete') {
    scheduleStart();
  } else {
    window.addEventListener('load', scheduleStart, { once: true });
  }
}
