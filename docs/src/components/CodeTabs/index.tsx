import React from 'react';
import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import CodeBlock from '@theme/CodeBlock';

// General synced tabs component with a children-based API. Wrap the logic of
// Docusaurus <Tabs>/<TabItem> + code-block rendering + tab syncing so pages can
// just write:
//
//   <CodeTabs groupId="package-managers">
//     <Tab label="npm">npm install react-native-enriched-markdown</Tab>
//     <Tab label="yarn">yarn add react-native-enriched-markdown</Tab>
//   </CodeTabs>
//
// A <Tab> whose children are a plain string get wrapped in a styled code block
// automatically (language via the `language` prop, default `bash`). If you put
// anything else inside a <Tab> (a fenced code block, prose, JSX) it is rendered
// as-is, so <CodeTabs> works for non-code tabs too.

export interface TabProps {
  /** Tab label shown to the reader. */
  label: string;
  /** Stable tab id used for syncing; defaults to a slug of the label. */
  value?: string;
  /** Prism language when the body is a plain string; falls back to CodeTabs' `language`. */
  language?: string;
  children?: React.ReactNode;
}

// Marker element — never rendered directly; <CodeTabs> reads its props.
export function Tab(_props: TabProps): React.ReactElement | null {
  return null;
}

interface CodeTabsProps {
  children: React.ReactNode;
  /** Sync + persist the chosen tab across all groups with this id. */
  groupId?: string;
  /** Default Prism language for string-bodied tabs. */
  language?: string;
}

function slug(label: string): string {
  return label.toLowerCase().replace(/\s+/g, '-');
}

export default function CodeTabs({
  children,
  groupId,
  language = 'bash',
}: CodeTabsProps) {
  const tabs = React.Children.toArray(children).filter(
    React.isValidElement,
  ) as React.ReactElement<TabProps>[];

  return (
    <Tabs groupId={groupId}>
      {tabs.map((tab, index) => {
        const { label, value, language: tabLanguage, children: body } = tab.props;
        const tabValue = value ?? slug(label ?? `tab-${index}`);
        const content =
          typeof body === 'string' ? (
            <CodeBlock language={tabLanguage ?? language}>{body}</CodeBlock>
          ) : (
            body
          );
        return (
          <TabItem key={tabValue} value={tabValue} label={label}>
            {content}
          </TabItem>
        );
      })}
    </Tabs>
  );
}
