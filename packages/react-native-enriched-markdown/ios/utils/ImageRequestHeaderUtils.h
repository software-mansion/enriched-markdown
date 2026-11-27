#pragma once

#import "StyleConfig.h"
#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <vector>

template <typename T>
static bool ENRMImageRequestHeadersChanged(const std::vector<T> &oldHeaders, const std::vector<T> &newHeaders)
{
  if (newHeaders.size() != oldHeaders.size()) {
    return true;
  }
  for (size_t i = 0; i < newHeaders.size(); i++) {
    if (newHeaders[i].name != oldHeaders[i].name || newHeaders[i].value != oldHeaders[i].value) {
      return true;
    }
  }
  return false;
}

template <typename T>
static NSDictionary<NSString *, NSString *> *_Nullable ENRMImageRequestHeadersFromProps(const std::vector<T> &headers)
{
  if (headers.empty()) {
    return nil;
  }
  NSMutableDictionary<NSString *, NSString *> *result = [NSMutableDictionary dictionaryWithCapacity:headers.size()];
  for (const auto &header : headers) {
    result[@(header.name.c_str())] = @(header.value.c_str());
  }
  return [result copy];
}

// The `imageSources` prop: per-image request overrides keyed by occurrence id.

template <typename T>
static bool ENRMImageSourcesChanged(const std::vector<T> &oldSources, const std::vector<T> &newSources)
{
  if (newSources.size() != oldSources.size()) {
    return true;
  }
  for (size_t i = 0; i < newSources.size(); i++) {
    if (newSources[i].id != oldSources[i].id || newSources[i].uri != oldSources[i].uri ||
        ENRMImageRequestHeadersChanged(oldSources[i].headers, newSources[i].headers)) {
      return true;
    }
  }
  return false;
}

template <typename T>
static NSDictionary<NSString *, ENRMImageSourceOverride *> *_Nullable ENRMImageSourceOverridesFromProps(
    const std::vector<T> &sources)
{
  if (sources.empty()) {
    return nil;
  }
  NSMutableDictionary<NSString *, ENRMImageSourceOverride *> *result =
      [NSMutableDictionary dictionaryWithCapacity:sources.size()];
  for (const auto &source : sources) {
    ENRMImageSourceOverride *override = [[ENRMImageSourceOverride alloc] init];
    override.uri = @(source.uri.c_str());
    NSMutableDictionary<NSString *, NSString *> *headers =
        [NSMutableDictionary dictionaryWithCapacity:source.headers.size()];
    for (const auto &header : source.headers) {
      headers[@(header.name.c_str()).lowercaseString] = @(header.value.c_str());
    }
    override.headers = headers;
    result[@(source.id.c_str())] = override;
  }
  return [result copy];
}

#endif
