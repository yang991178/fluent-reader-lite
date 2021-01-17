import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';

class ResponsiveActionSheet extends StatelessWidget {
  final Widget child;

  ResponsiveActionSheet(this.child);

  @override
  Widget build(BuildContext context) {
    if (!Global.isTablet) return child;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: 320),
          child: child,
        )
      ],
    );
  }
}
