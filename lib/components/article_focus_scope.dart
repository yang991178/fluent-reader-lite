import 'package:cupertino_ui/cupertino_ui.dart';

/// Lets the reader control its containing panes without replacing its route.
class ArticleFocusScope extends InheritedWidget {
  const ArticleFocusScope({
    super.key,
    required this.available,
    required this.preferred,
    required this.listVisible,
    required this.toggle,
    required this.showList,
    required this.showArticle,
    required super.child,
  });

  final bool available;
  final bool preferred;
  bool get enabled => available && preferred;
  final bool listVisible;
  final VoidCallback toggle;
  final VoidCallback showList;
  final VoidCallback showArticle;

  static ArticleFocusScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArticleFocusScope>();

  @override
  bool updateShouldNotify(ArticleFocusScope oldWidget) =>
      available != oldWidget.available ||
      preferred != oldWidget.preferred ||
      listVisible != oldWidget.listVisible;
}
