import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';

class SyncModel with ChangeNotifier {
  bool hasService = Global.service != null;
  bool syncing = false;
  bool _lastSyncSuccess = Store.sp.getBool(StoreKeys.LAST_SYNC_SUCCESS) ?? true;
  DateTime _lastSynced = DateTime.fromMillisecondsSinceEpoch(
    Store.sp.getInt(StoreKeys.LAST_SYNCED) ?? 0
  );

  void checkHasService() {
    var value = Global.service != null;
    if (value != hasService) {
      hasService = value;
      notifyListeners();
    }
  }

  Future<void> removeService() async {
    if (syncing || Global.service == null) return;
    syncing = true;
    notifyListeners();
    var sids = Global.sourcesModel.getSources()
      .map((s) => s.id)
      .toList();
    await Global.sourcesModel.removeSources(sids);
    Global.service.remove();
    hasService = false;
    syncing = false;
    notifyListeners();
  }

  bool get lastSyncSuccess => _lastSyncSuccess;
  set lastSyncSuccess(bool value) {
    _lastSyncSuccess = value;
    Store.sp.setBool(StoreKeys.LAST_SYNC_SUCCESS, value);
  }

  DateTime get lastSynced => _lastSynced;
  set lastSynced(DateTime value) {
    _lastSynced = value;
    Store.sp.setInt(StoreKeys.LAST_SYNCED, value.millisecondsSinceEpoch);
  }

  Future<void> syncWithService() async {
    if (syncing || Global.service == null) return;
    syncing = true;
    notifyListeners();
    try {
      await Global.service.reauthenticate();
      await Global.sourcesModel.updateSources();
      await Global.itemsModel.syncItems();
      await Global.itemsModel.fetchItems();
      lastSyncSuccess = true;
    } catch(exp) {
      lastSyncSuccess = false;
      Store.setErrorLog(exp.toString());
      print(exp);
    }
    lastSynced = DateTime.now();
    syncing = false;
    notifyListeners();
  }
}