import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/post_model.dart';
import '../screens/post_detail_screen.dart';
import '../../providers/app_providers.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Gọi hàm đánh dấu đã đọc sau khi frame đầu tiên render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  void _markRead() {
    final user = ref.read(authProvider).currentUser;
    if (user != null) {
      // Gọi repository trực tiếp để update
      ref.read(userRepoProvider).markAllNotificationsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notification",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: notifsAsync.when(
        data: (notifs) {
          if (notifs.isEmpty) {
            return const Center(child: Text("Chưa có thông báo nào."));
          }
          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final notif = notifs[index];
              return Container(
                decoration: BoxDecoration(
                  color: notif.isRead
                      ? Colors.white
                      : Colors.blue.withOpacity(0.05), // Highlight tin chưa đọc
                ),
                child: ListTile(
                  leading: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        backgroundImage: (notif.fromAvatarUrl.isNotEmpty)
                            ? NetworkImage(notif.fromAvatarUrl)
                            : null,
                        child: notif.fromAvatarUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      Icon(
                        notif.type == 'like'
                            ? Icons.favorite
                            : Icons.chat_bubble,
                        size: 16,
                        color: notif.type == 'like' ? Colors.pink : Colors.blue,
                      )
                    ],
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                            text: notif.fromDisplayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text: notif.type == 'like'
                                ? " đã thích bài viết của bạn."
                                : " đã trả lời: ${notif.commentPreview ?? ''}"),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    notif.createdAt != null
                        ? timeago.format(notif.createdAt!)
                        : "",
                    style: const TextStyle(fontSize: 12),
                  ),
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
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Lỗi: $e")),
      ),
    );
  }
}
