import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_model.dart';
import '../data/models/post_model.dart';
import '../data/models/comment_model.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';

// Firebase Instances
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final storageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// Repositories
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl();
});

final userRepoProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider), ref.watch(authProvider));
});

// Auth & User Profile
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authProvider).authStateChanges();
});

final currentUserProfileProvider =
    StreamProvider.autoDispose<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(userRepoProvider).getUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Feed Providers
final globalFeedProvider = StreamProvider.autoDispose<List<PostModel>>((ref) {
  return ref.watch(postRepositoryProvider).getGlobalFeed();
});

final userPostsProvider =
    StreamProvider.autoDispose.family<List<PostModel>, String>((ref, uid) {
  return ref.watch(postRepositoryProvider).getUserPosts(uid);
});

// Search
final userSearchProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(userRepoProvider).searchUsers(query);
});

// --- NEW PROVIDERS (Like, Comment, Notification) ---

// Check Like Status
final postLikedProvider =
    StreamProvider.family.autoDispose<bool, String>((ref, postId) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return Stream.value(false);
  return ref.watch(postRepositoryProvider).isPostLiked(postId, user.uid);
});

// Get Comments
final commentsProvider = StreamProvider.family
    .autoDispose<List<CommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).getComments(postId);
});

// Get Notifications
final notificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return Stream.value([]);

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((q) =>
          q.docs.map((d) => NotificationModel.fromFirestore(d)).toList());
});
