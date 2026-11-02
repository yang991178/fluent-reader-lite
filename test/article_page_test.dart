import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/article_item.dart';
import 'package:material_ui/material_ui.dart' show Divider, VerticalDivider;
import 'package:fluent_reader_lite/components/cupertino_toolbar.dart';
import 'package:fluent_reader_lite/components/reader_bar.dart';
import 'package:fluent_reader_lite/components/my_action_sheet_action.dart';
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

  testWidgets(
    'Bottom tabs and article toolbar paint visible dividers in both themes',
    (tester) async {
      const channel = MethodChannel(
        'me.hyliu.fluent_reader_lite/ios_bar_layout',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const ratio = 3.0;
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = const Size(390, 844) * ratio;
      tester.view.padding = const FakeViewPadding(
        top: 62 * ratio,
        bottom: 34 * ratio,
      );
      tester.view.viewPadding = const FakeViewPadding(
        top: 62 * ratio,
        bottom: 34 * ratio,
      );
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: MyApp()));
      await tester.pumpAndSettle();
      Future<void> checkDivider(Finder bar, bool dark) async {
        final rect = tester.getRect(bar);
        final render = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundary),
        );
        final image = await tester.runAsync(
          () => render.toImage(pixelRatio: ratio),
        );
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset =
            ((rect.top * ratio).round() * image!.width + (8 * ratio).round()) *
            4;
        final pixel = bytes!.buffer.asUint8List(offset, 4).toList();
        image.dispose();
        expect(
          pixel.take(3),
          everyElement(dark ? greaterThan(32) : lessThan(240)),
        );
        expect(pixel[3], 255);
      }

      for (final (index, theme) in [
        ThemeSetting.Light,
        ThemeSetting.Dark,
      ].indexed) {
        final dark = theme == ThemeSetting.Dark;
        Global.globalModel!.theme = theme;
        await tester.pumpAndSettle();
        await checkDivider(find.byType(CupertinoTabBar), dark);
        await tester.tap(find.text('Article 0'));
        await finishArticle(tester, platform, index + 1);
        await checkDivider(
          find.descendant(
            of: find.byType(CupertinoToolbar),
            matching: find.byType(ReaderBarBackground),
          ),
          dark,
        );
        Global.articlePanel.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final (size, top, toolbar) in [
    (const Size(390, 844), 62.0, [18.0, 62.0, 354.0, 44.0]),
    (const Size(466, 678), 82.0, [16.0, 26.0, 250.0, 44.0]),
  ]) {
    testWidgets(
      'Reduce Transparency preserves the open reader and list at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = FakeViewPadding(top: top, bottom: 34);
        tester.view.viewPadding = FakeViewPadding(top: top, bottom: 34);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
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
        Future<void> preference(bool reduced) async {
          await messenger.handlePlatformMessage(
            channel,
            const StandardMethodCodec().encodeSuccessEnvelope({
              'width': size.width,
              'height': size.height,
              'topInset': top,
              'toolbar': toolbar,
              'reduceTransparency': reduced,
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
        await tester.pumpWidget(MyApp());
        await preference(false);
        final list = PrimaryScrollController.of(
          tester.element(find.byType(ItemListPage)),
        );
        await tester.tap(find.text('Article 0'));
        await finishArticle(tester, platform, 1);
        list.jumpTo(500);
        await tester.pumpAndSettle();
        final view = find.byType(WebViewWidget);
        final element = tester.element(view);
        final frame = tester.getRect(view);
        final extent = list.position.maxScrollExtent;
        for (final reduced in [true, false, true]) {
          await preference(reduced);
          expect(platform.controllers, hasLength(1));
          expect(tester.element(view), same(element));
          expect(tester.getRect(view), frame);
          expect(list.offset, 500);
          expect(list.position.maxScrollExtent, extent);
          final article = find.byType(ArticlePage);
          final nav = tester.widget<CupertinoNavigationBar>(
            find.descendant(
              of: article,
              matching: find.byType(CupertinoNavigationBar),
            ),
          );
          expect(
            nav.backgroundColor!.a,
            top == 82 ? 0 : (reduced ? 1 : closeTo(0.8, 0.001)),
          );
          for (final bar
              in tester
                  .widgetList<ReaderBarBackground>(
                    find.descendant(
                      of: article,
                      matching: find.byType(ReaderBarBackground),
                    ),
                  )
                  .where((bar) => bar.color.a > 0)) {
            expect(bar.color.a, reduced ? 1 : closeTo(0.8, 0.001));
          }
          final filters = tester.widgetList<BackdropFilter>(
            find.descendant(of: article, matching: find.byType(BackdropFilter)),
          );
          expect(filters.any((filter) => filter.enabled), !reduced);
          final tab = tester.widget<CupertinoTabBar>(
            find.byType(CupertinoTabBar),
          );
          expect(tab.backgroundColor!.a, reduced ? 1 : closeTo(0.8, 0.001));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'Article selection and adjacent separators follow its navigation feed',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final thirdItem = Global.itemsModel!.getItem('0')!.clone()
        ..id = '2'
        ..title = 'Article 2';
      Global.itemsModel!.loadItems([thirdItem]);
      Global.feedsModel!.all.iids.add('2');
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      Finder row(String id) => find.byWidgetPredicate(
        (widget) => widget is ArticleItem && widget.item.id == id,
      );
      bool selected(String id) => tester
          .widget<Semantics>(
            find.descendant(
              of: row(id),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.selected != null,
              ),
            ),
          )
          .properties
          .selected!;
      Finder separator(String id) =>
          find.descendant(of: row(id), matching: find.byType(Divider));

      expect(selected('0'), isFalse);
      expect(selected('1'), isFalse);
      final thirdRowRect = tester.getRect(row('2'));
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      expect(selected('0'), isTrue);
      expect(selected('1'), isFalse);
      expect(separator('0'), findsNothing);
      expect(separator('1'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(S.current.next));
      await finishArticle(tester, platform, 2);
      expect(selected('0'), isFalse);
      expect(selected('1'), isTrue);
      expect(separator('0'), findsNothing);
      expect(separator('1'), findsNothing);
      expect(separator('2'), findsOneWidget);
      expect(tester.getRect(row('2')), thirdRowRect);

      // Keep the article open while showing a feed that excludes it. Selection
      // must not transfer to the row at the same index in the new feed.
      Global.feedsModel!.source = RSSFeed(sids: {'fixture'})
        ..iids = ['0']
        ..initialized = true
        ..allLoaded = true;
      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();
      final subscriptions = tester.element(find.byType(SubscriptionListPage));
      Navigator.of(subscriptions).pushNamed('/feed', arguments: 'Subset');
      await tester.pumpAndSettle();
      expect(ArticlePage.state.currentState!.iid, '1');
      expect(row('1'), findsNothing);
      expect(selected('0'), isFalse);
      expect(separator('0'), findsOneWidget);

      // Membership alone must not select an article opened from another feed.
      Global.feedsModel!.source!.iids = ['1', '0'];
      Global.feedsModel!.broadcast();
      await tester.pumpAndSettle();
      expect(selected('1'), isFalse);
      expect(separator('1'), findsOneWidget);
      expect(separator('0'), findsOneWidget);

      // Previous/Next still use the original all-articles feed, which includes
      // an article that is absent from this source feed.
      await tester.tap(find.bySemanticsLabel(S.current.next));
      await finishArticle(tester, platform, 3);
      expect(ArticlePage.state.currentState!.iid, '2');
      expect(selected('1'), isFalse);
      await tester.tap(find.bySemanticsLabel(S.current.prev));
      await finishArticle(tester, platform, 4);
      expect(ArticlePage.state.currentState!.iid, '1');
      expect(selected('1'), isFalse);

      // Reopening the same article from this list transfers its navigation
      // feed and must publish the new selection even though its ID is unchanged.
      await tester.tap(find.text('Article 1'));
      await finishArticle(tester, platform, 5);
      expect(selected('1'), isTrue);
      expect(selected('0'), isFalse);
      expect(separator('1'), findsNothing);
      expect(separator('0'), findsOneWidget);

      // A new source/group feed must not inherit the previous feed's highlight
      // or change the reader's Previous/Next order.
      final previousFeed = Global.feedsModel!.source!;
      Global.feedsModel!.source = RSSFeed(sids: {'fixture'})
        ..iids = ['0', '1']
        ..initialized = true
        ..allLoaded = true;
      Global.feedsModel!.broadcast();
      await tester.pumpAndSettle();
      expect(ArticlePage.selection.value!.feed, same(previousFeed));
      expect(selected('1'), isFalse);
      expect(separator('1'), findsOneWidget);
      expect(separator('0'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(S.current.next));
      await finishArticle(tester, platform, 6);
      expect(ArticlePage.state.currentState!.iid, '0');
      expect(selected('0'), isFalse);
      await tester.tap(find.text('Article 1'));
      await finishArticle(tester, platform, 7);
      expect(selected('1'), isTrue);
      expect(separator('0'), findsNothing);
      expect(separator('1'), findsNothing);

      await tester.tap(find.text(S.current.feed));
      await tester.pumpAndSettle();
      expect(selected('1'), isFalse);
      expect(separator('0'), findsOneWidget);
      expect(separator('1'), findsOneWidget);
      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();
      expect(selected('1'), isTrue);

      for (final theme in [ThemeSetting.Light, ThemeSetting.Dark]) {
        Global.globalModel!.theme = theme;
        await tester.pumpAndSettle();
        final context = tester.element(row('1'));
        final selectionColor = CupertinoColors.systemGrey5.resolveFrom(context);
        final background = find.descendant(
          of: row('1'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == selectionColor,
          ),
        );
        expect(tester.getRect(background), tester.getRect(row('1')));
        expect(selected('1'), isTrue);
      }

      Global.articlePanel.currentState!.pop();
      await tester.pumpAndSettle();
      expect(ArticlePage.selection.value, isNull);
      expect(selected('1'), isFalse);
      expect(selected('0'), isFalse);
      expect(separator('0'), findsOneWidget);
      expect(separator('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    'Tablet sidebar widens at 1160 points without replacing its pages',
    (tester) async {
      tester.view.physicalSize = const Size(1159, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      final listState = tester.state(find.byType(ItemListPage));
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      final articleState = ArticlePage.state.currentState!;
      final webView = tester.element(find.byType(WebViewWidget));
      for (final width in [1159.0, 1160.0, 1200.0, 1159.0, 1024.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        final sidebarWidth = width >= 1160 ? 375.0 : 320.0;
        expect(tester.getSize(find.byType(ItemListPage)).width, sidebarWidth);
        expect(
          tester.getRect(find.byType(ArticlePage)),
          Rect.fromLTWH(sidebarWidth + 1, 0, width - sidebarWidth - 1, 844),
        );
        expect(tester.state(find.byType(ItemListPage)), same(listState));
        expect(ArticlePage.state.currentState, same(articleState));
        expect(tester.element(find.byType(WebViewWidget)), same(webView));
        expect(platform.controllers, hasLength(1));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Focus mode starts with the list and retains its empty reader layout',
    (tester) async {
      await Store.sp.setBool(StoreKeys.ARTICLE_FOCUS_MODE, true);
      tester.view.physicalSize = const Size(1024, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      final list = find.byType(ItemListPage);
      final base = find.byType(TabletBasePage);
      final listState = tester.state(list);
      void expectCenteredLogo() {
        final logo = find.descendant(of: base, matching: find.byType(Image));
        expect(tester.getCenter(logo).dy, tester.getCenter(base).dy);
      }

      void expectEmptyFocus() {
        expect(find.byType(ArticlePage), findsNothing);
        expect(tester.getSize(list).width, 375);
        expect(tester.getTopLeft(list).dx, 0);
        expect(tester.getRect(base), const Rect.fromLTWH(376, 0, 1024, 844));
        expectCenteredLogo();
      }

      expectEmptyFocus();

      // The placeholder has both controls when the list is hidden, and Back
      // reveals the list without leaving the app.
      await tester.tap(find.bySemanticsLabel(S.current.showArticle));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(base), Offset.zero);
      expect(find.bySemanticsLabel(S.current.showArticleList), findsOneWidget);
      expect(find.bySemanticsLabel(S.current.exitFocusMode), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectEmptyFocus();

      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      expect(
        tester.getRect(find.byType(ArticlePage)),
        const Rect.fromLTWH(0, 0, 1024, 844),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expectEmptyFocus();
      expect(tester.state(list), same(listState));

      await tester.tap(find.bySemanticsLabel(S.current.showArticle));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(S.current.exitFocusMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(list).width, 320);
      expect(tester.getRect(base), const Rect.fromLTWH(321, 0, 703, 844));
      expectCenteredLogo();
      expect(find.bySemanticsLabel(S.current.showArticleList), findsNothing);
      await tester.tap(find.bySemanticsLabel(S.current.enterFocusMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(list).width, 375);
      expect(tester.getTopLeft(list).dx, -376);
      expect(tester.getRect(base), const Rect.fromLTWH(0, 0, 1024, 844));
      expectCenteredLogo();

      // Entering focus hides the list, but startup still reveals it. Folding
      // keeps the ordinary phone list and unfolding restores the placeholder.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      expectEmptyFocus();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.getSize(list).width, 390);
      expect(base, findsNothing);
      expect(find.bySemanticsLabel(S.current.exitFocusMode), findsNothing);
      tester.view.physicalSize = const Size(1024, 844);
      await tester.pumpAndSettle();
      expectEmptyFocus();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Article actions use pane width and sharing anchors to the moved button',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      final webView = tester.element(find.byType(WebViewWidget));
      Finder button(IconData icon) => find.ancestor(
        of: find.descendant(
          of: find.byType(CupertinoToolbar),
          matching: find.byIcon(icon),
        ),
        matching: find.byType(CupertinoButton),
      );
      final buttons = [
        button(CupertinoIcons.circle),
        button(CupertinoIcons.star),
        button(CupertinoIcons.share),
        button(CupertinoIcons.chevron_up),
        button(CupertinoIcons.chevron_down),
      ];

      for (final focused in [false, true]) {
        if (focused) {
          await tester.tap(find.bySemanticsLabel(S.current.enterFocusMode));
          await tester.pumpAndSettle();
        }
        // Include both sides of the pane breakpoint: a 961-wide window has
        // a 640-wide article in split view, while 962 gives it 641 points.
        for (final width in [
          1024.0,
          951.0,
          961.0,
          962.0,
          641.0,
          640.0,
          390.0,
          1024.0,
        ]) {
          tester.view.physicalSize = Size(width, 844);
          await tester.pumpAndSettle();
          final pane = tester.getRect(find.byType(ArticlePage));
          final rects = buttons.map(tester.getRect).toList();
          for (final rect in rects) {
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
          }
          final gaps = List.generate(
            4,
            (i) => rects[i + 1].left - rects[i].right,
          );
          if (pane.width > 640) {
            expect(rects.first.left, pane.left + 16);
            expect(rects.last.right, pane.right - 16);
            expect(gaps[0], 8);
            expect(gaps[1], 8);
            expect(gaps[3], 8);
            expect(gaps[2], greaterThan(8));
          } else {
            for (final gap in gaps) {
              expect(gap, closeTo(gaps.first, 0.001));
            }
          }
          if (width == 1024 || width == 641) {
            await tester.tap(buttons[2]);
            await tester.pump();
            final args = calls.last.arguments as Map;
            expect(args['originX'], rects[2].left);
            expect(args['originY'], rects[2].top);
            expect(args['originWidth'], rects[2].width);
            expect(args['originHeight'], rects[2].height);
          }
          expect(tester.element(find.byType(WebViewWidget)), same(webView));
          expect(platform.controllers, hasLength(1));
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Focus mode reveals the list and returns to the same reader',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      final listState = tester.state(find.byType(ItemListPage));
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      await tester.pumpAndSettle();
      final reader = ArticlePage.state.currentState!;
      final webView = tester.element(find.byType(WebViewWidget));

      await tester.tap(find.bySemanticsLabel(S.current.enterFocusMode));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(ArticlePage)),
        const Rect.fromLTWH(0, 0, 1024, 768),
      );
      expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);
      expect(Store.sp.getBool(StoreKeys.ARTICLE_FOCUS_MODE), isTrue);
      expect(tester.getTopLeft(find.byType(ItemListPage)).dx, -376);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Article 1')), findsNothing);
      semantics.dispose();

      await tester.tap(find.bySemanticsLabel(S.current.showArticleList));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(ArticlePage)),
        const Rect.fromLTWH(376, 0, 1024, 768),
      );
      expect(tester.state(find.byType(ItemListPage)), same(listState));
      expect(tester.getTopLeft(find.byType(ItemListPage)), Offset.zero);
      expect(tester.element(find.byType(WebViewWidget)), same(webView));

      // The first tap over a reader control only dismisses the list.
      final nextButton = tester.getCenter(
        find.byIcon(CupertinoIcons.chevron_down),
      );
      await tester.tapAt(Offset(nextButton.dx.clamp(377, 1000), nextButton.dy));
      await tester.pumpAndSettle();
      expect(reader.iid, '0');
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
      expect(tester.element(find.byType(WebViewWidget)), same(webView));
      expect(platform.controllers, hasLength(1));

      await tester.tap(find.bySemanticsLabel(S.current.showArticleList));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article 1'));
      await finishArticle(tester, platform, 2);
      expect(reader.iid, '1');
      expect(ArticlePage.state.currentState, same(reader));
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);

      await tester.tap(find.bySemanticsLabel(S.current.exitFocusMode));
      await tester.pumpAndSettle();
      expect(Store.sp.getBool(StoreKeys.ARTICLE_FOCUS_MODE), isFalse);
      expect(
        tester.getRect(find.byType(ArticlePage)),
        const Rect.fromLTWH(321, 0, 703, 768),
      );
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      expect(tester.state(find.byType(ItemListPage)), same(listState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Saved focus mode supports edge drags, system Back and folded screens',
    (tester) async {
      await Store.sp.setBool(StoreKeys.ARTICLE_FOCUS_MODE, true);
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Article 0'));
      await finishArticle(tester, platform, 1);
      final reader = ArticlePage.state.currentState!;
      final webView = tester.element(find.byType(WebViewWidget));
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
      final controller = platform.controllers.single;
      await tester.tapAt(const Offset(600, 300));
      expect(controller.pointerDowns, 1);

      // A short, slow drag settles closed; the reader follows the finger.
      var gesture = await tester.startGesture(const Offset(4, 300));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 400));
      final left = tester.getTopLeft(find.byType(ArticlePage)).dx;
      expect(left, greaterThan(0));
      expect(left, lessThan(160));
      expect(tester.getTopLeft(find.byType(ItemListPage)).dx, left - 376);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);

      gesture = await tester.startGesture(const Offset(4, 300));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);

      await tester.dragFrom(const Offset(4, 300), const Offset(290, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)).dx, 376);
      gesture = await tester.startGesture(const Offset(600, 300));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-400, 0));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
      expect(ArticlePage.state.currentState, same(reader));
      expect(tester.element(find.byType(WebViewWidget)), same(webView));
      expect(
        controller.pointerDowns,
        1,
        reason: 'Pane gestures must not also reach the native WebView',
      );

      // Folding restores phone navigation, while unfolding restores focus.
      for (final width in [640.0, 641.0, 390.0, 1024.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(ArticlePage)).width, width);
        expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
        expect(
          find.bySemanticsLabel(S.current.exitFocusMode),
          width > 640 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(CupertinoNavigationBarBackButton),
          width > 640 ? findsNothing : findsOneWidget,
        );
        expect(tester.element(find.byType(WebViewWidget)), same(webView));
        expect(platform.controllers, hasLength(1));
        expect(tester.takeException(), isNull);
      }

      // Back first reveals the list, then closes the article. Opening another
      // article from that list must start focused again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)).dx, 376);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      await tester.tap(find.text('Article 1'));
      await finishArticle(tester, platform, 2);
      expect(tester.getTopLeft(find.byType(ArticlePage)), Offset.zero);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      expect(Store.sp.getBool(StoreKeys.ARTICLE_FOCUS_MODE), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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
        expect(
          MediaQuery.paddingOf(tester.element(find.byType(WebViewWidget))).top,
          greaterThan(0),
        );
        expect(
          MediaQuery.paddingOf(tester.element(find.byType(WebViewWidget)))
              .bottom,
          greaterThan(0),
        );
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
      await updateLayout(const Size(1160, 700), partiallyOpen: true);
      expect(tester.getSize(find.byType(ItemListPage).first).width, 579.5);
      expect(tester.getSize(find.byType(ArticlePage)).width, 579.5);
      await updateLayout(
        const Size(669, 951),
        partiallyOpen: true,
        liveActivity: true,
      );
      expect(tester.getSize(find.byType(ItemListPage).first).width, 320);
      final selector = find.byType(CupertinoSlidingSegmentedControl<int>);
      expect(tester.getCenter(selector).dy, 104);
      // The WebView paints under the blurred header, while native content and
      // indicator insets retain the original unobscured reading origin.
      final webViewPadding = MediaQuery.paddingOf(
        tester.element(find.byType(WebViewWidget)),
      );
      expect(
        tester.getTopLeft(find.byType(WebViewWidget)).dy + webViewPadding.top,
        greaterThanOrEqualTo(126),
      );
      expect(tester.element(find.byType(WebViewWidget)), same(webView));
      expect(platform.controllers, hasLength(1));
      expect(tester.takeException(), isNull);
      // Both edge buttons must remain usable when a Live Activity leaves
      // insufficient room for them in the shared status row.
      await tester.tap(find.bySemanticsLabel(S.current.enterFocusMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ArticlePage)).width, 669);
      await updateLayout(const Size(951, 669), partiallyOpen: true);
      expect(tester.getSize(find.byType(ItemListPage).first).width, 475);
      expect(tester.getSize(find.byType(ArticlePage)).width, 951);
      await updateLayout(const Size(1160, 700), partiallyOpen: true);
      expect(tester.getSize(find.byType(ItemListPage).first).width, 579.5);
      expect(tester.getSize(find.byType(ArticlePage)).width, 1160);
      await updateLayout(const Size(669, 951), liveActivity: true);

      Rect relativeTo(Finder child, Finder page) =>
          tester.getRect(child).shift(-tester.getTopLeft(page));
      final article = find.byType(ArticlePage);
      final list = find.byType(ItemListPage).first;
      final selectorBounds = relativeTo(selector, article);
      final contentBounds = relativeTo(find.byType(WebViewWidget), article);
      final listItemBounds = relativeTo(find.text('Article 0'), list);
      final listSize = tester.getSize(list);
      void expectPannedPages() {
        final articleLeft = tester.getTopLeft(article).dx;
        expect(tester.getTopLeft(list).dx, articleLeft - 376);
        expect(tester.getSize(article), const Size(669, 951));
        expect(tester.getSize(list), listSize);
        expect(relativeTo(selector, article), selectorBounds);
        expect(relativeTo(find.byType(WebViewWidget), article), contentBounds);
        expect(relativeTo(find.text('Article 0'), list), listItemBounds);
      }

      // Panning must only translate the pages, including their headers and
      // bodies, without adapting the toolbar to the partly visible area.
      final pan = await tester.startGesture(const Offset(4, 300));
      await pan.moveBy(const Offset(40, 0));
      await tester.pump();
      await pan.moveBy(const Offset(100, 0));
      await tester.pump();
      expectPannedPages();
      await pan.cancel();
      await tester.pumpAndSettle();
      expectPannedPages();
      await tester.tap(find.bySemanticsLabel(S.current.showArticleList));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ArticlePage)).dx, 376);
      expectPannedPages();
      await tester.tapAt(const Offset(600, 300));
      await tester.pumpAndSettle();
      expectPannedPages();
      await tester.tap(find.bySemanticsLabel(S.current.exitFocusMode));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(WebViewWidget)), same(webView));
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ArticlePage), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'List action sheets track pane widths through focus, resize and folds',
    (tester) async {
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
      tester.view.physicalSize = const Size(1024, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      void expectSheetWidth() {
        final pane = tester.getRect(find.byType(ItemListPage));
        final sheet = tester.getRect(find.byType(CupertinoActionSheet));
        expect(sheet.left, pane.left);
        expect(sheet.width, pane.width);
        // Keep Cupertino's normal eight-point sheet margins within the pane.
        final action = find
            .descendant(
              of: find.byType(CupertinoActionSheet),
              matching: find.byType(MyActionSheetAction),
            )
            .first;
        expect(tester.getSize(action).width, pane.width - 16);
        expect(tester.takeException(), isNull);
      }

      Future<void> resize(double width) async {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        expectSheetWidth();
      }

      for (final label in [S.current.filter, S.current.markAll]) {
        await tester.tap(
          find.byIcon(
            label == S.current.filter
                ? CupertinoIcons.line_horizontal_3_decrease_circle
                : CupertinoIcons.checkmark_circle,
          ),
        );
        await tester.pumpAndSettle();
        expectSheetWidth();
        await resize(1160);
        await resize(1024);
        await tester.tap(find.text(S.current.cancel));
        await tester.pumpAndSettle();
        expect(find.byType(CupertinoActionSheet), findsNothing);
      }

      await tester.tap(find.bySemanticsLabel(S.current.enterFocusMode));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(S.current.showArticleList));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byIcon(CupertinoIcons.line_horizontal_3_decrease_circle),
      );
      await tester.pumpAndSettle();
      expectSheetWidth();
      await resize(390);
      await resize(1024);
      await resize(1160);
      await messenger.handlePlatformMessage(
        channel,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'width': 1160.0,
          'height': 844.0,
          'topInset': 0.0,
          'division': [579.0, 0.0, 2.0, 844.0],
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
      expectSheetWidth();
      expect(tester.getSize(find.byType(CupertinoActionSheet)).width, 579.5);
      await tester.tap(find.text(S.current.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);

      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.checkmark_circle));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CupertinoActionSheet)).width,
        tester.getSize(find.byType(SubscriptionListPage)).width,
      );
      await tester.tap(find.text(S.current.cancel));
      await tester.pumpAndSettle();
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
  int pointerDowns = 0;
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
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => controller.pointerDowns += 1,
      child: const SizedBox.expand(),
    );
  }
}
