/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:webf/bridge.dart';
import 'package:webf/css.dart';
import 'package:webf/dom.dart';
import 'package:webf/foundation.dart';

import 'canvas_context_2d.dart';
import 'canvas_painter.dart';

const String CANVAS = 'CANVAS';
const int _ELEMENT_DEFAULT_WIDTH_IN_PIXEL = 300;
const int _ELEMENT_DEFAULT_HEIGHT_IN_PIXEL = 150;

const Map<String, dynamic> _defaultStyle = {
  DISPLAY: INLINE_BLOCK,
};

class RenderCanvasPaint extends RenderCustomPaint {
  @override
  bool get isRepaintBoundary => true;

  RenderCanvasPaint(
      {required CustomPainter painter, required Size preferredSize})
      : super(
          painter: painter,
          foregroundPainter: null, // Ignore foreground painter
          preferredSize: preferredSize,
        );

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushClipRect(needsCompositing, offset,
        Rect.fromLTWH(0, 0, preferredSize.width, preferredSize.height),
        (context, offset) {
      super.paint(context, offset);
    });
  }
}

class CanvasElement extends Element {
  final ChangeNotifier repaintNotifier = ChangeNotifier();

  /// The painter that paints before the children.
  late CanvasPainter painter;

  // The custom paint render object.
  RenderCustomPaint? renderCustomPaint;

  CanvasElement([BindingContext? context]) : super(context) {
    painter = CanvasPainter(repaint: repaintNotifier);
  }

  @override
  bool get isReplacedElement => true;

  @override
  bool get isDefaultRepaintBoundary => true;

  @override
  Map<String, dynamic> get defaultStyle => _defaultStyle;

