import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/app_providers.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Alerts",
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
              return ListTile(
                leading: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                        backgroundImage: NetworkImage(notif.fromAvatarUrl)),
                    Icon(
                      notif.type == 'like' ? Icons.favorite : Icons.chat_bubble,
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
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
                onTap: () {
                  // TODO: Navigate to Post Detail based on notif.postId
                },
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
