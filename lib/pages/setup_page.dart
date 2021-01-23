import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:package_info/package_info.dart';

class SetupPage extends StatelessWidget {
  void _configure(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final welcomeStyle = TextStyle(
      color: CupertinoColors.label.resolveFrom(context),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      height: 1.5,
    );
    final top = Container(
      padding: EdgeInsets.symmetric(vertical: 100),
      child: Column(
        children: [
          Image.asset("assets/icons/logo.png", width: 80, height: 80),
          Text(S.of(context).welcome, style: welcomeStyle),
        ],
      ),
    );
    final services = ListTileGroup([
      MyListTile(
        title: Text("Fever API"),
        onTap: () { _configure(context, "/settings/service/fever"); },
      ),
      MyListTile(
        title: Text("Google Reader API"),
        onTap: () { _configure(context, "/settings/service/greader"); },
      ),
      MyListTile(
        title: Text("Inoreader"),
        onTap: () { _configure(context, "/settings/service/inoreader"); },
      ),
      MyListTile(
        title: Text("Feedbin"),
        onTap: () { _configure(context, "/settings/service/feedbin"); },
        withDivider: false,
      ),
    ], title: S.of(context).service);
    final settings = ListTileGroup([
      MyListTile(
        title: Text(S.of(context).general),
        onTap: () { _configure(context, "/settings/general"); },
      ),
      MyListTile(
        title: Text(S.of(context).about),
        onTap: () async {
          var infos = await PackageInfo.fromPlatform();
          Navigator.of(context).pushNamed("/settings/about", arguments: infos.version);
        },
        withDivider: false,
      ),
    ], title: S.of(context).settings);
    final page = CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      child: ListView(children: [
        top,
        services,
        settings,
      ]),
    );
    final b = Global.currentBrightness(context) == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: b ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: page,
    );
  }
}