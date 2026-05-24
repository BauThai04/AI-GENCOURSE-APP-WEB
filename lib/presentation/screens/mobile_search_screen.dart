import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/models/youtube_video_model.dart';
import '../../data/models/news_article_model.dart';
import '../screens/in_app_webview_screen.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import '../screens/in_app_webview_screen.dart';

/// Query hiện tại cho màn Search mobile
final mobileSearchQueryProvider = StateProvider<String>((ref) => "");

class MobileSearchScreen extends ConsumerWidget {
  const MobileSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(mobileSearchQueryProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ================== HEADER + SEARCH BOX ==================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      splashRadius: 22,
                      onPressed: () {
                        ref.read(navProvider.notifier).state = AppSection.home;
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3F4),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          onChanged: (text) => ref
                              .read(mobileSearchQueryProvider.notifier)
                              .state = text.trim(),
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            hintText: 'Search profiles, videos, news...',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 10, // cho text & icon canh đúng giữa
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ================== TAB BAR ==================
              const TabBar(
                isScrollable: true,
                labelColor: Color(0xFF5A4FCF),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Color(0xFF5A4FCF),
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Profiles'),
                  Tab(text: 'YouTube'),
                  Tab(text: 'News'),
                  Tab(text: 'Topics'),
                ],
              ),

              const SizedBox(height: 4),

              // ================== TAB CONTENT ==================
              Expanded(
                child: TabBarView(
                  children: [
                    ProfilesSearchTab(query: query),
                    YoutubeSearchTab(query: query),
                    NewsSearchTab(query: query),
                    const TopicsSearchTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//////////////////// PROFILES TAB ////////////////////

class ProfilesSearchTab extends ConsumerWidget {
  final String query;
  const ProfilesSearchTab({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) {
      return const Center(
        child: Text(
          'Type something to search profiles',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final resultsAsync = ref.watch(userSearchProvider(query));

    return resultsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (List<UserModel> users) {
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No matching profiles',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFEFF3F4)),
          itemBuilder: (context, index) {
            final user = users[index];
            final hasAvatar = user.avatarUrl.isNotEmpty;
            final initial = user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : 'U';

            return ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                    hasAvatar ? NetworkImage(user.avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              title: Text(
                user.displayName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                '@${user.username}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              onTap: () {
                // chuyển sang profile user đó
                ref.read(viewedProfileIdProvider.notifier).state = user.uid;
                ref.read(navProvider.notifier).state = AppSection.profile;
              },
            );
          },
        );
      },
    );
  }
}

//////////////////// YOUTUBE TAB ////////////////////

class YoutubeSearchTab extends ConsumerWidget {
  final String query;
  const YoutubeSearchTab({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = query.isEmpty
        ? ref.watch(mobileYoutubeTrendingProvider)
        : ref.watch(mobileYoutubeSearchProvider(query));

    return videosAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (List<YoutubeVideo> videos) {
        if (videos.isEmpty) {
          return const Center(
            child: Text(
              'No videos found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            final String id = v.id ?? '';
            final String title = v.title ?? '';
            final String channel = v.channelTitle ?? '';
            final String thumb = v.thumbnailUrl ?? '';

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        width: 80,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(width: 80, height: 50),
              ),
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                channel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                if (id.isEmpty) return;

                final url = 'https://www.youtube.com/watch?v=$id';

                // Nếu không phải Android/iOS → mở ngoài (tránh dùng WebView)
                final isMobile =
                    defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS;

                if (!isMobile) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return;
                }

                // Android/iOS → mở WebView trong app
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InAppWebViewScreen(
                      url: url,
                      title: title.isNotEmpty ? title : 'YouTube',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

//////////////////// NEWS TAB ////////////////////

class NewsSearchTab extends ConsumerWidget {
  final String query;
  const NewsSearchTab({super.key, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = query.isEmpty
        ? ref.watch(mobileNewsTrendingProvider)
        : ref.watch(mobileNewsSearchProvider(query));

    return newsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            'Error loading news:\n$e',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ),
      ),
      data: (List<NewsArticle> articles) {
        if (articles.isEmpty) {
          return const Center(
            child: Text(
              'No news found',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final a = articles[index];
            final String title = a.title ?? '';
            final String source = a.sourceName ?? '';
            final String? image = a.imageUrl;
            final String? urlStr = a.url;

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        image,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.article_outlined,
                            size: 28,
                            color: Colors.grey),
                      ),
                    )
                  : const Icon(Icons.article_outlined,
                      size: 28, color: Colors.grey),
              title: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                source,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                if (urlStr == null || urlStr.isEmpty) return;

                final isMobile =
                    defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.iOS;

                final uri = Uri.parse(urlStr);

                if (!isMobile) {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InAppWebViewScreen(
                      url: urlStr,
                      title: title.isNotEmpty ? title : 'News',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

//////////////////// TOPICS TAB – PLACEHOLDER ////////////////////

class TopicsSearchTab extends StatelessWidget {
  const TopicsSearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Search topics (#hashtag) – coming soon',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }
}
