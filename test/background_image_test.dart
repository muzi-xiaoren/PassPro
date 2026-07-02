import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:passpro/ui/background_image.dart';

/// 画一张纯色 PNG 作为解码输入。
Future<Uint8List> _makePng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366AA),
  );
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bakeBackgroundImage', () {
    test('超过 maxWidth 的图等比缩小解码', () async {
      final png = await _makePng(800, 400);
      final out = await bakeBackgroundImage(
        png,
        blurSigma: 5,
        maxWidth: 200,
        logicalWidth: 100,
      );
      expect(out.width, 200);
      expect(out.height, 100);
      out.dispose();
    });

    test('小图不放大；blur=0 直接返回解码结果', () async {
      final png = await _makePng(64, 32);
      final out = await bakeBackgroundImage(
        png,
        blurSigma: 0,
        maxWidth: 200,
        logicalWidth: 100,
      );
      expect(out.width, 64);
      expect(out.height, 32);
      out.dispose();
    });

    test('带模糊的烘焙保持尺寸不变', () async {
      final png = await _makePng(120, 80);
      final out = await bakeBackgroundImage(
        png,
        blurSigma: 8,
        maxWidth: 300,
        logicalWidth: 120,
      );
      expect(out.width, 120);
      expect(out.height, 80);
      out.dispose();
    });

    test('非图片字节抛异常而非崩溃', () async {
      expect(
        () => bakeBackgroundImage(
          Uint8List.fromList([1, 2, 3, 4]),
          blurSigma: 5,
          maxWidth: 200,
          logicalWidth: 100,
        ),
        throwsA(anything),
      );
    });
  });
}
