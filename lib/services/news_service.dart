import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/models/news_article_model.dart';

class NewsService {
  final String apiKey;

  NewsService(this.apiKey);

  /// Tin tech / AI mặc định (trending)
  Future<List<NewsArticle>> fetchTechNews() async {
    final uri = Uri.https(
      'newsapi.org',
      '/v2/top-headlines',
      {
        'country': 'us',
        'category': 'technology', // chọn technology cho hợp AI/tech
        'pageSize': '10',
        'apiKey': apiKey,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      // log body để debug nếu cần
      throw Exception('News API error: ${res.statusCode} ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    // NewsAPI trả status 'ok' hoặc 'error'
    if (data['status'] != 'ok') {
      throw Exception('News API error: ${data['code']}: ${data['message']}');
    }

    final List articlesJson = data['articles'] as List? ?? [];
    return articlesJson.map((e) => NewsArticle.fromJson(e)).toList();
  }

  /// Search news theo query
  Future<List<NewsArticle>> searchNews(String query) async {
    final uri = Uri.https(
      'newsapi.org',
      '/v2/everything',
      {
        'q': query,
        'sortBy': 'publishedAt',
        'language': 'en',
        'pageSize': '10',
        'apiKey': apiKey,
      },
    );

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('News API error: ${res.statusCode} ${res.body}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;

    if (data['status'] != 'ok') {
      throw Exception('News API error: ${data['code']}: ${data['message']}');
    }

    final List articlesJson = data['articles'] as List? ?? [];
    return articlesJson.map((e) => NewsArticle.fromJson(e)).toList();
  }
}
