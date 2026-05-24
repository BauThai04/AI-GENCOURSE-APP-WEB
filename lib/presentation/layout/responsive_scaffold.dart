import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/mobile_search_screen.dart';

import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/post_model.dart';
import '../widgets/notification_toast.dart';
import '../screens/post_detail_screen.dart';

import 'left_sidebar.dart';
import '../screens/home_screen.dart' hide LeftSidebar;
import '../screens/alerts_screen.dart';
import '../screens/ai_gencourse_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/profile_screen.dart';

class ResponsiveScaffold extends ConsumerStatefulWidget {
  const ResponsiveScaffold({super.key});

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  // ===================== TOAST NOTIFICATION =====================

  void _showNotificationToast(NotificationModel notif) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 20,
        right: 20,
        child: SafeArea(
          child: NotificationToast(
            notif: notif,
            onDismiss: () {
              if (entry.mounted) entry.remove();
            },
            onTap: () async {
              try {
                final doc = await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(notif.postId)
                    .get();

                if (!doc.exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Bài viết không còn tồn tại')),
                    );
                  }
                  return;
                }

                final post = PostModel.fromFirestore(doc);

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi tải bài viết: $e')),
                  );
                }
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(navProvider);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);

    // Lắng nghe notifications -> hiện toast khi có noti mới
    ref.listen<AsyncValue<List<NotificationModel>>>(
      notificationsProvider,
      (previous, next) {
        if (next.hasValue && !next.isLoading && !next.hasError) {
          final nextList = next.value!;
          final prevList = previous?.value ?? [];

          if (nextList.isNotEmpty) {
            final newest = nextList.first;

            bool isNew = false;
            if (prevList.isEmpty) {
              if (newest.createdAt != null &&
                  DateTime.now().difference(newest.createdAt!).inMinutes < 1) {
                isNew = true;
              }
            } else if (newest.id != prevList.first.id) {
              isNew = true;
            }

            if (isNew && !newest.isRead) {
              _showNotificationToast(newest);
            }
          }
        }
      },
    );

    Widget getContent() {
      switch (currentSection) {
        case AppSection.home:
          return const HomeScreen();
        case AppSection.alerts:
          return const AlertsScreen();
        case AppSection.aiStudio:
          return const AiGenCourseScreen();
        case AppSection.messages:
          return const MessagesScreen();
        case AppSection.communities:
          return const GroupsScreen();
        case AppSection.bookmarks:
          return const Center(child: Text("Bookmarks – Coming soon"));
        case AppSection.profile:
          final viewedId = ref.watch(viewedProfileIdProvider);
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final uidToShow = viewedId ?? currentUid;
          if (uidToShow == null) {
            return const Center(child: Text("Vui lòng đăng nhập"));
          }
          return ProfileScreen(userId: uidToShow);

        case AppSection.search: // 👈 NEW
          return const MobileSearchScreen();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isDesktop = width > 900;
        final bool showRightSidebar = width > 1200; // ← Chỉ hiện khi > 1200px

        if (isDesktop) {
          // ===================== DESKTOP =====================
          return Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 255, child: LeftSidebar()),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        vertical: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: getContent(),
                  ),
                ),
                // Right Sidebar - chỉ hiện khi màn hình đủ rộng
                if (showRightSidebar)
                  const SizedBox(width: 310, child: RightSidebarContent()),
              ],
            ),
          );
        } else {
          // ===================== MOBILE =====================
          return Scaffold(
            backgroundColor: Colors.white,
            body: getContent(),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _mobileIndexFromSection(currentSection),
              onTap: (index) {
                final section = _sectionFromMobileIndex(index);

                if (section == AppSection.profile) {
                  // 👉 profile của chính mình
                  ref.read(viewedProfileIdProvider.notifier).state = null;
                }

                ref.read(navProvider.notifier).state = section;
              }, // <-- CHỖ SỬA,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF5A4FCF),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: mobileNavItems.map((item) {
                final bool showBadge =
                    (item.section == AppSection.alerts && hasUnread);

                return BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(item.icon),
                      if (showBadge)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: Icon(item.activeIcon),
                  label: item.label,
                );
              }).toList(),
            ),
          );
        }
      },
    );
  }

  int _mobileIndexFromSection(AppSection section) {
    final idx = mobileNavItems.indexWhere((item) => item.section == section);
    if (idx == -1) return 0;
    return idx;
  }

  AppSection _sectionFromMobileIndex(int index) {
    return mobileNavItems[index].section;
  }
}

