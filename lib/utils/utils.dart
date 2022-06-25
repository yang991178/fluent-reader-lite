import 'package:fluent_reader_lite/generated/l10n.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:lpinyin/lpinyin.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class Utils {
  static const syncMaxId = 9007199254740991;

  static void openExternal(String url) {
    launch(url, forceSafariVC: false, forceWebView: false);
  }

  static int binarySearch<T>(
      List<T> sortedList, T value, int Function(T, T) compare) {
    var min = 0;
    var max = sortedList.length;
    while (min < max) {
      var mid = min + ((max - min) >> 1);
      var element = sortedList[mid];
      var comp = compare(element, value);
      if (comp == 0) return mid;
      if (comp < 0) {
        min = mid + 1;
      } else {
        max = mid;
      }
    }
    return min;
  }

  static Future<bool> validateFavicon(String url) async {
    var flag = false;
    try {
      var uri = Uri.parse(url);
      var result = await http.get(uri);
      if (result.statusCode == 200) {
        var contentType =
            result.headers["Content-Type"] ?? result.headers["content-type"];
        if (contentType != null && contentType.startsWith("image")) flag = true;
      }
    } finally {
      return flag;
    }
  }

  static final _urlRegex = RegExp(
    r"^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,63}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*$)",
    caseSensitive: false,
  );
  static bool testUrl(String url) =>
      url != null && _urlRegex.hasMatch(url.trim());

  static bool notEmpty(String text) => text != null && text.trim().length > 0;

  static void showServiceFailureDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(S.of(context).serviceFailure),
        content: Text(S.of(context).serviceFailureHint),
        actions: [
          CupertinoDialogAction(
            child: Text(S.of(context).close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  static int localStringCompare(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    try {
      String ap = PinyinHelper.getShortPinyin(a);
      String bp = PinyinHelper.getShortPinyin(b);
      return ap.compareTo(bp);
    } catch (exp) {
      return a.compareTo(b);
    }
  }
}
