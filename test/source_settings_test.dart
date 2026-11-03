import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/badge.dart';
import 'package:fluent_reader_lite/components/mark_all_action_sheet.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/source.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/pages/item_list_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/reader_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _SettingsSources sources;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.sp = await SharedPreferences.getInstance();
    initializeReaderFixture();
    Global.sourcesModel!.dispose();
    Global.sourcesModel = sources = _SettingsSources();
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

  for (final width in [390.0, 1024.0]) {
    testWidgets(
      'Source visibility switch works at $width with a translated label',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Global.globalModel!.locale = const Locale('de');
        Global.globalModel!.textScale = 1.3;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(MyApp());
        await tester.pumpAndSettle();
        Navigator.of(
          tester.element(find.byType(ItemListPage)),
          rootNavigator: true,
        ).pushNamed('/settings/sources/edit', arguments: 'fixture');
        await tester.pumpAndSettle();
        final toggle = find.byType(CupertinoSwitch);
        await tester.ensureVisible(toggle);
        expect(find.text(S.current.hideFromAllArticles), findsOneWidget);
        expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
        expect(
          tester.getSemantics(toggle).label,
          S.current.hideFromAllArticles,
        );
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(sources.changedSource, 'fixture');
        expect(sources.getSource('fixture')!.hidden, isTrue);
        expect(tester.widget<CupertinoSwitch>(toggle).value, isTrue);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(sources.getSource('fixture')!.hidden, isFalse);
        expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets(
    'Feed badge and bulk actions exclude hidden sources; subscriptions include them',
    (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).label, '2');
      await tester.tap(find.byIcon(CupertinoIcons.checkmark_circle));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkAllActionSheet>(find.byType(MarkAllActionSheet)).sids,
        {'fixture'},
      );
      await tester.tap(find.text(S.current.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Badge>(find.byType(Badge))
            .map((badge) => badge.label),
        containsAll(['2', '5']),
      );
      await tester.tap(find.byIcon(CupertinoIcons.checkmark_circle));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MarkAllActionSheet>(find.byType(MarkAllActionSheet)).sids,
        {'fixture', 'quiet'},
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _SettingsSources extends SourcesModel {
  final sources = {
    'fixture': RSSSource('fixture', 'https://example.com/feed', 'Test source')
      ..unreadCount = 2,
    'quiet': RSSSource('quiet', 'https://example.com/quiet', 'Quiet source')
      ..hidden = true
      ..unreadCount = 5,
  };
  String? changedSource;

  @override
  RSSSource? getSource(String? id) => sources[id];

  @override
  Iterable<RSSSource> getSources() => sources.values;

  @override
  Future<void> setHidden(String sid, bool hidden) async {
    changedSource = sid;
    sources[sid] = sources[sid]!.clone()..hidden = hidden;
    notifyListeners();
  }
}
