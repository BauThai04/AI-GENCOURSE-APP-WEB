import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_model.dart';
import '../data/models/post_model.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';

// ========================================================
// 1. FIREBASE INSTANCES (Cung cấp các instance cơ bản)
// ========================================================
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final storageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// ========================================================
// 2. REPOSITORIES (Logic xử lý dữ liệu)
// ========================================================

// Post Repository (Xử lý bài viết, ảnh)
final postRepositoryProvider = Provider<PostRepository>((ref) {
  // PostRepositoryImpl mới của bạn tự khởi tạo instance bên trong, không cần truyền tham số
  return PostRepositoryImpl();
});

// User Repository (Xử lý thông tin user, follow, search)
final userRepoProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(authProvider), // <-- QUAN TRỌNG: Cần Auth để check follow
  );
});

// ========================================================
// 3. AUTH & CURRENT USER
// ========================================================

// Theo dõi trạng thái đăng nhập
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authProvider).authStateChanges();
});

// Lấy thông tin chi tiết của người dùng hiện tại (My Profile)
final currentUserProfileProvider =
    StreamProvider.autoDispose<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      // Gọi qua Repository cho sạch code
      return ref.watch(userRepoProvider).getUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ========================================================
// 4. FEEDS & POSTS DATA
// ========================================================

// Lấy toàn bộ bài viết (Cho Home Feed)
final globalFeedProvider = StreamProvider.autoDispose<List<PostModel>>((ref) {
  final repo = ref.watch(postRepositoryProvider);
  return repo.getGlobalFeed();
});

// Lấy bài viết của một User cụ thể (Cho Profile Screen)
final userPostsProvider =
    StreamProvider.autoDispose.family<List<PostModel>, String>((ref, uid) {
  final repo = ref.watch(postRepositoryProvider);
  return repo.getUserPosts(uid);
});

// ========================================================
// 5. SEARCH LOGIC
// ========================================================

// Tìm kiếm User (Dùng cho ô Search Sidebar)
final userSearchProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(userRepoProvider).searchUsers(query);
});
