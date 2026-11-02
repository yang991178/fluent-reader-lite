/*
 * cupertino_toolbar
 * Copyright (c) 2019 Christian Mengler. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:fluent_reader_lite/utils/global.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'reader_bar.dart';

/// Display a persistent bottom iOS styled toolbar for Cupertino theme
///
class CupertinoToolbar extends StatelessWidget {
  /// Creates a persistent bottom iOS styled toolbar for Cupertino
  /// themed app,
  ///
  /// Typically used as the [child] attribute of a [CupertinoPageScaffold].
  ///
  /// {@tool sample}
  ///
  /// A sample code implementing a typical iOS page with bottom toolbar.
  ///
  /// ```dart
  /// CupertinoPageScaffold(
  /// 	navigationBar: CupertinoNavigationBar(
  /// 		middle: Text('Cupertino Toolbar')
  /// 	),
  /// 	child: CupertinoToolbar(
  /// 		items: <CupertinoToolbarItem>[
  /// 			CupertinoToolbarItem(
  /// 				icon: CupertinoIcons.delete,
  /// 				onPressed: () {}
  /// 			),
  /// 			CupertinoToolbarItem(
  /// 				icon: CupertinoIcons.settings,
  /// 				onPressed: () {}
  /// 			)
  /// 		],
  /// 		body: Center(
  /// 			child: Text('Hello World')
  /// 		)
  /// 	)
  /// )
  /// ```
  /// {@end-tool}
  ///
  CupertinoToolbar({
    Key? key,
    required this.items,
    this.trailingItems = const [],
    required this.body,
  }) : super(key: key);

  /// The interactive items laid out within the toolbar where each item has an icon.
  final List<CupertinoToolbarItem> items;

  /// Actions placed at the opposite edge when this pane is wide enough.
  final List<CupertinoToolbarItem> trailingItems;

  /// The body displayed above the toolbar.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final toolbarHeight = Global.isTablet(context) ? 50.0 : 44.0;
    final underlap = readerBarBlurEnabled
        ? toolbarHeight + MediaQuery.paddingOf(context).bottom
        : 0.0;
    return Column(
      children: <Widget>[
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.paddingOf(context).copyWith(
                bottom: readerBarBlurEnabled
                    ? 0
                    : MediaQuery.paddingOf(context).bottom,
              ),
            ),
            child: ReaderBarUnderlap(
              insets: EdgeInsets.only(bottom: underlap),
              child: body,
            ),
          ),
        ),
        ReaderBarBackground(
          color: readerBarColor(context),
          border: Border(top: readerBarBorder(context).bottom),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final grouped =
                  constraints.maxWidth > Global.tabletBreakpoint &&
                  trailingItems.isNotEmpty;
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: toolbarHeight,
                  child: grouped
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: _createButtons(items),
                              ),
                              const Spacer(),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: _createButtons(trailingItems),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _createButtons([
                            ...items,
                            ...trailingItems,
                          ]),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _createButtons(List<CupertinoToolbarItem> items) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i += 1) {
      children.add(
        CupertinoButton(
          key: items[i].key,
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          child: Icon(
            items[i].icon,
            // color: CupertinoColors.systemBlue,
            semanticLabel: items[i].semanticLabel,
          ),
          onPressed: items[i].onPressed,
        ),
      );
    }
    return children;
  }
}

/// An interactive button within iOS themed [CupertinoToolbar]
class CupertinoToolbarItem {
  /// Creates an item that is used with [CupertinoToolbar.items].
  ///
  /// The argument [icon] should not be null.
  const CupertinoToolbarItem({
    this.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
  });

  final Key? key;

  /// The icon of the item.
  ///
  /// This attribute must not be null.
  final IconData icon;

  /// The callback that is called when the item is tapped.
  ///
  /// This attribute must not be null.
  final VoidCallback? onPressed;

  /// Semantic label for the icon.
  ///
  /// Announced in accessibility modes (e.g TalkBack/VoiceOver).
  /// This label does not show in the UI.
  final String? semanticLabel;
}
