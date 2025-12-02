import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import các thành phần cần thiết
import '../../providers/app_providers.dart';
import '../../providers/nav_provider.dart'; // Để điều hướng sang Profile
import '../../services/auth_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_composer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Màu chủ đạo
    const primaryColor = Color(0xFF5A4FCF);
    const accentPink = Color(0xFFE04F5F);

    return const MainFeed(primaryColor: primaryColor, accentPink: accentPink);
  }
}

// =========================================================
// WIDGET FEED: LOAD DỮ LIỆU TỪ FIREBASE
// =========================================================
class MainFeed extends ConsumerWidget {
  final Color primaryColor;
  final Color accentPink;

  const MainFeed(
      {super.key, required this.primaryColor, required this.accentPink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(globalFeedProvider);
    final currentUserAsync =
        ref.watch(currentUserProfileProvider); // Lấy user hiện tại

    // Kiểm tra mobile (dưới 900px)
    final isMobile = MediaQuery.of(context).size.width <= 900;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,

        // --- APP BAR (CHỈ HIỆN TRÊN MOBILE) ---
        appBar: isMobile
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                // Leading: Avatar User (Click để vào Profile)
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      // Điều hướng sang Profile bằng State Provider
                      ref.read(navProvider.notifier).state = AppSection.profile;
                    },
                    child: currentUserAsync.when(
                      loading: () => CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child:
                              const CircularProgressIndicator(strokeWidth: 2)),
                      error: (_, __) => const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.error)),
                      data: (user) {
                        final String displayName =
                            (user?.displayName.isNotEmpty ?? false)
                                ? user!.displayName
                                : "User";
                        final String avatarUrl = user?.avatarUrl ?? "";
                        final String initial = displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : "U";

                        if (avatarUrl.isNotEmpty) {
                          return CircleAvatar(
                            backgroundColor: primaryColor,
                            backgroundImage: NetworkImage(avatarUrl),
                          );
                        } else {
                          return CircleAvatar(
                            backgroundColor: primaryColor,
                            child: Text(initial,
                                style: const TextStyle(color: Colors.white)),
                          );
                        }
                      },
                    ),
                  ),
                ),
                title: const Text("Home",
                    style: TextStyle(
                        color: Color(0xFF5A4FCF), fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  // Nút Logout có xác nhận
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.black),
                    onPressed: () async {
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Đăng xuất'),
                          content: const Text(
                              'Bạn có chắc chắn muốn đăng xuất khỏi AI GenCourse?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );

                      if (shouldLogout == true) {
                        await AuthService().signOut();
                      }
                    },
                  )
                ],
              )
            : null,

        // Header Tab (For You / Following)
        body: Column(
          children: [
            // Tab Bar
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEFF3F4)))),
              child: TabBar(
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "For You"),
                  Tab(text: "Following"),
                  Tab(text: "Groups"),
                ],
              ),
            ),

            // Nội dung cuộn
            Expanded(
              child: ListView(
                children: [
                  // 1. Khung đăng bài (Post Composer)
                  const PostComposer(),

                  const Divider(thickness: 8, color: Color(0xFFF5F8FA)),

                  // 2. Danh sách bài viết (Load từ Firebase)
                  feedAsync.when(
                    data: (posts) {
                      if (posts.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rate_review_outlined,
                                    size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                const Text(
                                  "Chưa có bài viết nào.\nHãy là người đầu tiên lên tiếng!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return PostCard(post: post);
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, stack) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                          child: Text('Lỗi tải tin: $err',
                              style: const TextStyle(color: Colors.red))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Nút FAB cho Mobile
        floatingActionButton: isMobile
            ? FloatingActionButton(
                onPressed: () {},
                backgroundColor: accentPink,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }
}
