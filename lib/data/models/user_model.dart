import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final bool isVerified;
  final DateTime joinedAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.bio = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.isVerified = false,
    required this.joinedAt,
  });

  // Chuyển từ Object sang Map để lưu Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(
          joinedAt), // Lưu ý key là createdAt hoặc joinedAt tùy db cũ của bạn
    };
  }

  // Chuyển từ Firestore Map sang Object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      bio: map['bio'] ?? '',
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      // Xử lý Timestamp an toàn
      joinedAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
