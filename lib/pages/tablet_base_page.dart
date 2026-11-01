import 'package:fluent_reader_lite/components/article_focus_controls.dart';
import 'package:fluent_reader_lite/components/article_focus_scope.dart';
import 'package:fluent_reader_lite/components/reader_page_scaffold.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

class TabletBasePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final focus = ArticleFocusScope.maybeOf(context);
    var b = Global.currentBrightness(context) == Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: b ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            child: Center(
              child: Image.asset(
                "assets/icons/logo-outline${b ? '' : '-dark'}.png",
                width: 120,
                height: 120,
              ),
            ),
          ),
          ReaderPageScaffold(
            keepMiddle: true,
            backgroundColor: CupertinoColors.transparent,
            navigationBar: CupertinoNavigationBar(
              automaticallyImplyLeading: false,
              automaticallyImplyMiddle: false,
              padding: EdgeInsetsDirectional.zero,
              backgroundColor: CupertinoColors.systemBackground,
              leading: focus?.enabled == true
                  ? ArticlePaneButton(onPressed: focus!.showList)
                  : null,
              trailing: focus?.available == true
                  ? ArticleFocusToggle(
                      enabled: focus!.enabled,
                      onPressed: focus.toggle,
                    )
                  : null,
            ),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}
