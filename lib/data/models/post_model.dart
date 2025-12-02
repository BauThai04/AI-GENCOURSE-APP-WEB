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
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;

  PostModel({
    required this.postId,
    required this.authorUid,
    required this.authorName,
    required this.authorUsername,
    required this.authorAvatarUrl,
    this.visibility = 'public',
    required this.text,
    required this.imageUrls,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

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
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return PostModel(
      postId: map['postId'] ?? '',
      authorUid: map['authorUid'] ?? '',
      authorName: map['authorName'] ?? '',
      authorUsername: map['authorUsername'] ?? '',
      authorAvatarUrl: map['authorAvatarUrl'] ?? '',
      visibility: map['visibility'] ?? 'public',
      text: map['text'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
