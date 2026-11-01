import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';

class ArticlePaneButton extends StatelessWidget {
  const ArticlePaneButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: Icon(
      CupertinoIcons.sidebar_left,
      semanticLabel: S.of(context).showArticleList,
    ),
  );
}

class ArticleFocusToggle extends StatelessWidget {
  const ArticleFocusToggle({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: enabled,
    button: true,
    enabled: true,
    onTap: onPressed,
    excludeSemantics: true,
    label: enabled ? S.of(context).exitFocusMode : S.of(context).enterFocusMode,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Icon(
        enabled
            ? CupertinoIcons.arrow_down_right_arrow_up_left
            : CupertinoIcons.arrow_up_left_arrow_down_right,
      ),
    ),
  );
}
