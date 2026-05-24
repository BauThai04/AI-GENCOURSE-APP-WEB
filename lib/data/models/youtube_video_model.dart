class YoutubeVideo {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String channelTitle;

  YoutubeVideo({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.channelTitle,
  });

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final defaultThumb = thumbnails['medium'] ?? thumbnails['default'] ?? {};

    return YoutubeVideo(
      id: (json['id'] is Map)
          ? (json['id']['videoId'] ?? '')
          : (json['id'] ?? ''),
      title: snippet['title'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      thumbnailUrl: defaultThumb['url'] ?? '',
    );
  }
}
