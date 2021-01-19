import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).settings),
      ),
      child: ListView(children: [
        ListTileGroup([
          MyListTile(
            title: Text(S.of(context).subscriptions),
            leading: Icon(Icons.rss_feed, color: CupertinoColors.systemOrange, size: 24),
            onTap: () { Navigator.of(context).pushNamed("/settings/sources"); },
          ),
          MyListTile(
            title: Text(S.of(context).feed),
            leading: Icon(Icons.timeline, color: CupertinoColors.systemBlue, size: 24),
            onTap: () { Navigator.of(context).pushNamed("/settings/feed"); },
          ),
          MyListTile(
            title: Text(S.of(context).reading),
            leading: Icon(Icons.article_outlined, color: CupertinoColors.systemBlue, size: 24),
            onTap: () { Navigator.of(context).pushNamed("/settings/reading"); },
            withDivider: false,
          ),
        ], title: S.of(context).preferences),
        ListTileGroup([
          MyListTile(
            title: Text(S.of(context).service),
            leading: Icon(Icons.account_circle, color: CupertinoColors.systemOrange, size: 24),
            onTap: () { Navigator.of(context).pushNamed("/settings/service"); },
            withDivider: false,
          ),
        ], title: S.of(context).account),
        ListTileGroup([
          MyListTile(
            title: Text(S.of(context).general),
            leading: Icon(Icons.toggle_on, color: CupertinoColors.systemGreen, size: 24),
            onTap: () { Navigator.of(context).pushNamed("/settings/general"); },
          ),
          MyListTile(
            title: Text(S.of(context).about),
            leading: Icon(Icons.info, color: CupertinoColors.systemBlue, size: 24),
            onTap: () async {
              var infos = await PackageInfo.fromPlatform();
              Navigator.of(context).pushNamed("/settings/about", arguments: infos.version);
            },
            withDivider: false,
          ),
        ], title: S.of(context).app),
      ]),
    );
  }
}