import React, { useEffect, useRef, useState } from 'react';
import clsx from 'clsx';
import { usePlatform } from '@site/src/platform/context';
import { PLATFORMS, getPlatform } from '@site/src/platform/config';

// Navbar-hosted platform selector — occupies the slot the version dropdown used
// to. Reuses Infima's `dropdown` classes so it matches the navbar. Opening is
// driven by React state (click/tap), not CSS :hover, so it works on touch /
// mobile; desktop hover is still supported via CSS in overrides.css.
export default function PlatformNavbarItem() {
  const { platform, setPlatform } = usePlatform();
  const current = getPlatform(platform);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close when tapping/clicking outside.
  useEffect(() => {
    if (!open) {
      return;
    }
    function onDocClick(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('click', onDocClick);
    return () => document.removeEventListener('click', onDocClick);
  }, [open]);

  return (
    <div
      ref={ref}
      className={clsx(
        'navbar__item',
        'dropdown',
        'dropdown--hoverable',
        'dropdown--right',
        open && 'rnem-open',
      )}>
      <a
        href="#"
        className="navbar__link"
        aria-haspopup="true"
        aria-expanded={open}
        onClick={(e) => {
          e.preventDefault();
          setOpen((o) => !o);
        }}>
        {current.label}
        <span style={{ opacity: 0.6, marginLeft: 6 }}>v{current.version}</span>
      </a>
      <ul className="dropdown__menu">
        {PLATFORMS.map((p) => (
          <li key={p.id}>
            <a
              href="#"
              className={clsx(
                'dropdown__link',
                p.id === platform && 'dropdown__link--active',
              )}
              onClick={(e) => {
                e.preventDefault();
                setPlatform(p.id);
                setOpen(false);
              }}
              style={{ display: 'flex', justifyContent: 'space-between', gap: 16 }}>
              <span>{p.label}</span>
              <span style={{ opacity: 0.6 }}>v{p.version}</span>
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
