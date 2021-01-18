import 'dart:io';

import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:share/share.dart';
import 'package:fluent_reader_lite/components/cupertino_toolbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ArticlePage extends StatefulWidget {
  static final GlobalKey<ArticlePageState> state = GlobalKey();

  ArticlePage() : super(key: state);

  @override
  ArticlePageState createState() => ArticlePageState();
}

class ArticlePageState extends State<ArticlePage> {
  WebViewController _controller;
  int requestId = 0;
  bool loaded = false;
  bool navigated = false;
  SourceOpenTarget _target;
  String iid;
  bool isSourceFeed;

  void loadNewItem(String id, {bool isSource}) {
    if (!Global.itemsModel.getItem(id).hasRead) {
      Global.itemsModel.updateItem(id, read: true);
    }
    setState(() {
      iid = id;
      loaded = false;
      navigated = false;
      _target = null;
      if (isSource != null) isSourceFeed = isSource;
    });
  }

  Future<NavigationDecision> _onNavigate(NavigationRequest request) async {
    if (navigated && request.isForMainFrame) {
      await launch(request.url);
      return NavigationDecision.prevent;
    } else {
      return NavigationDecision.navigate;
    }
  }

  void _loadHtml(RSSItem item, RSSSource source, {loadFull: false}) async {
    var localUrl = "http://127.0.0.1:9000/article/article.html";
    var currId = requestId;
    String a;
    if (loadFull) {
      try {
        var html = (await http.get(item.link)).body;
        a = Uri.encodeComponent(html);
      } catch(exp) {
        setState(() { loaded = true; });
        return;
      }
    } else {
      a = Uri.encodeComponent(item.content);
    }
    var h = '<p id="source">${source.name}${(item.creator!=null&&item.creator.length>0)?' / '+item.creator:''}</p>';
    h += '<p id="title">${item.title}</p>';
    h += '<p id="date">${DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(item.date)}</p>';
    h += '<article></article>';
    h = Uri.encodeComponent(h);
    var s = Store.getArticleFontSize();
    localUrl += "?a=$a&h=$h&s=$s&u=${item.link}&m=${loadFull ? 1 : 0}";
    if (Platform.isAndroid || Global.globalModel.getBrightness() != null) {
      var brightness = Global.currentBrightness(context);
      localUrl += "&t=${brightness.index}";
    }
    if (currId == requestId) _controller.loadUrl(localUrl);
  }

  void _onPageReady(_) async {
    if (Platform.isAndroid || Global.globalModel.getBrightness() != null) {
      await Future.delayed(Duration(milliseconds: 300));
    }
    setState(() { loaded = true; });
  }
  void _onWebpageReady(_) {
    if (loaded) navigated = true;
  }

  void _setOpenTarget(RSSSource source, {SourceOpenTarget target}) {
    setState(() {
      _target = target ?? source.openTarget;
    });
  }

  void _loadOpenTarget(RSSItem item, RSSSource source) {
    setState(() {
      requestId += 1;
      loaded = false;
      navigated = false;
    });
    switch (_target) {
      case SourceOpenTarget.Local:
        _loadHtml(item, source);
        break;
      case SourceOpenTarget.FullContent:
        _loadHtml(item, source, loadFull: true);
        break;
      case SourceOpenTarget.Webpage:
      case SourceOpenTarget.External:
        _controller.loadUrl(item.link);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Tuple2<String, bool> arguments = ModalRoute.of(context).settings.arguments;
    if (iid == null) iid = arguments.item1;
    if (isSourceFeed == null) isSourceFeed = arguments.item2;
    final resolvedDarkGrey = MyColors.dynamicDarkGrey.resolveFrom(context);
    final viewOptions = {
      0: Padding(child: Icon(Icons.rss_feed, color: resolvedDarkGrey), padding: EdgeInsets.symmetric(horizontal: 8)),
      1: Icon(Icons.article_outlined, color: resolvedDarkGrey),
      2: Icon(Icons.language, color: resolvedDarkGrey),
    };
    return Selector2<ItemsModel, SourcesModel, Tuple2<RSSItem, RSSSource>>(
      selector: (context, itemsModel, sourcesModel) {
        var item = itemsModel.getItem(iid);
        var source = sourcesModel.getSource(item.source);
        return Tuple2(item, source);
      },
      builder: (context, tuple, child) {
        var item = tuple.item1;
        var source = tuple.item2;
        if (_target == null) _target = source.openTarget;
        final body = SafeArea(child: IndexedStack(
          index: !loaded ? 0 : 1,
          children: [
            Center(
              child: CupertinoActivityIndicator()
            ),
            WebView(
              key: Key("a-$iid-${_target.index}"),
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated: (WebViewController webViewController) {
                _controller = webViewController;
                _loadOpenTarget(item, source);
              },
              onPageStarted: _onPageReady,
              onPageFinished: _onWebpageReady,
              navigationDelegate: _onNavigate,
            ),
          ],
        ), bottom: false,);
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            backgroundColor: CupertinoColors.systemBackground,
            middle: CupertinoSlidingSegmentedControl(
              children: viewOptions,
              onValueChanged: (v) { _setOpenTarget(source, target: SourceOpenTarget.values[v]); },
              groupValue: _target.index,
            ),
          ),
          child: Consumer<FeedsModel>(
            child: body,
            builder: (context, feedsModel, child) {
              final feed = isSourceFeed ? feedsModel.source : feedsModel.all;
              var idx = feed.iids.indexOf(iid);
              return CupertinoToolbar(
                items: [
                  CupertinoToolbarItem(
                    icon: item.hasRead ? CupertinoIcons.circle : CupertinoIcons.smallcircle_fill_circle,
                    onPressed: () {
                      Global.itemsModel.updateItem(item.id, read: !item.hasRead);
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: item.starred ? CupertinoIcons.star_fill : CupertinoIcons.star,
                    onPressed: () {
                      Global.itemsModel.updateItem(item.id, starred: !item.starred);
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.share,
                    onPressed: () { Share.share(item.link); },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.chevron_up,
                    onPressed: idx <= 0 ? null : () {
                      loadNewItem(feed.iids[idx - 1]);
                    },
                  ),
                  CupertinoToolbarItem(
                    icon: CupertinoIcons.chevron_down,
                    onPressed: (idx == -1 || (idx == feed.iids.length - 1 && feed.allLoaded))
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
                body: child,
              );
            },
          ),
        );
      },
    );
  }
}