// ===================================================================
// RIGHT SIDEBAR: YouTube videos + News (desktop only)
// ===================================================================

class RightSidebarContent extends ConsumerWidget {
  const RightSidebarContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(youtubeVideosProvider);
    final newsAsync = ref.watch(newsArticlesProvider);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Search nhỏ bên phải (placeholder)
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F4),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Banner Premium (Truth+ style)
            _premiumBanner(),

            const SizedBox(height: 16),

            // ====== LIVE SECTION (Truth Social style) ======
            _sectionContainer(
              title: "Live",
              showMore: true,
              child: Column(
                children: [
                  _liveTile(
                    context,
                    title: "Top Weather News, Reports",
                    source: "Weather Nation",
                    isLive: true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _liveTile(
                    context,
                    title: "Watch Live TV",
                    source: "RSBN",
                    isLive: true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _liveTile(
                    context,
                    title: "Get Real",
                    source: "Real America's Voice",
                    isLive: true,
                  ),
                  const SizedBox(height: 4), // Padding bottom
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ====== TOPICS TRENDING (Truth Social style) ======
            _sectionContainer(
              title: "Topics",
              showMore: true,
              child: Column(
                children: [
                  _topicTile(context, hashtag: "#MAGA", count: "10.4k"),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _topicTile(context, hashtag: "#China", count: "468"),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _topicTile(context, hashtag: "#Truth", count: "6.58k"),
                  const SizedBox(height: 4), // Padding bottom
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ====== YouTube block ======
            _sectionContainer(
              title: "AI videos on YouTube",
              child: videosAsync.when(
                data: (videos) {
                  if (videos.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        "No videos found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return Column(
                    children:
                        videos.map((v) => _videoTile(context, v)).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "Error loading videos: $e",
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ====== News block ======
            _sectionContainer(
              title: "AI / Tech news",
              child: newsAsync.when(
                data: (articles) {
                  if (articles.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        "No news found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return Column(
                    children:
                        articles.map((a) => _newsTile(context, a)).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "Error loading news: $e",
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Wrap(
              spacing: 10,
              children: [
                Text("Terms",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Privacy",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("© 2025 AI GenCourse",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ---------------- helpers ----------------

  static Widget _liveTile(
    BuildContext context, {
    required String title,
    required String source,
    bool isLive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            // Icon/Thumbnail
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.play_circle_outline, 
                color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Live badge
            if (isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Colors.white, size: 6),
                    SizedBox(width: 4),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _topicTile(
    BuildContext context, {
    required String hashtag,
    required String count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hashtag,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Recents: $count",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.trending_up, color: Color(0xFF5A4FCF), size: 20),
          ],
        ),
      ),
    );
  }

  static Widget _premiumBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle, color: Color(0xFF5A4FCF), size: 20),
              const SizedBox(width: 8),
              const Text(
                "Get Plus+",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Access the full experience with ad-free, member content.",
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                "Subscribe",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionContainer({
    required String title,
    required Widget child,
    bool showMore = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18),
                ),
                if (showMore)
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      "Show More",
                      style: TextStyle(
                        color: Color(0xFF5A4FCF),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  static Widget _videoTile(BuildContext context, dynamic v) {
    // v là YoutubeVideo
    final String thumb = v.thumbnailUrl ?? '';
    final String title = v.title ?? '';
    final String channel = v.channelTitle ?? '';
    final String id = v.id ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
        onTap: () async {
          final url = Uri.parse('https://www.youtube.com/watch?v=$id');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumb.isNotEmpty
                  ? Image.network(
                      thumb,
                      width: 60,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.play_circle_outline, 
                          color: Colors.white),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_circle_outline, 
                        color: Colors.white),
                    ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    channel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _newsTile(BuildContext context, dynamic a) {
    // a là NewsArticle
    final String title = a.title ?? '';
    final String source = a.sourceName ?? '';
    final String? image = a.imageUrl;
    final String? urlStr = a.url;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GestureDetector(
        onTap: () async {
          if (urlStr == null) return;
          final url = Uri.parse(urlStr);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image/Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image != null
                  ? Image.network(
                      image,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.article_outlined, 
                          size: 24, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.article_outlined, 
                        size: 24, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
