import 'package:fluent_reader_lite/components/badge.dart';
import 'package:fluent_reader_lite/components/dismissible_background.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GroupListPage extends StatefulWidget {
  @override
  _GroupListPageState createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  static const List<String> _uncategorizedIndicator = [null, null];

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
        minSize: 36,
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
          onTap: () { Navigator.of(context).pop(List<String>.empty()); },
          background: CupertinoColors.systemBackground,
        ));
      },
    );
    final dismissBg = DismissibleBackground(CupertinoIcons.checkmark_circle, true);
    final groupList = Consumer2<GroupsModel, SourcesModel>(
      builder: (context, groupsModel, sourcesModel, child) {
        final groupNames = groupsModel.groups.keys.toList();
        groupNames.sort(Utils.localStringCompare);
        if (groupsModel.uncategorized != null) {
          groupNames.insert(0, null);
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            String groupName;
            List<String> group;
            final isUncategorized = groupsModel.showUncategorized && index == 0;
            if (isUncategorized) {
              groupName = S.of(context).uncategorized;
              group = groupsModel.uncategorized;
            } else {
              groupName = groupNames[index];
              group = groupsModel.groups[groupName];
            }
            final count = _unreadCount(
              group.map((sid) => sourcesModel.getSource(sid))
            );
            final tile = MyListTile(
              title: Flexible(child: Text(groupName, overflow: TextOverflow.ellipsis)),
              trailing: count > 0 ? Badge(count) : null,
              onTap: () { 
                Navigator.of(context).pop(
                  isUncategorized ? _uncategorizedIndicator : [groupName]
                );
              },
              background: CupertinoColors.systemBackground,
            );
            return Dismissible(
              key: Key("$groupName$index"),
              child: tile,
              background: dismissBg,
              direction: DismissDirection.startToEnd,
              dismissThresholds: _dismissThresholds,
              confirmDismiss: (_) async {
                HapticFeedback.mediumImpact();
                Set<String> sids = Set.from(group);
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
