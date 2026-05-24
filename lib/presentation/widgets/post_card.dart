import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/models/post_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/nav_provider.dart';
import '../screens/post_detail_screen.dart';

class PostCard extends ConsumerWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  // 👉 Mở profile trong cột giữa (không push màn hình mới)
  void _openProfile(WidgetRef ref, String uid) {
    // uid = user mà ta muốn xem
    ref.read(viewedProfileIdProvider.notifier).state = uid;
    ref.read(navProvider.notifier).state = AppSection.profile;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLikedAsync = ref.watch(postLikedProvider(post.postId));
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    final String timeAgo = post.createdAt != null
        ? DateFormat('MMM d').format(post.createdAt!)
        : "";

    return GestureDetector(
      // Bấm vào card -> xem chi tiết truth
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent, // Di chuyển color vào decoration
          border: Border(
            bottom: BorderSide(color: Color(0xFFEFF3F4)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- AVATAR ----------------
            GestureDetector(
              onTap: () => _openProfile(ref, post.authorUid),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: post.authorAvatarUrl.isNotEmpty
                    ? NetworkImage(post.authorAvatarUrl)
                    : null,
                child: post.authorAvatarUrl.isEmpty
                    ? Text(
                        (post.authorName.isNotEmpty ? post.authorName[0] : 'U')
                            .toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // ---------------- NỘI DUNG ----------------
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER: tên, username, thời gian
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _openProfile(ref, post.authorUid),
                        child: Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "@${post.authorUsername} · $timeAgo",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Text bài viết
                  if (post.text.isNotEmpty)
                    Text(
                      post.text,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),

                  // Ảnh (nếu có)
                  if (post.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: post.imageUrls.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 200,
                              color: Colors.grey.shade100,
                            ),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ---------------- ACTION ROW ----------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Comment -> mở PostDetail
                      _actionButton(
                        context,
                        Icons.chat_bubble_outline,
                        "${post.commentCount}",
                        Colors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          );
                        },
                      ),

                      // Repost (placeholder)
                      _actionButton(
                        context,
                        Icons.cached,
                        "0",
                        Colors.green,
                        onTap: () {},
                      ),

                      // LIKE
                      isLikedAsync.when(
                        data: (isLiked) => _actionButton(
                          context,
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          "${post.likeCount}",
                          Colors.pink,
                          isActive: isLiked,
                          onTap: () async {
                            final user = currentUserAsync.value;
                            if (user != null) {
                              await ref.read(postRepositoryProvider).toggleLike(
                                    postId: post.postId,
                                    currentUser: user,
                                    postAuthorUid: post.authorUid,
                                  );
                            }
                          },
                        ),
                        loading: () => const Icon(
                          Icons.favorite_border,
                          size: 20,
                          color: Colors.grey,
                        ),
                        error: (_, __) => const Icon(Icons.error, size: 20),
                      ),

                      // Share (placeholder)
                      _actionButton(
                        context,
                        Icons.share_outlined,
                        "",
                        Colors.grey,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- WIDGET ACTION BUTTON ----------------
  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color, {
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? color : Colors.grey.shade600,
            ),
            if (label != "0" && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? color : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
