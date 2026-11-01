import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show VerticalDivider;
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/feed.dart';
import 'package:fluent_reader_lite/models/global_model.dart';
import 'package:fluent_reader_lite/pages/article_page.dart';
import 'package:fluent_reader_lite/pages/home_page.dart';
import 'package:fluent_reader_lite/pages/item_list_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/reader_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestWebViewPlatform platform;

  setUp(() async {
    // Cached asset futures must not cross widget tests' FakeAsync zones.
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
    Store.sp = await SharedPreferences.getInstance();
    initializeReaderFixture();
    platform = _TestWebViewPlatform();
    WebViewPlatform.instance = platform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
  });

  tearDown(() {
    Global.globalModel!.dispose();
    Global.sourcesModel!.dispose();
    Global.itemsModel!.dispose();
    Global.feedsModel!.dispose();
    Global.groupsModel!.dispose();
    Global.syncModel!.dispose();
  });

  testWidgets('Idle article pane does not dim the phone list in light mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Global.globalModel!.theme = ThemeSetting.Light;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: MyApp()));
    await tester.pumpAndSettle();

    Future<void> expectWhiteList(String reason) async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage());
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      // Sample empty list space, away from text and navigation bars, from
      // the composited frame so an overlay above the list is included.
      final offset = (600 * image!.width + 20) * 4;
      final pixel = bytes!.buffer.asUint8List(offset, 4).toList();
      image.dispose();
      expect(pixel, [255, 255, 255, 255], reason: reason);
    }

    await expectWhiteList('initial phone layout');
    await tester.tap(find.text('Article 0'));
    await finishArticle(tester, platform, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await expectWhiteList('after closing an article');
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    await expectWhiteList('after returning from tablet layout');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final initialWidth in [390.0, 1024.0]) {
    testWidgets('Open article survives width changes from $initialWidth', (
      tester,
    ) async {
      tester.view.physicalSize = Size(initialWidth, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      final listState = tester.state(find.byType(ItemListPage));
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      final articleState = ArticlePage.state.currentState!;

      // Change the selection before resizing so stale route arguments cannot
      // silently restore the first article.
      await tester.tap(find.bySemanticsLabel(S.current.next));
      await finishArticle(tester, platform, 2);
      final controller = platform.controllers.last;
      final currentWebView = tester.element(find.byType(WebViewWidget));
      for (final width in [1024.0, 640.0, 641.0, 390.0, 1024.0, 390.0]) {
        tester.view.physicalSize = Size(width, width > 640 ? 590 : 844);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(ArticlePage.state.currentState, same(articleState));
        expect(articleState.iid, '1');
        expect(platform.controllers, hasLength(2));
        expect(platform.controllers.last, same(controller));
        expect(
          tester.element(find.byType(WebViewWidget)),
          same(currentWebView),
        );
        final bounds = tester.getRect(find.byType(ArticlePage));
        expect(bounds.left, width > 640 ? 321 : 0);
        expect(bounds.width, width > 640 ? width - 321 : width);
        expect(
          tester.state(find.byType(ItemListPage, skipOffstage: false)),
          same(listState),
        );
        expect(tester.takeException(), isNull);
      }

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      expect(find.text('Article 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Duo shared status row preserves the reader across folds and rotations',
    (tester) async {
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
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 82, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 82, bottom: 34);
      tester.view.physicalSize = const Size(466, 678);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      Future<void> updateLayout(
        Size size, {
        bool partiallyOpen = false,
        bool liveActivity = false,
      }) async {
        tester.view.physicalSize = size;
        await messenger.handlePlatformMessage(
          channel,
          codec.encodeSuccessEnvelope({
            'width': size.width,
            'height': size.height,
            'topInset': 82.0,
            'toolbar': [
              16.0,
              26.0,
              size.width - (liveActivity ? 300 : 172),
              44.0,
            ],
            'division': partiallyOpen
                ? [size.width / 2 - 8, 0.0, 16.0, size.height]
                : null,
          }),
          (_) {},
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await updateLayout(const Size(466, 678));
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      final articleState = ArticlePage.state.currentState!;
      final webView = tester.element(find.byType(WebViewWidget));
      for (final size in [
        const Size(951, 669),
        const Size(669, 951),
        const Size(466, 678),
      ]) {
        await updateLayout(size);
        expect(ArticlePage.state.currentState, same(articleState));
        expect(tester.element(find.byType(WebViewWidget)), same(webView));
        expect(platform.controllers, hasLength(1));
        for (final label in [
          S.current.rssText,
          S.current.loadFull,
          S.current.loadWebpage,
        ]) {
          final control = find.bySemanticsLabel(label);
          final bounds = tester.getRect(control);
          final portraitPane = size == const Size(669, 951);
          expect(bounds.center.dy, portraitPane ? 104 : 48);
          expect(
            bounds.right,
            lessThanOrEqualTo(size.width - (portraitPane ? 16 : 156)),
          );
        }
        expect(tester.takeException(), isNull);
      }
      for (final partiallyOpen in [true, false, true]) {
        await updateLayout(const Size(951, 669), partiallyOpen: partiallyOpen);
        final divider = tester.getRect(find.byType(VerticalDivider));
        final sidebar = tester.getSize(find.byType(ItemListPage).first);
        expect(sidebar.width, partiallyOpen ? 475 : 320);
        expect(divider.left, sidebar.width);
        expect(
          tester.getSize(find.byType(ArticlePage)).width,
          partiallyOpen ? 475 : 630,
        );
        expect(ArticlePage.state.currentState, same(articleState));
        expect(tester.element(find.byType(WebViewWidget)), same(webView));
        expect(platform.controllers, hasLength(1));
      }
      await updateLayout(
        const Size(669, 951),
        partiallyOpen: true,
        liveActivity: true,
      );
      expect(tester.getSize(find.byType(ItemListPage).first).width, 320);
      final selector = find.byType(CupertinoSlidingSegmentedControl<int>);
      expect(tester.getCenter(selector).dy, 104);
      expect(
        tester.getTopLeft(find.byType(WebViewWidget)).dy,
        greaterThanOrEqualTo(126),
      );
      expect(tester.element(find.byType(WebViewWidget)), same(webView));
      expect(platform.controllers, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Duo toolbar taps preserve feed offsets and tab scroll-to-top', (
    tester,
  ) async {
    const channel = 'me.hyliu.fluent_reader_lite/ios_bar_layout';
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
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    Future<void> geometry({bool duo = true}) async {
      final size = duo ? const Size(466, 678) : const Size(390, 844);
      final top = duo ? 82.0 : 62.0;
      tester.view.physicalSize = size;
      tester.view.padding = FakeViewPadding(top: top, bottom: 34);
      tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
      await messenger.handlePlatformMessage(
        channel,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'width': size.width,
          'height': size.height,
          'topInset': top,
          'toolbar': duo ? [16.0, 26.0, 250.0, 44.0] : [0.0, 62.0, 390.0, 44.0],
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    final template = Global.itemsModel!.getItem('0')!;
    final items = List.generate(
      30,
      (index) => template.clone()
        ..id = '$index'
        ..title = 'Article $index',
    );
    Global.itemsModel!.loadItems(items);
    Global.feedsModel!.all.iids = items.map((item) => item.id).toList();
    tester.view.physicalSize = const Size(466, 678);
    tester.view.padding = const FakeViewPadding(top: 82, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 82, bottom: 34);
    await tester.pumpWidget(MyApp());
    await geometry();
    final list = tester.element(find.byType(ItemListPage));
    final controller = PrimaryScrollController.of(list);
    Future<void> checkActions(ScrollController controller) async {
      for (final label in [S.current.filter, S.current.markAll]) {
        controller.jumpTo(500);
        await tester.pump();
        // iOS can deliver the locationless status-bar event before the button
        // tap opens its modal; the scrolling animation must never start.
        tester.simulateStatusBarTap();
        await tester.tap(
          find.byIcon(
            label == S.current.filter
                ? CupertinoIcons.line_horizontal_3_decrease_circle
                : CupertinoIcons.checkmark_circle,
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.offset, 500);
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
        Navigator.of(
          tester.element(find.byType(CupertinoActionSheet)),
          rootNavigator: true,
        ).pop();
        await tester.pumpAndSettle();
        expect(controller.offset, 500);
      }
    }

    await checkActions(controller);
    await tester.tap(find.text(S.current.feed));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    await tester.tap(find.text(S.current.subscriptions));
    await tester.pumpAndSettle();
    Global.feedsModel!.source = RSSFeed(sids: {'fixture'})
      ..iids = items.map((item) => item.id).toList()
      ..initialized = true
      ..allLoaded = true;
    final subscriptions = tester.element(find.byType(SubscriptionListPage));
    Navigator.of(subscriptions).pushNamed('/feed', arguments: 'Test source');
    await tester.pumpAndSettle();
    final sourceList = tester.element(find.byType(ItemListPage));
    final sourceController = PrimaryScrollController.of(sourceList);
    await checkActions(sourceController);
    await tester.tap(find.text(S.current.subscriptions));
    await tester.pumpAndSettle();
    expect(sourceController.offset, 0);
    Navigator.of(sourceList).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.feed));
    await tester.pumpAndSettle();

    controller.jumpTo(500);
    await tester.pump();
    await geometry(duo: false);
    expect(
      PrimaryScrollController.of(tester.element(find.byType(ItemListPage))),
      same(controller),
    );
    expect(controller.offset, 500);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'Tablet status-bar taps preserve the list with and without articles',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final template = Global.itemsModel!.getItem('0')!;
      final items = List.generate(
        30,
        (index) => template.clone()
          ..id = '$index'
          ..title = 'Article $index',
      );
      Global.itemsModel!.loadItems(items);
      Global.feedsModel!.all.iids = items.map((item) => item.id).toList();
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      final list = tester.element(find.byType(ItemListPage));
      final controller = PrimaryScrollController.of(list);
      controller.jumpTo(500);
      await tester.pump();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controller.offset, 500);
      controller.jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      controller.jumpTo(500);
      await tester.pump();

      tester.simulateStatusBarTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.offset, 500);

      // The sidebar's explicit scroll-to-top action still works.
      await tester.tap(find.text(S.current.feed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.offset, 0);

      controller.jumpTo(500);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      tester.simulateStatusBarTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.offset, 500);
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pump();
      expect(PrimaryScrollController.of(list), same(controller));
      expect(platform.controllers, hasLength(1));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controller.offset, 500);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Source feed and Back navigation survive article resizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Global.globalModel!.locale = const Locale('zh');
    Global.feedsModel!.source = RSSFeed(sids: {'fixture'})
      ..iids = ['1', '0']
      ..initialized = true
      ..allLoaded = true;
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    final homeRoute = ModalRoute.of(tester.element(find.byType(HomePage)))!;
    expect(homeRoute.popDisposition, RoutePopDisposition.bubble);
    await tester.tap(find.text(S.current.subscriptions));
    await tester.pumpAndSettle();
    final subscriptions = tester.element(find.byType(SubscriptionListPage));
    // Seed the source feed without a database, then use the normal feed route.
    Navigator.of(subscriptions).pushNamed('/feed', arguments: 'RSS');
    await tester.pumpAndSettle();
    expect(homeRoute.popDisposition, RoutePopDisposition.doNotPop);
    final sourceList = tester.state(find.byType(ItemListPage));
    await tester.tap(find.text('Article 1'));
    await finishArticle(tester, platform, 1);
    final articleState = ArticlePage.state.currentState!;

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(ArticlePage.state.currentState, same(articleState));
    expect(articleState.isSourceFeed, isTrue);
    await tester.tap(find.bySemanticsLabel(S.current.next));
    await finishArticle(tester, platform, 2);
    expect(articleState.iid, '0');

    tester.view.physicalSize = const Size(1024, 768);
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(ArticlePage),
        matching: find.byType(CupertinoNavigationBarBackButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArticlePage), findsNothing);
    expect(find.byType(TabletBasePage), findsOneWidget);
    expect(tester.state(find.byType(ItemListPage)), same(sourceList));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ItemListPage)), same(sourceList));
    await tester.tap(find.text('Article 0'));
    await finishArticle(tester, platform, 3);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ArticlePage), findsNothing);
    expect(tester.state(find.byType(ItemListPage)), same(sourceList));
    expect(Navigator.of(subscriptions).canPop(), isTrue);

    // An inactive tab's source feed must not keep the app handling Back.
    await tester.tap(find.text(S.current.feed));
    await tester.pumpAndSettle();
    expect(homeRoute.popDisposition, RoutePopDisposition.bubble);
    expect(Navigator.of(subscriptions).canPop(), isTrue);
    await tester.tap(find.text(S.current.subscriptions));
    await tester.pumpAndSettle();
    expect(homeRoute.popDisposition, RoutePopDisposition.doNotPop);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionListPage), findsOneWidget);
    expect(find.byType(ItemListPage), findsNothing);
    expect(homeRoute.popDisposition, RoutePopDisposition.bubble);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Article canvas stays themed on open, next, previous and retry',
    (tester) async {
      final nativeBackground = defaultTargetPlatform != TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      Global.globalModel!.theme = ThemeSetting.Dark;
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article 0'));

      Future<_TestController> finishArticle(int count, String status) async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          if (platform.controllers.length == count &&
              platform.controllers.last.document != null)
            break;
        }
        expect(platform.controllers, hasLength(count));
        final controller = platform.controllers.last;
        expect(controller.document, contains('class="dark"'));
        expect(
          controller.backgroundAtLoad,
          nativeBackground ? CupertinoColors.black : null,
        );
        controller.status!.onMessageReceived(
          JavaScriptMessage(message: status),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        return controller;
      }

      await finishArticle(1, 'success');
      await tester.tap(find.bySemanticsLabel(S.current.next));
      await finishArticle(2, 'success');
      await tester.tap(find.bySemanticsLabel(S.current.prev));
      await finishArticle(3, 'failure');
      await tester.tap(find.text(S.current.retry));
      final controller = await finishArticle(4, 'success');

      Global.globalModel!.theme = ThemeSetting.Light;
      await tester.pump();
      expect(
        controller.background,
        nativeBackground ? CupertinoColors.white : null,
      );
      expect(controller.scripts.last, contains('setArticleTheme(1)'));
      expect(platform.controllers, hasLength(4));

      Global.globalModel!.theme = ThemeSetting.Default;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      expect(
        controller.background,
        nativeBackground ? CupertinoColors.black : null,
      );
      expect(controller.scripts.last, contains('setArticleTheme(0)'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}

Future<void> finishArticle(
  WidgetTester tester,
  _TestWebViewPlatform platform,
  int count,
) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (platform.controllers.length == count &&
        platform.controllers.last.document != null)
      break;
  }
  expect(platform.controllers, hasLength(count));
  platform.controllers.last.status!.onMessageReceived(
    JavaScriptMessage(message: 'success'),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

class _TestWebViewPlatform extends WebViewPlatform {
  final controllers = <_TestController>[];

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _TestController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _TestNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _TestWebViewWidget(params);
}

class _TestController extends PlatformWebViewController {
  _TestController(super.params) : super.implementation();
  Color? background;
  Color? backgroundAtLoad;
  String? document;
  JavaScriptChannelParams? status;
  final scripts = <String>[];

  @override
  Future<void> setBackgroundColor(Color color) async => background = color;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    status = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate delegate,
  ) async {}

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    backgroundAtLoad = background;
    document = html;
  }

  @override
  Future<void> runJavaScript(String script) async => scripts.add(script);
}

class _TestNavigationDelegate extends PlatformNavigationDelegate {
  _TestNavigationDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class _TestWebViewWidget extends PlatformWebViewWidget {
  _TestWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) {
    final controller = params.controller as _TestController;
    expect(
      controller.background,
      defaultTargetPlatform == TargetPlatform.iOS ? isNull : isNotNull,
      reason:
          'Keep iOS opaque; configure other native canvases before attaching',
    );
    return const SizedBox.expand();
  }
}
