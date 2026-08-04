import { withGradleProperties, type ConfigPlugin } from '@expo/config-plugins';

export type CodeHighlightOptions = { enabled?: boolean; languages?: string[] };

export const withAndroidCodeHighlight: ConfigPlugin<CodeHighlightOptions> = (
  config,
  { enabled = true, languages } = {}
) => {
  const hasLanguages = Array.isArray(languages) && languages.length > 0;
  // Always run the mod so switching back to defaults strips previously-injected
  // properties; an absent property already means enabled with the curated set.
  return withGradleProperties(config, (gradleConfig) => {
    const drop = new Set([
      'enrichedMarkdown.enableCodeHighlight',
      'enrichedMarkdown.codeHighlightLanguages',
    ]);
    gradleConfig.modResults = gradleConfig.modResults.filter(
      (prop) => prop.type !== 'property' || !drop.has(prop.key)
    );

    if (!enabled) {
      gradleConfig.modResults.push({
        type: 'property',
        key: 'enrichedMarkdown.enableCodeHighlight',
        value: 'false',
      });
    }
    if (hasLanguages) {
      gradleConfig.modResults.push({
        type: 'property',
        key: 'enrichedMarkdown.codeHighlightLanguages',
        value: languages!.join(','),
      });
    }

    return gradleConfig;
  });
};
