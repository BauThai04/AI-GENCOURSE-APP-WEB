import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart'; // Chứa hasUnreadNotificationsProvider
import '../../data/models/notification_model.dart';
import '../widgets/notification_toast.dart'; // Widget Toast mới
import '../screens/post_detail_screen.dart'; // Bấm noti ra
import '../../data/models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Hàm hiển thị Toast
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
                // 1. Lấy bài viết từ Firestore theo postId trong notification
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

                // 2. Map sang PostModel (dùng factory từ post_model.dart)
                final post = PostModel.fromFirestore(doc);

                if (!mounted) return;

                // 3. Mở màn chi tiết post
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

    // Tự ẩn sau 4 giây
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ref.watch(navProvider);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);

    // --- LOGIC LẮNG NGHE NOTIFICATION ĐỂ HIỆN TOAST ---
    ref.listen<AsyncValue<List<NotificationModel>>>(
      notificationsProvider,
      (previous, next) {
        if (next.hasValue && !next.isLoading && !next.hasError) {
          final nextList = next.value!;
          final prevList = previous?.value ?? [];

          if (nextList.isNotEmpty) {
            final newest = nextList.first;

            // Nếu danh sách mới dài hơn, HOẶC item đầu tiên khác nhau -> Có tin mới
            // Và tin mới đó phải chưa đọc (isRead == false)
            bool isNew = false;
            if (prevList.isEmpty) {
              // Lần đầu load app có thể bỏ qua toast nếu muốn
              // Ở đây mình check nếu thời gian tạo < 1 phút thì hiện (tránh hiện notif cũ)
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
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null)
            return const Center(child: Text("Vui lòng đăng nhập"));
          return ProfileScreen(userId: uid);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isDesktop = width > 900;

        if (isDesktop) {
          // DESKTOP LAYOUT
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
                          vertical: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: getContent(),
                  ),
                ),
                const SizedBox(width: 310, child: RightSidebarContent()),
              ],
            ),
          );
        } else {
          // MOBILE LAYOUT
          return Scaffold(
            backgroundColor: Colors.white,
            body: getContent(),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _mobileIndexFromSection(currentSection),
              onTap: (index) {
                ref.read(navProvider.notifier).state =
                    _sectionFromMobileIndex(index);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: const Color(0xFF5A4FCF),
              unselectedItemColor: Colors.grey,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: mobileNavItems.map((item) {
                // Check Badge cho item Alerts
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
                  activeIcon: Icon(item
                      .activeIcon), // Active icon thường không cần badge hoặc giữ nguyên
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

// Right Sidebar Placeholder
class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: const Center(
          child: Text("Trending / Suggestions",
              style: TextStyle(color: Colors.grey))),
    );
  }
}
