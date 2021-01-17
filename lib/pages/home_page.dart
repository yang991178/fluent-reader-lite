import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_builder/responsive_builder.dart';

import 'item_list_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class ScrollTopNotifier with ChangeNotifier {
  int index = 0;
  
  void onTap(int newIndex) {
    var oldIndex = index;
    index = newIndex;
    if (newIndex == oldIndex) notifyListeners();
  } 
}

class _HomePageState extends State<HomePage> {
  final _scrollTopNotifier = ScrollTopNotifier();

  Widget _constructPage(Widget page, bool isMobile) {
    return isMobile
      ? CupertinoPageScaffold(
        child: page,
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      )
      : Container(
        child: page,
        color: CupertinoColors.systemBackground.resolveFrom(context),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.hasService,
      builder: (context, hasService, child) {
        if (!hasService) return SetupPage();
        var isMobile = true;
        var left = CupertinoTabScaffold(
          backgroundColor: CupertinoColors.systemBackground,
          tabBar: CupertinoTabBar(
            backgroundColor: CupertinoColors.systemBackground,
            onTap: _scrollTopNotifier.onTap,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.timeline),
                label: S.of(context).feed,
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: S.of(context).subscriptions,
              ),
            ],
          ),
          tabBuilder: (context, index) {
            return CupertinoTabView(
              routes: {
                '/feed': (context) {
                  Widget page = ItemListPage(_scrollTopNotifier);
                  return _constructPage(page, isMobile);
                },
              },
              builder: (context) {
                Widget page = index == 0
                  ? ItemListPage(_scrollTopNotifier)
                  : SubscriptionListPage(_scrollTopNotifier);
                return _constructPage(page, isMobile);
              },
            );
          },
        );
        return ScreenTypeLayout.builder(
          mobile: (context) => left,
          tablet: (context) {
            isMobile = false;
            var right = Container(
              decoration: BoxDecoration(),
              clipBehavior: Clip.hardEdge,
              child: CupertinoTabView(
              navigatorKey: Global.tabletPanel,
              routes: {
                "/": (context) => TabletBasePage(),
                ...MyApp.baseRoutes,
              },
            ));
            return Container(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Row(
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: 320),
                    child: left,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                  ),
                  Expanded(child: right),
                ],
              )
            );
          },
        );
      },
    );
  }
}
