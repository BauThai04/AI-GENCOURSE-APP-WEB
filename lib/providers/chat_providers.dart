import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_providers.dart'; // Để lấy authProvider
import '../data/repositories/chat_repository.dart';
import '../data/models/chat_thread_model.dart';
import '../data/models/chat_message_model.dart';

// 1. Provider cho Repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

// 2. Danh sách các cuộc trò chuyện của User hiện tại (Real-time)
final userChatsProvider =
    StreamProvider.autoDispose<List<ChatThreadModel>>((ref) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return Stream.value([]);

  return ref.watch(chatRepositoryProvider).getUserChats(user.uid);
});

// 3. Quản lý Chat ID đang được chọn (Dùng cho giao diện Desktop 2 cột)
final selectedChatIdProvider = StateProvider<String?>((ref) => null);

// 4. Danh sách tin nhắn của 1 cuộc trò chuyện cụ thể (Real-time)
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).getMessages(chatId);
});

// 5. Quản lý AI Chat Session ID đang được chọn (Riverpod Provider để lưu trạng thái bền vững)
final activeAiSessionIdProvider = StateProvider<String?>((ref) => null);
