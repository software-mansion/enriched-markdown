#pragma once
#import "ENRMUIKit.h"
#import <React/RCTUtils.h>
#include <memory>
#include <react/renderer/core/StateData.h>
#import <react/utils/ManagedObjectWrapper.h>

/// Returns YES if the measured content height differs from the frame height
/// Yoga assigned, comparing at physical-pixel granularity to avoid
/// false positives from sub-pixel floating-point differences.
static inline BOOL needsHeightUpdate(CGSize measuredSize, CGRect bounds)
{
  CGFloat scale = RCTScreenScale();
  CGFloat assignedHeight = ceil(bounds.size.height * scale) / scale;
  CGFloat measuredHeight = ceil(measuredSize.height * scale) / scale;
  return assignedHeight != measuredHeight;
}

/// Bumps the height counter on top of the latest state data, so anything the
/// shadow node published into the state (block slot frames) survives the
/// view-initiated update.
template <typename StateDataT, typename ConcreteStateT>
inline void ENRMRequestHeightUpdate(std::shared_ptr<const ConcreteStateT> const &state, int &counter, id self)
{
  if (!state)
    return;
  counter++;
  const int nextCounter = counter;
  std::shared_ptr<void> ref = facebook::react::wrapManagedObjectWeakly(self);
  state->updateState([nextCounter, ref](const StateDataT &oldData) -> facebook::react::StateData::Shared {
    return std::make_shared<const StateDataT>(oldData.withHeightRecalculationCounter(nextCounter, ref));
  });
}
