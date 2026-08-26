#pragma once

#import "ENRMFormattingRange.h"
#import "ENRMFormattingStore.h"
#import <Foundation/Foundation.h>

@class AutoLinkDetector;

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMAutoLinkDetecting <NSObject>
- (void)clearAutoLinkInRange:(NSRange)range;
@end

@interface ENRMLinkCoordinator : NSObject

- (instancetype)initWithFormattingStore:(ENRMFormattingStore *)formattingStore
                       autoLinkDetector:(id<ENRMAutoLinkDetecting>)autoLinkDetector;

- (NSString *)sanitizeURL:(NSString *)url;
- (nullable ENRMFormattingRange *)linkAtPosition:(NSUInteger)position;

/// Sets a link on the selection range, or updates an existing link's URL at the cursor.
/// Returns YES if a mutation occurred.
- (BOOL)setLinkURL:(NSString *)url atCursor:(NSUInteger)cursor selection:(NSRange)selection;

/// Adds a new link range (sanitizes the URL, clears auto-links).
- (void)addLinkWithURL:(NSString *)url start:(NSUInteger)start end:(NSUInteger)end;

/// Adds a link range with an already-sanitized URL (no auto-link clearing).
- (void)addLinkDirectWithURL:(NSString *)url start:(NSUInteger)start end:(NSUInteger)end;

/// Removes the link at the given position. Returns YES if a link was found and removed.
- (BOOL)removeLinkAtPosition:(NSUInteger)position;

/// Returns the link range containing `position - 1`, for atomic link deletion.
- (nullable ENRMFormattingRange *)linkRangeForDeletionAtPosition:(NSUInteger)position;

@end

NS_ASSUME_NONNULL_END
