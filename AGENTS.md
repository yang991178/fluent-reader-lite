# Copilot Instructions — Fluent Reader Lite

## Repository Overview

Fluent Reader Lite is an open-source, cross-platform **RSS feed reader** built with **Flutter** (Dart). It targets **iOS** (15.0+) and **Android** (API 24+). It supports Fever API, Google Reader API, Inoreader, and Feedbin as backend sync services. The codebase is ~40 Dart files with no native platform code beyond the standard Flutter boilerplate.

**Flutter version:** 3.47.x (stable channel). **Dart SDK:** >=3.13.0 <4.0.0 (see `pubspec.yaml`).
The project uses **FVM** (Flutter Version Manager); the SDK path in `android/local.properties` points to `~/fvm/versions/stable`.

## Build & Development Commands

Always run commands from the repository root.

### 1. Install dependencies (always do this first)

```sh
flutter pub get
```

### 2. Generate localization code (required after changing any `lib/l10n/*.arb` file)

The project uses `intl_utils` (not Flutter's built-in `flutter gen-l10n`). The generated code lives in `lib/generated/` and is gitignored. Always regenerate after cloning or modifying ARB files:

```sh
dart run intl_utils:generate
```

**Do NOT use** `flutter gen-l10n` — it will fail because `flutter: generate: true` is not set in pubspec.yaml.

### 3. Static analysis

```sh
flutter analyze
```

There are 10 pre-existing infos (deprecated `launch()` calls and `WillPopScope` usage). Use `flutter analyze --no-fatal-infos` to allow those while still failing on warnings and errors. Do **not** introduce new warnings. Treat new warnings as errors.

## Project Structure

```
lib/
├── main.dart              # App entry point, route definitions, MaterialApp setup
├── components/            # Reusable UI widgets (article_item, favicon, sync_control, etc.)
├── models/                # State models using Provider (ChangeNotifier pattern)
│   ├── feeds_model.dart   # Feed list state
│   ├── items_model.dart   # Article items state
│   ├── sources_model.dart # RSS source state
│   ├── groups_model.dart  # Feed group state
│   ├── sync_model.dart    # Sync orchestration
│   ├── global_model.dart  # App-wide settings/preferences
│   ├── service.dart       # ServiceHandler abstract class, SyncService enum
│   └── services/          # Concrete service implementations (fever, feedbin, greader)
├── pages/                 # Screen-level widgets
│   ├── home_page.dart     # Main navigation (tabs: feed, subscriptions, settings)
│   ├── article_page.dart  # Article reader (WebView-based)
│   ├── settings/          # Settings screens and service configuration pages
│   ├── tablet_base_page.dart  # Two-pane tablet layout
│   └── ...
├── utils/
│   ├── global.dart        # Global singleton initialization, local Jaguar HTTP server
│   ├── store.dart         # SharedPreferences key constants (StoreKeys)
│   ├── db.dart            # SQLite database schema and helper (tables: sources, items)
│   ├── colors.dart        # Theme colors
│   └── utils.dart         # Misc utilities
├── l10n/                  # ARB translation files (10 languages: en, de, es, fr, hr, pt, ru, tr, uk, zh)
└── generated/             # Auto-generated localization code (gitignored — regenerate with intl_utils)
```

### Other key paths

| Path | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies, version (1.0.7+17), assets |
| `android/app/build.gradle` | Android build config: compileSdk 36, minSdk 24, Java 21 |
| `android/key.properties` | Release signing config (not committed in upstream) |
| `ios/Runner.xcodeproj` | iOS 15.0 minimum; native plugins use Swift Package Manager without CocoaPods |
| `assets/article/` | WebView article renderer: HTML template, CSS, JS, Mercury parser |
| `test/widget_test.dart` | App startup, service navigation, localization and legacy widget regression tests |
| `.github/` | Issue templates and funding config only; **no CI/CD workflows** |

## Architecture Notes

- **State management:** Provider with ChangeNotifier models. Models are initialized in `Global.init()` (`lib/utils/global.dart`) and provided via `MultiProvider` in `main.dart`.
- **Local storage:** `SharedPreferences` for settings, `sqflite` for articles/sources (SQLite DB `frlite.db`).
- **Article rendering:** A local Jaguar HTTP server (port 9000) serves Flutter assets to a WebView for article display.
- **Navigation:** Named routes defined in `MyApp.baseRoutes` in `main.dart`.
- **Localization:** The `S` class in `lib/generated/l10n.dart` — access strings via `S.of(context).keyName`. Source strings are in `lib/l10n/intl_en.arb`.
- **UI packages:** Use `material_ui` and `cupertino_ui` for design widgets. Their localization delegates are separate from the SDK delegates; `MyApp` bridges legacy widgets still used by `modal_bottom_sheet` and `overlay_dialog`.
- **No analysis_options.yaml** — the project uses Flutter's default lint rules.

## Key Conventions

- All Dart source is in `lib/`. No custom native platform code (Kotlin/Swift) beyond Flutter defaults.
- Generated localization files (`lib/generated/`) are gitignored. Always run `dart run intl_utils:generate` after changing ARB files.
- The `.gitignore` also excludes `/build/`, `.dart_tool/`, `.flutter-plugins`, and `.flutter-plugins-dependencies`.
- Use `SyncService` enum and `ServiceHandler` abstract class when adding new RSS service integrations.
- `StoreKeys` in `lib/utils/store.dart` defines all SharedPreferences key constants.
- Database schema is in `lib/utils/db.dart` — two tables: `sources` and `items`.

## Validation Checklist

Before submitting changes, always verify:

1. `flutter pub get` succeeds
2. `dart run intl_utils:generate` succeeds (if ARB files were changed)
3. `flutter analyze` introduces **no new** warnings or errors
