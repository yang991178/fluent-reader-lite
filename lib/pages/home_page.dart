import 'dart:async';

import 'package:fluent_reader_lite/components/article_focus_scope.dart';
import 'package:fluent_reader_lite/components/reader_pane_layout.dart';
import 'package:fluent_reader_lite/components/ios_bar_layout.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:fluent_reader_lite/components/reader_bar.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/services/service_import.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _listReveal;
  bool _focusMode = Store.sp.getBool(StoreKeys.ARTICLE_FOCUS_MODE) ?? false;
  bool _dragStartedOpen = false;
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
    _listReveal = AnimationController(
      vsync: this,
      value: _focusMode ? 1 : 0,
      duration: const Duration(milliseconds: 250),
    );
    final appLinks = AppLinks();
    _uriSub = appLinks.uriLinkStream.listen(_uriStreamListener);
  }

  @override
  dispose() {
    _uriSub.cancel();
    _listReveal.dispose();
    _scrollTopNotifier.dispose();
    _controller.dispose();
    _articleObserver.hasPages.dispose();
    for (final observer in _tabObservers) {
      observer.hasPages.dispose();
    }
    for (final controller in _heroControllers) controller.dispose();
    super.dispose();
  }

  void _toggleFocus() {
    setState(() => _focusMode = !_focusMode);
    _listReveal.value = 0;
    Store.sp.setBool(StoreKeys.ARTICLE_FOCUS_MODE, _focusMode);
  }

  void _showList() => _listReveal.animateTo(1, curve: Curves.easeOutCubic);

  void _showArticle() => _listReveal.animateTo(0, curve: Curves.easeOutCubic);

  void _startPaneDrag(DragStartDetails details) {
    _dragStartedOpen = _listReveal.value > 0.5;
    _listReveal.stop();
  }

  void _endPaneDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open = velocity.abs() > 300 ? velocity > 0 : _listReveal.value > 0.5;
    open ? _showList() : _showArticle();
  }

  void _cancelPaneDrag() => _dragStartedOpen ? _showList() : _showArticle();

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
        IosBarLayoutScope.maybeOf(context)?.row(context)?.sharesStatusArea ==
        true;
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
        backgroundColor: readerBarColor(context),
        border: Border(top: readerBarBorder(context).bottom),
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
    final sidebarWidth = readerListPaneWidth(context, focusMode: _focusMode);
    return Selector<SyncModel, bool>(
      selector: (context, syncModel) => syncModel.hasService,
      builder: (context, hasService, child) {
        if (!hasService) return SetupPage();
        final isTablet = Global.isTablet(context);
        return ListenableBuilder(
          listenable: Listenable.merge([
            _controller,
            _listReveal,
            _articleObserver.hasPages,
            for (final observer in _tabObservers) observer.hasPages,
          ]),
          builder: (context, child) {
            final hasArticle = _articleObserver.hasPages.value;
            final focused = isTablet && _focusMode;
            final reveal = focused ? _listReveal.value : 0.0;
            final articleLeft = isTablet
                ? (focused ? reveal * (sidebarWidth + 1) : sidebarWidth + 1)
                : 0.0;
            final listLeft = focused ? articleLeft - sidebarWidth - 1 : 0.0;
            final articleWidth = focused
                ? size.width
                : size.width - articleLeft;
            final hideList =
                (!isTablet && hasArticle) || (focused && reveal == 0);
            final revealListOnBack = focused && reveal < 1;
            void updatePaneDrag(DragUpdateDetails details) {
              _listReveal.value += details.delta.dx / (sidebarWidth + 1);
            }

            return ArticleFocusScope(
              available: isTablet,
              preferred: _focusMode,
              listVisible: reveal > 0,
              toggle: _toggleFocus,
              showList: _showList,
              showArticle: _showArticle,
              child: PopScope(
                canPop:
                    !hasArticle &&
                    !_tabObservers[_controller.index].hasPages.value &&
                    !revealListOnBack,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  // Handle pane navigation before forwarding Back to a nested
                  // route, including while the list is still opening.
                  if (revealListOnBack) {
                    _showList();
                    return;
                  }
                  final navigator = hasArticle
                      ? Global.articlePanel.currentState
                      : _tabNavigatorKeys[_controller.index].currentState;
                  navigator?.maybePop(result);
                },
                // Keep both navigators in the same place in the widget tree.
                // Only their bounds change, preserving the reader and WebView.
                child: Stack(
                  children: [
                    // Give blur kernels a matching background beyond the pane
                    // edge before either pane is drawn.
                    Positioned.fill(
                      child: ColoredBox(
                        color: CupertinoColors.systemBackground.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                    Positioned(
                      left: listLeft,
                      top: 0,
                      bottom: 0,
                      width: isTablet ? sidebarWidth : size.width,
                      child: ExcludeSemantics(
                        excluding: hideList,
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
                      left: listLeft + sidebarWidth,
                      top: 0,
                      bottom: 0,
                      width: 1,
                      child: Offstage(
                        offstage: !isTablet || (focused && reveal == 0),
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: articleLeft,
                      width: articleWidth,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        ignoring: !isTablet && !hasArticle,
                        child: ExcludeSemantics(
                          excluding: focused && reveal > 0,
                          child: ClipRect(
                            child: IosBarLayoutScope.pane(
                              context,
                              // Panning translates the whole page. Keep its
                              // unpanned frame so the header does not reflow.
                              bounds: Rect.fromLTWH(
                                focused ? 0 : articleLeft,
                                0,
                                articleWidth,
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
                    ),
                    // Cover the native WebView as well as its toolbars so the
                    // first tap returns to reading without activating content.
                    if (focused)
                      Positioned(
                        left: articleLeft,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: reveal == 0,
                          child: ExcludeSemantics(
                            excluding: reveal == 0,
                            child: Semantics(
                              button: true,
                              label: S.of(context).showArticle,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _showArticle,
                                onHorizontalDragStart: _startPaneDrag,
                                onHorizontalDragUpdate: updatePaneDrag,
                                onHorizontalDragEnd: _endPaneDrag,
                                onHorizontalDragCancel: _cancelPaneDrag,
                                child: ColoredBox(
                                  color: CupertinoColors.black.withValues(
                                    alpha: 0.08 * reveal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (focused)
                      Positioned(
                        key: const ValueKey('article-focus-edge'),
                        left: 0,
                        // Leave the navigation buttons tappable when the
                        // header has no horizontal padding.
                        top:
                            IosBarLayoutScope.maybeOf(context)
                                ?.row(context)
                                ?.height ??
                            MediaQuery.paddingOf(context).top +
                                kMinInteractiveDimensionCupertino,
                        bottom: 0,
                        width: 24 + MediaQuery.paddingOf(context).left,
                        child: IgnorePointer(
                          ignoring: reveal == 1,
                          child: GestureDetector(
                            excludeFromSemantics: true,
                            // Stop the native WebView receiving this pointer;
                            // a translucent strip lets WebKit take the swipe.
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: _startPaneDrag,
                            onHorizontalDragUpdate: updatePaneDrag,
                            onHorizontalDragEnd: _endPaneDrag,
                            onHorizontalDragCancel: _cancelPaneDrag,
                          ),
                        ),
                      ),
                  ],
                ),
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
