import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/reader_bar.dart';
import 'package:fluent_reader_lite/components/cupertino_toolbar.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:fluent_reader_lite/components/ios_bar_layout.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Reduce Transparency makes bar fills opaque and disables their filters',
    (tester) async {
      Color? adaptiveColor, defaultBarColor;
      Widget host(bool reduced, Brightness brightness) => CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        builder: (context, child) => IosBarLayoutScope(
          layout: IosBarLayout(
            size: const Size(800, 600),
            topInset: 0,
            reduceTransparency: reduced,
          ),
          bounds: const Rect.fromLTWH(0, 0, 800, 600),
          child: ReaderTransparencyTheme(child: child!),
        ),
        home: Builder(
          builder: (context) {
            adaptiveColor = readerBarColor(context);
            defaultBarColor = CupertinoTheme.of(context).barBackgroundColor;
            return Column(
              children: [
                const ReaderBarBackground(
                  key: Key('fill'),
                  color: Color(0x66FFFFFF),
                  child: SizedBox(height: 44, width: 200),
                ),
                const ReaderBarBackground(
                  key: Key('inner'),
                  color: CupertinoColors.transparent,
                  blur: false,
                  child: SizedBox(height: 44, width: 200),
                ),
              ],
            );
          },
        ),
      );
      for (final brightness in Brightness.values) {
        Element? fillElement;
        Rect? fillRect;
        for (final reduced in [false, true, false]) {
          await tester.pumpWidget(host(reduced, brightness));
          await tester.pumpAndSettle();
          final applied = reduced && readerBarBlurEnabled;
          final fill = find.byKey(const Key('fill'));
          fillElement ??= tester.element(fill);
          fillRect ??= tester.getRect(fill);
          expect(tester.element(fill), same(fillElement));
          expect(tester.getRect(fill), fillRect);
          final filter = tester.widget<BackdropFilter>(
            find.descendant(of: fill, matching: find.byType(BackdropFilter)),
          );
          final background = tester.widget<ColoredBox>(
            find.descendant(of: fill, matching: find.byType(ColoredBox)),
          );
          expect(filter.enabled, !applied);
          expect(background.color.a, applied ? 1 : closeTo(0.4, 0.001));
          expect(
            adaptiveColor!.a,
            readerBarBlurEnabled && !applied ? closeTo(0.8, 0.001) : 1,
          );
          expect(defaultBarColor!.a, applied ? 1 : lessThan(1));
          final inner = find.byKey(const Key('inner'));
          expect(
            tester
                .widget<ColoredBox>(
                  find.descendant(of: inner, matching: find.byType(ColoredBox)),
                )
                .color
                .a,
            0,
          );
          expect(
            tester
                .widget<BackdropFilter>(
                  find.descendant(
                    of: inner,
                    matching: find.byType(BackdropFilter),
                  ),
                )
                .enabled,
            isFalse,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'List scrollbar avoids the pinned row without moving its content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget host(bool bounded) => CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 62, bottom: 34),
          ),
          child: child!,
        ),
        home: ReaderPageScaffold(
          child: PrimaryScrollController(
            controller: controller,
            child: Builder(
              builder: (context) {
                const bar = ReaderSliverNavigationBar(
                  CupertinoSliverNavigationBar(
                    largeTitle: Text('Articles'),
                    transitionBetweenRoutes: false,
                  ),
                );
                return ReaderListScrollbar(
                  topInset: bounded ? bar.persistentHeight(context) : null,
                  slivers: [
                    bar,
                    SliverFixedExtentList(
                      itemExtent: 80,
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => Text('Item $index'),
                        childCount: 40,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.pumpAndSettle();
      controller.jumpTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final item = tester.getRect(find.text('Item 0'));
      final viewport = controller.position.viewportDimension;
      final extent = controller.position.maxScrollExtent;
      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(controller.offset, 1);
      expect(tester.getRect(find.text('Item 0')), item);
      expect(controller.position.viewportDimension, viewport);
      expect(controller.position.maxScrollExtent, extent);
      final scrollbar = find.byType(CupertinoScrollbar);
      final track = tester.getRect(scrollbar);
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(of: scrollbar, matching: find.byType(CustomPaint)),
          )
          .map((widget) => widget.foregroundPainter)
          .whereType<ScrollbarPainter>()
          .single;
      List<int> thumbPixels() => [
        for (var y = 0; y < track.height; y++)
          if (painter.hitTestOnlyThumbInteractive(
            Offset(track.width - 4, y.toDouble()),
            PointerDeviceKind.mouse,
          ))
            y,
      ];
      final thumb = thumbPixels();
      expect(thumb, isNotEmpty);
      final top = readerBarBlurEnabled ? 106 : 62;
      expect(thumb.first, inInclusiveRange(top + 3, top + 5));
      controller.jumpTo(700);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final dragThumb = thumbPixels();
      final drag = await tester.startGesture(
        Offset(track.right - 4, track.top + dragThumb[dragThumb.length ~/ 2]),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await drag.moveBy(const Offset(0, 50));
      await tester.pump(const Duration(milliseconds: 150));
      await drag.up();
      expect(controller.offset, greaterThan(700));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'Translucent tabs preserve list positions and scrollbar geometry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      ScrollMetrics? reported;
      Widget host(bool blur) => CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 24, bottom: 34),
          ),
          child: CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              backgroundColor: blur
                  ? const Color(0xCCFFFFFF)
                  : CupertinoColors.white,
              items: const [
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet)),
                BottomNavigationBarItem(icon: Icon(CupertinoIcons.star)),
              ],
            ),
            tabBuilder: (context, index) => PrimaryScrollController(
              controller: controller,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  reported = notification.metrics;
                  return false;
                },
                child: Builder(
                  builder: (context) {
                    final slivers = [
                      SliverFixedExtentList(
                        itemExtent: 80,
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => Text('Item $index'),
                          childCount: 40,
                        ),
                      ),
                    ];
                    return blur
                        ? ReaderListScrollbar(slivers: slivers)
                        : CupertinoScrollbar(
                            child: CustomScrollView(slivers: slivers),
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      Future<
        ({
          Rect track,
          Rect item,
          double extent,
          double viewport,
          List<int> thumb,
          double dragged,
        })
      >
      measure(bool blur) async {
        await tester.pumpWidget(host(blur));
        await tester.pumpAndSettle();
        controller.jumpTo(700);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final scrollbar = find.byType(CupertinoScrollbar);
        final track = tester.getRect(scrollbar);
        final item = tester.getRect(find.text('Item 10'));
        final painter = tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: scrollbar,
                matching: find.byType(CustomPaint),
              ),
            )
            .map((w) => w.foregroundPainter)
            .whereType<ScrollbarPainter>()
            .single;
        final thumb = [
          for (var y = 0; y < track.height; y++)
            if (painter.hitTestOnlyThumbInteractive(
              Offset(track.width - 4, y.toDouble()),
              PointerDeviceKind.mouse,
            ))
              y,
        ];
        expect(thumb, isNotEmpty);
        final extent = controller.position.maxScrollExtent;
        final viewport = reported!.viewportDimension;
        final drag = await tester.startGesture(
          Offset(track.right - 4, track.top + thumb[thumb.length ~/ 2]),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await drag.moveBy(const Offset(0, 50));
        await tester.pump(const Duration(milliseconds: 150));
        await drag.up();
        final dragged = controller.offset;
        expect(dragged, greaterThan(700));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        return (
          track: track,
          item: item,
          extent: extent,
          viewport: viewport,
          thumb: thumb,
          dragged: dragged,
        );
      }

      final opaque = await measure(false);
      final blurred = await measure(true);
      expect(blurred.track, opaque.track);
      expect(blurred.item, opaque.item);
      expect(blurred.extent, opaque.extent);
      expect(blurred.viewport, opaque.viewport);
      expect(blurred.thumb, opaque.thumb);
      expect(blurred.dragged, closeTo(opaque.dragged, 0.01));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Navigation underlap preserves the visible body above a keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final keyboard in [0.0, 300.0]) {
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                padding: EdgeInsets.only(
                  top: 24,
                  bottom: keyboard == 0 ? 34 : 0,
                ),
                viewInsets: EdgeInsets.only(bottom: keyboard),
              ),
              child: ReaderPageScaffold(
                underlapNavigationBar: true,
                navigationBar: CupertinoNavigationBar(
                  backgroundColor: const Color(0xCCFFFFFF),
                  automaticBackgroundVisibility: false,
                  middle: const Text('Reader'),
                ),
                child: CupertinoToolbar(
                  items: const [],
                  body: Builder(
                    builder: (context) => Padding(
                      padding: MediaQuery.paddingOf(context),
                      child: const SizedBox.expand(key: Key('visible')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byKey(const Key('visible'))),
          Rect.fromLTRB(0, 68, 390, 844 - 44 - (keyboard == 0 ? 34 : keyboard)),
        );
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
