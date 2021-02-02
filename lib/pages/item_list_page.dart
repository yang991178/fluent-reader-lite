import 'package:fluent_reader_lite/components/article_item.dart';
import 'package:fluent_reader_lite/components/badge.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/responsive_action_sheet.dart';
import 'package:fluent_reader_lite/components/sync_control.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/feed.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/pages/settings/text_editor_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:tuple/tuple.dart';

import 'home_page.dart';

class ItemListPage extends StatefulWidget {
  final ScrollTopNotifier scrollTopNotifier;

  ItemListPage(this.scrollTopNotifier, {Key key}) : super(key: key);

  @override
  _ItemListPageState createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  DateTime lastLoadedMore;

  void _onScrollTop() {
    var expectedCanPop = widget.scrollTopNotifier.index == 1;
    if (expectedCanPop == Navigator.of(context).canPop()) {
      PrimaryScrollController.of(context).animateTo(
        0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.scrollTopNotifier.addListener(_onScrollTop);
  }
  
  @override
  void dispose() {
    widget.scrollTopNotifier.removeListener(_onScrollTop);
    super.dispose();
  }

  RSSFeed getFeed() {
    return ModalRoute.of(context).settings.arguments != null
     ? Global.feedsModel.source
     : Global.feedsModel.all;
  }

  bool _onScroll(ScrollNotification scrollInfo) {
    var feed = getFeed();
    if (!ModalRoute.of(context).isCurrent
      || !feed.initialized || feed.loading || feed.allLoaded) {
      return true;
    }
    if (scrollInfo.metrics.extentAfter == 0.0 &&
      scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8 &&
      (lastLoadedMore == null || DateTime.now().difference(lastLoadedMore).inSeconds > 1)) {
      lastLoadedMore = DateTime.now();
      feed.loadMore();
    }
    return false;
  }

  void _openMarkAllModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MarkAllActionSheet(getFeed().sids),
    );
  }

  static const _iconPadding = Padding(padding: EdgeInsets.only(left: 24));

  void _openFilterModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final feed = getFeed();
        final sheet = CupertinoActionSheet(
          title: Text(S.of(context).filter),
          actions: [
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(CupertinoIcons.today),
                Text(S.of(context).allArticles),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                feed.setFilter(FilterType.All);
                _onScrollTop();
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(Icons.radio_button_checked),
                Text(S.of(context).unreadOnly),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                feed.setFilter(FilterType.Unread);
                _onScrollTop();
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(CupertinoIcons.star_fill),
                Text(S.of(context).starredOnly),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                feed.setFilter(FilterType.Starred);
                _onScrollTop();
              },
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Row(children: [
                Icon(CupertinoIcons.search, color: CupertinoColors.destructiveRed),
                Text(feed.search.length > 0 ? S.of(context).editKeyword : S.of(context).search),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                _editSearchKeyword();
              },
            ),
            if (feed.search.length > 0) CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: Row(children: [
                Icon(CupertinoIcons.clear_fill, color: CupertinoColors.destructiveRed),
                Text(S.of(context).clearSearch),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                feed.performSearch("");
                _onScrollTop();
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(S.of(context).cancel),
            onPressed: () { 
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        );
        return ResponsiveActionSheet(sheet);
      }
    );
  }

