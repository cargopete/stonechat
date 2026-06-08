import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stonechat/src/branding/stonechat_mark.dart';

/// One-off icon generator (no-op in CI). Run:
///   GEN_ICON=1 flutter test test/tools/generate_icon_test.dart
///   dart run flutter_launcher_icons
void main() {
  testWidgets('renders the app-icon source PNG when GEN_ICON=1', (tester) async {
    if (Platform.environment['GEN_ICON'] != '1') return;

    const size = 1024.0;
    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: CustomPaint(
          size: const Size(size, size),
          painter: StonechatMarkPainter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/icon/stonechat.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
