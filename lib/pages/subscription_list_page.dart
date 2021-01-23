import 'package:fluent_reader_lite/components/badge.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/my_list_tile.dart';
import 'package:fluent_reader_lite/components/subscription_item.dart';
import 'package:fluent_reader_lite/components/sync_control.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/group_list_page.dart';
import 'package:fluent_reader_lite/pages/home_page.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

class SubscriptionListPage extends StatefulWidget {
  final ScrollTopNotifier scrollTopNotifier;

  SubscriptionListPage(this.scrollTopNotifier, {Key key}) : super(key: key);

  @override
  _SubscriptionListPageState createState() {
    return _SubscriptionListPageState();
  }
}

class _SubscriptionListPageState extends State<SubscriptionListPage> {
  List<String> sids;
  String title;
  bool transitioning = false;

  void _onScrollTop() {
    if (widget.scrollTopNotifier.index == 1 && !Navigator.of(context).canPop()) {
      PrimaryScrollController.of(context).animateTo(
        0,
        curve: Curves.easeOut,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.scrollTopNotifier.addListener(_onScrollTop);
  }
  
  @override
  void dispose() {
    widget.scrollTopNotifier.removeListener(_onScrollTop);
    super.dispose();
  }

  void _openGroups() async {
    List<String> result;
    if (Global.isTablet) {
      result = await Navigator.of(context).push(CupertinoPageRoute(
        builder: (context) => GroupListPage(),
      ));
    } else {
      setState(() { transitioning = true; });
      result = await CupertinoScaffold.showCupertinoModalBottomSheet(
        context: context,
        useRootNavigator: true,
        builder: (context) => GroupListPage(),
      );
    }
    if (!mounted) return;
    if (result != null) {
      if (result.length == 0) {
        setState(() {
          title = null;
          sids = null;
        });
      } else {
        setState(() {
          title = result[0];
          sids = Global.groupsModel.groups[title];
        });
      }
    }
    await Future.delayed(Duration(milliseconds: 300));
    setState(() { transitioning = false; });
  }

  void _openMarkAllModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MarkAllActionSheet(sids == null ? {} : Set.from(sids)),
    );
  }

  void _openSettings() {
    Navigator.of(context, rootNavigator: true).pushNamed("/settings");
  }

  @override
  Widget build(BuildContext context) {
    final navigationBar = CupertinoSliverNavigationBar(
      stretch: false,
      largeTitle: Text(title ?? S.of(context).subscriptions),
      heroTag: "subscriptions",
      transitionBetweenRoutes: true,
      backgroundColor: transitioning ? MyColors.tileBackground : CupertinoColors.systemBackground,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        child: Text(S.of(context).groups),
        onPressed: _openGroups,
      ),
      trailing: Container(
        transform: Matrix4.translationValues(12, 0, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                CupertinoIcons.checkmark_circle,
                semanticLabel: S.of(context).markAll,
              ),
              onPressed: _openMarkAllModal,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                CupertinoIcons.settings,
                semanticLabel: S.of(context).settings,
              ),
              onPressed: _openSettings,
            ),
          ],
        ), 
      )
    );
    final sourcesList = Consumer<SourcesModel>(
      builder: (context, sourcesModel, child) {
        List<RSSSource> sources;
        if (sids == null) {
          sources = Global.sourcesModel.getSources().toList();
        } else {
          sources = [];
          for (var sid in sids) {
            sources.add(Global.sourcesModel.getSource(sid));
          }
        }
        // Latest sources first
        sources.sort((a, b) {
          return b.latest.compareTo(a.latest);
        });
        return SliverList(
          delegate: SliverChildBuilderDelegate((content, index) {
            var source = sources[index];
            return SubscriptionItem(source, key: Key(source.id));
          }, childCount: sources.length),
        );
      },
    );
    final syncStyle = TextStyle(
      fontSize: 14,
      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
    );
    final syncInfo = Consumer<SyncModel>(
      builder: (context, syncModel, child) {
        return SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  syncModel.lastSyncSuccess
                    ? S.of(context).lastSyncSuccess
                    : S.of(context).lastSyncFailure,
                  style: syncStyle,
                ),
                Text(
                  DateFormat
                    .Md(Localizations.localeOf(context).toString())
                    .add_Hm().format(syncModel.lastSynced),
                  style: syncStyle,
                ),
              ],
            ),
          ),
        );
      },
    );
    return CupertinoScrollbar(child: CustomScrollView(
      slivers: [
        navigationBar,
        SyncControl(),
        if (sids != null) Consumer<SourcesModel>(
          builder: (context, sourcesModel, child) {
            var count = sids
              .map((sid) => sourcesModel.getSource(sid))
              .fold(0, (c, s) => c + s.unreadCount);
            return SliverToBoxAdapter(child: MyListTile(
              title: Text(S.of(context).allArticles),
              trailing: count > 0 ? Badge(count) : null,
              trailingChevron: false,
              onTap: () async { 
                await Global.feedsModel.initSourcesFeed(sids.toList());
                Navigator.of(context).pushNamed("/feed", arguments: title);
              },
              background: CupertinoColors.systemBackground,
            ));
          },
        ),
        sourcesList,
        syncInfo,
      ]
    ));
  }
  
}