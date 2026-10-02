import React from 'react';
import { No, Version, Yes } from './index';

// Support matrix for react-native-enriched-markdown against React Native
// versions. Mirrors the Compatibility Table in the package README.
const REACT_NATIVE_VERSIONS = ['0.82', '0.83', '0.84', '0.85', '0.86', '0.87'];

// Keep in sync with the Compatibility Table in
// packages/react-native-enriched-markdown/README.md - the two are maintained
// by hand and have drifted before.
const LIBRARY_VERSIONS = [
  { version: 'nightly', supportedFrom: '0.83', supportedTo: '0.87' },
  { version: '1.1.0', supportedFrom: '0.83', supportedTo: '0.87' },
  { version: '1.0.x', supportedFrom: '0.83', supportedTo: '0.87' },
  { version: '0.7.0', supportedFrom: '0.83', supportedTo: '0.87' },
  { version: '0.6.0', supportedFrom: '0.83', supportedTo: '0.85' },
  { version: '0.5.0', supportedFrom: '0.83', supportedTo: '0.85' },
  { version: '0.4.x', supportedFrom: '0.82', supportedTo: '0.84' },
  { version: '0.3.0', supportedFrom: '0.82', supportedTo: '0.84' },
] as const;

function isSupported(
  reactNativeVersion: string,
  supportedFrom: string,
  supportedTo: string,
) {
  return (
    reactNativeVersion.localeCompare(supportedFrom, undefined, {
      numeric: true,
    }) >= 0 &&
    reactNativeVersion.localeCompare(supportedTo, undefined, {
      numeric: true,
    }) <= 0
  );
}

export default function EnrichedCompatibility() {
  return (
    <div className="compatibility">
      <table>
        <thead>
          <tr>
            <th scope="col"></th>
            {REACT_NATIVE_VERSIONS.map(version => (
              <th key={version} scope="col">
                {version}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {LIBRARY_VERSIONS.map(({ version, supportedFrom, supportedTo }) => (
            <tr key={version}>
              <td>
                <Version version={version} />
              </td>
              {REACT_NATIVE_VERSIONS.map(reactNativeVersion => (
                <td key={reactNativeVersion}>
                  {isSupported(
                    reactNativeVersion,
                    supportedFrom,
                    supportedTo,
                  ) ? (
                    <Yes />
                  ) : (
                    <No />
                  )}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
