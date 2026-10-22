import 'package:cupertino_ui/cupertino_ui.dart';

class MyActionSheetAction extends CupertinoActionSheetAction {
  MyActionSheetAction({
    super.key,
    required super.onPressed,
    super.isDefaultAction,
    super.isDestructiveAction,
    super.mouseCursor,
    super.focusNode,
    super.focusColor,
    required Widget child,
  }) : super(
         child: Builder(
           builder: (context) => IconTheme.merge(
             data: IconThemeData(
               color: DefaultTextStyle.of(context).style.color,
             ),
             child: child,
           ),
         ),
       );
}
