#pragma once
#import "ENRMStreamingEffects.h"
#import <React/RCTConversions.h>

/// Configures `effects` from a component's `streamingConfig` (animation and its options).
template <typename StreamingConfigT>
inline void ENRMConfigureStreamingEffects(ENRMStreamingEffects *effects, const StreamingConfigT &config)
{
  ENRMStreamingEffectType type = config.animation == "gradient" ? ENRMStreamingEffectGradient
                                 : config.animation == "none"   ? ENRMStreamingEffectNone
                                                                : ENRMStreamingEffectFade;
  if (ENRMShouldReduceMotion()) {
    type = ENRMStreamingEffectNone;
  }
  [effects configureType:type
                duration:config.animationDuration > 0 ? config.animationDuration / 1000.0 : 0.2
                  length:config.animationLength > 0 ? (NSUInteger)config.animationLength : 20
              startColor:facebook::react::isColorMeaningful(config.animationStartColor)
                             ? RCTUIColorFromSharedColor(config.animationStartColor)
                             : nil
                endColor:facebook::react::isColorMeaningful(config.animationEndColor)
                             ? RCTUIColorFromSharedColor(config.animationEndColor)
                             : nil];
}

/// Whether two `streamingConfig`s describe the same animation.
template <typename StreamingConfigT>
inline bool ENRMSameStreamingAnimation(const StreamingConfigT &a, const StreamingConfigT &b)
{
  return a.animation == b.animation && a.animationDuration == b.animationDuration &&
         a.animationLength == b.animationLength && a.animationStartColor == b.animationStartColor &&
         a.animationEndColor == b.animationEndColor;
}
