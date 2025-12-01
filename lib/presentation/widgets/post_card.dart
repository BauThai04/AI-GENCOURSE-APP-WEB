import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/post_model.dart';
import '../screens/profile_screen.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: post.authorUid)));
  }

  @override
  Widget build(BuildContext context) {
    String timeAgo = post.createdAt != null
        ? DateFormat('MMM d').format(post.createdAt!)
        : "";

    return InkWell(
      onTap: () {},
      hoverColor: Colors.grey.shade50,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEFF3F4))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AVATAR
            GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: NetworkImage(post.authorAvatarUrl),
                onBackgroundImageError: (_, __) {},
              ),
            ),
            const SizedBox(width: 12),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(context),
                        child: Text(post.authorName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black)),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          color: Colors.blue, size: 16), // Giả lập tích xanh
                      const SizedBox(width: 4),
                      Text("@${post.authorUsername}",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15)),
                      const SizedBox(width: 4),
                      Text("· $timeAgo",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.more_horiz,
                          size: 18, color: Colors.grey),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // TEXT
                  if (post.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(post.text,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: Colors.black87)),
                    ),

                  // IMAGE (ĐÃ SỬA LỖI CONSTRAINTS)
                  if (post.imageUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          // 👉 CHUYỂN CONSTRAINTS RA ĐÂY LÀ ĐÚNG
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200)),
                          child: CachedNetworkImage(
                            imageUrl: post.imageUrls.first,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // ❌ Đã xóa dòng constraints gây lỗi ở đây
                            placeholder: (context, url) => Container(
                                height: 200, color: Colors.grey.shade100),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),

                  // ACTIONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _actionButton(
                          Icons.chat_bubble_outline, "${post.commentCount}"),
                      _actionButton(Icons.cached, "0"),
                      _actionButton(Icons.favorite_border, "${post.likeCount}"),
                      _actionButton(Icons.ios_share_outlined, ""),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            if (label != "0" && label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ]
          ],
        ),
      ),
    );
  }
}
