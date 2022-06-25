/*
 * cupertino_toolbar
 * Copyright (c) 2019 Christian Mengler. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';

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
    Key key,
    @required this.items,
    @required this.body
  }) : assert(items != null),
       assert(
        items.every((CupertinoToolbarItem item) => (item.icon != null)) == true,
        'Every item must have an icon and onPressed defined',
       ),
       assert(body != null),
       super(key: key);

  /// The interactive items laid out within the toolbar where each item has an icon.
  final List<CupertinoToolbarItem> items;

  /// The body displayed above the toolbar.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: body
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: MyColors.barDivider.resolveFrom(context), width: 0.0)
            )
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: Global.isTablet ? 50.0 : 44.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _createButtons()
              )
            )
          )
        )
      ]
    );
  }

  List<Widget> _createButtons() {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i += 1) {
      children.add(CupertinoButton(
        padding: EdgeInsets.zero,
        child: Icon(
          items[i].icon,
          // color: CupertinoColors.systemBlue,
          semanticLabel: items[i].semanticLabel,
        ),
        onPressed: items[i].onPressed
      ));
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
    @required this.icon,
    this.onPressed,
    this.semanticLabel
  }) : assert(icon != null);

  /// The icon of the item.
  ///
  /// This attribute must not be null.
  final IconData icon;

  /// The callback that is called when the item is tapped.
  ///
  /// This attribute must not be null.
  final VoidCallback onPressed;

  /// Semantic label for the icon.
  ///
  /// Announced in accessibility modes (e.g TalkBack/VoiceOver).
  /// This label does not show in the UI.
  final String semanticLabel;
}