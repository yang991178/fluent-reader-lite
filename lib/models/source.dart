enum SourceOpenTarget {
    Local, FullContent, Webpage, External
}

class RSSSource {
  String id;
  String url;
  String iconUrl;
  String name;
  SourceOpenTarget openTarget;
  int unreadCount;
  DateTime latest;
  String lastTitle;

  RSSSource(this.id, this.url, this.name) {
    openTarget = SourceOpenTarget.Local;
    latest = DateTime.now();
    unreadCount = 0;
    lastTitle = "";
  }

  RSSSource._privateConstructor(
    this.id, this.url, this.iconUrl, this.name, this.openTarget,
    this.unreadCount, this.latest, this.lastTitle,
  );

  RSSSource clone() {
    return RSSSource._privateConstructor(
      this.id, this.url, this.iconUrl, this.name, this.openTarget,
      this.unreadCount, this.latest, this.lastTitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "sid": id,
      "url": url,
      "iconUrl": iconUrl,
      "name": name,
      "openTarget": openTarget.index,
      "latest": latest.millisecondsSinceEpoch,
      "lastTitle": lastTitle,
    };
  }

  RSSSource.fromMap(Map<String, dynamic> map) {
    id = map["sid"];
    url = map["url"];
    iconUrl = map["iconUrl"];
    name = map["name"];
    openTarget = SourceOpenTarget.values[map["openTarget"]];
    latest = DateTime.fromMillisecondsSinceEpoch(map["latest"]);
    lastTitle = map["lastTitle"];
    unreadCount = 0;
  }
}
