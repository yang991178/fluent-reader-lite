import 'dart:convert';
import 'dart:io';

import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/article.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tuple/tuple.dart';
import 'package:fluent_reader_lite/components/cupertino_toolbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ArticlePage extends StatefulWidget {
  static final GlobalKey<ArticlePageState> state = GlobalKey();

  ArticlePage() : super(key: state);

  @override
  ArticlePageState createState() => ArticlePageState();
}

enum _ArticleLoadState { Loading, Success, Failure }

class ArticlePageState extends State<ArticlePage> {
  WebViewController? _controller;
  Brightness? _brightness;
  int requestId = 0;
  _ArticleLoadState loaded = _ArticleLoadState.Loading;
  bool navigated = false;
  SourceOpenTarget? _target;
  String? iid;
  bool? isSourceFeed;

  void loadNewItem(String? id, {bool? isSource}) {
    requestId += 1;
    if (!Global.itemsModel!.getItem(id)!.hasRead) {
      Global.itemsModel!.updateItem(id, read: true);
    }
    setState(() {
      iid = id;
      loaded = _ArticleLoadState.Loading;
      navigated = false;
      _target = null;
      if (isSource != null) isSourceFeed = isSource;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = CupertinoTheme.brightnessOf(context);
    if (_brightness == brightness) return;
    _brightness = brightness;
    _controller?.setBackgroundColor(_backgroundColor);
    _updateArticleTheme();
  }

  Color get _backgroundColor => _brightness == Brightness.dark
      ? CupertinoColors.black
      : CupertinoColors.white;

  void _updateArticleTheme() {
    if (_target == SourceOpenTarget.Local ||
        _target == SourceOpenTarget.FullContent) {
      _controller?.runJavaScript(
        'if (typeof setArticleTheme === "function") '
        'setArticleTheme(${_brightness!.index});',
      );
    }
  }

  Future<WebViewController> getNewWebviewController() async {
    final currId = requestId;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ArticleStatus',
        onMessageReceived: (message) {
          if (_target != SourceOpenTarget.Local &&
              _target != SourceOpenTarget.FullContent)
            return;
          if (message.message == 'success') {
            _setLoadState(currId, _ArticleLoadState.Success);
          } else if (message.message == 'failure') {
            _setLoadState(currId, _ArticleLoadState.Failure);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted && currId == requestId) _onPageReady();
          },
          onPageFinished: (_) {
            if (mounted && currId == requestId) _onWebpageReady();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _setLoadState(currId, _ArticleLoadState.Failure);
            }
          },
          onNavigationRequest: (request) {
            if (!mounted || currId != requestId) {
              return NavigationDecision.prevent;
            }
            return _onNavigate(request);
          },
        ),
      );
    // Configure the native canvas before attaching or navigating the WebView.
    await controller.setBackgroundColor(_backgroundColor);
    return controller;
  }

  void _setLoadState(int currId, _ArticleLoadState state) {
    if (!mounted || currId != requestId) return;
    setState(() {
      loaded = state;
      navigated = state == _ArticleLoadState.Success;
    });
  }

  void loadRequest(Uri uri) async {
    final currId = requestId;
    try {
      final controller = await getNewWebviewController();
      if (!mounted || currId != requestId) return;
      setState(() => _controller = controller);
      await controller.loadRequest(uri);
    } catch (_) {
      _setLoadState(currId, _ArticleLoadState.Failure);
    }
  }

  Future<NavigationDecision> _onNavigate(NavigationRequest request) async {
    if (navigated && request.isMainFrame) {
      final internal = Global.globalModel!.inAppBrowser;
      await launch(
        request.url,
        forceSafariVC: internal,
        forceWebView: internal,
      );
      return NavigationDecision.prevent;
    } else {
      return NavigationDecision.navigate;
    }
  }

  void _loadHtml(RSSItem item, RSSSource? source, {loadFull = false}) async {
    final currId = requestId;
    try {
      var content = item.content;
      if (loadFull) {
        final response = await http
            .get(Uri.parse(item.link))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Article request failed: ${response.statusCode}');
        }
        content = decodeArticleResponse(response);
      }
      final template = await rootBundle.loadString(
        'assets/article/article.html',
      );
      if (!mounted || currId != requestId) return;
      final creator = item.creator;
      var h =
          '<p id="source">${htmlEscape.convert(source!.name)}'
          '${creator != null && creator.isNotEmpty ? ' / ' + htmlEscape.convert(creator) : ''}</p>';
      h += '<p id="title">${htmlEscape.convert(item.title)}</p>';
      h +=
          '<p id="date">${DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(item.date)}</p>';
      h += '<article></article>';
      final document = buildArticleDocument(template, {
        'content': content,
        'header': h,
        'fontSize': Store.getArticleFontSize(),
        'url': item.link,
        'fullContent': loadFull,
        'theme': _brightness!.index,
      });
      final controller = await getNewWebviewController();
      if (!mounted || currId != requestId) return;
      setState(() {
        _controller = controller;
      });
      // Pass the document as data rather than expanding it into a navigation
      // URL, which can exceed WebView limits on large publisher pages.
      await controller.loadHtmlString(
        document,
        baseUrl: 'http://127.0.0.1:9000/article/',
      );
    } catch (_) {
      _setLoadState(currId, _ArticleLoadState.Failure);
    }
  }

  void _onPageReady() {
    if (_target == SourceOpenTarget.Local ||
        _target == SourceOpenTarget.FullContent)
      return;
    setState(() {
      loaded = _ArticleLoadState.Success;
    });
  }

  void _onWebpageReady() {
    _updateArticleTheme();
    if (loaded == _ArticleLoadState.Success) navigated = true;
  }

  void _setOpenTarget(RSSSource? source, {SourceOpenTarget? target}) {
    setState(() {
      _target = target ?? source!.openTarget;
    });
  }

  void _loadOpenTarget(RSSItem item, RSSSource? source) {
    requestId += 1;
    loaded = _ArticleLoadState.Loading;
    navigated = false;
    switch (_target) {
      case SourceOpenTarget.Local:
        _loadHtml(item, source);
        break;
      case SourceOpenTarget.FullContent:
        _loadHtml(item, source, loadFull: true);
        break;
      case SourceOpenTarget.Webpage:
      case SourceOpenTarget.External:
        loadRequest(Uri.parse(item.link));
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Tuple2<String, bool>? arguments =
        ModalRoute.of(context)!.settings.arguments as Tuple2<String, bool>?;
    if (iid == null) iid = arguments!.item1;
    if (isSourceFeed == null) isSourceFeed = arguments!.item2;
    final resolvedDarkGrey = MyColors.dynamicDarkGrey.resolveFrom(context);
    final viewOptions = {
      0: Padding(
        child: Icon(
          Icons.rss_feed,
          color: resolvedDarkGrey,
          semanticLabel: S.of(context).rssText,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
      1: Icon(
        Icons.article_outlined,
        color: resolvedDarkGrey,
        semanticLabel: S.of(context).loadFull,
      ),
      2: Icon(
        Icons.language,
        color: resolvedDarkGrey,
        semanticLabel: S.of(context).loadWebpage,
      ),
    };
    return Selector2<ItemsModel, SourcesModel, Tuple2<RSSItem, RSSSource?>>(
      selector: (context, itemsModel, sourcesModel) {
        var item = itemsModel.getItem(iid)!;
        var source = sourcesModel.getSource(item.source);
        return Tuple2(item, source);
      },
      builder: (context, tuple, child) {
        var item = tuple.item1;
        var source = tuple.item2;
        if (_target == null) {
          _target = source!.openTarget;
          _loadOpenTarget(item, source);
        }
        final body = SafeArea(
          child: IndexedStack(
            index: loaded.index,
            children: [
              Center(child: CupertinoActivityIndicator()),
              if (_controller != null)
                WebViewWidget(
                  key: Key("a-$iid-${_target!.index}-$requestId"),
                  controller: _controller!,
                )
              else
                const SizedBox.shrink(),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.of(context).wentWrong,
                      style: TextStyle(
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    CupertinoButton(
                      child: Text(S.of(context).retry),
                      onPressed: () {
                        _loadOpenTarget(item, source);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: false,
        );
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground,
            middle: CupertinoSlidingSegmentedControl(
              children: viewOptions,
              onValueChanged: (dynamic v) {
                _setOpenTarget(source, target: SourceOpenTarget.values[v]);
                _loadOpenTarget(item, source);
              },
              groupValue: _target!.index,
            ),
          ),
          child: Consumer<FeedsModel>(
            child: body,
            builder: (context, feedsModel, child) {
              final feed = isSourceFeed! ? feedsModel.source! : feedsModel.all;
              var idx = feed.iids.indexOf(iid);
              return CupertinoToolbar(
                items: [
                  CupertinoToolbarItem(
                    icon: item.hasRead
                        ? CupertinoIcons.circle
                        : CupertinoIcons.smallcircle_fill_circle,
                    semanticLabel: item.hasRead
                        ? S.of(context).markUnread
                        : S.of(context).markRead,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Global.itemsModel!.updateItem(
                        item.id,
                        read: !item.hasRead,
                      );
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: item.starred
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    semanticLabel: item.starred
                        ? S.of(context).star
                        : S.of(context).unstar,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Global.itemsModel!.updateItem(
                        item.id,
                        starred: !item.starred,
                      );
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.share,
                    semanticLabel: S.of(context).share,
                    onPressed: () {
                      final media = MediaQuery.of(context);
                      SharePlus.instance.share(
                        ShareParams(
                          uri: Uri.parse(item.link),
                          sharePositionOrigin: Rect.fromLTWH(
                            media.size.width -
                                ArticlePage.state.currentContext!.size!.width /
                                    2,
                            media.size.height - media.padding.bottom - 54,
                            0,
                            0,
                          ),
                        ),
                      );
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.chevron_up,
                    semanticLabel: S.of(context).prev,
                    onPressed: idx <= 0
                        ? null
                        : () {
                            loadNewItem(feed.iids[idx - 1]);
                          },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.chevron_down,
                    semanticLabel: S.of(context).next,
                    onPressed:
                        (idx == -1 ||
                            (idx == feed.iids.length - 1 && feed.allLoaded))
                        ? null
                        : () async {
                            if (idx == feed.iids.length - 1) {
                              await feed.loadMore();
                            }
                            idx = feed.iids.indexOf(iid);
                            if (idx != feed.iids.length - 1) {
                              loadNewItem(feed.iids[idx + 1]);
                            }
                          },
                  ),
                ],
                body: child!,
              );
            },
          ),
        );
      },
    );
  }
}
