// lib/data/models/post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String authorUid;
  final String authorName;
  final String authorUsername;
  final String authorAvatarUrl;
  final String visibility;
  final String text;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  PostModel({
    required this.postId,
    required this.authorUid,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    required this.visibility,
    required this.text,
    List<String>? imageUrls,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
  })  : imageUrls = imageUrls ?? [],
        createdAt = createdAt ?? DateTime.now(),
        likeCount = likeCount ?? 0,
        commentCount = commentCount ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorUid': authorUid,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
      'visibility': visibility,
      'text': text,
      'imageUrls': imageUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: doc.id,
      authorUid: data['authorUid'] ?? '',
      authorName: data['authorName'] ?? 'User',
      authorUsername: data['authorUsername'] ?? 'user',
      authorAvatarUrl: data['authorAvatarUrl'] ?? '',
      visibility: data['visibility'] ?? 'public',
      text: data['text'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
    );
  }
}
