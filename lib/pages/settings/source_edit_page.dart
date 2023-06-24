import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/pages/settings/text_editor_page.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class SourceEditPage extends StatelessWidget {
  void _editName(BuildContext context, RSSSource source) async {
    final String name = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        AppLocalizations.of(context).name,
        (v) => v.trim().length > 0,
        initialValue: source.name,
      ),
    ));
    if (name == null || name == source.name) return;
    var cloned = source.clone();
    cloned.name = name;
    await Global.sourcesModel.put(cloned);
  }

  void _editIcon(BuildContext context, RSSSource source) async {
    final String iconUrl = await Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => TextEditorPage(
        AppLocalizations.of(context).icon,
        (v) async {
          var trimmed = v.trim();
          if (trimmed.length == 0) return false;
          return await Utils.validateFavicon(trimmed);
        },
        initialValue: source.iconUrl,
      ),
    ));
    if (iconUrl == null || iconUrl == source.iconUrl) return;
    var cloned = source.clone();
    cloned.iconUrl = iconUrl;
    await Global.sourcesModel.put(cloned);
  }

  @override
  Widget build(BuildContext context) {
    final String sid = ModalRoute.of(context).settings.arguments;
    return Selector<SourcesModel, RSSSource>(
      selector: (context, sourcesModel) => sourcesModel.getSource(sid),
      builder: (context, source, child) {
        final urlStyle = TextStyle(
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        );
        final urlTile = ListTileGroup([
          MyListTile(
            title: Flexible(
                child: Text(source.url,
                    style: urlStyle, overflow: TextOverflow.ellipsis)),
            trailing: Icon(
              CupertinoIcons.doc_on_clipboard,
              semanticLabel: AppLocalizations.of(context).copy,
            ),
            onTap: () {
              Clipboard.setData(ClipboardData(text: source.url));
            },
            trailingChevron: false,
            withDivider: false,
          ),
        ], title: "URL");
        final editSource = ListTileGroup([
          MyListTile(
            title: Text(AppLocalizations.of(context).name),
            onTap: () {
              _editName(context, source);
            },
          ),
          MyListTile(
            title: Text(AppLocalizations.of(context).icon),
            onTap: () {
              _editIcon(context, source);
            },
            withDivider: false,
          ),
        ], title: AppLocalizations.of(context).edit);
        final openTarget = ListTileGroup.fromOptions(
          [
            Tuple2(
                AppLocalizations.of(context).rssText, SourceOpenTarget.Local),
            Tuple2(AppLocalizations.of(context).loadFull,
                SourceOpenTarget.FullContent),
            Tuple2(AppLocalizations.of(context).loadWebpage,
                SourceOpenTarget.Webpage),
            Tuple2(AppLocalizations.of(context).openExternal,
                SourceOpenTarget.External),
          ],
          source.openTarget,
          (v) {
            var cloned = source.clone();
            cloned.openTarget = v;
            Global.sourcesModel.put(cloned);
          },
          title: AppLocalizations.of(context).openTarget,
        );
        return CupertinoPageScaffold(
          backgroundColor: MyColors.background,
          navigationBar: CupertinoNavigationBar(
            middle: Text(source.name, overflow: TextOverflow.ellipsis),
          ),
          child: ListView(
            children: [
              urlTile,
              editSource,
              openTarget,
            ],
          ),
        );
      },
    );
  }
}
