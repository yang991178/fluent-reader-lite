enum SourceOpenTarget { Local, FullContent, Webpage, External }

class RSSSource {
  String id;
  String url;
  String? iconUrl;
  String name;
  SourceOpenTarget openTarget = SourceOpenTarget.Local;
  int unreadCount = 0;
  DateTime latest = DateTime.now();
  String lastTitle = "";

  RSSSource(this.id, this.url, this.name);

  RSSSource._privateConstructor(
    this.id,
    this.url,
    this.iconUrl,
    this.name,
    this.openTarget,
    this.unreadCount,
    this.latest,
    this.lastTitle,
  );

  RSSSource clone() {
    return RSSSource._privateConstructor(
      this.id,
      this.url,
      this.iconUrl,
      this.name,
      this.openTarget,
      this.unreadCount,
      this.latest,
      this.lastTitle,
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

  factory RSSSource.fromMap(Map<String, dynamic> map) {
    return RSSSource._privateConstructor(
      map["sid"],
      map["url"],
      map["iconUrl"],
      map["name"],
      SourceOpenTarget.values[map["openTarget"]],
      0, // Default unreadCount
      DateTime.fromMillisecondsSinceEpoch(map["latest"]),
      map["lastTitle"],
    );
  }
}
