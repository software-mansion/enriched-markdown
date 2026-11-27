#pragma once

// React Native's C++ headers, reached through the module umbrellas where this
// React Native version has them. From 0.88 the fine-grained headers of a public
// module carry a guard (react/cxxstableapi/UmbrellaGuard.h) that hard-errors
// when an app defines RN_STRICT_API; the umbrellas are the blessed path. Older
// versions have no umbrella, so each falls back to the fine-grained headers.

#if __has_include(<React/View.h>)
#include <React/View.h>
#else
#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/components/view/ViewEventEmitter.h>
#include <react/renderer/components/view/ViewProps.h>
#endif

#if __has_include(<React/RendererCore.h>)
#include <React/RendererCore.h>
#else
#include <react/renderer/core/ConcreteComponentDescriptor.h>
#include <react/renderer/core/LayoutConstraints.h>
#include <react/renderer/core/LayoutContext.h>
#include <react/renderer/core/LayoutPrimitives.h>
#include <react/renderer/core/LayoutableShadowNode.h>
#include <react/renderer/core/PropsParserContext.h>
#include <react/renderer/core/StateData.h>
#include <react/renderer/core/conversions.h>
#include <react/renderer/core/propsConversions.h>
#endif

#if __has_include(<React/Debug.h>)
#include <React/Debug.h>
#else
#include <react/debug/react_native_assert.h>
#endif
