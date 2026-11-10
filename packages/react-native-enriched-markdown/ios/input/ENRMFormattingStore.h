#pragma once

#import "ENRMFormattingRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMFormattingStore : NSObject

@property (nonatomic, readonly) NSArray<ENRMFormattingRange *> *allRanges;

- (void)setRanges:(NSArray<ENRMFormattingRange *> *)ranges;
- (void)clearAll;

- (nullable ENRMFormattingRange *)rangeOfType:(ENRMInputStyleType)type containingPosition:(NSUInteger)position;
- (BOOL)isStyleActive:(ENRMInputStyleType)type atPosition:(NSUInteger)position;
- (BOOL)isStyleActive:(ENRMInputStyleType)type inRange:(NSRange)range;
- (BOOL)isStyleAdjacentBefore:(ENRMInputStyleType)type position:(NSUInteger)position;
- (NSArray<ENRMFormattingRange *> *)rangesOfType:(ENRMInputStyleType)type;

/// Snaps a selection so it never partially overlaps an atomic link: a partial selection expands to
/// the whole link, a caret inside a link moves to its end (unchanged when no adjustment is needed).
- (NSRange)selectionAdjustedForAtomicLinks:(NSRange)selection;

/// YES when the entire `range` is covered by adjacent/overlapping ranges of `type`.
- (BOOL)isStyleFullyActive:(ENRMInputStyleType)type inRange:(NSRange)range;

/// Toggles `type` on `range`. For a selection (length > 0), removes the style
/// when fully active, otherwise strips `conflictingStyles` and adds it.
/// For a caret (length == 0), reports the current state without mutating.
/// Returns YES when the style was active (removed / pending removal).
- (BOOL)toggleStyle:(ENRMInputStyleType)type
              inRange:(NSRange)range
    conflictingStyles:(NSSet<NSNumber *> *)conflictingStyles;

/// Strips `conflictingStyles` from `range` and adds `type` over it.
- (void)addStyle:(ENRMInputStyleType)type
              inRange:(NSRange)range
    conflictingStyles:(NSSet<NSNumber *> *)conflictingStyles;

/// The range toggling `type` over `range` should cover, or `range` itself when it needs no change.
/// md4c ignores a `_` between two word characters ("Intra-word underscore doesn't have special
/// meaning"), so an underline that starts or ends inside a word would be written as markdown that
/// reads back with a literal `_`. Instead the toggle, on or off, grows to the word's edges:
/// - a caret touching a word takes the whole word, also at the word's edge: letters typed there
///   join the word, so "text|" takes "text" before "underline" is typed after it;
/// - a selection edge inside a word moves out to the word's edge.
/// A caret with no word on either side stays a caret. A link's edge stops the growth, since the
/// link's own delimiters already separate the `_` from the word.
- (NSRange)wholeWordRangeForStyle:(ENRMInputStyleType)type inText:(NSString *)text range:(NSRange)range;

/// Whether the store gives `type` to text typed at a caret at `position`: a range covers it or, for
/// underline, an underlined word ends there, since growToWholeWordsInText: pulls letters typed right
/// after the word into it.
- (BOOL)isStyleActive:(ENRMInputStyleType)type atCaret:(NSUInteger)position inText:(NSString *)text;

/// Grows every underline that an edit left starting or ending inside a word to that word's edges,
/// by the selection rule of wholeWordRangeForStyle: letters typed or pasted right before or after
/// an underlined word join it, and so does the word a deletion glued to it.
- (void)growToWholeWordsInText:(NSString *)text;

/// YES when toggling `type` ON at `position` should be refused because one of
/// the `blockingStyles` is active there. Toggling OFF is never blocked.
- (BOOL)isToggleBlocked:(ENRMInputStyleType)type
             atPosition:(NSUInteger)position
         blockingStyles:(NSSet<NSNumber *> *)blockingStyles;

- (void)addRange:(ENRMFormattingRange *)range;
- (void)removeType:(ENRMInputStyleType)type inRange:(NSRange)range;
- (void)removeRange:(ENRMFormattingRange *)range;

- (void)adjustForEditAtLocation:(NSUInteger)location
                  deletedLength:(NSUInteger)deletedLength
                 insertedLength:(NSUInteger)insertedLength;

@end

NS_ASSUME_NONNULL_END
