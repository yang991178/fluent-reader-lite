class RSSItem {
  String id;
  String source;
  String title;
  String link;
  DateTime date;
  String content;
  String snippet;
  bool hasRead;
  bool starred;
  String creator; // Optional
  String thumb; // Optional

  RSSItem({
    this.id, this.source, this.title, this.link, this.date,
    this.content, this.snippet, this.hasRead, this.starred,
    this.creator, this.thumb
  });

  RSSItem clone() {
    return RSSItem(
      id: id, source: source, title: title, link: link, date: date,
      content: content, snippet: snippet, hasRead: hasRead, starred: starred,
      creator: creator, thumb: thumb,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "iid": id,
      "source": source,
      "title": title,
      "link": link,
      "date": date.millisecondsSinceEpoch,
      "content": content,
      "snippet": snippet,
      "hasRead": hasRead ? 1 : 0,
      "starred": starred ? 1 : 0,
      "creator": creator,
      "thumb": thumb,
    };
  }

  RSSItem.fromMap(Map<String, dynamic> map) {
    id = map["iid"];
    source = map["source"];
    title = map["title"];
    link = map["link"];
    date = DateTime.fromMillisecondsSinceEpoch(map["date"]);
    content = map["content"];
    snippet = map["snippet"];
    hasRead = map["hasRead"] != 0;
    starred = map["starred"] != 0;
    creator = map["creator"];
    thumb = map["thumb"];
  }
}
