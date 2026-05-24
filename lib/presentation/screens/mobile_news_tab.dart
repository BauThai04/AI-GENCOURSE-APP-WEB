import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';
import '../../data/models/news_article_model.dart';

class MobileNewsTab extends ConsumerWidget {
  final String query; // text đang search

  const MobileNewsTab({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nếu query trống -> dùng trending, ngược lại -> search
    final asyncNews = query.trim().isEmpty
        ? ref.watch(mobileNewsTrendingProvider)
        : ref.watch(mobileNewsSearchProvider(query));

    return asyncNews.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'Lỗi tải tin tức:\n$err',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      ),
      data: (articles) {
        if (articles.isEmpty) {
          return const Center(
            child: Text(
              'Không tìm thấy tin nào.\nThử từ khóa khác nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final NewsArticle a = articles[index];

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _buildThumbnail(a),
              title: Text(
                a.title ?? 'No title',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                a.sourceName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                if (a.url == null) return;
                final url = Uri.parse(a.url!);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnail(NewsArticle a) {
    if (a.imageUrl == null) {
      return const Icon(Icons.article_outlined, size: 32, color: Colors.grey);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        a.imageUrl!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.article_outlined, size: 32, color: Colors.grey),
      ),
    );
  }
}
