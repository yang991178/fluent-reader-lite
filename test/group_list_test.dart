import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/components/subscription_item.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/feed.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/item.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/pages/group_list_page.dart';
import 'package:fluent_reader_lite/pages/item_list_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/reader_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _GroupFeeds feeds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.sp = await SharedPreferences.getInstance();
    initializeReaderFixture();
    final all = Global.feedsModel!.all;
    Global.feedsModel!.dispose();
    Global.feedsModel = feeds = _GroupFeeds()..all = all;
    Global.sourcesModel!.dispose();
    Global.sourcesModel = _GroupSources();
    Global.itemsModel!.loadItems([
      RSSItem(
        id: 'other',
        source: 'other',
        title: 'Outside the group',
        link: 'https://example.com/other',
        date: DateTime(2026, 10, 21),
        content: '',
        snippet: '',
        hasRead: true,
        starred: false,
      ),
    ]);
    Global.groupsModel!.groups = {
      'News': ['fixture'],
      'Empty': [],
    };
    Global.groupsModel!.showUncategorized = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.app_links/events'),
          (_) async => null,
        );
  });

  tearDown(() {
    Global.globalModel!.dispose();
    Global.sourcesModel!.dispose();
    Global.itemsModel!.dispose();
    Global.feedsModel!.dispose();
    Global.groupsModel!.dispose();
    Global.syncModel!.dispose();
  });

  Future<void> openGroups(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.subscriptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.groups));
    await tester.pumpAndSettle();
    expect(find.byType(GroupListPage), findsOneWidget);
  }

  Finder groupRow(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Dismissible));

  for (final width in [390.0, 1024.0]) {
    for (final uncategorized in [false, true]) {
      testWidgets(
        'Swipe from right opens ${uncategorized ? 'uncategorized' : 'group'} articles at $width',
        (tester) async {
          await openGroups(tester, width);
          final title = uncategorized ? S.current.uncategorized : 'News';
          final row = groupRow(title);
          final bounds = tester.getRect(row);
          await tester.dragFrom(
            Offset(bounds.right - 24, bounds.center.dy),
            Offset(-bounds.width * 0.6, 0),
          );
          await tester.pumpAndSettle();
          expect(find.byType(GroupListPage), findsNothing);
          expect(find.byType(ItemListPage), findsOneWidget);
          expect(feeds.openedSources, [uncategorized ? 'other' : 'fixture']);
          expect(feeds.source!.iids, uncategorized ? ['other'] : ['0', '1']);
          expect(
            find.text('Outside the group'),
            uncategorized ? findsOneWidget : findsNothing,
          );
          Navigator.of(tester.element(find.byType(ItemListPage))).pop();
          await tester.pumpAndSettle();
          expect(find.byType(SubscriptionItem), findsNWidgets(2));
          expect(find.text('Test source'), findsOneWidget);
          expect(find.text('Other source'), findsOneWidget);
          expect(find.text(S.current.allArticles), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets('Group tap filters subscriptions and preserves mark-read swipe', (
    tester,
  ) async {
    await openGroups(tester, 390);
    final row = groupRow('News');
    await tester.drag(row, Offset(tester.getSize(row).width * 0.6, 0));
    await tester.pumpAndSettle();
    expect(find.byType(MarkAllActionSheet), findsOneWidget);
    expect(
      tester.widget<MarkAllActionSheet>(find.byType(MarkAllActionSheet)).sids,
      {'fixture'},
    );
    expect(feeds.openedSources, isNull);
    await tester.tap(
      find.descendant(
        of: find.byType(MarkAllActionSheet),
        matching: find.text(S.current.cancel),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('News'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupListPage), findsNothing);
    expect(find.byType(ItemListPage), findsNothing);
    expect(feeds.openedSources, isNull);
    expect(find.byType(SubscriptionItem), findsOneWidget);
    await tester.tap(find.text(S.current.allArticles));
    await tester.pumpAndSettle();
    expect(feeds.openedSources, ['fixture']);
    expect(find.byType(ItemListPage), findsOneWidget);

    // Swiping a different group opens its articles without replacing the
    // subscription filter previously chosen by tapping News.
    Navigator.of(tester.element(find.byType(ItemListPage))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.groups));
    await tester.pumpAndSettle();
    final uncategorized = groupRow(S.current.uncategorized);
    await tester.drag(
      uncategorized,
      Offset(-tester.getSize(uncategorized).width * 0.6, 0),
    );
    await tester.pumpAndSettle();
    expect(feeds.openedSources, ['other']);
    expect(find.text('Outside the group'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ItemListPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionItem), findsOneWidget);
    expect(find.text('Test source'), findsOneWidget);
    expect(find.text('Other source'), findsNothing);
    expect(find.text('News'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('An empty group cannot open an unscoped article feed', (
    tester,
  ) async {
    await openGroups(tester, 390);
    final row = groupRow('Empty');
    await tester.drag(row, Offset(-tester.getSize(row).width * 0.6, 0));
    await tester.pumpAndSettle();
    expect(find.byType(GroupListPage), findsOneWidget);
    expect(feeds.openedSources, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

class _GroupSources extends SourcesModel {
  final sources = [
    RSSSource('fixture', 'https://example.com', 'Test source'),
    RSSSource('other', 'https://example.com/other', 'Other source'),
  ];

  @override
  RSSSource? getSource(String? id) =>
      sources.where((s) => s.id == id).firstOrNull;

  @override
  Iterable<RSSSource> getSources() => sources;
}

class _GroupFeeds extends FeedsModel {
  List<String?>? openedSources;

  @override
  Future<void> initSourcesFeed(Iterable<String?> sids) async {
    openedSources = sids.toList();
    source = RSSFeed(sids: sids.whereType<String>().toSet())
      ..iids = Global.itemsModel!
          .getItems()
          .where((item) => sids.contains(item.source))
          .map((item) => item.id)
          .toList()
      ..initialized = true
      ..allLoaded = true;
  }
}
