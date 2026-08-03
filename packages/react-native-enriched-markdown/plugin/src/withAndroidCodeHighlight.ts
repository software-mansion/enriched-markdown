import { withGradleProperties, type ConfigPlugin } from '@expo/config-plugins';

export type CodeHighlightOptions = { enabled?: boolean; languages?: string[] };

export const withAndroidCodeHighlight: ConfigPlugin<CodeHighlightOptions> = (
  config,
  { enabled = true, languages } = {}
) => {
  const hasLanguages = Array.isArray(languages) && languages.length > 0;
  // Default (enabled, curated set) needs no gradle property.
  if (enabled && !hasLanguages) {
    return config;
  }
  return withGradleProperties(config, (gradleConfig) => {
    const drop = new Set([
      'enrichedMarkdown.enableCodeHighlight',
      'enrichedMarkdown.codeHighlightLanguages',
    ]);
    gradleConfig.modResults = gradleConfig.modResults.filter(
      (prop) => prop.type !== 'property' || !drop.has(prop.key)
    );

    gradleConfig.modResults.push({
      type: 'property',
      key: 'enrichedMarkdown.enableCodeHighlight',
      value: String(enabled),
    });
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
