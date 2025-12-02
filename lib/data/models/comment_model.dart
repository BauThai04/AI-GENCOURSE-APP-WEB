import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorUid;
  final String authorDisplayName;
  final String authorAvatarUrl;
  final String content;
  final DateTime? createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorDisplayName,
    required this.authorAvatarUrl,
    required this.content,
    this.createdAt,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorUid: data['authorUid'] ?? '',
      authorDisplayName: data['authorDisplayName'] ?? '',
      authorAvatarUrl: data['authorAvatarUrl'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorUid': authorUid,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
