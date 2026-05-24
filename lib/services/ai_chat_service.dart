import 'package:cloud_firestore/cloud_firestore.dart';

/// Lớp đại diện cho một phiên hội thoại AI
class AiChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  AiChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory AiChatSession.fromFirestore(Map<String, dynamic> data, String docId) {
    return AiChatSession(
      id: docId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Cuộc trò chuyện mới',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }
}

/// Lớp đại diện cho một tin nhắn AI
class AiChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;

  AiChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
  });

  factory AiChatMessage.fromFirestore(Map<String, dynamic> data, String docId) {
    return AiChatMessage(
      id: docId,
      text: data['text'] ?? '',
      isMe: data['isMe'] ?? false,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'isMe': isMe,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

/// Dịch vụ quản lý Lịch sử Chat AI với Firestore
class AiChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Tạo một phiên chat mới
  Future<String> createSession(String userId, String title) async {
    final docRef = _firestore.collection('ai_chats').doc();
    final session = AiChatSession(
      id: docRef.id,
      userId: userId,
      title: title,
      createdAt: DateTime.now(),
      lastUpdatedAt: DateTime.now(),
    );
    await docRef.set(session.toFirestore());
    return docRef.id;
  }

  /// Cập nhật tiêu đề phiên chat
  Future<void> updateSessionTitle(String sessionId, String title) async {
    await _firestore.collection('ai_chats').doc(sessionId).update({
      'title': title,
    });
  }

  /// Xóa phiên chat và tất cả tin nhắn con
  Future<void> deleteSession(String sessionId) async {
    // 1. Xóa tất cả các tài liệu tin nhắn con trước
    final messagesSnapshot = await _firestore
        .collection('ai_chats')
        .doc(sessionId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // 2. Xóa tài liệu phiên chat cha
    await _firestore.collection('ai_chats').doc(sessionId).delete();
  }

  /// Lấy Stream danh sách các phiên chat của User (Sắp xếp local để tránh yêu cầu Composite Index trên Firestore)
  Stream<List<AiChatSession>> getSessions(String userId) {
    return _firestore
        .collection('ai_chats')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AiChatSession.fromFirestore(doc.data(), doc.id))
          .toList();

      // Sắp xếp local theo thời gian cập nhật mới nhất (lastUpdatedAt) giảm dần
      list.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
      return list;
    });
  }

  /// Lưu một tin nhắn mới và cập nhật thời gian phản hồi/tương tác mới nhất của Session
  Future<void> saveMessage(String sessionId, String text, bool isMe) async {
    final docRef = _firestore
        .collection('ai_chats')
        .doc(sessionId)
        .collection('messages')
        .doc();

    final message = AiChatMessage(
      id: docRef.id,
      text: text,
      isMe: isMe,
      timestamp: DateTime.now(),
    );

    // Sử dụng Write Batch để đảm bảo lưu tin nhắn và cập nhật Session đồng bộ
    final batch = _firestore.batch();
    batch.set(docRef, message.toFirestore());
    batch.update(_firestore.collection('ai_chats').doc(sessionId), {
      'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
    });
    await batch.commit();
  }

  /// Lấy Stream danh sách tin nhắn của một phiên chat, sắp xếp theo thứ tự thời gian
  Stream<List<AiChatMessage>> getMessages(String sessionId) {
    return _firestore
        .collection('ai_chats')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AiChatMessage.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }
}
