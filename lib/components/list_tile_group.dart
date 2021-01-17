import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

class ListTileGroup extends StatelessWidget {
  ListTileGroup(this.children, {this.title, Key key}) : super(key: key);

  ListTileGroup.fromOptions(
    List<Tuple2<String, dynamic>> options, 
    dynamic selected, 
    Function onSelected,
    {this.title, Key key}) :
    children = options.map((t) => MyListTile(
      title: Text(t.item1),
      trailing: t.item2 == selected
        ? Icon(Icons.done)
        : Icon(null),
      trailingChevron: false,
      onTap: () { onSelected(t.item2); },
      withDivider: t.item2 != options.last.item2,
    )),
    super(key: key);

  final Iterable<Widget> children;
  final String title;

  static const _titleStyle = TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title != null) Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(title, style: _titleStyle),
      ),
      Container(
        color: MyColors.tileBackground.resolveFrom(context),
        child: Column(children: [
          Divider(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            height: 1,
            thickness: 1,
          ),
          ...children,
          Divider(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            height: 1,
            thickness: 1,
          ),
        ],
      ),
    ),
  ],);
}