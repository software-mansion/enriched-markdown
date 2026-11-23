package com.swmansion.enriched.markdown.test;

import android.content.Context;
import com.facebook.react.bridge.BridgeReactContext;
import com.facebook.react.uimanager.events.Event;
import com.facebook.react.uimanager.events.EventDispatcher;
import com.facebook.react.uimanager.events.EventDispatcherProvider;
import java.lang.reflect.Proxy;
import java.util.List;

/**
 * A React context whose event dispatcher adds the name of each event views dispatch to a list.
 * Java, because Kotlin callers can't implement the internal EventDispatcherProvider.
 */
@SuppressWarnings("deprecation")
public final class EventRecordingContext extends BridgeReactContext implements EventDispatcherProvider {
  private final EventDispatcher dispatcher;

  private EventRecordingContext(Context base, List<String> eventNames) {
    super(base);
    dispatcher =
        (EventDispatcher)
            Proxy.newProxyInstance(
                EventDispatcher.class.getClassLoader(),
                new Class<?>[] {EventDispatcher.class},
                (proxy, method, args) -> {
                  switch (method.getName()) {
                    case "dispatchEvent":
                      eventNames.add(((Event<?>) args[0]).getEventName());
                      return null;
                    case "hashCode":
                      return System.identityHashCode(proxy);
                    case "equals":
                      return proxy == args[0];
                    case "toString":
                      return "RecordingEventDispatcher";
                    default:
                      return null;
                  }
                });
  }

  public static Context create(Context base, List<String> eventNames) {
    return new EventRecordingContext(base, eventNames);
  }

  @Override
  public EventDispatcher getEventDispatcher() {
    return dispatcher;
  }
}
