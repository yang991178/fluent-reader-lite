import 'package:fluent_reader_lite/components/favicon.dart';
import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class SourcesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).subscriptions),
      ),
      child: ListView(children: [
        Consumer<SourcesModel>(
          builder: (context, sourcesModel, child) {
            var sources = sourcesModel.getSources().toList();
            sources.sort((a, b) => Utils.localStringCompare(a.name, b.name));
            return ListTileGroup(sources.map((s) => MyListTile(
              title: Flexible(child: Text(s.name, overflow: TextOverflow.ellipsis)),
              leading: Favicon(s, size: 20),
              withDivider: s.id != sources.last.id,
              onTap: () {
                Navigator.of(context).pushNamed("/settings/sources/edit", arguments: s.id);
              },
            )));
          },
        ),
      ]),
    ); 
  }
}