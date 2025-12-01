import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Cần package intl để format ngày

import '../../providers/app_providers.dart'; // Để lấy authProvider
import 'profile_providers.dart'; // Các provider vừa tạo ở bước 3
import '../widgets/post_card.dart'; // Tái sử dụng thẻ bài viết

class ProfileScreen extends ConsumerWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  // Màu chủ đạo
  static const primaryColor = Color(0xFF5A4FCF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy thông tin user từ Stream
    final userAsync = ref.watch(userProfileProvider(userId));

    // Kiểm tra xem đây là profile của mình hay người khác
    final currentUid = ref.watch(authProvider).currentUser?.uid;
    final isMe = currentUid == userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Lỗi: $err")),
        data: (user) {
          return DefaultTabController(
            length: 3, // Truths, Replies, Media
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header (Avatar + Nút Follow)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: NetworkImage(user.avatarUrl),
                                onBackgroundImageError: (_, __) {},
                              ),
                              if (!isMe)
                                _FollowButton(targetUid: user.uid)
                              else
                                OutlinedButton(
                                  onPressed: () {}, // TODO: Edit Profile
                                  style: OutlinedButton.styleFrom(
                                      shape: const StadiumBorder()),
                                  child: const Text("Edit Profile"),
                                )
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 2. Tên và Username
                          Text(user.displayName,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text("@${user.username}",
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.grey)),

                          const SizedBox(height: 12),

                          // 3. Bio
                          if (user.bio.isNotEmpty)
                            Text(user.bio,
                                style: const TextStyle(fontSize: 15)),

                          const SizedBox(height: 12),

                          // 4. Ngày tham gia & Follow stats
                          Row(
                            children: [
                              const Icon(Icons.calendar_month,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                  "Joined ${DateFormat.yMMMd().format(user.joinedAt)}",
                                  style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _statItem(user.followingCount, "Following"),
                              const SizedBox(width: 20),
                              _statItem(user.followersCount, "Followers"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. TabBar dính
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        labelColor: primaryColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: primaryColor,
                        tabs: [
                          Tab(text: "Truths"),
                          Tab(text: "Replies"),
                          Tab(text: "Media"),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildUserPosts(ref), // Tab 1: Bài viết
                  const Center(child: Text("No replies yet")), // Tab 2
                  const Center(child: Text("No media yet")), // Tab 3
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statItem(int count, String label) {
    return Row(
      children: [
        Text("$count",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  // Danh sách bài viết của User
  Widget _buildUserPosts(WidgetRef ref) {
    final postsAsync = ref.watch(profilePostsProvider(userId));
    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) return const Center(child: Text("No posts yet"));
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }
}

// --- WIDGET NÚT FOLLOW THÔNG MINH ---
class _FollowButton extends ConsumerWidget {
  final String targetUid;
  const _FollowButton({required this.targetUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowingAsync = ref.watch(isFollowingProvider(targetUid));

    return isFollowingAsync.when(
      data: (isFollowing) {
        return ElevatedButton(
          onPressed: () async {
            // Gọi hàm trong Repository
            await ref.read(userRepoProvider).toggleFollow(targetUid);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isFollowing ? Colors.white : const Color(0xFF5A4FCF),
            foregroundColor:
                isFollowing ? const Color(0xFF5A4FCF) : Colors.white,
            shape: const StadiumBorder(),
            side: isFollowing
                ? const BorderSide(color: Color(0xFF5A4FCF))
                : BorderSide.none,
          ),
          child: Text(isFollowing ? "Following" : "Follow"),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

// Helper cho Sticky Header
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