  // Currently only 2d rendering context for canvas is supported.
  CanvasRenderingContext2D? context2d;

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
    super.initializeMethods(methods);
    methods['getContext'] = BindingObjectMethodSync(
        call: (args) => getContext(castToType<String>(args[0])));
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
    super.initializeProperties(properties);
    properties['width'] = BindingObjectProperty(
        getter: () => width, setter: (value) => width = castToType<int>(value));
    properties['height'] = BindingObjectProperty(
        getter: () => height,
        setter: (value) => height = castToType<int>(value));
  }

  @override
  void willAttachRenderer() {
    super.willAttachRenderer();
    renderCustomPaint = RenderCanvasPaint(
      painter: painter,
      preferredSize: size,
    );

    addChild(renderCustomPaint!);
    style.addStyleChangeListener(_styleChangedListener);
  }

  @override
  void didDetachRenderer() {
    super.didDetachRenderer();
    style.removeStyleChangeListener(_styleChangedListener);
    painter.dispose();
    renderCustomPaint = null;
  }

  CanvasRenderingContext2D getContext(String type, {options}) {
    switch (type) {
      case '2d':
        if (painter.context != null) {
          painter.context!.dispose();
          painter.dispose();
        }

        context2d = CanvasRenderingContext2D(BindingContext(ownerView, ownerView.contextId, allocateNewBindingObject()), this);
        painter.context = context2d;

        return context2d!;
      default:
        throw FlutterError('CanvasRenderingContext $type not supported!');
    }
  }

  /// The size that this [CustomPaint] should aim for, given the layout
  /// constraints, if there is no child.
  ///
  /// If there's a child, this is ignored, and the size of the child is used
  /// instead.
  Size get size {
    double? width;
    double? height;

    RenderStyle renderStyle = renderBoxModel!.renderStyle;
    double? styleWidth = renderStyle.width.isAuto ? null : renderStyle.width.computedValue;
    double? styleHeight = renderStyle.height.isAuto ? null : renderStyle.height.computedValue;

    if (styleWidth != null) {
      width = styleWidth;
    }

    if (styleHeight != null) {
      height = styleHeight;
    }

    // [width/height] has default value, should not be null.
    if (height == null && width == null) {
      width = this.width.toDouble();
      height = this.height.toDouble();
    } else if (width == null && height != null) {
      width = this.height / height * this.width;
    } else if (width != null && height == null) {
      height = this.width / width * this.height;
    }

    // need to minus padding and border size
    width = width! -
        renderStyle.effectiveBorderLeftWidth.computedValue -
        renderStyle.effectiveBorderRightWidth.computedValue -
        renderStyle.paddingLeft.computedValue -
        renderStyle.paddingRight.computedValue;
    height = height! -
        renderStyle.effectiveBorderTopWidth.computedValue -
        renderStyle.effectiveBorderBottomWidth.computedValue -
        renderStyle.paddingTop.computedValue -
        renderStyle.paddingLeft.computedValue;

    return Size(width, height);
  }

  void resize() {
    if (renderCustomPaint != null) {
      // https://html.spec.whatwg.org/multipage/canvas.html#concept-canvas-set-bitmap-dimensions
      final Size paintingBounding = size;
      renderCustomPaint!.preferredSize = paintingBounding;

      // The intrinsic dimensions of the canvas element when it represents embedded content are
      // equal to the dimensions of the element’s bitmap.
      // A canvas element can be sized arbitrarily by a style sheet, its bitmap is then subject
      // to the object-fit CSS property.
      // @TODO: CSS object-fit for canvas.
      // To fill (default value of object-fit) the bitmap content, use scale to get the same performed.
      RenderStyle renderStyle = renderBoxModel!.renderStyle;
      double? styleWidth = renderStyle.width.isAuto ? null : renderStyle.width.computedValue;
      double? styleHeight = renderStyle.height.isAuto ? null : renderStyle.height.computedValue;

      double? scaleX;
      double? scaleY;
      if (styleWidth != null) {
        scaleX = paintingBounding.width / width;
      }
      if (styleHeight != null) {
        scaleY = paintingBounding.height / height;
      }
      if (painter.scaleX != scaleX || painter.scaleY != scaleY) {
        painter
          ..scaleX = scaleX
          ..scaleY = scaleY;
        if (painter.shouldRepaint(painter)) {
          renderCustomPaint!.markNeedsPaint();
        }
      }
    }
  }

  /// Element property width.
  int get width {
    String? attrWidth = getAttribute(WIDTH);
    if (attrWidth != null) {
      return attributeToProperty<int>(attrWidth);
    } else {
      return _ELEMENT_DEFAULT_WIDTH_IN_PIXEL;
    }
  }

  set width(int value) {
    _setDimensions(value, null);
  }

  /// Element property height.
  int get height {
    String? attrHeight = getAttribute(HEIGHT);
    if (attrHeight != null) {
      return attributeToProperty<int>(attrHeight);
    } else {
      return _ELEMENT_DEFAULT_HEIGHT_IN_PIXEL;
    }
  }

  set height(int value) {
    _setDimensions(null, value);
  }

  void _setDimensions(num? width, num? height) {
    // When the user agent is to set bitmap dimensions to width and height, it must run these steps:
    // 1. Reset the rendering context to its default state.
    context2d?.reset();

    // 2. Let canvas be the canvas element to which the rendering context's canvas attribute was initialized.
    // 3. If the numeric value of canvas's width content attribute differs from width,
    // then set canvas's width content attribute to the shortest possible string representing width as
    // a valid non-negative integer.
    if (width != null && width.toString() != getAttribute(WIDTH)) {
      if (width < 0) width = 0;
      internalSetAttribute(WIDTH, width.toString());
    }
    // 5. If the numeric value of canvas's height content attribute differs from height,
    // then set canvas's height content attribute to the shortest possible string representing height as
    // a valid non-negative integer.
    if (height != null && height.toString() != getAttribute(HEIGHT)) {
      if (height < 0) height = 0;
      internalSetAttribute(HEIGHT, height.toString());
    }

    // 4. Resize the output bitmap to the new width and height and clear it to transparent black.
    resize();
  }

  void _styleChangedListener(String key, String? original, String present, {String? baseHref}) {
    switch (key) {
      case WIDTH:
      case HEIGHT:
      case PADDING_BOTTOM:
      case PADDING_LEFT:
      case PADDING_RIGHT:
      case PADDING_TOP:
      case BORDER_TOP_STYLE:
      case BORDER_TOP_WIDTH:
      case BORDER_LEFT_STYLE:
      case BORDER_LEFT_WIDTH:
      case BORDER_RIGHT_STYLE:
      case BORDER_RIGHT_WIDTH:
      case BORDER_BOTTOM_STYLE:
      case BORDER_BOTTOM_WIDTH:
        resize();
        break;
    }
  }

  @override
  void setAttribute(String qualifiedName, String value) {
    super.setAttribute(qualifiedName, value);
    switch (qualifiedName) {
      case 'width':
        width = attributeToProperty<int>(value);
        break;
      case 'height':
        height = attributeToProperty<int>(value);
        break;
    }
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    // If not getContext and element is disposed that context is not existed.
    if (painter.context != null) {
      painter.context!.dispose();
    }
  }
}
