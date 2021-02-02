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
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool unreadOnly = Store.sp.getBool(StoreKeys.UNREAD_SUBS_ONLY) ?? false;

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
      _onScrollTop();
      if (result.length == 0) {
        setState(() {
          title = null;
          sids = null;
        });
      } else if (result.length > 1) {
        setState(() {
          title = S.of(context).uncategorized;
          sids = Global.groupsModel.uncategorized;
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

  void _openErrorLog() {
    if (!Global.syncModel.lastSyncSuccess) {
      HapticFeedback.mediumImpact();
      Navigator.of(context, rootNavigator: true).pushNamed("/error-log");
    }
  }

  void _toggleUnreadOnly() {
    HapticFeedback.mediumImpact();
    setState(() { unreadOnly = !unreadOnly; });
    _onScrollTop();
    Store.sp.setBool(StoreKeys.UNREAD_SUBS_ONLY, unreadOnly);
  }

  void _dismissTip() {
    if (Global.sourcesModel.showUnreadTip) {
      Global.sourcesModel.showUnreadTip = false;
      setState(() {});
    }
  }

  Widget _buildUnreadTip() {
    return SliverToBoxAdapter(child: Container(
      padding: EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(12),
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.radio_button_checked),
              ),
              Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).unreadSourceTip,
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Padding(padding: EdgeInsets.only(bottom: 6)),
                  CupertinoButton(
                    minSize: 28,
                    padding: EdgeInsets.zero,
                    child: Text(S.of(context).confirm),
                    onPressed: _dismissTip,
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titleWidget = GestureDetector(
      onLongPress: _toggleUnreadOnly,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: Global.isTablet
                ? 260
                : MediaQuery.of(context).size.width - 60,
            ),
            child: Text(
              title ?? S.of(context).subscriptions, 
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unreadOnly) Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.radio_button_checked, size: 18),
          ),
        ],
      ),
    );
    final navigationBar = CupertinoSliverNavigationBar(
      stretch: false,
      largeTitle: titleWidget,
      heroTag: "subscriptions",
      transitionBetweenRoutes: true,
      backgroundColor: transitioning ? MyColors.tileBackground : CupertinoColors.systemBackground,
      leading: CupertinoButton(
        minSize: 36,
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
          if (unreadOnly) {
            sources = sources.where((s) => s.unreadCount > 0).toList();
          }
        } else {
          sources = [];
          for (var sid in sids) {
            final source = Global.sourcesModel.getSource(sid);
            if (!unreadOnly || source.unreadCount > 0) {
              sources.add(source);
            }
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
          child: GestureDetector(
            onLongPress: _openErrorLog,
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
          ),
        );
      },
    );
    return CupertinoScrollbar(child: CustomScrollView(
      slivers: [
        navigationBar,
        SyncControl(),
        if (Global.sourcesModel.showUnreadTip) _buildUnreadTip(),
        if (sids != null && sids.length > 0) Consumer<SourcesModel>(
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