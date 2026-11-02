import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// WebKit's covered-content viewport keeps the reading origin, scroll range
/// and indicator track intact while painting below bars. Older WebKit versions
/// retain the original visible frame.
class ReaderWebView extends StatefulWidget {
  const ReaderWebView({
    super.key,
    required this.controller,
    required this.viewKey,
  });

  final WebViewController controller;
  final Key viewKey;

  @override
  State<ReaderWebView> createState() => _ReaderWebViewState();
}

class _ReaderWebViewState extends State<ReaderWebView> {
  static const _channel = MethodChannel(
    'me.hyliu.fluent_reader_lite/article_insets',
  );
  EdgeInsets? _lastInsets;
  bool _canUnderlap = true;

  @override
  void didUpdateWidget(ReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _lastInsets = null;
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.controller.platform;
    final padding = MediaQuery.paddingOf(context);
    final insets = EdgeInsets.only(top: padding.top, bottom: padding.bottom);
    if (_canUnderlap &&
        platform is WebKitWebViewController &&
        _lastInsets != insets) {
      _lastInsets = insets;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted ||
            widget.controller.platform != platform ||
            _lastInsets != insets)
          return;
        final supported = await _channel.invokeMethod<bool>('setInsets', {
          'id': platform.webViewIdentifier,
          'top': insets.top,
          'bottom': insets.bottom,
        });
        if (mounted && supported == false) {
          setState(() => _canUnderlap = false);
        }
      });
    }
    return Padding(
      padding: _canUnderlap ? EdgeInsets.zero : insets,
      child: WebViewWidget(key: widget.viewKey, controller: widget.controller),
    );
  }
}
