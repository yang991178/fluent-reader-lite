import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';

class ReadingPage extends StatefulWidget {
  @override
  _ReadingPageState createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  int _fontSize = Store.getArticleFontSize();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).reading),
      ),
      child: ListView(children: [
        ListTileGroup([
          MyListTile(
            title: Text(S.of(context).fontSize),
            trailing: Text(_fontSize.toString()),
            trailingChevron: false,
            withDivider: false,
          ),
          MyListTile(
            title: Expanded(child: CupertinoSlider(
              min: 10,
              max: 22,
              divisions: 13,
              value: _fontSize.toDouble(),
              onChanged: (v) { setState(() { _fontSize = v.toInt(); }); },
              onChangeEnd: (v) { Store.setArticleFontSize(v.toInt()); },
            )),
            trailingChevron: false,
            withDivider: false,
          ),
        ], title: S.of(context).preferences),
      ]),
    );
  }
}
