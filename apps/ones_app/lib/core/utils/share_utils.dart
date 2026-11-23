import 'package:flutter/widgets.dart';

/// Returns a non-zero rect, in the source view's coordinate space, to pass as
/// `sharePositionOrigin` to `share_plus`.
///
/// On iOS (iPad popovers, and share_plus >= 10 on any iOS device) the native
/// share plugin requires a non-zero rect contained in the source view or it
/// throws: `sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}} must
/// be non-zero and within coordinate space of source view`.
///
/// Pass the [BuildContext] of the widget that triggered the share (e.g. inside
/// a `Builder` wrapping the share button) so the share sheet is anchored near
/// it. Falls back to the whole screen if the widget has no usable render box.
Rect shareOriginRect(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (rect.size.isFinite && !rect.size.isEmpty) {
      return rect;
    }
  }
  final size = MediaQuery.maybeSizeOf(context);
  if (size != null && size.width > 0 && size.height > 0) {
    return Offset.zero & size;
  }
  return const Rect.fromLTWH(0, 0, 1, 1);
}