  void _editSearchKeyword() async {
    String keyword = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        S.of(context).editKeyword,
        (v) => v.trim().length > 0,
        saveText: S.of(context).search,
        initialValue: getFeed().search,
        navigationBarColor: CupertinoColors.systemBackground,
        autocorrect: true,
      ),
    ));
    if (keyword == null) return;
    getFeed().performSearch(keyword);
    _onScrollTop();
  }

  void _openActionSheet(RSSItem item) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final sheet = CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(item.hasRead ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                Text(item.hasRead ? S.of(context).markUnread : S.of(context).markRead),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                Global.itemsModel.updateItem(item.id, read: !item.hasRead);
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(item.starred ? CupertinoIcons.star : CupertinoIcons.star_fill),
                Text(item.starred ? S.of(context).unstar : S.of(context).star),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                Global.itemsModel.updateItem(item.id, starred: !item.starred);
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(CupertinoIcons.arrow_up),
                Text(S.of(context).markAbove),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                Global.itemsModel.markAllRead(getFeed().sids, date: item.date, before: false);
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(CupertinoIcons.arrow_down),
                Text(S.of(context).markBelow),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                Global.itemsModel.markAllRead(getFeed().sids, date: item.date);
              },
            ),
            CupertinoActionSheetAction(
              child: Row(children: [
                Icon(CupertinoIcons.share),
                Text(S.of(context).share),
                _iconPadding,
              ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
              onPressed: () { 
                Navigator.of(context, rootNavigator: true).pop();
                final media = MediaQuery.of(context);
                Share.share(
                  item.link,
                  sharePositionOrigin: Rect.fromLTWH(
                    160, media.size.height - media.padding.bottom, 0, 0
                  ),
                );
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text(S.of(context).cancel),
            onPressed: () { 
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
        );
        return ResponsiveActionSheet(sheet);
      },
    );
  }

  Widget _titleFromFilter() => Consumer<FeedsModel>(
    builder: (context, feedsModel, child) {
      String text;
      switch (getFeed().filterType) {
        case FilterType.Unread:
          text = S.of(context).unread;
          break;
        case FilterType.Starred:
          text = S.of(context).starred;
          break;
        default:
          text = S.of(context).all;
          break;
      }
      return Text(text, overflow: TextOverflow.ellipsis);
    },
  );

  @override
  Widget build(BuildContext context) {
    final String title = ModalRoute.of(context).settings.arguments;
    final titleWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: Global.isTablet
              ? 260
              : MediaQuery.of(context).size.width - 60,
          ),
          child: title == null ? _titleFromFilter() : Text(
            title, 
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Consumer<SourcesModel>(
          builder: (context, sourcesModel, child) {
            var sources = sourcesModel.getSources();
            if (title != null) {
              var feed = getFeed();
              sources = sources.where((s) => feed.sids.contains(s.id));
            }
            var count = sources.fold(0, (c, s) => c + s.unreadCount);
            if (count > 0) {
              return Padding(
                padding: EdgeInsets.only(left: 4),
                child: Badge(count, color: CupertinoColors.systemBlue),
              );
            }
            return Container();
          },
        ),
      ],
    );
    final navigationBar = CupertinoSliverNavigationBar(
      stretch: false,
      heroTag: title != null ? "source" : "all",
      transitionBetweenRoutes: true,
      backgroundColor: CupertinoColors.systemBackground,
      largeTitle: titleWidget,
      trailing: Container(
        transform: Matrix4.translationValues(12, 0, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                CupertinoIcons.checkmark_circle,
                semanticLabel: S.of(context).markAll,
              ),
              onPressed: _openMarkAllModal,
            ),
            Consumer<FeedsModel>(
              builder: (context, feedsModel, child) {
                var feed = getFeed();
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon((feed.filterType != FilterType.All || feed.search.length > 0)
                    ? CupertinoIcons.line_horizontal_3_decrease_circle_fill
                    : CupertinoIcons.line_horizontal_3_decrease_circle,
                    semanticLabel: S.of(context).filter,
                  ),
                  onPressed: _openFilterModal,
                );
              },
            ),
          ]
        ),
      )
    );
    final subscriptionList = Consumer<FeedsModel>(
      builder: (context, feedsModel, child) {
        var feed = getFeed();
        return SliverList(
          delegate: SliverChildBuilderDelegate((content, index) {
            return Selector2<ItemsModel, SourcesModel, Tuple2<RSSItem, RSSSource>>(
              selector: (context, itemsModel, sourcesModel) {
                var item = itemsModel.getItem(feed.iids[index]);
                var source = sourcesModel.getSource(item.source);
                return Tuple2(item, source);
              },
              builder: (context, tuple, child) => ArticleItem(
                tuple.item1, tuple.item2, _openActionSheet
              ),
            );
          }, childCount: feed.iids.length),
        );
      },
    );
    final loadMoreIndicator = Consumer<FeedsModel>(
      builder: (context, feedsModel, child) {
        var feed = getFeed();
        return SliverToBoxAdapter(child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: feed.allLoaded
              ? Text(S.of(context).allLoaded, style: TextStyle(
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ))
              : CupertinoActivityIndicator()
          ),
        ));
      }
    );
    return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CupertinoScrollbar(child: CustomScrollView(
          slivers: [
            navigationBar,
            SyncControl(),
            subscriptionList,
            loadMoreIndicator,
          ],
        )),
      );
  }
  
}