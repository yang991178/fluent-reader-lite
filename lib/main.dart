import 'dart:io';

import 'package:fluent_reader_lite/models/service.dart';
import 'package:fluent_reader_lite/pages/article_page.dart';
import 'package:fluent_reader_lite/pages/error_log_page.dart';
import 'package:fluent_reader_lite/pages/settings/about_page.dart';
import 'package:fluent_reader_lite/pages/home_page.dart';
import 'package:fluent_reader_lite/pages/settings/feed_page.dart';
import 'package:fluent_reader_lite/pages/settings/general_page.dart';
import 'package:fluent_reader_lite/pages/settings/reading_page.dart';
import 'package:fluent_reader_lite/pages/settings/services/feedbin_page.dart';
import 'package:fluent_reader_lite/pages/settings/services/fever_page.dart';
import 'package:fluent_reader_lite/pages/settings/services/greader_page.dart';
import 'package:fluent_reader_lite/pages/settings/services/inoreader_page.dart';
import 'package:fluent_reader_lite/pages/settings/source_edit_page.dart';
import 'package:fluent_reader_lite/pages/settings/sources_page.dart';
import 'package:fluent_reader_lite/pages/settings_page.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'generated/l10n.dart';
import 'models/global_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Store.sp = await SharedPreferences.getInstance();
  Global.init();
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));
    WebView.platform = SurfaceAndroidWebView();
  }
  runApp(MyApp());
  SystemChannels.lifecycle.setMessageHandler((msg) {
    if (msg == AppLifecycleState.resumed.toString()) {
      if (Global.server != null) Global.server.restart();
      if (Global.globalModel.syncOnStart &&
          DateTime.now().difference(Global.syncModel.lastSynced).inMinutes >=
              10) {
        Global.syncModel.syncWithService();
      }
    }
    return null;
  });
}

class MyApp extends StatelessWidget {
  static final Map<String, Widget Function(BuildContext)> baseRoutes = {
    "/article": (context) => ArticlePage(),
    "/error-log": (context) => ErrorLogPage(),
    "/settings": (context) => SettingsPage(),
    "/settings/sources": (context) => SourcesPage(),
    "/settings/sources/edit": (context) => SourceEditPage(),
    "/settings/feed": (context) => FeedPage(),
    "/settings/reading": (context) => ReadingPage(),
    "/settings/general": (context) => GeneralPage(),
    "/settings/about": (context) => AboutPage(),
    "/settings/service/fever": (context) => FeverPage(),
    "/settings/service/feedbin": (context) => FeedbinPage(),
    "/settings/service/inoreader": (context) => InoreaderPage(),
    "/settings/service/greader": (context) => GReaderPage(),
    "/settings/service": (context) {
      var serviceType =
          SyncService.values[Store.sp.getInt(StoreKeys.SYNC_SERVICE) ?? 0];
      switch (serviceType) {
        case SyncService.None:
          break;
        case SyncService.Fever:
          return FeverPage();
        case SyncService.Feedbin:
          return FeedbinPage();
        case SyncService.GReader:
          return GReaderPage();
          break;
        case SyncService.Inoreader:
          return InoreaderPage();
          break;
      }
      return AboutPage();
    }
  };
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: Global.globalModel),
        ChangeNotifierProvider.value(value: Global.sourcesModel),
        ChangeNotifierProvider.value(value: Global.itemsModel),
        ChangeNotifierProvider.value(value: Global.feedsModel),
        ChangeNotifierProvider.value(value: Global.groupsModel),
        ChangeNotifierProvider.value(value: Global.syncModel),
      ],
      child: Consumer<GlobalModel>(
        builder: (context, globalModel, child) => CupertinoApp(
          title: "Fluent Reader",
          debugShowCheckedModeBanner: false,
          localizationsDelegates: [
            // ... app-specific localization delegate[s] here
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: globalModel.locale,
          supportedLocales: [
            const Locale("de"),
            const Locale("en"),
            const Locale("es"),
            const Locale("zh"),
            const Locale("fr"),
            const Locale("uk"),
            const Locale("hr"),
            const Locale("pt"),
          ],
          localeResolutionCallback: (_locale, supportedLocales) {
            _locale = Locale(_locale.languageCode);
            if (globalModel.locale != null)
              return globalModel.locale;
            else if (supportedLocales.contains(_locale))
              return _locale;
            else
              return Locale("en");
          },
          theme: CupertinoThemeData(
            primaryColor: CupertinoColors.systemBlue,
            brightness: globalModel.getBrightness(),
          ),
          routes: {
            "/": (context) => CupertinoScaffold(body: HomePage()),
            ...baseRoutes,
          },
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            if (Global.globalModel.textScale == null) return child;
            return MediaQuery(
                data: mediaQueryData.copyWith(
                    textScaleFactor: Global.globalModel.textScale),
                child: child);
          },
        ),
      ),
    );
  }
}
