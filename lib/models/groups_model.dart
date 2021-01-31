import 'package:fluent_reader_lite/utils/global.dart';
import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';

class GroupsModel with ChangeNotifier {
  Map<String, List<String>> _groups = Store.getGroups();
  List<String> uncategorized = Store.getUncategorized();

  Map<String, List<String>> get groups => _groups;
  set groups(Map<String, List<String>> groups) {
    _groups = groups;
    updateUncategorized();
    notifyListeners();
    Store.setGroups(groups);
  }

  void updateUncategorized({force: false}) {
    if (uncategorized != null || force) {
      final sids = Set<String>.from(
        Global.sourcesModel.getSources().map<String>((s) => s.id)
      );
      for (var group in _groups.values) {
        for (var sid in group) {
          sids.remove(sid);
        }
      }
      uncategorized = sids.toList();
      Store.setUncategorized(uncategorized);
    }
  }

  bool get showUncategorized => uncategorized != null;
  set showUncategorized(bool value) {
    if (showUncategorized != value) {
      if (value) {
        updateUncategorized(force: true);
      } else {
        uncategorized = null;
        Store.setUncategorized(null);
      }
      notifyListeners();
    }
  }
}