import 'package:fluent_reader_lite/components/responsive_action_sheet.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';

class MarkAllActionSheet extends StatelessWidget {
  final Set<String> sids;

  MarkAllActionSheet(this.sids, {Key key}) : super(key: key);

  DateTime _offset(int days) {
    return DateTime.now().subtract(Duration(days: days));
  }

  void _markAll(BuildContext context, {DateTime date}) {
    Navigator.of(context, rootNavigator: true).pop();
    Global.itemsModel.markAllRead(sids, date: date);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = CupertinoActionSheet(
      title: Text(AppLocalizations.of(context).markAll),
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          child: Text(AppLocalizations.of(context).allArticles),
          onPressed: () {
            _markAll(context);
          },
        ),
        CupertinoActionSheetAction(
          child: Text(AppLocalizations.of(context).daysAgo(1)),
          onPressed: () {
            _markAll(context, date: _offset(1));
          },
        ),
        CupertinoActionSheetAction(
          child: Text(AppLocalizations.of(context).daysAgo(3)),
          onPressed: () {
            _markAll(context, date: _offset(3));
          },
        ),
        CupertinoActionSheetAction(
          child: Text(AppLocalizations.of(context).daysAgo(7)),
          onPressed: () {
            _markAll(context, date: _offset(7));
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(AppLocalizations.of(context).cancel),
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
    return ResponsiveActionSheet(sheet);
  }
}
