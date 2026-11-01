import 'package:fluent_reader_lite/components/article_focus_scope.dart';
import 'package:fluent_reader_lite/components/reader_pane_layout.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

Future<T?> showResponsiveActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final focusMode = ArticleFocusScope.maybeOf(context)?.preferred ?? false;
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) =>
        ResponsiveActionSheet(builder(context), focusMode: focusMode),
  );
}

class ResponsiveActionSheet extends StatelessWidget {
  final Widget child;
  final bool focusMode;

  const ResponsiveActionSheet(this.child, {super.key, this.focusMode = false});

  @override
  Widget build(BuildContext context) {
    if (!Global.isTablet(context)) return child;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: readerListPaneWidth(context, focusMode: focusMode),
          child: child,
        ),
      ],
    );
  }
}
