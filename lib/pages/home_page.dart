import 'dart:async';

import 'package:fluent_reader_lite/components/ios_bar_layout.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/services/service_import.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';

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
  final _articleObserver = _NavigationObserver();
  final _tabObservers = List.generate(2, (_) => _NavigationObserver());
  final _heroControllers = List.generate(
    3,
    (_) => CupertinoApp.createCupertinoHeroController(),
  );
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys = [
    GlobalKey(),
    GlobalKey(),
  ];
  late StreamSubscription _uriSub;

  void _uriStreamListener(Uri? uri) {
    if (uri == null) return;
    if (uri.host == "import") {
      if (Global.syncModel!.hasService) {
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
      } else if (!Global.syncModel!.syncing) {
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
    final appLinks = AppLinks();
    _uriSub = appLinks.uriLinkStream.listen(_uriStreamListener);
  }

  @override
  dispose() {
    _uriSub.cancel();
    _scrollTopNotifier.dispose();
    _controller.dispose();
    _articleObserver.hasPages.dispose();
    for (final observer in _tabObservers) observer.hasPages.dispose();
    for (final controller in _heroControllers) controller.dispose();
    super.dispose();
  }

  Widget _constructPage(BuildContext context, Widget page) {
    final scrollController = PrimaryScrollController.of(context);
    final scaffold = ReaderPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: PrimaryScrollController(controller: scrollController, child: page),
    );
    // Status-bar events carry no tap location, so Duo's shared-row buttons can
    // also trigger them. Keep the controller on the list (including explicit
    // tab scroll-to-top), but hide it from the scaffold's automatic handler.
    final sharedStatusRow =
        IosBarLayoutScope.maybeOf(context)?.row(context) != null;
    return Global.isTablet(context) || sharedStatusRow
        ? PrimaryScrollController.none(child: scaffold)
        : PrimaryScrollController(
            controller: scrollController,
            child: scaffold,
          );
  }

  Widget _buildNavigator({
    required GlobalKey<NavigatorState> navigatorKey,
    required HeroController heroController,
    required NavigatorObserver observer,
    required Map<String, WidgetBuilder> routes,
  }) {
    // Handle system Back once at the home level, rather than independently
    // in each pane as CupertinoTabView does.
    return HeroControllerScope(
      controller: heroController,
      child: Navigator(
        key: navigatorKey,
        observers: [observer],
        onGenerateRoute: (settings) {
          final builder = routes[settings.name];
          if (builder == null) return null;
          if (navigatorKey == Global.articlePanel &&
              settings.name == Navigator.defaultRouteName) {
            return _ArticleBaseRoute(builder: builder, settings: settings);
          }
          return CupertinoPageRoute(builder: builder, settings: settings);
        },
      ),
    );
  }

  Widget buildLeft(BuildContext context) {
    return CupertinoTabScaffold(
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
        return _buildNavigator(
          navigatorKey: _tabNavigatorKeys[index],
          heroController: _heroControllers[index],
          observer: _tabObservers[index],
          routes: {
            '/': (context) {
              Widget page = index == 0
                  ? ItemListPage(_scrollTopNotifier)
                  : SubscriptionListPage(_scrollTopNotifier);
              return _constructPage(context, page);
            },
            '/feed': (context) {
              Widget page = ItemListPage(_scrollTopNotifier);
              return _constructPage(context, page);
            },
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final layout = IosBarLayoutScope.maybeOf(context)?.layout;
    final equalSplit =
        layout?.size == size &&
        layout?.division != null &&
        size.width > size.height;
    final sidebarWidth = equalSplit ? (size.width - 1) / 2 : 320.0;
    return Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.hasService,
      builder: (context, hasService, child) {
        if (!hasService) return SetupPage();
        final isTablet = Global.isTablet(context);
        return ListenableBuilder(
          listenable: Listenable.merge([
            _controller,
            _articleObserver.hasPages,
            for (final observer in _tabObservers) observer.hasPages,
          ]),
          builder: (context, child) {
            final hasArticle = _articleObserver.hasPages.value;
            return PopScope(
              canPop:
                  !hasArticle &&
                  !_tabObservers[_controller.index].hasPages.value,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                final navigator = hasArticle
                    ? Global.articlePanel.currentState
                    : _tabNavigatorKeys[_controller.index].currentState;
                navigator?.maybePop(result);
              },
              // Keep both navigators in the same place in the widget tree.
              // Only their bounds change, preserving the reader and WebView.
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: isTablet ? sidebarWidth : size.width,
                    child: ExcludeSemantics(
                      excluding: !isTablet && hasArticle,
                      child: IosBarLayoutScope.pane(
                        context,
                        bounds: Rect.fromLTWH(
                          0,
                          0,
                          isTablet ? sidebarWidth : size.width,
                          MediaQuery.sizeOf(context).height,
                        ),
                        child: buildLeft(context),
                      ),
                    ),
                  ),
                  Positioned(
                    left: sidebarWidth,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: Offstage(
                      offstage: !isTablet,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    left: isTablet ? sidebarWidth + 1 : 0,
                    child: IgnorePointer(
                      ignoring: !isTablet && !hasArticle,
                      child: ClipRect(
                        child: IosBarLayoutScope.pane(
                          context,
                          bounds: Rect.fromLTWH(
                            isTablet ? sidebarWidth + 1 : 0,
                            0,
                            MediaQuery.sizeOf(context).width -
                                (isTablet ? sidebarWidth + 1 : 0),
                            MediaQuery.sizeOf(context).height,
                          ),
                          child: _buildNavigator(
                            navigatorKey: Global.articlePanel,
                            heroController: _heroControllers[2],
                            observer: _articleObserver,
                            routes: {
                              '/': (context) => Global.isTablet(context)
                                  ? TabletBasePage()
                                  : const SizedBox.expand(),
                              ...MyApp.baseRoutes,
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ArticleBaseRoute extends CupertinoPageRoute<void> {
  _ArticleBaseRoute({required super.builder, required super.settings});

  // The placeholder is transparent on phones, including its route barrier.
  @override
  Color? get barrierColor => null;
}

class _NavigationObserver extends NavigatorObserver {
  final hasPages = ValueNotifier(false);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    hasPages.value = !topRoute.isFirst;
  }
}
