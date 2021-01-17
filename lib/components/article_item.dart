import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_reader_lite/components/dismissible_background.dart';
import 'package:fluent_reader_lite/components/favicon.dart';
import 'package:fluent_reader_lite/components/time_text.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/pages/article_page.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticleItem extends StatefulWidget {
  final RSSItem item;
  final RSSSource source;
  final Function openActionSheet;

  ArticleItem(this.item, this.source, this.openActionSheet, {Key key}) : super(key: key);

  @override
  _ArticleItemState createState() => _ArticleItemState();
}

class _ArticleItemState extends State<ArticleItem> {
  bool pressed = false;

  void _openArticle() {
    Navigator.of(context, rootNavigator: true).popUntil((route) {
      return route.isFirst;
    });
    if (!widget.item.hasRead) {
      Global.itemsModel.updateItem(widget.item.id, read: true);
    }
    if (widget.source.openTarget == SourceOpenTarget.External) {
      launch(widget.item.link, forceSafariVC: false, forceWebView: false);
    } else {
      var isSource = Navigator.of(context).canPop();
      if (ArticlePage.state.currentWidget != null) {
        ArticlePage.state.currentState.loadNewItem(
          widget.item.id,
          isSource: isSource,
        );
      } else {
        var navigator = Global.responsiveNavigator(context);
        while (navigator.canPop()) navigator.pop();
        navigator.pushNamed(
          "/article", 
          arguments: Tuple2(widget.item.id, isSource)
        );
      }
    }
  }

  void _openActionSheet() {
    HapticFeedback.mediumImpact();
    widget.openActionSheet(widget.item);
  }

  Widget _imagePlaceholderBuilder(BuildContext context, String _) {
    return Container(
      color: CupertinoColors.systemGrey5.resolveFrom(context)
    );
  }

  static final _unreadIndicator = Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(
      CupertinoIcons.circle_fill,
      size: 8,
      color: MyColors.indicatorOrange,
    ),
  );
  static final _starredIndicator = Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: Icon(
      CupertinoIcons.star_fill,
      size: 9,
      color: MyColors.indicatorOrange,
    ),
  );

  IconData _getDismissIcon(ItemSwipeOption option) {
    switch (option) {
      case ItemSwipeOption.ToggleRead:
        return widget.item.hasRead
          ? Icons.radio_button_checked
          : Icons.radio_button_unchecked;
      case ItemSwipeOption.ToggleStar:
        return widget.item.starred
          ? CupertinoIcons.star
          : CupertinoIcons.star_fill;
      case ItemSwipeOption.Share:
        return CupertinoIcons.share;
      case ItemSwipeOption.OpenMenu:
        return CupertinoIcons.ellipsis;
      case ItemSwipeOption.OpenExternal:
        return CupertinoIcons.square_arrow_right;
    }
    return null;
  }

  void _performSwipeAction(ItemSwipeOption option) async {
    switch(option) {
      case ItemSwipeOption.ToggleRead:
        await Future.delayed(Duration(milliseconds: 200));
        Global.itemsModel.updateItem(widget.item.id, read: !widget.item.hasRead);
        break;
      case ItemSwipeOption.ToggleStar:
        await Future.delayed(Duration(milliseconds: 200));
        Global.itemsModel.updateItem(widget.item.id, starred: !widget.item.starred);
        break;
      case ItemSwipeOption.Share:
        Share.share(widget.item.link);
        break;
      case ItemSwipeOption.OpenMenu:
        widget.openActionSheet(widget.item);
        break;
      case ItemSwipeOption.OpenExternal:
        if (!widget.item.hasRead) {
          Global.itemsModel.updateItem(widget.item.id, read: true);
        }
        launch(widget.item.link, forceSafariVC: false, forceWebView: false);
        break;
    }
  }

  Future<bool> _onDismiss(DismissDirection direction) async {
    HapticFeedback.mediumImpact();
    if (direction == DismissDirection.startToEnd) {
      _performSwipeAction(Global.feedsModel.swipeR);
    } else {
      _performSwipeAction(Global.feedsModel.swipeL);
    }
    return false;
  }

  static const _dismissThresholds = {
    DismissDirection.horizontal: 0.25,
  };

  @override
  Widget build(BuildContext context) {
    final _descStyle = TextStyle(
      fontSize: 12,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final _titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Global.feedsModel.dimRead && widget.item.hasRead
        ? CupertinoColors.secondaryLabel.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context),
    );
    final _snippetStyle = TextStyle(
      fontSize: 16,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final infoLine = Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
          Expanded(child: Text(
            widget.source.name,
            style: _descStyle,
            overflow: TextOverflow.ellipsis,
          )),
          Row(children: [
            if (!Global.feedsModel.dimRead && !widget.item.hasRead) _unreadIndicator,
            if (widget.item.starred) _starredIndicator,
            TimeText(widget.item.date, style: _descStyle),
          ]),
        ],
      ),
    );
    final itemTexts = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.title, 
            style: _titleStyle,
          ),
          if (Global.feedsModel.showSnippet && widget.item.snippet.length > 0) Text(
            widget.item.snippet,
            style: _snippetStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],)
    );
    final body = GestureDetector(
      onTapDown: (_) { setState(() { pressed = true; }); },
      onTapUp: (_) { setState(() { pressed = false; }); },
      onTapCancel: () { setState(() { pressed = false; }); },
      onLongPress: _openActionSheet,
      onTap: _openArticle,
      child: Container(
        color: pressed 
          ? CupertinoColors.systemGrey4.resolveFrom(context) 
          : CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(0, 20, 8, 0),
                  child: Favicon(widget.source),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      infoLine,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          itemTexts,
                          if (Global.feedsModel.showThumb && widget.item.thumb != null) Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: widget.item.thumb,
                                width: 64, height: 64, fit: BoxFit.cover,
                                placeholder: _imagePlaceholderBuilder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            padding: EdgeInsets.only(left: 16),
            child: Divider(color: CupertinoColors.systemGrey4.resolveFrom(context), height: 1),
          ),
        ])
      )
    );
    return Dismissible(
      key: Key("D-${widget.item.id}"),
      background: DismissibleBackground(
        _getDismissIcon(Global.feedsModel.swipeR),
        true,
      ),
      secondaryBackground: DismissibleBackground(
        _getDismissIcon(Global.feedsModel.swipeL),
        false,
      ),
      dismissThresholds: _dismissThresholds,
      confirmDismiss: _onDismiss,
      child: body,
    );
  }
}