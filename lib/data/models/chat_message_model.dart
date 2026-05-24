import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String senderUid;
  final String? text;
  final String type; // 'text', 'image', 'file', 'audio'
  final String? mediaUrl;
  final String? fileName;
  final int? fileSize;
  final DateTime createdAt;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.senderUid,
    this.text,
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
    this.fileSize,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'createdAt': FieldValue.serverTimestamp(), // Server time
      'isRead': isRead,
    };
  }

  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessageModel(
      id: doc.id,
      senderUid: data['senderUid'] ?? '',
      text: data['text'],
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      fileName: data['fileName'],
      fileSize: data['fileSize'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
    );
  }
}
