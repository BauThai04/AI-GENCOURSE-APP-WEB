import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThreadModel {
  final String chatId;
  final List<String> participants;
  // Map lưu info nhanh để không phải query lại User nhiều lần
  // Key: uid, Value: {'displayName': '...', 'avatarUrl': '...'}
  final Map<String, dynamic> participantInfos;
  final String lastMessage;
  final String lastSenderUid;
  final DateTime lastTimestamp;
  final DateTime createdAt;

  ChatThreadModel({
    required this.chatId,
    required this.participants,
    required this.participantInfos,
    required this.lastMessage,
    required this.lastSenderUid,
    required this.lastTimestamp,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'participantInfos': participantInfos,
      'lastMessage': lastMessage,
      'lastSenderUid': lastSenderUid,
      'lastTimestamp': Timestamp.fromDate(lastTimestamp),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ChatThreadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatThreadModel(
      chatId: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      participantInfos:
          Map<String, dynamic>.from(data['participantInfos'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastSenderUid: data['lastSenderUid'] ?? '',
      lastTimestamp:
          (data['lastTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Helper: Lấy thông tin người chat cùng (người không phải là mình)
  Map<String, dynamic>? getOtherParticipantInfo(String myUid) {
    final otherUid =
        participants.firstWhere((uid) => uid != myUid, orElse: () => '');
    if (otherUid.isEmpty) return null;
    return participantInfos[otherUid];
  }
}
