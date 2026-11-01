import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/ios_bar_layout.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _cover = Size(466, 678);
const _corner = Rect.fromLTWH(266, 0, 200, 82);
const _alignmentY = 48.0;
const _layout = IosBarLayout(
  size: _cover,
  topInset: 82,
  toolbar: Rect.fromLTWH(16, 26, 250, 44),
);

Widget _host(
  Widget page, {
  IosBarLayout? layout = _layout,
  Size size = _cover,
  double top = 82,
  double keyboard = 0,
  double pixelRatio = 1,
  Brightness brightness = Brightness.light,
}) => CupertinoApp(
  theme: CupertinoThemeData(brightness: brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQueryData(
      size: size,
      devicePixelRatio: pixelRatio,
      padding: EdgeInsets.only(top: top, bottom: keyboard > 0 ? 0 : 34),
      viewPadding: EdgeInsets.only(top: top, bottom: 34),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: IosBarLayoutScope(
      layout: layout,
      bounds: Offset.zero & size,
      child: child!,
    ),
  ),
  home: page,
);

void main() {
  Future<void> sizeView(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets(
    'Windowed iPad navigation avoids controls without moving its body',
    (tester) async {
      const size = Size(902, 671.5);
      await sizeView(tester, size);
      var taps = 0;
      final page = ReaderPageScaffold(
        keepMiddle: true,
        navigationBar: CupertinoNavigationBar(
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => taps++,
            child: const Icon(CupertinoIcons.sidebar_left),
          ),
          middle: const SizedBox(width: 180, height: 32, key: Key('selector')),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => taps++,
            child: const Icon(CupertinoIcons.fullscreen),
          ),
        ),
        child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
      );
      Element? originalBody;
      for (final (left, keyboard) in [
        (66.0, 0.0),
        (128.0, 200.0),
        (66.0, 0.0),
      ]) {
        // Native geometry captured while the iPad window was floating. This
        // bar sits below the top safe area, beside the window controls.
        final toolbar = Rect.fromLTWH(left, 10, 892.5 - left, 44);
        await tester.pumpWidget(
          _host(
            page,
            size: size,
            top: 10,
            keyboard: keyboard,
            layout: IosBarLayout(
              size: size,
              topInset: 10,
              toolbar: toolbar,
              avoidsWindowControls: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final leading = find.ancestor(
          of: find.byIcon(CupertinoIcons.sidebar_left),
          matching: find.byType(CupertinoButton),
        );
        final trailing = find.ancestor(
          of: find.byIcon(CupertinoIcons.fullscreen),
          matching: find.byType(CupertinoButton),
        );
        expect(tester.getRect(leading).left, greaterThanOrEqualTo(left));
        expect(
          tester.getRect(trailing).right,
          lessThanOrEqualTo(toolbar.right),
        );
        expect(tester.getCenter(leading).dy, 32);
        expect(tester.getCenter(find.byKey(const Key('selector'))).dy, 32);
        final body = tester.getRect(find.byKey(const Key('body')));
        expect(body.top, 54);
        expect(body.bottom, size.height - (keyboard > 0 ? keyboard : 34));
        originalBody ??= tester.element(find.byKey(const Key('body')));
        expect(
          tester.element(find.byKey(const Key('body'))),
          same(originalBody),
        );
        await tester.tap(leading);
        await tester.tap(trailing);
        expect(tester.takeException(), isNull);
      }
      expect(taps, 6);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Corner row prioritizes tappable actions and hides a crowded title',
    (tester) async {
      await sizeView(tester, _cover);
      final semantics = tester.ensureSemantics();
      var leadingTaps = 0, trailingTaps = 0;
      final page = ReaderPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('A moderately long title'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => leadingTaps++,
            child: const Icon(
              CupertinoIcons.back,
              semanticLabel: 'Back action',
            ),
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => trailingTaps++,
            child: const Icon(
              CupertinoIcons.check_mark,
              semanticLabel: 'Save action',
            ),
          ),
        ),
        child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
      );
      await tester.pumpWidget(_host(page));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 82);
      expect(
        tester.getCenter(find.bySemanticsLabel('Save action')).dy,
        closeTo(_alignmentY, 0.00001),
      );
      expect(
        tester.getRect(find.bySemanticsLabel('Save action')).right,
        lessThan(_corner.left),
      );
      expect(find.bySemanticsLabel('A moderately long title'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Back action'));
      await tester.tap(find.bySemanticsLabel('Save action'));
      expect([leadingTaps, trailingTaps], [1, 1]);

      // A wider pane restores the title without changing the page or actions.
      const wide = Size(951, 669);
      tester.view.physicalSize = wide;
      await tester.pumpWidget(
        _host(
          page,
          size: wide,
          layout: const IosBarLayout(
            size: wide,
            topInset: 82,
            toolbar: Rect.fromLTWH(16, 27, 749, 44),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('A moderately long title'), findsOneWidget);
      expect(tester.getCenter(find.bySemanticsLabel('Save action')).dy, 49);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Live Activity narrows navigation without moving content or losing actions',
    (tester) async {
      await sizeView(tester, _cover);
      final semantics = tester.ensureSemantics();
      var taps = 0;
      final page = ReaderPageScaffold(
        navigationBar: CupertinoNavigationBar(
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => taps++,
            child: const Icon(CupertinoIcons.back),
          ),
          middle: const Text('News'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final icon in [
                CupertinoIcons.check_mark,
                CupertinoIcons.search,
              ])
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => taps++,
                  child: Icon(icon),
                ),
            ],
          ),
        ),
        child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
      );
      // Captured from UIKit on the Duo cover display with a real ActivityKit
      // activity. The compact status reserve starts at x=213.33 (< width/2).
      const compact = IosBarLayout(
        size: _cover,
        topInset: 82,
        toolbar: Rect.fromLTWH(2.3333333333333335, 26, 211, 44),
      );
      for (final layout in [_layout, compact, compact, _layout]) {
        await tester.pumpWidget(_host(page, layout: layout));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 82);
        for (final icon in [
          CupertinoIcons.back,
          CupertinoIcons.check_mark,
          CupertinoIcons.search,
        ]) {
          final button = find
              .ancestor(
                of: find.byIcon(icon),
                matching: find.byType(CupertinoButton),
              )
              .first;
          final frame = tester.getRect(button);
          expect(frame.center.dy, 48);
          expect(frame.width, closeTo(44, 0.00001));
          expect(frame.height, closeTo(44, 0.00001));
          expect(frame.right, lessThanOrEqualTo(layout.toolbar!.right));
          await tester.tap(button);
        }
        expect(
          find.semantics.byLabel('News'),
          layout == compact ? findsNothing : findsOne,
        );
        expect(
          find.text('News').hitTestable(),
          layout == compact ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      expect(taps, 12);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Interactive middle and keyboard avoidance survive the compact row',
    (tester) async {
      await sizeView(tester, _cover);
      int selected = 0;
      await tester.pumpWidget(
        _host(
          ReaderPageScaffold(
            keepMiddle: true,
            navigationBar: CupertinoNavigationBar(
              middle: CupertinoSlidingSegmentedControl<int>(
                groupValue: 0,
                children: const {
                  0: Icon(CupertinoIcons.doc),
                  1: Icon(CupertinoIcons.globe),
                },
                onValueChanged: (value) => selected = value!,
              ),
            ),
            child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
          ),
          keyboard: 260,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.globe));
      await tester.pumpAndSettle();
      expect(selected, 1);
      final body = tester.getRect(find.byKey(const Key('body')));
      expect(body.top, 82);
      expect(body.bottom, _cover.height - 260);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Crowded center controls move below the status row and return', (
    tester,
  ) async {
    await sizeView(tester, _cover);
    var selected = 0;
    var backTaps = 0;
    final selectorKey = GlobalKey();
    final page = ReaderPageScaffold(
      keepMiddle: true,
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => backTaps++,
          child: const Icon(CupertinoIcons.back),
        ),
        middle: CupertinoSlidingSegmentedControl<int>(
          key: selectorKey,
          groupValue: 0,
          children: const {0: Text('RSS'), 1: Text('Full'), 2: Text('Web')},
          onValueChanged: (value) => selected = value!,
        ),
      ),
      child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
    );
    Element? selector;
    for (final narrow in [true, false, true]) {
      final layout = narrow
          ? const IosBarLayout(
              size: _cover,
              topInset: 82,
              toolbar: Rect.fromLTWH(16, 26, 160, 44),
            )
          : const IosBarLayout(
              size: _cover,
              topInset: 82,
              toolbar: Rect.fromLTWH(16, 26, 434, 44),
            );
      await tester.pumpWidget(_host(page, layout: layout));
      await tester.pumpAndSettle();
      selector ??= tester.element(find.byKey(selectorKey));
      expect(tester.element(find.byKey(selectorKey)), same(selector));
      expect(
        tester.getTopLeft(find.byKey(const Key('body'))).dy,
        narrow ? 126 : 82,
      );
      expect(tester.getCenter(find.byKey(selectorKey)).dy, narrow ? 104 : 48);
      expect(tester.getCenter(find.byIcon(CupertinoIcons.back)).dy, 48);
      await tester.tap(find.text('Web'));
      await tester.tap(find.byIcon(CupertinoIcons.back));
      await tester.pumpAndSettle();
      expect(selected, 2);
      expect(tester.takeException(), isNull);
    }
    expect(backTaps, 3);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Duo headers remain borderless before and after scrolling', (
    tester,
  ) async {
    await sizeView(tester, _cover);
    final boundary = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    for (final scenario in [
      (1.0, Brightness.light),
      (3.0, Brightness.light),
      (1.0, Brightness.dark),
      (3.0, Brightness.dark),
    ]) {
      final (ratio, brightness) = scenario;
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = _cover * ratio;
      if (controller.hasClients) controller.jumpTo(0);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: _host(
            ReaderPageScaffold(
              child: CustomScrollView(
                controller: controller,
                slivers: [
                  ReaderSliverNavigationBar(
                    CupertinoSliverNavigationBar(
                      backgroundColor: CupertinoColors.systemBackground,
                      largeTitle: const Text('Feed'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: brightness == Brightness.light
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                      child: const SizedBox(height: 2000),
                    ),
                  ),
                ],
              ),
            ),
            pixelRatio: ratio,
            brightness: brightness,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final image = await tester.runAsync(
        () => render.toImage(pixelRatio: ratio),
      );
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final offset =
          (((82 * ratio).round() - 1) * image!.width + (8 * ratio).round()) * 4;
      final pixel = data!.buffer.asUint8List(offset, 4).toList();
      image.dispose();
      expect(
        pixel,
        brightness == Brightness.light ? [255, 255, 255, 255] : [0, 0, 0, 255],
      );
      expect(pixel[1], pixel[0]);
      expect(pixel[2], pixel[0]);
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Repeated fold events update the crowded header in the first frame',
    (tester) async {
      await sizeView(tester, _cover);
      final page = ReaderPageScaffold(
        keepMiddle: true,
        navigationBar: CupertinoNavigationBar(
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: const Icon(CupertinoIcons.back),
          ),
          middle: SizedBox(
            key: const Key('selector'),
            width: 180,
            height: 32,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: const Text('Mode'),
            ),
          ),
        ),
        child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
      );
      for (final partial in [false, true, false, true]) {
        await tester.pumpWidget(
          _host(
            page,
            layout: IosBarLayout(
              size: _cover,
              topInset: 82,
              toolbar: const Rect.fromLTWH(16, 26, 211, 44),
              division: partial ? const Rect.fromLTWH(225, 0, 16, 678) : null,
            ),
          ),
        );
        expect(tester.getCenter(find.byKey(const Key('selector'))).dy, 104);
        expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 126);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Sliver controls stay in the shared row while content scrolls', (
    tester,
  ) async {
    await sizeView(tester, _cover);
    var taps = 0;
    await tester.pumpWidget(
      _host(
        ReaderPageScaffold(
          child: CustomScrollView(
            slivers: [
              ReaderSliverNavigationBar(
                CupertinoSliverNavigationBar(
                  largeTitle: const Text('Feed'),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => taps++,
                    child: const Icon(CupertinoIcons.search),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: 80,
                itemBuilder: (_, i) =>
                    SizedBox(height: 60, child: Text('Article $i')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Article 0')).dy, 134);
    final expandedTitle = find.text('Feed').hitTestable();
    expect(tester.getTopLeft(expandedTitle).dy, greaterThanOrEqualTo(82));
    expect(
      DefaultTextStyle.of(tester.element(expandedTitle)).style.fontSize,
      34,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byIcon(CupertinoIcons.search)).dy,
      closeTo(_alignmentY, 0.00001),
    );
    final compactTitle = find.text('Feed').hitTestable();
    expect(
      DefaultTextStyle.of(tester.element(compactTitle)).style.fontSize,
      17,
    );
    await tester.tap(find.byIcon(CupertinoIcons.search));
    expect(taps, 1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Article 0')).dy, 134);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Window geometry is converted to the correct pane and physical edge',
    (tester) async {
      const size = Size(951, 669);
      await sizeView(tester, size);
      for (final rightCorner in [true, false]) {
        final layout = IosBarLayout(
          size: size,
          topInset: 82,
          toolbar: Rect.fromLTWH(rightCorner ? 16 : 186, 19, 749, 44),
        );
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => Row(
                children: [
                  for (final left in [0.0, 321.0])
                    SizedBox(
                      width: left == 0 ? 320 : 630,
                      child: IosBarLayoutScope.pane(
                        context,
                        bounds: Rect.fromLTWH(
                          left,
                          0,
                          left == 0 ? 320 : 630,
                          669,
                        ),
                        child: ReaderPageScaffold(
                          navigationBar: CupertinoNavigationBar(
                            middle: Text('Pane $left'),
                            leading: const Icon(CupertinoIcons.back),
                            trailing: const Icon(CupertinoIcons.search),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            size: size,
            layout: layout,
          ),
        );
        await tester.pumpAndSettle();
        final back = find.byIcon(CupertinoIcons.back);
        final search = find.byIcon(CupertinoIcons.search);
        expect(tester.getCenter(back.first).dy, 41);
        expect(tester.getCenter(search.last).dy, 41);
        if (rightCorner) {
          expect(tester.getRect(search.first).right, lessThan(320));
          expect(tester.getRect(search.last).right, lessThan(765));
        } else {
          expect(tester.getRect(back.first).left, greaterThanOrEqualTo(186));
          expect(tester.getRect(back.last).left, greaterThan(321));
        }
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final scenario in [
    'ordinary iPhone',
    'iPad',
    'Android',
    'stale fold metrics',
    'modal sheet',
  ]) {
    testWidgets(
      '$scenario retains the original Cupertino bar',
      (tester) async {
        await sizeView(tester, _cover);
        final layout = switch (scenario) {
          'ordinary iPhone' => const IosBarLayout(
            size: _cover,
            topInset: 62,
            toolbar: Rect.fromLTWH(0, 62, 466, 44),
          ),
          'iPad' => const IosBarLayout(
            size: _cover,
            topInset: 24,
            toolbar: Rect.fromLTWH(0, 24, 466, 44),
          ),
          'stale fold metrics' => const IosBarLayout(
            size: Size(951, 669),
            topInset: 82,
            toolbar: Rect.fromLTWH(16, 26, 749, 44),
          ),
          _ => _layout,
        };
        final top = scenario == 'modal sheet' ? 0.0 : layout.topInset;
        const original = CupertinoNavigationBar(middle: Text('Settings'));
        await tester.pumpWidget(
          _host(
            const ReaderPageScaffold(
              navigationBar: original,
              child: SizedBox.expand(),
            ),
            layout: layout,
            top: top,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget(find.byType(CupertinoNavigationBar)),
          same(original),
        );
        expect(
          tester.getSize(find.byType(CupertinoNavigationBar)).height,
          top + 44,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        scenario == 'Android' ? TargetPlatform.android : TargetPlatform.iOS,
      ),
    );
  }

  testWidgets('Native layout stream updates and clears when geometry changes', (
    tester,
  ) async {
    await sizeView(tester, _cover);
    const channel = 'me.hyliu.fluent_reader_lite/ios_bar_layout';
    const codec = StandardMethodCodec();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(channel),
      (_) async => null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel(channel),
        null,
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: const SizedBox(),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: _cover,
            padding: EdgeInsets.only(top: 82),
          ),
          child: IosBarLayoutProvider(
            child: ReaderPageScaffold(
              navigationBar: CupertinoNavigationBar(middle: Text('Feed')),
              child: const SafeArea(child: SizedBox.expand(key: Key('body'))),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 126);
    Future<void> send(List<double>? toolbar) async {
      await messenger.handlePlatformMessage(
        channel,
        codec.encodeSuccessEnvelope({
          'width': 466.0,
          'height': 678.0,
          'topInset': 82.0,
          'toolbar': toolbar,
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await send([16, 26, 250, 44]);
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 82);
    // A Live Activity updates only the toolbar frame, without new window or
    // safe-area metrics. It must not switch the page back to the stock bar.
    await send([2.3333333333333335, 26, 211, 44]);
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 82);
    await send(null);
    expect(tester.getTopLeft(find.byKey(const Key('body'))).dy, 126);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
