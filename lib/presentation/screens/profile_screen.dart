import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../widgets/post_card.dart';
import '../../providers/nav_provider.dart';

class ProfileScreen extends ConsumerWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  // Màu chủ đạo
  static const primaryColor = Color(0xFF5A4FCF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Lấy stream thông tin User
    final userStream = ref.watch(userRepoProvider).getUserProfile(userId);

    // 2. Lấy danh sách bài viết của user này (dùng Provider có sẵn)
    final postsAsync = ref.watch(userPostsProvider(userId));

    return Scaffold(
      backgroundColor: Colors.white,

      // AppBar đơn giản
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),

        // 🔥 SỬA LẠI PHẦN leading Ở ĐÂY
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);

            if (navigator.canPop()) {
              // Trường hợp Profile được mở bằng Navigator.push(...)
              navigator.pop();
            } else {
              // Trường hợp Profile đang là "root" do navProvider
              ref.read(navProvider.notifier).state = AppSection.home;
            }
          },
        ),
      ),

      body: StreamBuilder<UserModel>(
        stream: userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Không tìm thấy người dùng"));
          }

          final user = snapshot.data!;
          final joinedDate = DateFormat("dd/MM/yyyy").format(user.joinedAt);
          final initial = user.displayName.isNotEmpty
              ? user.displayName[0].toUpperCase()
              : "U";

          return DefaultTabController(
            length: 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar & Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar
                              if (user.avatarUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 36,
                                  backgroundImage: NetworkImage(user.avatarUrl),
                                  backgroundColor: Colors.grey.shade200,
                                )
                              else
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor:
                                      primaryColor.withOpacity(0.2),
                                  child: Text(initial,
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor)),
                                ),

                              // Nút Edit / Follow (Placeholder)
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  side: const BorderSide(color: Colors.grey),
                                ),
                                child: const Text("Edit Profile",
                                    style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Tên hiển thị
                          Text(user.displayName,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          Text("@${user.username}",
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.grey)),

                          const SizedBox(height: 12),

                          // Bio
                          Text(
                            user.bio.isNotEmpty
                                ? user.bio
                                : "Thành viên mới của AI GenCourse",
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),

                          const SizedBox(height: 12),

                          // Ngày tham gia
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text("Tham gia ngày $joinedDate",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 14)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Follow Stats
                          Row(
                            children: [
                              _buildStat(user.followingCount, "đang theo dõi"),
                              const SizedBox(width: 16),
                              _buildStat(user.followersCount, "người theo dõi"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // TabBar
                  const SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      TabBar(
                        labelColor: primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: primaryColor,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: "Truths"),
                          Tab(text: "Replies"),
                          Tab(text: "Media"),
                          Tab(text: "Likes"),
                        ],
                      ),
                    ),
                  ),
                ];
              },

              // Body Tabs
              body: TabBarView(
                children: [
                  // Tab 1: Bài viết của User
                  postsAsync.when(
                    data: (posts) {
                      if (posts.isEmpty) {
                        return _buildEmptyState(
                            "User này chưa có bài đăng nào.");
                      }
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: posts.length,
                        itemBuilder: (context, index) =>
                            PostCard(post: posts[index]),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text("Lỗi: $e")),
                  ),

                  // Các tab khác (Placeholder)
                  _buildEmptyState("No Replies yet"),
                  _buildEmptyState("No Media yet"),
                  _buildEmptyState("No Likes yet"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(int count, String label) {
    return Row(
      children: [
        Text("$count",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// Helper Class cho Sticky TabBar
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  const _StickyTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}
