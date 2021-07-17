import 'dart:async';

import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/services/service_import.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:uni_links/uni_links.dart';

import 'item_list_page.dart';

class HomePage extends StatefulWidget {
  HomePage() : super(key: Key("home"));

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
  final _controller = CupertinoTabController();
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys = [
    GlobalKey(),
    GlobalKey(),
  ];
  StreamSubscription _uriSub;

  void _uriStreamListener(Uri uri) {
    if (uri == null) return;
    if (uri.host == "import") {
      if (Global.syncModel.hasService) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(S.of(context).serviceExists),
            actions: [
              CupertinoDialogAction(
                child: Text(S.of(context).confirm),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      } else if (!Global.syncModel.syncing) {
        final import = ServiceImport(uri.queryParameters);
        final route = ServiceImport.typeMap[uri.queryParameters["t"]];
        if (route != null) {
          final navigator = Navigator.of(context);
          while (navigator.canPop()) navigator.pop();
          navigator.pushNamed(route, arguments: import);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _uriSub = uriLinkStream.listen(_uriStreamListener);
    Future.delayed(Duration.zero, () async {
      try {
        final uri = await getInitialUri();
        if (uri != null) {
          _uriStreamListener(uri);
        }
      } catch (exp) {
        print(exp);
      }
    });
  }

  @override
  dispose() {
    _uriSub.cancel();
    super.dispose();
  }

  Widget _constructPage(Widget page, bool isMobile) {
    return isMobile
        ? CupertinoPageScaffold(
            child: page,
            backgroundColor:
                CupertinoColors.systemBackground.resolveFrom(context),
          )
        : Container(
            child: page,
            color: CupertinoColors.systemBackground.resolveFrom(context),
          );
  }

  Widget buildLeft(BuildContext context, {isMobile: true}) {
    final leftTabs = CupertinoTabScaffold(
      controller: _controller,
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
          navigatorKey: _tabNavigatorKeys[index],
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
    return WillPopScope(
      child: leftTabs,
      onWillPop: () async {
        return !(await _tabNavigatorKeys[_controller.index]
            .currentState
            .maybePop());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.hasService,
      builder: (context, hasService, child) {
        if (!hasService) return SetupPage();
        return ScreenTypeLayout.builder(
          breakpoints: ScreenBreakpoints(
            tablet: 640,
            watch: 0,
            desktop: 1600,
          ),
          mobile: (context) => buildLeft(context),
          tablet: (context) {
            final left = buildLeft(context, isMobile: false);
            final right = Container(
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
                ));
          },
        );
      },
    );
  }
}
