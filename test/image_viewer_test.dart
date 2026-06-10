import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/ui/image_viewer.dart';

void main() {
  testWidgets('viewer sizes the image to fill the screen, not its intrinsic size',
      (tester) async {
    // A valid 2×2 PNG — if the viewer used intrinsic sizing the image box would
    // be ~2px; the explicit screen-sized box must make it fill instead.
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAEUlEQVR4nGP4z8DwH4QZYAwAR8oH+WdZbrcAAAAASUVORK5CYII=',
    );
    tester.view.physicalSize = const Size(1170, 2532); // ~390×844 logical @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: ImageViewerPage(bytes: bytes)));
    await tester.pump();

    final imgSize = tester.getSize(find.byType(Image));
    expect(imgSize.width, greaterThan(300));
    expect(imgSize.height, greaterThan(300));
  });
}
