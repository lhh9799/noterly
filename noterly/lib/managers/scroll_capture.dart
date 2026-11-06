import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Lets the system screenshot tool (the Galaxy screenshot toolbar's scroll capture, Android's "Capture more") capture
/// the whole list instead of only the visible screen.
///
/// Flutter draws everything into one native view, so Android cannot see that the list scrolls. MainActivity attaches
/// a ScrollCaptureCallback to that view and forwards each step here over [_channel]: find the list on screen, scroll it
/// to the part the system asks for, and hand back that part's pixels.
class ScrollCapture {
  static const _channel = MethodChannel('noterly/scroll_capture');

  static final List<_ScrollCaptureTargetState> _targets = [];

  static _ScrollCaptureTargetState? _active;
  static double _startOffset = 0;

  /// The call being handled now; the next one waits for it, so a capture never scrolls the list under another one.
  static Future<Object?> _pending = Future.value();

  static void init() {
    _channel.setMethodCallHandler((call) {
      final result = _pending.catchError((_) => null).then((_) => _handle(call));
      _pending = result;
      return result;
    });
  }

  static Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'search':
        _active = _findTarget();
        final bounds = _active?._boundsInPixels();
        if (bounds == null) return null;
        return {'left': bounds.left, 'top': bounds.top, 'right': bounds.right, 'bottom': bounds.bottom};
      case 'start':
        final position = _active?._position;
        if (position == null) return false;
        _startOffset = position.pixels;
        return true;
      case 'capture':
        final args = call.arguments as Map;
        return _active?._capture(_startOffset, args['top'] as int, args['bottom'] as int);
      case 'end':
        final position = _active?._position;
        position?.jumpTo(_startOffset.clamp(position.minScrollExtent, position.maxScrollExtent));
        _active = null;
        return true;
    }
    throw MissingPluginException(call.method);
  }

  /// The scrollable list that is on screen now and can scroll, the biggest one if there are several.
  static _ScrollCaptureTargetState? _findTarget() {
    _ScrollCaptureTargetState? best;
    double bestArea = 0;
    for (final target in _targets) {
      final visible = target._visibleArea();
      if (visible > bestArea) {
        best = target;
        bestArea = visible;
      }
    }
    return best;
  }
}

/// Marks [child], a scroll view driven by [controller], as a list the system screenshot tool may scroll and capture.
class ScrollCaptureTarget extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const ScrollCaptureTarget({required this.controller, required this.child, super.key});

  @override
  State<ScrollCaptureTarget> createState() => _ScrollCaptureTargetState();
}

class _ScrollCaptureTargetState extends State<ScrollCaptureTarget> {
  final _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ScrollCapture._targets.add(this);
  }

  @override
  void dispose() {
    ScrollCapture._targets.remove(this);
    if (ScrollCapture._active == this) ScrollCapture._active = null;
    super.dispose();
  }

  ScrollPosition? get _position {
    final controller = widget.controller;
    return (mounted && controller.hasClients && controller.positions.length == 1) ? controller.position : null;
  }

  RenderRepaintBoundary? get _boundary {
    final object = _boundaryKey.currentContext?.findRenderObject();
    return (object is RenderRepaintBoundary && object.attached && object.hasSize) ? object : null;
  }

  double get _pixelRatio => View.of(context).devicePixelRatio;

  /// How much of the list is on screen, in logical pixels squared; 0 when it can't be captured now.
  double _visibleArea() {
    final position = _position;
    final boundary = _boundary;
    if (position == null || boundary == null) return 0;
    if (position.maxScrollExtent <= position.minScrollExtent) return 0; // Nothing to scroll
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return 0; // Covered by another page
    final screen = Offset.zero & View.of(context).physicalSize / _pixelRatio;
    final rect = MatrixUtils.transformRect(boundary.getTransformTo(null), Offset.zero & boundary.size);
    final visible = rect.intersect(screen);
    if (visible.width <= 0 || visible.height <= 0) return 0; // e.g. the other tab of the PageView
    return visible.width * visible.height;
  }

  /// The list's bounds in physical pixels, relative to the Flutter view.
  Rect? _boundsInPixels() {
    final boundary = _boundary;
    if (boundary == null) return null;
    final rect = MatrixUtils.transformRect(boundary.getTransformTo(null), Offset.zero & boundary.size);
    final ratio = _pixelRatio;
    return Rect.fromLTRB(
      (rect.left * ratio).roundToDouble(),
      (rect.top * ratio).roundToDouble(),
      (rect.right * ratio).roundToDouble(),
      (rect.bottom * ratio).roundToDouble(),
    );
  }

  /// Scrolls so that the rows [top]..[bottom] (physical pixels, relative to the list's top when the capture started)
  /// are on screen, then returns the part of them that could be captured with its pixels.
  Future<Map<String, Object>?> _capture(double startOffset, int top, int bottom) async {
    final position = _position;
    final bounds = _boundsInPixels();
    if (position == null || bounds == null || !mounted) return null;
    final ratio = _pixelRatio;
    final background = Theme.of(context).scaffoldBackgroundColor;

    final target = (startOffset + top / ratio).clamp(position.minScrollExtent, position.maxScrollExtent);
    position.jumpTo(target);
    // The screenshot UI covers the app, so make sure a frame is drawn even if the engine is not asking for one, and
    // never wait forever: the system gives up on the whole capture if one request does not answer
    SchedulerBinding.instance.scheduleForcedFrame();
    await SchedulerBinding.instance.endOfFrame.timeout(const Duration(seconds: 1), onTimeout: () {});

    final boundary = _boundary;
    if (boundary == null || !mounted) return null;

    // Where the list's viewport sits now, in the capture's coordinates
    final windowTop = ((position.pixels - startOffset) * ratio).round();
    final windowBottom = windowTop + bounds.height.round();
    final capturedTop = math.max(top, windowTop);
    final capturedBottom = math.min(bottom, windowBottom);
    if (capturedBottom <= capturedTop) return {'top': 0, 'bottom': 0};

    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final width = image.width;
      final sourceTop = (capturedTop - windowTop).clamp(0, image.height);
      final height = math.min(capturedBottom - capturedTop, image.height - sourceTop);
      if (height <= 0) return {'top': 0, 'bottom': 0};

      // Copy the rows onto an opaque background: the list itself is transparent over the page colour
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(background, BlendMode.src);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, sourceTop.toDouble(), width.toDouble(), height.toDouble()),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint(),
      );
      final cropped = await recorder.endRecording().toImage(width, height);
      try {
        final bytes = await cropped.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (bytes == null) return null;
        return {
          'top': capturedTop,
          'bottom': capturedTop + height,
          'width': width,
          'height': height,
          'pixels': bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        };
      } finally {
        cropped.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(key: _boundaryKey, child: widget.child);
}
