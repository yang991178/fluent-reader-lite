import 'package:flutter/cupertino.dart';

class DismissibleBackground extends StatelessWidget {
  final IconData icon;
  final bool isToRight;

  DismissibleBackground(this.icon, this.isToRight, {Key key})
    : super(key: key);

  @override
  Widget build(BuildContext context) => Container(
    color: CupertinoColors.systemGrey5.resolveFrom(context),
    padding: EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isToRight
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
      children: [Icon(
        icon,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      )],
    ),
  );
}