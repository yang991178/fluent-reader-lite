import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/reader_webview.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  for (final supported in [true, false]) {
    testWidgets(
      'WebView configures covered content before display ($supported)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        WebViewPlatform.instance = _Platform();
        final calls = <MethodCall>[];
        const channel = MethodChannel(
          'me.hyliu.fluent_reader_lite/article_insets',
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return supported;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final controller = WebViewController.fromPlatform(_Controller());
        Widget host(int index) => CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 106, bottom: 78),
            ),
            child: IndexedStack(
              index: index,
              children: [
                const SizedBox.expand(),
                ReaderWebView(
                  controller: controller,
                  viewKey: const Key('view'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(host(0));
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        expect(calls.single.method, 'setInsets');
        expect(calls.single.arguments, {'id': 7, 'top': 106.0, 'bottom': 78.0});
        await tester.pumpWidget(host(1));
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        expect(
          tester.getRect(find.byType(WebViewWidget)),
          supported
              ? const Rect.fromLTWH(0, 0, 390, 844)
              : const Rect.fromLTRB(0, 106, 390, 766),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Controller extends PlatformWebViewController
    implements WebKitWebViewController {
  _Controller()
    : super.implementation(const PlatformWebViewControllerCreationParams());
  @override
  int get webViewIdentifier => 7;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Platform extends WebViewPlatform {
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _View(params);
}

class _View extends PlatformWebViewWidget {
  _View(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
