#pragma once

#import "ENRMInputDecorationDrawer.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Draws list markers (bullets / ordered numbers) into the head-indent column.
@interface ENRMInputListMarkerDrawer : NSObject <ENRMInputDecorationDrawer>

@property (nonatomic, assign) NSInteger emptyBulletDepth;
@property (nonatomic, assign) BOOL emptyBulletOrdered;
@property (nonatomic, assign) NSInteger emptyBulletOrdinal;
@property (nonatomic, assign) NSUInteger emptyBulletLocation;
@property (nonatomic, strong, nullable) UIFont *emptyBulletFont;
@property (nonatomic, strong, nullable) UIColor *emptyBulletColor;
@property (nonatomic, assign) BOOL emptyBulletRTL;
@property (nonatomic, assign) CGFloat listItemSpacing;

@end

NS_ASSUME_NONNULL_END
