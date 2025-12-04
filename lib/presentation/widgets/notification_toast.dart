import 'package:flutter/material.dart';
import '../../data/models/notification_model.dart';

class NotificationToast extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const NotificationToast({
    super.key,
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 20, left: 20),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 320, // Kích thước chuẩn cho toast
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar người gửi
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (notif.fromAvatarUrl.isNotEmpty)
                      ? NetworkImage(notif.fromAvatarUrl)
                      : null,
                  child: (notif.fromAvatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                // Nội dung
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(
                              text: "${notif.fromDisplayName} ",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: notif.type == 'like'
                                  ? "đã thích bài viết của bạn."
                                  : "đã trả lời: ",
                            ),
                            if (notif.type == 'comment' &&
                                notif.commentPreview != null)
                              TextSpan(
                                text: notif.commentPreview!.length > 50
                                    ? "${notif.commentPreview!.substring(0, 50)}..."
                                    : notif.commentPreview,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
                              ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Nút đóng
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
