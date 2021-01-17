import 'package:fluent_reader_lite/utils/store.dart';
import 'package:flutter/cupertino.dart';

class GroupsModel with ChangeNotifier {
  Map<String, List<String>> _groups = Store.getGroups();

  Map<String, List<String>> get groups => _groups;
  set groups(Map<String, List<String>> groups) {
    _groups = groups;
    notifyListeners();
    Store.setGroups(groups);
  }
}