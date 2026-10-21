import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/global_model.dart';
import 'package:fluent_reader_lite/pages/item_list_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/reader_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _TestWebViewPlatform platform;

  setUp(() async {
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

  testWidgets('Article canvas stays themed on open, next, previous and retry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    Global.globalModel!.theme = ThemeSetting.Dark;
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ItemListPage));
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/article', arguments: const Tuple2('0', false));

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
      expect(controller.backgroundAtLoad, CupertinoColors.black);
      controller.status!.onMessageReceived(JavaScriptMessage(message: status));
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
    expect(controller.background, CupertinoColors.white);
    expect(controller.scripts.last, contains('setArticleTheme(1)'));
    expect(platform.controllers, hasLength(4));

    Global.globalModel!.theme = ThemeSetting.Default;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(controller.background, CupertinoColors.black);
    expect(controller.scripts.last, contains('setArticleTheme(0)'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
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
      isNotNull,
      reason: 'Set the native canvas color before attaching the WebView',
    );
    return const SizedBox.expand();
  }
}
