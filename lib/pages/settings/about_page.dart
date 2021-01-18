import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String version = ModalRoute.of(context).settings.arguments ?? "1.0.0";
    final nameStyle = TextStyle(
      color: CupertinoColors.label.resolveFrom(context),
      fontSize: 18,
      fontWeight: FontWeight.bold,
      height: 1.5,
    );
    final versionStyle = TextStyle(
      color: CupertinoColors.label.resolveFrom(context),
      fontSize: 14,
      height: 1.5,
    );
    final copyrightStyle = TextStyle(
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
      fontSize: 12,
      height: 2,
    );
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).about),
      ),
      child: ListView(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 100),
            child: Column(
              children: [
                Image.asset("assets/icons/logo.png", width: 80, height: 80),
                Text("Fluent Reader Lite", style: nameStyle),
                Text("${S.of(context).version} $version", style: versionStyle),
                Text("Copyright © 2021 Haoyuan Liu. All rights reserved.", style: copyrightStyle),
              ],
            ),
          ),
          ListTileGroup([
            MyListTile(
              title: Text(S.of(context).openSource),
              onTap: () { Utils.openExternal("https://github.com/yang991178/fluent-reader-lite"); },
            ),
            MyListTile(
              title: Text(S.of(context).feedback),
              onTap: () { Utils.openExternal("https://github.com/yang991178/fluent-reader-lite/issues"); },
              withDivider: false,
            ),
          ]),
        ],
      ),
    );
  }
}