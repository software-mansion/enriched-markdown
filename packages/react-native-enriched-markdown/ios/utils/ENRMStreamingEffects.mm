#import "ENRMStreamingEffects.h"
#include "StreamingEffects.hpp"
#include <string>

using Markdown::EffectColor;
using Markdown::StreamingEffectType;

static std::optional<EffectColor> ENRMEffectColor(RCTUIColor *_Nullable color)
{
  if (color == nil) {
    return std::nullopt;
  }
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [color getRed:&r green:&g blue:&b alpha:&a];
  return EffectColor{(float)r, (float)g, (float)b, (float)a};
}

@implementation ENRMStreamingEffects {
  Markdown::StreamingEffects _effects;
  // As configured; Reduce Motion turns it into None.
  Markdown::StreamingEffectConfig _config;
  BOOL _reducesMotion;
}

- (void)configureType:(ENRMStreamingEffectType)type
             duration:(CFTimeInterval)duration
               length:(NSUInteger)length
           startColor:(RCTUIColor *)startColor
             endColor:(RCTUIColor *)endColor
{
  Markdown::StreamingEffectConfig config;
  config.type = type == ENRMStreamingEffectGradient ? StreamingEffectType::Gradient
                : type == ENRMStreamingEffectFade   ? StreamingEffectType::Fade
                                                    : StreamingEffectType::None;
  config.duration = duration;
  config.length = length;
  config.startColor = ENRMEffectColor(startColor);
  config.endColor = ENRMEffectColor(endColor);
  _config = config;
  [self configureEffects];
}

- (void)configureEffects
{
  _reducesMotion = ENRMShouldReduceMotion();
  Markdown::StreamingEffectConfig config = _config;
  if (_reducesMotion) {
    config.type = StreamingEffectType::None;
  }
  _effects.configure(config);
}

- (ENRMStreamingEffectType)type
{
  switch (_effects.config().type) {
    case StreamingEffectType::Gradient:
      return ENRMStreamingEffectGradient;
    case StreamingEffectType::Fade:
      return ENRMStreamingEffectFade;
    case StreamingEffectType::None:
      return ENRMStreamingEffectNone;
  }
}

- (void)noteArrivalIn:(NSString *)text from:(NSUInteger)start to:(NSUInteger)end at:(CFTimeInterval)time
{
  // Reduce Motion applies from the next arrival, as it does to blocks.
  if (ENRMShouldReduceMotion() != _reducesMotion) {
    [self configureEffects];
  }
  end = MIN(end, text.length);
  std::u16string characters(start < end ? end - start : 0, u'\0');
  if (!characters.empty()) {
    [text getCharacters:reinterpret_cast<unichar *>(characters.data()) range:NSMakeRange(start, end - start)];
  }
  char16_t previous = start > 0 && start <= text.length ? [text characterAtIndex:start - 1] : u' ';
  _effects.noteArrival(start, end, time, characters, previous);
}

- (void)finishAt:(CFTimeInterval)time
{
  _effects.finish(time);
}

- (void)reset
{
  _effects.reset();
}

- (BOOL)changesOverTimeAt:(CFTimeInterval)time
{
  return _effects.changesOverTime(time);
}

- (NSRange)animatedRangeAt:(CFTimeInterval)time
{
  auto range = _effects.animatedRange(time);
  return range ? NSMakeRange(range->start, range->length) : NSMakeRange(NSNotFound, 0);
}

- (RCTUIColor *)colorForCharacterAtIndex:(NSUInteger)index ownColor:(RCTUIColor *)ownColor time:(CFTimeInterval)time
{
  Markdown::CharacterLook look = _effects.lookAt(index, time);
  if (look.tintAmount == 0 && look.opacity == 1) {
    return ownColor;
  }
  CGFloat r = 0, g = 0, b = 0, a = 0;
  [ownColor getRed:&r green:&g blue:&b alpha:&a];
  CGFloat t = look.tintAmount;
  return [RCTUIColor colorWithRed:r + (look.tint.r - r) * t
                            green:g + (look.tint.g - g) * t
                             blue:b + (look.tint.b - b) * t
                            // The character's own alpha stays: hidden text stays hidden.
                            alpha:a * (1 + (look.tint.a - 1) * t) * look.opacity];
}

@end
