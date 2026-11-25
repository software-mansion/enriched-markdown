#import "ENRMUIKit.h"
#import <Foundation/Foundation.h>

@class StyleConfig;
@class ENRMListMarkerDescriptor;

@interface ListMarkerDrawer : NSObject

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)drawMarker:(ENRMListMarkerDescriptor *)marker
         boundaryX:(CGFloat)x
         baselineY:(CGFloat)baseline
              font:(UIFont *)font
             isRTL:(BOOL)isRTL;

- (void)drawMarkersForGlyphRange:(NSRange)glyphsToShow
                   layoutManager:(NSLayoutManager *)layoutManager
                   textContainer:(NSTextContainer *)textContainer
                         atPoint:(CGPoint)origin;

@end
