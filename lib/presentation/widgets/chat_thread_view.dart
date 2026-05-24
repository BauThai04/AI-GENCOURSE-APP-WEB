import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/chat_providers.dart';
import '../../providers/app_providers.dart';
import '../../data/models/chat_message_model.dart';

class ChatThreadView extends ConsumerWidget {
  final String chatId;
  const ChatThreadView({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe tin nhắn
    final messagesAsync = ref.watch(chatMessagesProvider(chatId));
    final myUid = ref.watch(authProvider).currentUser?.uid;

    return Column(
      children: [
        // 1. DANH SÁCH TIN NHẮN
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
            data: (messages) {
              if (messages.isEmpty)
                return const Center(child: Text("No messages yet. Say hi!"));

              return ListView.builder(
                reverse: true, // Tin nhắn mới nhất ở dưới cùng (đảo ngược list)
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderUid == myUid;
                  return _MessageBubble(message: msg, isMe: isMe);
                },
              );
            },
          ),
        ),

        // 2. THANH NHẬP LIỆU
        _MessageInputBar(chatId: chatId),
      ],
    );
  }
}

// BONG BÓNG CHAT
class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5A4FCF);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250), // Giới hạn chiều rộng
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: !isMe ? const Radius.circular(16) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hiển thị ảnh
            if (message.type == 'image' && message.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  placeholder: (_, __) =>
                      const CircularProgressIndicator(strokeWidth: 2),
                  errorWidget: (_, __, ___) => const Icon(Icons.error),
                ),
              ),

            // Hiển thị text
            if (message.type == 'text' && message.text != null)
              Text(
                message.text!,
                style: TextStyle(
                    color: isMe ? Colors.white : Colors.black, fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }
}

// THANH NHẬP LIỆU (INPUT BAR)
class _MessageInputBar extends ConsumerStatefulWidget {
  final String chatId;
  const _MessageInputBar({required this.chatId});

  @override
  ConsumerState<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<_MessageInputBar> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isSending = false;

  // Gửi Text
  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    _ctrl.clear();
    await ref
        .read(chatRepositoryProvider)
        .sendTextMessage(chatId: widget.chatId, sender: user, text: text);
  }

  // Gửi Ảnh
  Future<void> _sendImage() async {
    try {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) return;

      dynamic imageFile;
      if (kIsWeb) {
        var result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null) imageFile = result.files.first.bytes;
      } else {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) imageFile = File(img.path);
      }

      if (imageFile != null) {
        setState(() => _isSending = true);
        await ref.read(chatRepositoryProvider).sendImageMessage(
            chatId: widget.chatId, sender: user, imageFile: imageFile);
        setState(() => _isSending = false);
      }
    } catch (e) {
      print(e);
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5A4FCF);

    if (_isSending) return const LinearProgressIndicator(color: primaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.image_outlined, color: primaryColor),
                onPressed: _sendImage),
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  fillColor: Colors.grey.shade100,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.send, color: primaryColor),
                onPressed: _sendText),
          ],
        ),
      ),
    );
  }
}
