#import "MarkdownASTNode.h"
#import <stdatomic.h>

@implementation MarkdownASTNode {
  _Atomic(uint64_t) _signature;
  atomic_bool _hasSignature;
}

- (instancetype)initWithType:(MarkdownNodeType)type
{
  if (self = [super init]) {
    _type = type;
    _content = nil;
    _attributes = [[NSMutableDictionary alloc] init];
    _children = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)addChild:(MarkdownASTNode *)child
{
  [_children addObject:child];
  atomic_store(&_hasSignature, false);
}

- (void)setAttribute:(NSString *)key value:(NSString *)value
{
  _attributes[key] = value;
  atomic_store(&_hasSignature, false);
}

- (void)setContent:(NSString *)content
{
  _content = content;
  atomic_store(&_hasSignature, false);
}

- (BOOL)getCachedSignature:(uint64_t *)signature
{
  if (!atomic_load(&_hasSignature)) {
    return NO;
  }
  *signature = atomic_load(&_signature);
  return YES;
}

- (void)cacheSignature:(uint64_t)signature
{
  atomic_store(&_signature, signature);
  atomic_store(&_hasSignature, true);
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"MarkdownASTNode(type=%ld, content=%@, children=%lu)", (long)_type, _content,
                                    (unsigned long)_children.count];
}

@end

BOOL ENRMIsTopLevelBlockType(MarkdownNodeType type)
{
  switch (type) {
    case MarkdownNodeTypeParagraph:
    case MarkdownNodeTypeHeading:
    case MarkdownNodeTypeCodeBlock:
    case MarkdownNodeTypeBlockquote:
    case MarkdownNodeTypeAdmonition:
    case MarkdownNodeTypeTable:
    case MarkdownNodeTypeUnorderedList:
    case MarkdownNodeTypeOrderedList:
    case MarkdownNodeTypeThematicBreak:
    case MarkdownNodeTypeBlankLine:
    case MarkdownNodeTypeLatexMathDisplay:
      return YES;
    default:
      return NO;
  }
}
