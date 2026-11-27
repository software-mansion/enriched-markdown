#pragma once

#import <Foundation/Foundation.h>
#include <string>
#include <string_view>

// UTF-8 both ways, length-aware: a NUL inside the Markdown is text, as it is for
// the JS collector, not the end of the string.
static inline NSString *ENRMStringFromUTF8(std::string_view utf8)
{
  return [[NSString alloc] initWithBytes:utf8.data() length:utf8.size() encoding:NSUTF8StringEncoding] ?: @"";
}

static inline std::string ENRMUTF8String(NSString *string)
{
  std::string utf8([string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], '\0');
  NSUInteger used = 0;
  [string getBytes:utf8.data()
           maxLength:utf8.size()
          usedLength:&used
            encoding:NSUTF8StringEncoding
             options:0
               range:NSMakeRange(0, string.length)
      remainingRange:NULL];
  utf8.resize(used);
  return utf8;
}
