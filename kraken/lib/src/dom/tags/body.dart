/*
 * Copyright (C) 2019-present Alibaba Inc. All rights reserved.
 * Author: Kraken Team.
 */

import 'dart:ffi';
import 'package:kraken/bridge.dart';
import 'package:kraken/css.dart';
import 'package:kraken/dom.dart';

const String BODY = 'BODY';

class BodyElement extends Element {
  BodyElement(double viewportWidth, double viewportHeight, int targetId, Pointer<NativeElement> nativePtr, ElementManager elementManager)
      : super(
        targetId,
        nativePtr,
        elementManager,
        repaintSelf: true,
        tagName: BODY,
        defaultStyle: {
            WIDTH: '${viewportWidth}px',
            HEIGHT: '${viewportHeight}px',
            OVERFLOW: AUTO,
            BACKGROUND_COLOR: 'white',
          }
        );

  void attachBody() {
    willAttachRenderer();
    style.applyTargetProperties();
    didAttachRenderer();
  }
}