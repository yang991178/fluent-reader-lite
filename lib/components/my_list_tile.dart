import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyListTile extends StatefulWidget {
  final Widget leading;
  final Widget title;
  final Widget trailing;
  final bool trailingChevron;
  final bool withDivider;
  final Function onTap;
  final CupertinoDynamicColor background;

  MyListTile({
    this.leading,
    @required this.title,
    this.trailing,
    this.trailingChevron : true,
    this.withDivider : true,
    this.onTap,
    this.background : MyColors.tileBackground,
    Key key,
  }) : super(key: key);

  @override
  _MyListTileState createState() => _MyListTileState();
}

class _MyListTileState extends State<MyListTile> {
  bool pressed = false;

  void _onTap() {
    if (widget.onTap != null) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final _titleStyle = TextStyle(
      fontSize: 16,
      color: CupertinoColors.label.resolveFrom(context),
    );
    final leftPart = Flexible(child: Row(
      children: [
        if (widget.leading != null) Container(
          padding: EdgeInsets.only(right: 16),
          width: 40,
          height: 24,
          child: widget.leading,
        ),
        DefaultTextStyle(
          child: widget.title,
          style: _titleStyle,
        ),
      ],
    ));
    final _labelStyle = TextStyle(
      fontSize: 16,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    final rightPart = Row(
      children: [
        if (widget.trailing != null) DefaultTextStyle(
          child: widget.trailing,
          style: _labelStyle,
        ),
        if (widget.trailingChevron) Icon(
          CupertinoIcons.chevron_forward,
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
      ],
    );
    return GestureDetector(
      onTapDown: (_) { setState(() { pressed = true; }); },
      onTapUp: (_) { setState(() { pressed = false; }); },
      onTapCancel: () { setState(() { pressed = false; }); },
      onTap: _onTap,
      child: Column(children: [
        Container(
          color: (pressed && widget.onTap != null)
            ? CupertinoColors.systemGrey4.resolveFrom(context) 
            : widget.background.resolveFrom(context),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          constraints: BoxConstraints(minHeight: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              leftPart,
              rightPart,
            ],
          ),
        ),
        if (widget.withDivider) Padding(
          padding: EdgeInsets.only(left: widget.leading == null ? 16 : 50),
          child: Divider(color: CupertinoColors.systemGrey4.resolveFrom(context), height: 0),
        ),
      ],),
    );
  }
}
