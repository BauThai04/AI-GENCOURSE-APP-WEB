import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // check kIsWeb
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/chat_thread_model.dart';
import '../models/chat_message_model.dart';

abstract class ChatRepository {
  Stream<List<ChatThreadModel>> getUserChats(String uid);
  Future<String> createOrGetChat(String myUid, UserModel me, UserModel other);
  Stream<List<ChatMessageModel>> getMessages(String chatId);
  Future<void> sendTextMessage(
      {required String chatId,
      required UserModel sender,
      required String text});
  Future<void> sendImageMessage(
      {required String chatId,
      required UserModel sender,
      required dynamic imageFile});
}

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  ChatRepositoryImpl();

  // 1. Lấy danh sách các cuộc trò chuyện của User
  @override
  Stream<List<ChatThreadModel>> getUserChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatThreadModel.fromFirestore(doc))
            .toList());
  }

  // 2. Tạo hoặc Lấy Chat ID (Logic Deterministic)
  @override
  Future<String> createOrGetChat(
      String myUid, UserModel me, UserModel other) async {
    // Sắp xếp UID để luôn tạo ra 1 ID duy nhất cho cặp đôi này bất kể ai bắt đầu trước
    final List<String> uids = [myUid, other.uid];
    uids.sort();
    final String chatId = "${uids[0]}_${uids[1]}";

    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    // Nếu chưa có thì tạo mới document Chat Thread
    if (!chatDoc.exists) {
      final newChat = ChatThreadModel(
        chatId: chatId,
        participants: uids,
        participantInfos: {
          myUid: {
            'displayName': me.displayName,
            'avatarUrl': me.avatarUrl,
            'username': me.username
          },
          other.uid: {
            'displayName': other.displayName,
            'avatarUrl': other.avatarUrl,
            'username': other.username
          },
        },
        lastMessage: 'Started a conversation',
        lastSenderUid: myUid,
        lastTimestamp: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await chatRef.set(newChat.toMap());
    }
    return chatId;
  }

  // 3. Lấy tin nhắn Real-time
  @override
  Stream<List<ChatMessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt',
            descending:
                true) // Mới nhất ở dưới (khi hiển thị sẽ reverse listview)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromFirestore(doc))
            .toList());
  }

  // Helper: Gửi tin nhắn chung (Update Thread + Add Message)
  Future<void> _sendMessage(
      String chatId, Map<String, dynamic> messageData, String summary) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc();

    final batch = _firestore.batch();

    // Tạo doc message
    batch.set(messageRef, {
      ...messageData,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // Update doc thread (để hiện tin nhắn cuối cùng ra ngoài list)
    batch.update(chatRef, {
      'lastMessage': summary,
      'lastSenderUid': messageData['senderUid'],
      'lastTimestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 4. Gửi Text
  @override
  Future<void> sendTextMessage(
      {required String chatId,
      required UserModel sender,
      required String text}) async {
    await _sendMessage(
        chatId, {'senderUid': sender.uid, 'text': text, 'type': 'text'}, text);
  }

  // 5. Gửi Ảnh
  @override
  Future<void> sendImageMessage(
      {required String chatId,
      required UserModel sender,
      required dynamic imageFile}) async {
    // Upload ảnh
    String fileName = "${_uuid.v4()}.jpg";
    String path = 'chats/$chatId/images/$fileName';
    Reference ref = _storage.ref().child(path);

    if (kIsWeb) {
      await ref.putData(
          imageFile as Uint8List, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(imageFile as File);
    }
    String url = await ref.getDownloadURL();

    // Gửi tin nhắn chứa link ảnh
    await _sendMessage(
        chatId,
        {'senderUid': sender.uid, 'type': 'image', 'mediaUrl': url},
        "Sent an image");
  }
}
