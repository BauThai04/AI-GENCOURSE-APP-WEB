import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lớp thực thể đại diện cho một phòng học cộng đồng
class CommunityRoom {
  final String id;
  final String name;
  final String description;
  final String agoraAppId;
  final String agoraChannelName;
  final String agoraToken;
  final String creatorId;
  final String creatorName;
  final int activeUsersCount;
  final DateTime createdAt;
  final bool isMock;

  CommunityRoom({
    required this.id,
    required this.name,
    required this.description,
    required this.agoraAppId,
    required this.agoraChannelName,
    required this.agoraToken,
    required this.creatorId,
    required this.creatorName,
    required this.activeUsersCount,
    required this.createdAt,
    this.isMock = false,
  });

  factory CommunityRoom.fromFirestore(Map<String, dynamic> data, String docId) {
    return CommunityRoom(
      id: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      agoraAppId: data['agoraAppId'] ?? '',
      agoraChannelName: data['agoraChannelName'] ?? '',
      agoraToken: data['agoraToken'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      activeUsersCount: data['activeUsersCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMock: data['isMock'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'agoraAppId': agoraAppId,
      'agoraChannelName': agoraChannelName,
      'agoraToken': agoraToken,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'activeUsersCount': activeUsersCount,
      'createdAt': FieldValue.serverTimestamp(),
      'isMock': isMock,
    };
  }
}

/// Lớp đại diện cho một tin nhắn thảo luận trong phòng học cộng đồng
class CommunityMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String text;
  final DateTime timestamp;

  CommunityMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timestamp,
  });

  factory CommunityMessage.fromFirestore(Map<String, dynamic> data, String docId) {
    return CommunityMessage(
      id: docId,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Học viên ẩn danh',
      senderAvatar: data['senderAvatar'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

// ===================================================================
//  PROVIDERS
// ===================================================================

/// Stream danh sách các phòng học cộng đồng từ Firestore (Sắp xếp thời gian tạo giảm dần)
final communitiesStreamProvider = StreamProvider.autoDispose<List<CommunityRoom>>((ref) {
  return FirebaseFirestore.instance
      .collection('communities')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CommunityRoom.fromFirestore(doc.data(), doc.id))
        .toList();
  });
});

/// Quản lý ID của Community hiện tại đang được người dùng lựa chọn thảo luận
final selectedCommunityIdProvider = StateProvider<String?>((ref) => null);

/// Stream danh sách tin nhắn thảo luận thời gian thực của một phòng học cụ thể
final communityMessagesStreamProvider = StreamProvider.autoDispose.family<List<CommunityMessage>, String>((ref, communityId) {
  return FirebaseFirestore.instance
      .collection('communities')
      .doc(communityId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CommunityMessage.fromFirestore(doc.data(), doc.id))
        .toList();
  });
});
