#pragma once

#import <Foundation/Foundation.h>
#import <ReactCommon/RCTTurboModule.h>

NS_ASSUME_NONNULL_BEGIN

/// Hands the pure C++ EnrichedMarkdownParser TurboModule to the runtime. Registered
/// through `codegenConfig.ios.modulesProvider` in package.json.
@interface EnrichedMarkdownParserProvider : NSObject <RCTModuleProvider>
@end

NS_ASSUME_NONNULL_END
