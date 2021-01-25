import 'package:fluent_reader_lite/components/list_tile_group.dart';
import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:fluent_reader_lite/utils/colors.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorLogPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final errorLog = Store.getErrorLog();
    return CupertinoPageScaffold(
      backgroundColor: MyColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(S.of(context).errorLog),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(S.of(context).copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: errorLog));
          },
        ),
      ),
      child: ListView(children: [
        ListTileGroup([
          SelectableText(
            errorLog,
            style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          ),
        ]),
      ]),
    );
  }
}