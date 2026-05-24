// lib/services/youtube_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/models/youtube_video_model.dart';

class YoutubeService {
  final String apiKey;

  YoutubeService(this.apiKey);

  /// Dùng cho sidebar Desktop & mobile trending mặc định
  Future<List<YoutubeVideo>> fetchAiVideos() async {
    // Bạn có thể đổi query mặc định nếu muốn
    return searchVideos(
      'lập trình ai',
      maxResults: 6,
      order: 'date',
    );
  }

  /// Hàm search video – dùng cho:
  /// - mobileYoutubeSearchProvider(query)
  /// - (nếu muốn) phần search trên desktop
  Future<List<YoutubeVideo>> searchVideos(
    String query, {
    int maxResults = 10,
    String order = 'relevance',
  }) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https(
      'www.googleapis.com',
      '/youtube/v3/search',
      {
        'part': 'snippet',
        'maxResults': '$maxResults',
        'q': query,
        'type': 'video',
        'order': order,
        'key': apiKey,
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('YouTube error: ${res.statusCode} – ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    // Giữ nguyên cách map cũ dùng fromJson
    return items.map<YoutubeVideo>((e) => YoutubeVideo.fromJson(e)).toList();
  }
}
