import { type ConfigPlugin } from '@expo/config-plugins';
import { withIosMath } from './withIosMath';
import { withAndroidMath } from './withAndroidMath';
import { withAndroidCodeHighlight } from './withAndroidCodeHighlight';
import { withIosCodeHighlight } from './withIosCodeHighlight';

type EnrichedMarkdownProps = {
  enableMath?: boolean;
  codeHighlight?: { enabled?: boolean; languages?: string[] };
};

const withEnrichedMarkdown: ConfigPlugin<EnrichedMarkdownProps | void> = (
  config,
  props
) => {
  const enableMath = props?.enableMath !== false;

  config = withAndroidMath(config, { enableMath });
  config = withIosMath(config, { enableMath });

  const codeHighlight = props?.codeHighlight ?? {};
  config = withAndroidCodeHighlight(config, codeHighlight);
  config = withIosCodeHighlight(config, codeHighlight);

  return config;
};

export default withEnrichedMarkdown;
