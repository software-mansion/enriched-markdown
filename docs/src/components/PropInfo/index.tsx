import React from 'react';
import styles from './styles.module.css';

interface Props {
  /** The prop's TypeScript type, shown verbatim in the Type column. */
  type: string;
  /** The default value. Omit for props with no default. */
  default?: string;
  /** Marks the prop as required - renders "Required" in the Default column. */
  required?: boolean;
}

// A compact, React-Native-docs-style table for a single prop's Type and
// Default. Both columns always render with fixed widths so every prop's table
// lines up down the page. Props with no default show a muted dash.
export default function PropInfo({
  type,
  default: defaultValue,
  required = false,
}: Props) {
  return (
    <table className={styles.table}>
      <thead>
        <tr>
          <th className={styles.typeCol}>Type</th>
          <th className={styles.defaultCol}>Default</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>{type}</td>
          <td>
            {required ? (
              <span className={styles.required}>Required</span>
            ) : defaultValue != null ? (
              defaultValue
            ) : (
              <span className={styles.empty}>—</span>
            )}
          </td>
        </tr>
      </tbody>
    </table>
  );
}
