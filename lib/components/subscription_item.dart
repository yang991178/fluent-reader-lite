import 'package:fluent_reader_lite/components/dismissible_background.dart';
import 'package:fluent_reader_lite/components/favicon.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/time_text.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'badge.dart';

class SubscriptionItem extends StatefulWidget {
  final RSSSource source;

  SubscriptionItem(this.source, {Key key}) : super(key: key);

  @override
  _SubscriptionItemState createState() => _SubscriptionItemState();
}

class _SubscriptionItemState extends State<SubscriptionItem> {
  bool pressed = false;

  void _openSourcePage() async {
    await Global.feedsModel.initSourcesFeed([widget.source.id]);
    Navigator.of(context).pushNamed("/feed", arguments: widget.source.name);
  }

  static const _dismissThresholds = {
    DismissDirection.horizontal: 0.25,
  };

  Future<bool> _onDismiss(DismissDirection direction) async {
    HapticFeedback.mediumImpact();
    if (direction == DismissDirection.startToEnd) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => MarkAllActionSheet({widget.source.id}),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pushNamed(
        "/settings/sources/edit",
        arguments: widget.source.id,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final _titleStyle = TextStyle(
      fontSize: 16,
      color: CupertinoColors.label.resolveFrom(context),
      fontWeight: FontWeight.bold,
    );
    final _descStyle = TextStyle(
      fontSize: 16,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final _timeStyle = TextStyle(
      fontSize: 14,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final topLine = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(children: [
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Favicon(widget.source),
            ),
            Expanded(
              child: Text(widget.source.name, style: _titleStyle, overflow: TextOverflow.ellipsis,),
            ),
          ]),
        ),
        TimeText(widget.source.latest, style: _timeStyle),
      ],
    );
    final bottomLine = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(widget.source.lastTitle, style: _descStyle, overflow: TextOverflow.ellipsis),
        ),
        if (widget.source.unreadCount > 0) Badge(widget.source.unreadCount),
      ],
    );
    final body = GestureDetector(
      onTapDown: (_) { setState(() { pressed = true; }); },
      onTapUp: (_) { setState(() { pressed = false; }); },
      onTapCancel: () { setState(() { pressed = false; }); },
      onTap: _openSourcePage,
      child: Column(children: [
        Container(
          constraints: BoxConstraints(minHeight: 64),
          color: pressed 
            ? CupertinoColors.systemGrey4.resolveFrom(context) 
            : CupertinoColors.systemBackground.resolveFrom(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                topLine,
                Padding(padding: EdgeInsets.only(top: 4)),
                bottomLine
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 16),
          child: Divider(color: CupertinoColors.systemGrey4.resolveFrom(context), height: 1),
        ),
      ],),
    );
    return Dismissible(
      key: Key("D-${widget.source.id}"),
      background: DismissibleBackground(CupertinoIcons.checkmark_circle, true),
      secondaryBackground: DismissibleBackground(CupertinoIcons.pencil_circle, false),
      dismissThresholds: _dismissThresholds,
      confirmDismiss: _onDismiss,
      child: body,
    );
  }
}