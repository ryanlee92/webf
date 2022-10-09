/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:webf/dom.dart';
import 'package:webf/rendering.dart';
import 'package:webf/src/gesture/gesture_dispatcher.dart';

typedef HandleGetEventTarget = EventTarget Function();

mixin RenderEventListenerMixin on RenderBox {
  HandleGetEventTarget? getEventTarget;

  GestureDispatcher? get gestureDispatcher {
    AbstractNode? p = parent;
    while(p != null) {
      if (p is RenderViewportBox) {
        return p.gestureDispatcher;
      }
      if (p is RenderPortal) {
        return p.gestureDispatcher;
      }

      p = p.parent;
    }
    return null;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    assert(debugHandleEvent(event, entry));
    // Set event path at begin stage and reset it at end stage on viewport render box.
    // And if event path existed, it means current render box is not the first in path.
    if (getEventTarget != null) {
      if (event is PointerDownEvent) {
        // Store the first handleEvent the event path list.
        GestureDispatcher? dispatcher = gestureDispatcher;
        if (dispatcher != null && dispatcher.getEventPath().isEmpty) {
          dispatcher.setEventPath(getEventTarget!());
        }
      }
    }

    super.handleEvent(event, entry);
  }
}
