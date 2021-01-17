import 'package:fluent_reader_lite/components/badge.dart';
import 'package:fluent_reader_lite/components/dismissible_background.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GroupListPage extends StatefulWidget {
  @override
  _GroupListPageState createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  int _unreadCount(Iterable<RSSSource> sources) {
    return sources.fold(0, (c, s) => c + (s != null ? s.unreadCount : 0));
  }

  static const _dismissThresholds = {
    DismissDirection.startToEnd: 0.25,
  };

  @override
  Widget build(BuildContext context) {
    final navigationBar = CupertinoSliverNavigationBar(
      largeTitle: Text(S.of(context).groups),
      automaticallyImplyLeading: false,
      backgroundColor: Global.isTablet ? CupertinoColors.systemBackground : null,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(S.of(context).cancel),
        onPressed: () { Navigator.of(context).pop(); },
      ),
    );
    final allSources = Consumer<SourcesModel>(
      builder: (context, sourcesModel, child) {
        var count = _unreadCount(sourcesModel.getSources());
        return SliverToBoxAdapter(child: MyListTile(
          title: Text(S.of(context).allSubscriptions),
          trailing: count > 0 ? Badge(count) : null,
          onTap: () { Navigator.of(context).pop(List<String>()); },
          background: CupertinoColors.systemBackground,
        ));
      },
    );
    final dismissBg = DismissibleBackground(CupertinoIcons.checkmark_circle, true);
    final groupList = Consumer2<GroupsModel, SourcesModel>(
      builder: (context, groupsModel, sourcesModel, child) {
        final groupNames = groupsModel.groups.keys.toList();
        groupNames.sort();
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final groupName = groupNames[index];
            final count = _unreadCount(
              groupsModel.groups[groupName].map((sid) => sourcesModel.getSource(sid))
            );
            final tile = MyListTile(
              title: Flexible(child: Text(groupName, overflow: TextOverflow.ellipsis)),
              trailing: count > 0 ? Badge(count) : null,
              onTap: () { Navigator.of(context).pop([groupName]); },
              background: CupertinoColors.systemBackground,
            );
            return Dismissible(
              key: Key(groupName),
              child: tile,
              background: dismissBg,
              direction: DismissDirection.startToEnd,
              dismissThresholds: _dismissThresholds,
              confirmDismiss: (_) async {
                HapticFeedback.mediumImpact();
                Set<String> sids = Set.from(groupsModel.groups[groupName]);
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => MarkAllActionSheet(sids),
                );
                return false;
              },
            );
          }, childCount: groupNames.length),
        );
      },
    );
    final padding = SliverToBoxAdapter(child: Padding(
      padding: EdgeInsets.only(bottom: 80),
    ),);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      child: CupertinoScrollbar(child: CustomScrollView(
        slivers: [
          navigationBar,
          allSources,
          groupList,
          padding,
        ],
      ))
    );
  }
}
