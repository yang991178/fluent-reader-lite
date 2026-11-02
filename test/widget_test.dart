import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/main.dart';
import 'package:fluent_reader_lite/models/feeds_model.dart';
import 'package:fluent_reader_lite/models/global_model.dart';
import 'package:fluent_reader_lite/models/groups_model.dart';
import 'package:fluent_reader_lite/models/items_model.dart';
import 'package:fluent_reader_lite/models/sources_model.dart';
import 'package:fluent_reader_lite/models/sync_model.dart';
import 'package:fluent_reader_lite/pages/setup_page.dart';
import 'package:fluent_reader_lite/pages/item_list_page.dart';
import 'package:fluent_reader_lite/pages/subscription_list_page.dart';
import 'package:fluent_reader_lite/pages/tablet_base_page.dart';
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

  testWidgets(
    'Duo keeps the subscription toggle with trailing actions and a large title',
    (tester) async {
      final semantics = tester.ensureSemantics();
      const channel = 'me.hyliu.fluent_reader_lite/ios_bar_layout';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(channel),
        (_) async => null,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel(channel),
          null,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(466, 678);
      tester.view.padding = const FakeViewPadding(top: 82, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 82, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      Global.syncModel!.hasService = true;
      Global.feedsModel!.all
        ..initialized = true
        ..allLoaded = true;
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      Future<void> sendGeometry(List<double>? toolbar) async {
        await messenger.handlePlatformMessage(
          channel,
          const StandardMethodCodec().encodeSuccessEnvelope({
            'width': 466.0,
            'height': 678.0,
            'topInset': 82.0,
            'toolbar': toolbar,
          }),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await sendGeometry([16, 26, 250, 44]);
      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();
      final toggle = find.byIcon(Icons.radio_button_unchecked);
      final markAll = find.byIcon(CupertinoIcons.checkmark_circle);
      final settings = find.byIcon(CupertinoIcons.settings);
      expect(tester.widget<Icon>(toggle).semanticLabel, S.current.unreadOnly);
      expect(tester.getCenter(toggle).dy, 48);
      expect(tester.getCenter(markAll).dy, 48);
      expect(tester.getCenter(settings).dy, 48);
      final groups = find.ancestor(
        of: find.text(S.current.groups),
        matching: find.byType(CupertinoButton),
      );
      expect(tester.getRect(groups).left, 16);
      expect(
        tester.getRect(toggle).right,
        lessThan(tester.getRect(markAll).left),
      );
      expect(
        tester.getRect(markAll).right,
        lessThan(tester.getRect(settings).left),
      );
      expect(tester.getRect(settings).right, lessThan(280));
      final title = find.descendant(
        of: find.byType(ReaderSliverNavigationBar),
        matching: find.text(S.current.subscriptions),
      );
      expect(tester.getTopLeft(title).dy, greaterThan(82));
      expect(DefaultTextStyle.of(tester.element(title)).style.fontSize, 34);
      // The narrowest frame captured with a compact Live Activity must leave
      // all three subscription actions and the Groups button reachable.
      await sendGeometry([2.3333333333333335, 26, 211, 44]);
      final groupsButton = find
          .ancestor(
            of: find.text(S.current.groups),
            matching: find.byType(CupertinoButton),
          )
          .first;
      expect(groupsButton.hitTestable(), findsOneWidget);
      for (final icon in [toggle, markAll, settings]) {
        expect(icon.hitTestable(), findsOneWidget);
        expect(tester.getCenter(icon).dy, 48);
        expect(tester.getRect(icon).right, lessThan(213.33333333333334 + 16));
      }
      expect(tester.getTopLeft(title).dy, greaterThan(82));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(Store.sp.getBool(StoreKeys.UNREAD_SUBS_ONLY), isTrue);
      // Returning to ordinary geometry removes only the Duo-specific button.
      await sendGeometry([18, 82, 430, 44]);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.semanticLabel == S.current.allSubscriptions,
        ),
        findsNothing,
      );
      // A custom iPad row avoids window controls without sharing status UI.
      await messenger.handlePlatformMessage(
        channel,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'width': 466.0,
          'height': 678.0,
          'topInset': 82.0,
          'toolbar': [66.0, 82.0, 384.0, 44.0],
          'avoidsWindowControls': true,
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.semanticLabel == S.current.allSubscriptions,
        ),
        findsNothing,
      );
      await sendGeometry([18, 82, 430, 44]);
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('All tabs inherit theme changes at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      Global.syncModel!.hasService = true;
      // Short labels keep the test font within the narrow tablet sidebar.
      Global.globalModel!.locale = const Locale('zh');
      Global.feedsModel!.all
        ..initialized = true
        ..allLoaded = true;

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.current.subscriptions));
      await tester.pumpAndSettle();

      void expectBrightness(Brightness brightness) {
        for (final type in [
          ItemListPage,
          SubscriptionListPage,
          if (size.width > 640) TabletBasePage,
        ]) {
          final context = tester.element(
            find.byType(type, skipOffstage: false),
          );
          expect(CupertinoTheme.brightnessOf(context), brightness);
          expect(
            CupertinoColors.systemBackground.resolveFrom(context).toARGB32(),
            brightness == Brightness.dark
                ? CupertinoColors.black.toARGB32()
                : CupertinoColors.white.toARGB32(),
          );
        }
      }

      // Change the preference from the same settings route used in the report.
      final context = tester.element(find.byType(SubscriptionListPage));
      Navigator.of(context, rootNavigator: true).pushNamed('/settings/general');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(S.current.dark));
      await tester.tap(find.text(S.current.dark));
      await tester.pumpAndSettle();
      Navigator.of(context, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      expectBrightness(Brightness.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      Global.globalModel!.theme = ThemeSetting.Light;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.light);

      Global.globalModel!.theme = ThemeSetting.Default;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expectBrightness(Brightness.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
