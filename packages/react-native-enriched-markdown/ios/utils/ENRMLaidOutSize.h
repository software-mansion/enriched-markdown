#pragma once

#include <CoreGraphics/CGGeometry.h>
#import <Foundation/Foundation.h>
#include <memory>
#include <os/lock.h>
#include <string>
#include <string_view>

/**
 * The size a markdown view laid its content out at, the width it laid it out
 * for and the markdown it rendered: published on main, read by the shadow node
 * from the layout thread.
 *
 * `measureContent` may run while React Native holds the ShadowTree revision
 * mutex that a main-thread committer (e.g. Reanimated) can be waiting on, so
 * the measure path must never wait on main (issue #550), and reading the
 * view's `bounds` off main is unsafe. The view publishes instead, and the
 * values are read together under a lock that is only held to copy them.
 */
class ENRMLaidOutSize {
public:
  void store(CGFloat width, CGSize size, std::shared_ptr<const std::string> markdown)
  {
    os_unfair_lock_lock(&lock_);
    width_ = width;
    size_ = size;
    markdown_.swap(markdown);
    os_unfair_lock_unlock(&lock_);
  }

  void clear()
  {
    store(0, CGSizeZero, nullptr);
  }

  /// The laid-out size if the view laid out for `width`, give or take a physical
  /// pixel (Yoga rounds the two edges of a frame separately), and rendered
  /// markdown that `markdown` keeps all of: an earlier state of the same stream,
  /// not a document it replaced. Else zero.
  CGSize sizeFor(CGFloat width, CGFloat pointScaleFactor, std::string_view markdown) const
  {
    os_unfair_lock_lock(&lock_);
    CGFloat laidOutWidth = width_;
    CGSize size = size_;
    std::shared_ptr<const std::string> laidOutMarkdown = markdown_;
    os_unfair_lock_unlock(&lock_);
    CGFloat tolerance = 1 / (pointScaleFactor > 0 ? pointScaleFactor : 1);
    if (size.height <= 0 || laidOutWidth - width > tolerance || width - laidOutWidth > tolerance) {
      return CGSizeZero;
    }
    if (!laidOutMarkdown || laidOutMarkdown->empty() ||
        markdown.compare(0, laidOutMarkdown->size(), *laidOutMarkdown) != 0) {
      return CGSizeZero;
    }
    return size;
  }

  /// sizeFor, when the view rendered only a start of `markdown`: smooth pacing still revealing it.
  CGSize partialSizeFor(CGFloat width, CGFloat pointScaleFactor, std::string_view markdown) const
  {
    os_unfair_lock_lock(&lock_);
    size_t laidOutLength = markdown_ ? markdown_->size() : 0;
    os_unfair_lock_unlock(&lock_);
    return laidOutLength < markdown.size() ? sizeFor(width, pointScaleFactor, markdown) : CGSizeZero;
  }

private:
  mutable os_unfair_lock lock_ = OS_UNFAIR_LOCK_INIT;
  CGFloat width_ = 0;
  CGSize size_ = CGSizeZero;
  std::shared_ptr<const std::string> markdown_;
};

/// `markdown` as ENRMLaidOutSize keeps it.
inline std::shared_ptr<const std::string> ENRMLaidOutMarkdown(NSString *markdown)
{
  return std::make_shared<const std::string>(markdown.UTF8String ?: "");
}
