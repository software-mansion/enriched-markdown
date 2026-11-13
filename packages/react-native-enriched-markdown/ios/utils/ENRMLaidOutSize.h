#pragma once

#include <CoreGraphics/CGGeometry.h>
#import <Foundation/Foundation.h>
#include <memory>
#include <os/lock.h>
#include <string>
#include <string_view>
#include <vector>

/// A block slot placeholder the view laid out at the root of its stack: where it starts in the
/// content and the height it reserved for its React child.
struct ENRMLaidOutSlot {
  std::string id;
  CGFloat y;
  CGFloat height;
};

/// The laid-out size with the slot placeholders it was laid out with.
struct ENRMLaidOutLayout {
  CGSize size = CGSizeZero;
  std::shared_ptr<const std::vector<ENRMLaidOutSlot>> slots;
};

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
  void store(CGFloat width, CGSize size, std::shared_ptr<const std::string> markdown,
             std::shared_ptr<const std::vector<ENRMLaidOutSlot>> slots = nullptr)
  {
    os_unfair_lock_lock(&lock_);
    width_ = width;
    size_ = size;
    markdown_.swap(markdown);
    slots_.swap(slots);
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
    return copy().sizeFor(width, pointScaleFactor, markdown);
  }

  /// sizeFor, with the slot placeholders laid out with that size.
  ENRMLaidOutLayout layoutFor(CGFloat width, CGFloat pointScaleFactor, std::string_view markdown) const
  {
    Values laidOut = copy();
    CGSize size = laidOut.sizeFor(width, pointScaleFactor, markdown);
    return size.height > 0 ? ENRMLaidOutLayout{size, laidOut.slots} : ENRMLaidOutLayout{};
  }

  /// sizeFor, when the view rendered only a start of `markdown`: smooth pacing still revealing it.
  CGSize partialSizeFor(CGFloat width, CGFloat pointScaleFactor, std::string_view markdown) const
  {
    Values laidOut = copy();
    size_t laidOutLength = laidOut.markdown ? laidOut.markdown->size() : 0;
    return laidOutLength < markdown.size() ? laidOut.sizeFor(width, pointScaleFactor, markdown) : CGSizeZero;
  }

private:
  // What the view published, copied under the lock.
  struct Values {
    CGFloat width;
    CGSize size;
    std::shared_ptr<const std::string> markdown;
    std::shared_ptr<const std::vector<ENRMLaidOutSlot>> slots;

    CGSize sizeFor(CGFloat forWidth, CGFloat pointScaleFactor, std::string_view forMarkdown) const
    {
      CGFloat tolerance = 1 / (pointScaleFactor > 0 ? pointScaleFactor : 1);
      if (size.height <= 0 || width - forWidth > tolerance || forWidth - width > tolerance) {
        return CGSizeZero;
      }
      if (!markdown || markdown->empty() || forMarkdown.compare(0, markdown->size(), *markdown) != 0) {
        return CGSizeZero;
      }
      return size;
    }
  };

  Values copy() const
  {
    os_unfair_lock_lock(&lock_);
    Values values{width_, size_, markdown_, slots_};
    os_unfair_lock_unlock(&lock_);
    return values;
  }

  mutable os_unfair_lock lock_ = OS_UNFAIR_LOCK_INIT;
  CGFloat width_ = 0;
  CGSize size_ = CGSizeZero;
  std::shared_ptr<const std::string> markdown_;
  std::shared_ptr<const std::vector<ENRMLaidOutSlot>> slots_;
};

/// `markdown` as ENRMLaidOutSize keeps it.
inline std::shared_ptr<const std::string> ENRMLaidOutMarkdown(NSString *markdown)
{
  return std::make_shared<const std::string>(markdown.UTF8String ?: "");
}
