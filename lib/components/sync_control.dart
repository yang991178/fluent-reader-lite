import 'dart:async';

import 'package:fluent_reader_lite/utils/global.dart';
import 'package:flutter/cupertino.dart';

class SyncControl extends StatefulWidget {
  @override
  _SyncControlState createState() => _SyncControlState();
}

class _SyncControlState extends State<SyncControl> {
  Future<void> _onRefresh() {
    var completer = Completer();
    Function listener;
    listener = () {
      if (!Global.syncModel.syncing) {
        completer.complete();
        Global.syncModel.removeListener(listener);
      }
    };
    Global.syncModel.addListener(listener);
    Global.syncModel.syncWithService();
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: _onRefresh,
    );
  }
}
