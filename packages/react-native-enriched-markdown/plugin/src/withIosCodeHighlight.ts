import { withDangerousMod, type ConfigPlugin } from '@expo/config-plugins';
import fs from 'fs';
import path from 'path';

export type CodeHighlightOptions = { enabled?: boolean; languages?: string[] };

const ENABLE_KEY = 'ENRICHED_MARKDOWN_ENABLE_CODE_HIGHLIGHT';
const LANGUAGES_KEY = 'ENRICHED_MARKDOWN_CODE_HIGHLIGHT_LANGUAGES';

export const withIosCodeHighlight: ConfigPlugin<CodeHighlightOptions> = (
  config,
  { enabled = true, languages } = {}
) => {
  const hasLanguages = Array.isArray(languages) && languages.length > 0;
  // Default (enabled, curated set) needs no Podfile ENV lines.
  if (enabled && !hasLanguages) {
    return config;
  }
  return withDangerousMod(config, [
    'ios',
    async (modConfig) => {
      const file = path.join(
        modConfig.modRequest.platformProjectRoot,
        'Podfile'
      );
      const contents = fs.readFileSync(file, 'utf8');
      const lines = contents
        .split('\n')
        .filter(
          (line: string) =>
            !line.includes(ENABLE_KEY) && !line.includes(LANGUAGES_KEY)
        );

      const inject: string[] = [];
      if (!enabled) {
        inject.push(`ENV['${ENABLE_KEY}'] = '0'`);
      }
      if (hasLanguages) {
        inject.push(`ENV['${LANGUAGES_KEY}'] = '${languages!.join(',')}'`);
      }
      lines.unshift(...inject);

      fs.writeFileSync(file, lines.join('\n'));
      return modConfig;
    },
  ]);
};
