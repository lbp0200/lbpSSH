import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lbp_ssh/presentation/widgets/graphics_overlay.dart';

/// 模拟 kterm GraphicsManager 的 fake 对象
class _FakeGraphicsManager {
  final Map<Object, Object> _placements;
  ui.Image? image;
  bool throwOnAccess;

  _FakeGraphicsManager({
    Map<Object, Object> placements = const {},
    this.image,
    this.throwOnAccess = false,
  }) : _placements = placements;

  dynamic get placements =>
      throwOnAccess ? throw StateError('boom') : _placements;

  ui.Image? getImage(String imageId) => image;
}

final _overlayStack = find.descendant(
  of: find.byType(GraphicsOverlayWidget),
  matching: find.byType(Stack),
);

void main() {
  Future<ui.Image> createTestImage(WidgetTester tester) async {
    late ui.Image image;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 10, 10),
        Paint()..color = const Color(0xFF336699),
      );
      final picture = recorder.endRecording();
      image = await picture.toImage(10, 10);
    });
    return image;
  }

  Future<void> pumpOverlay(
    WidgetTester tester,
    _FakeGraphicsManager manager, {
    double cellWidth = 10.0,
    double cellHeight = 20.0,
    int scrollOffset = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphicsOverlayWidget(
            graphicsManager: manager,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            scrollOffset: scrollOffset,
          ),
        ),
      ),
    );
    // 推进一轮轮询，让 placements 更新触发 setState
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// 卸载 widget 并推进时间，让轮询循环检测到 !mounted 后退出
  Future<void> teardownOverlay(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('GraphicsOverlayWidget', () {
    testWidgets('Given empty placements, When rendered, Then shows nothing', (
      tester,
    ) async {
      await pumpOverlay(tester, _FakeGraphicsManager());

      expect(_overlayStack, findsNothing);
      expect(find.byType(GraphicsOverlayWidget), findsOneWidget);

      await teardownOverlay(tester);
    });

    testWidgets(
      'Given placements with null image, When rendered, Then skips image and shows nothing',
      (tester) async {
        final manager = _FakeGraphicsManager(
          placements: {
            'img1': <String, Object>{
              'imageId': 'img1',
              'x': 1,
              'y': 1,
              'width': 2,
              'height': 2,
            },
          },
        );
        await pumpOverlay(tester, manager);

        expect(_overlayStack, findsNothing);
        expect(find.byType(RawImage), findsNothing);

        await teardownOverlay(tester);
      },
    );

    testWidgets(
      'Given visible placement with image, When rendered, Then shows positioned image',
      (tester) async {
        final image = await createTestImage(tester);
        final manager = _FakeGraphicsManager(
          placements: {
            'img1': <String, Object>{
              'imageId': 'img1',
              'x': 2,
              'y': 3,
              'width': 4,
              'height': 5,
            },
          },
          image: image,
        );
        await pumpOverlay(tester, manager);

        expect(_overlayStack, findsOneWidget);
        expect(find.byType(RawImage), findsOneWidget);
        expect(find.byType(Positioned), findsOneWidget);

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.left, 20); // x=2 * cellWidth=10
        expect(positioned.top, 60); // y=3 * cellHeight=20

        final rawImage = tester.widget<RawImage>(find.byType(RawImage));
        expect(rawImage.image, same(image));

        await teardownOverlay(tester);
      },
    );

    testWidgets(
      'Given placement scrolled off screen, When rendered, Then skips it',
      (tester) async {
        final image = await createTestImage(tester);
        final manager = _FakeGraphicsManager(
          placements: {
            'offscreen': <String, Object>{
              'imageId': 'offscreen',
              'x': -100,
              'y': 0,
              'width': 1,
              'height': 1,
            },
            'visible': <String, Object>{
              'imageId': 'visible',
              'x': 1,
              'y': 1,
              'width': 1,
              'height': 1,
            },
          },
          image: image,
        );
        await pumpOverlay(tester, manager);

        expect(_overlayStack, findsOneWidget);
        expect(find.byType(RawImage), findsOneWidget);

        await teardownOverlay(tester);
      },
    );

    testWidgets(
      'Given scrollOffset shifts placement up, When rendered, Then y is adjusted',
      (tester) async {
        final image = await createTestImage(tester);
        final manager = _FakeGraphicsManager(
          placements: {
            'img1': <String, Object>{
              'imageId': 'img1',
              'x': 0,
              'y': 10,
              'width': 1,
              'height': 1,
            },
          },
          image: image,
        );
        await pumpOverlay(tester, manager, scrollOffset: 4);

        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.top, 120); // (10 - 4) * 20

        await teardownOverlay(tester);
      },
    );

    testWidgets(
      'Given graphics manager throws, When rendered, Then shows nothing instead of crashing',
      (tester) async {
        final manager = _FakeGraphicsManager(throwOnAccess: true);
        await pumpOverlay(tester, manager);

        expect(_overlayStack, findsNothing);
        expect(tester.takeException(), isNull);

        await teardownOverlay(tester);
      },
    );
  });
}
