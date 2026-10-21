import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/global_model.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart' as legacy_cupertino;
import 'package:flutter/material.dart' as legacy_material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:overlay_dialog/overlay_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Store.sp = await SharedPreferences.getInstance();
    // Exercise the real app without starting its database or HTTP server.
    Global.globalModel = GlobalModel();
    Global.sourcesModel = SourcesModel();
    Global.itemsModel = ItemsModel();
    Global.feedsModel = FeedsModel();
    Global.groupsModel = GroupsModel();
    Global.syncModel = SyncModel();
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

  for (final locale in S.delegate.supportedLocales) {
    testWidgets('Setup and service navigation work in $locale', (tester) async {
      Global.globalModel!.locale = locale;
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();

      expect(find.text(S.current.welcome), findsOneWidget);
      final context = tester.element(find.byType(SetupPage));
      expect(CupertinoLocalizations.of(context).copyButtonLabel, isNotEmpty);
      expect(MaterialLocalizations.of(context).okButtonLabel, isNotEmpty);
      expect(
        legacy_cupertino.CupertinoLocalizations.of(context).copyButtonLabel,
        isNotEmpty,
      );
      expect(
        legacy_material.MaterialLocalizations.of(context).okButtonLabel,
        isNotEmpty,
      );

      await tester.tap(find.text('Feedbin'));
      await tester.pumpAndSettle();
      expect(find.text(S.current.username), findsOneWidget);
      expect(find.text(S.current.password), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Legacy dialogs and sheets inherit dark theme and localization', (
    tester,
  ) async {
    Global.globalModel!.theme = ThemeSetting.Dark;
    Global.globalModel!.locale = const Locale('zh');
    Global.globalModel!.textScale = 1.125;
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SetupPage));
    expect(
      legacy_cupertino.CupertinoTheme.of(context).brightness,
      Brightness.dark,
    );
    expect(legacy_material.Theme.of(context).brightness, Brightness.dark);
    expect(MediaQuery.textScalerOf(context).scale(16), 18);

    DialogHelper().show(
      context,
      DialogWidget.alert(
        style: DialogStyle.cupertino,
        title: 'Legacy dialog',
        content: 'Localized dialog content',
        actions: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legacy dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
    DialogHelper().hideImmediate(context);
    await tester.pumpAndSettle();

    final sheet = CupertinoScaffold.showCupertinoModalBottomSheet<void>(
      context: context,
      builder: (_) => const CupertinoPageScaffold(
        child: Center(child: Text('Legacy sheet')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Legacy sheet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await sheet;

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
