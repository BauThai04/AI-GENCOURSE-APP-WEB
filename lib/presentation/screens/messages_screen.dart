import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import '../../providers/chat_providers.dart';
import '../../providers/app_providers.dart'; // authProvider, userRepoProvider, ...
import '../../data/models/user_model.dart';
import '../widgets/chat_thread_view.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    if (isDesktop) {
      // --- DESKTOP: 2 COLUMN LAYOUT ---
      return Row(
        children: [
          // LEFT: chat list
          Container(
            width: 350,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: const _ChatListPanel(),
          ),
          // RIGHT: chat detail (header + thread)
          const Expanded(
            child: _ChatDetailPanel(),
          ),
        ],
      );
    } else {
      // --- MOBILE: only list screen; detail is a separate page ---
      return const Scaffold(
        backgroundColor: Colors.white,
        body: _ChatListPanel(),
      );
    }
  }
}

// =======================================================
// 1. LEFT PANEL – LIST OF CONVERSATIONS
// =======================================================

class _ChatListPanel extends ConsumerWidget {
  const _ChatListPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(userChatsProvider);
    final myUid = ref.watch(authProvider).currentUser?.uid;
    final selectedChatId = ref.watch(selectedChatIdProvider);

    return Column(
      children: [
        // Header + "Message someone..." search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Messages",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const _NewChatSheet(),
                  );
                },
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: Colors.grey),
                      SizedBox(width: 10),
                      Text(
                        "Message someone...",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Conversations list
        Expanded(
          child: chatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
            data: (chats) {
              if (chats.isEmpty) {
                return const Center(child: Text("No conversations yet."));
              }

              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final otherInfo = chat.getOtherParticipantInfo(myUid ?? '');
                  final isSelected = chat.chatId == selectedChatId;

                  // tạm: bold nếu tin cuối không phải mình gửi
                  final bool isBold = chat.lastSenderUid != myUid;

                  return Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF5A4FCF).withOpacity(0.08)
                          : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          otherInfo?['avatarUrl'] ?? '',
                        ),
                        onBackgroundImageError: (_, __) {},
                      ),
                      title: Text(
                        otherInfo?['displayName'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isBold ? FontWeight.bold : FontWeight.normal,
                          color: isBold ? Colors.black : Colors.grey,
                        ),
                      ),
                      trailing: Text(
                        timeago.format(
                          chat.lastTimestamp,
                          locale: 'en_short',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        final isDesktop =
                            MediaQuery.of(context).size.width > 900;

                        if (isDesktop) {
                          // desktop: chỉ set selectedChatId
                          ref.read(selectedChatIdProvider.notifier).state =
                              chat.chatId;
                        } else {
                          // mobile: push sang detail
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatDetailScreen(chatId: chat.chatId),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// =======================================================
// 2. RIGHT PANEL – CHAT DETAIL (DESKTOP)
// =======================================================

class _ChatDetailPanel extends ConsumerWidget {
  const _ChatDetailPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChatId = ref.watch(selectedChatIdProvider);

    if (selectedChatId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Select a conversation to start messaging",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ChatDetailBody(chatId: selectedChatId);
  }
}

// =======================================================
// 3. CHAT DETAIL BODY – dùng chung cho desktop & mobile
// =======================================================

class ChatDetailBody extends ConsumerWidget {
  final String chatId;
  const ChatDetailBody({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authProvider).currentUser?.uid;

    if (myUid == null) {
      return const Center(child: Text("Please sign in to chat."));
    }

    final chatsAsync = ref.watch(userChatsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
      data: (chats) {
        final chat = chats
            .where((c) => c.chatId == chatId)
            .cast<dynamic>()
            .fold<dynamic?>(null, (prev, c) => prev ?? c);

        if (chat == null) {
          return const Center(child: Text("Conversation not found."));
        }

        final otherInfo = chat.getOtherParticipantInfo(myUid) ?? {};
        final otherUid = otherInfo['uid'] as String?;

        if (otherUid == null) {
          // Fallback: chỉ có thông tin basic từ chat
          return Column(
            children: [
              _ChatUserHeader.fromMap(otherInfo),
              const Divider(height: 1),
              Expanded(child: ChatThreadView(chatId: chatId)),
            ],
          );
        }

        final userStream = ref.watch(userRepoProvider).getUserProfile(otherUid);

        return StreamBuilder<UserModel>(
          stream: userStream,
          builder: (context, snapshot) {
            final user = snapshot.data;

            return Column(
              children: [
                _ChatUserHeader(
                  displayName:
                      user?.displayName ?? (otherInfo['displayName'] ?? 'User'),
                  username: user?.username ?? (otherInfo['username'] ?? ''),
                  avatarUrl: user?.avatarUrl ?? (otherInfo['avatarUrl'] ?? ''),
                  followersCount: user?.followersCount ?? 0,
                  followingCount: user?.followingCount ?? 0,
                  joinedAt: user?.joinedAt,
                ),
                const Divider(height: 1),
                const SizedBox(height: 4),
                Expanded(child: ChatThreadView(chatId: chatId)),
              ],
            );
          },
        );
      },
    );
  }
}

// Header hiển thị thông tin user phía trên khung chat
class _ChatUserHeader extends StatelessWidget {
  final String displayName;
  final String username;
  final String avatarUrl;
  final int followersCount;
  final int followingCount;
  final DateTime? joinedAt;

  const _ChatUserHeader({
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.followersCount,
    required this.followingCount,
    required this.joinedAt,
  });

  // Fallback nếu chỉ có map từ chat
  factory _ChatUserHeader.fromMap(Map<String, dynamic> map) {
    return _ChatUserHeader(
      displayName: map['displayName'] ?? 'User',
      username: map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      joinedAt: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final joinedText = joinedAt != null
        ? "Joined ${DateFormat('MMM d, yyyy').format(joinedAt!)}"
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar + name
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        "@$username",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              // optional icon giống "info" bên Truth
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.info_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _statItem(followersCount, "Followers"),
              const SizedBox(width: 16),
              _statItem(followingCount, "Following"),
            ],
          ),
          if (joinedText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  joinedText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _statItem(int value, String label) {
    return Row(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// =======================================================
// 4. NEW CHAT SHEET (tạm placeholder như cũ)
// =======================================================

class _NewChatSheet extends StatelessWidget {
  const _NewChatSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 600,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Center(
        child: Text(
          "Search users in the sidebar -> Go to Profile -> Click 'Message' to start a chat.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// =======================================================
// 5. MOBILE CHAT DETAIL SCREEN – reuse ChatDetailBody
// =======================================================

class ChatDetailScreen extends StatelessWidget {
  final String chatId;
  const ChatDetailScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chat",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: ChatDetailBody(chatId: chatId),
    );
  }
}
