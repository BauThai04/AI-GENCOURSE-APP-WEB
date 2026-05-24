class NewsArticle {
  final String title;
  final String sourceName;
  final String? imageUrl;
  final String? url;

  NewsArticle({
    required this.title,
    required this.sourceName,
    this.imageUrl,
    this.url,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    final source = json['source'] ?? {};
    return NewsArticle(
      title: json['title'] ?? '',
      sourceName: source['name'] ?? '',
      imageUrl: json['urlToImage'],
      url: json['url'],
    );
  }
}
