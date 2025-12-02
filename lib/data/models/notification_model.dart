import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'like' | 'comment'
  final String fromUid;
  final String fromDisplayName;
  final String fromAvatarUrl;
  final String postId;
  final String? commentPreview;
  final DateTime? createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromDisplayName,
    required this.fromAvatarUrl,
    required this.postId,
    this.commentPreview,
    this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: data['type'] ?? '',
      fromUid: data['fromUid'] ?? '',
      fromDisplayName: data['fromDisplayName'] ?? 'User',
      fromAvatarUrl: data['fromAvatarUrl'] ?? '',
      postId: data['postId'] ?? '',
      commentPreview: data['commentPreview'],
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'fromUid': fromUid,
      'fromDisplayName': fromDisplayName,
      'fromAvatarUrl': fromAvatarUrl,
      'postId': postId,
      'commentPreview': commentPreview,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
