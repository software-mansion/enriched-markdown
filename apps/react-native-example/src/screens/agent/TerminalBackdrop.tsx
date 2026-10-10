import { memo } from 'react';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import Svg, {
  Circle,
  Defs,
  Ellipse,
  Pattern,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';

/** Dark glass with a dot grid, a warm lamp behind the prompt and a cool glow below. */
export const TerminalBackdrop = memo(function TerminalBackdrop() {
  const { width, height } = useWindowDimensions();
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Svg width={width} height={height}>
        <Defs>
          <RadialGradient id="ember" cx="50%" cy="50%" r="50%">
            <Stop offset="0" stopColor="#FB923C" stopOpacity="0.28" />
            <Stop offset="0.6" stopColor="#F97316" stopOpacity="0.08" />
            <Stop offset="1" stopColor="#F97316" stopOpacity="0" />
          </RadialGradient>
          <RadialGradient id="steel" cx="50%" cy="50%" r="50%">
            <Stop offset="0" stopColor="#60A5FA" stopOpacity="0.14" />
            <Stop offset="1" stopColor="#60A5FA" stopOpacity="0" />
          </RadialGradient>
          <Pattern
            id="dots"
            width={22}
            height={22}
            patternUnits="userSpaceOnUse"
          >
            <Circle cx={1} cy={1} r={1} fill="#E5E7EB" fillOpacity={0.1} />
          </Pattern>
        </Defs>
        <Rect width={width} height={height} fill="#0B0A0F" />
        <Ellipse
          cx={width * 0.18}
          cy={height * 0.12}
          rx={width * 0.8}
          ry={height * 0.3}
          fill="url(#ember)"
        />
        <Ellipse
          cx={width * 0.9}
          cy={height * 0.75}
          rx={width * 0.7}
          ry={height * 0.3}
          fill="url(#steel)"
        />
        <Rect width={width} height={height} fill="url(#dots)" />
      </Svg>
    </View>
  );
});
