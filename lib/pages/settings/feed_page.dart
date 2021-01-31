import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class FeedPage extends StatelessWidget {
  void _openGestureOptions(BuildContext context, bool isToRight) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (context) => CupertinoPageScaffold(
        backgroundColor: MyColors.background,
        navigationBar: CupertinoNavigationBar(
          middle: Text(isToRight ? S.of(context).swipeRight : S.of(context).swipeLeft),
        ),
        child: Consumer<FeedsModel>(
          builder: (context, feedsModel, child) {
            final swipeOptons = [
              Tuple2(S.of(context).toggleRead, ItemSwipeOption.ToggleRead),
              Tuple2(S.of(context).toggleStar, ItemSwipeOption.ToggleStar),
              Tuple2(S.of(context).share, ItemSwipeOption.Share),
              Tuple2(S.of(context).openExternal, ItemSwipeOption.OpenExternal),
              Tuple2(S.of(context).openMenu, ItemSwipeOption.OpenMenu),
            ];
            return ListView(children: [
              ListTileGroup.fromOptions(
                swipeOptons,
                isToRight ? feedsModel.swipeR : feedsModel.swipeL,
                (v) { 
                  if (isToRight) feedsModel.swipeR = v;
                  else feedsModel.swipeL = v;
                },
              ),
            ]);
          },
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).feed),
      ),
      child: Consumer<FeedsModel>(
        builder: (context, feedsModel, child) {
          final swipeOptons = {
            ItemSwipeOption.ToggleRead: S.of(context).toggleRead,
            ItemSwipeOption.ToggleStar: S.of(context).toggleStar,
            ItemSwipeOption.Share: S.of(context).share,
            ItemSwipeOption.OpenExternal: S.of(context).openExternal,
            ItemSwipeOption.OpenMenu: S.of(context).openMenu,
          };
          final preferences = ListTileGroup([
            MyListTile(
              title: Text(S.of(context).showThumb),
              trailing: CupertinoSwitch(
                value: feedsModel.showThumb,
                onChanged: (v) { feedsModel.showThumb = v; },
              ),
              trailingChevron: false,
            ),
            MyListTile(
              title: Text(S.of(context).showSnippet),
              trailing: CupertinoSwitch(
                value: feedsModel.showSnippet,
                onChanged: (v) { feedsModel.showSnippet = v; },
              ),
              trailingChevron: false,
            ),
            MyListTile(
              title: Text(S.of(context).dimRead),
              trailing: CupertinoSwitch(
                value: feedsModel.dimRead,
                onChanged: (v) { feedsModel.dimRead = v; },
              ),
              trailingChevron: false,
              withDivider: false,
            ),
          ], title: S.of(context).preferences);
          final groups = ListTileGroup([
            Consumer<GroupsModel>(
              builder: (context, groupsModel, child) {
                return MyListTile(
                  title: Text(S.of(context).showUncategorized),
                  trailing: CupertinoSwitch(
                    value: groupsModel.showUncategorized,
                    onChanged: (v) { groupsModel.showUncategorized = v; },
                  ),
                  trailingChevron: false,
                  withDivider: false,
                );
              },
            ),
          ], title: S.of(context).groups);
          return ListView(
            children: [
              preferences,
              groups,
              ListTileGroup([
                MyListTile(
                  title: Text(S.of(context).swipeRight),
                  trailing: Text(swipeOptons[feedsModel.swipeR]),
                  onTap: () { _openGestureOptions(context, true); },
                ),
                MyListTile(
                  title: Text(S.of(context).swipeLeft),
                  trailing: Text(swipeOptons[feedsModel.swipeL]),
                  onTap: () { _openGestureOptions(context, false); },
                  withDivider: false,
                ),
              ], title: S.of(context).gestures),
            ],
          );
        },
      ),
    );
  }
}