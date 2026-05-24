// lib/providers/app_providers.dart
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

import '../services/youtube_service.dart';
import '../services/news_service.dart';
import '../data/models/youtube_video_model.dart';
import '../data/models/news_article_model.dart';

// ===================================================================
//  FIREBASE INSTANCES
// ===================================================================

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final storageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// ===================================================================
//  REPOSITORIES
// ===================================================================

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl();
});

final userRepoProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(authProvider),
  );
});

// ===================================================================
//  AUTH & USER PROFILE
// ===================================================================

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

// ===================================================================
//  FEED PROVIDERS
// ===================================================================

final globalFeedProvider = StreamProvider.autoDispose<List<PostModel>>((ref) {
  return ref.watch(postRepositoryProvider).getGlobalFeed();
});

final userPostsProvider =
    StreamProvider.autoDispose.family<List<PostModel>, String>((ref, uid) {
  return ref.watch(postRepositoryProvider).getUserPosts(uid);
});

// ===================================================================
//  SEARCH
// ===================================================================

final userSearchProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(userRepoProvider).searchUsers(query);
});

// ===================================================================
//  LIKE & COMMENTS
// ===================================================================

final postLikedProvider =
    StreamProvider.family.autoDispose<bool, String>((ref, postId) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) {
    // ❌ KHÔNG dùng const ở đây
    return Stream<bool>.value(false);
  }
  return ref.watch(postRepositoryProvider).isPostLiked(postId, user.uid);
});

final commentsProvider = StreamProvider.family
    .autoDispose<List<CommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).getComments(postId);
});

// ===================================================================
//  NOTIFICATIONS
// ===================================================================

final notificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) {
    // ❌ KHÔNG dùng const ở đây
    return Stream<List<NotificationModel>>.value([]);
  }

  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (q) => q.docs.map((d) => NotificationModel.fromFirestore(d)).toList(),
      );
});

final hasUnreadNotificationsProvider = Provider.autoDispose<bool>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.any((n) => !n.isRead),
    orElse: () => false,
  );
});

// ===================================================================
//  EXTERNAL API: YOUTUBE & NEWS
// ===================================================================

const _youtubeApiKey = 'AIzaSyBs20nwAy0Yr3GEidkrnVE3a6RYnEiAt5E';
const _newsApiKey = '3cd1ce49977b4aa296c0e4fd74aefb8f';

final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  return YoutubeService(_youtubeApiKey);
});

final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService(_newsApiKey);
});

/// Desktop / sidebar: AI videos mặc định
final youtubeVideosProvider =
    FutureProvider.autoDispose<List<YoutubeVideo>>((ref) async {
  return ref.watch(youtubeServiceProvider).fetchAiVideos();
});

/// Desktop / sidebar: Tech news mặc định
final newsArticlesProvider =
    FutureProvider.autoDispose<List<NewsArticle>>((ref) async {
  return ref.watch(newsServiceProvider).fetchTechNews();
});

// ===================================================================
//  MOBILE SEARCH – YOUTUBE & NEWS
// ===================================================================

/// Mobile: YouTube trending (khi chưa nhập query)
final mobileYoutubeTrendingProvider =
    FutureProvider.autoDispose<List<YoutubeVideo>>((ref) async {
  return ref.watch(youtubeServiceProvider).fetchAiVideos();
});

/// Mobile: search YouTube theo query
final mobileYoutubeSearchProvider = FutureProvider.autoDispose
    .family<List<YoutubeVideo>, String>((ref, query) async {
  final service = ref.watch(youtubeServiceProvider);
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return service.fetchAiVideos();
  }
  return service.searchVideos(trimmed);
});

/// Mobile: News trending (khi chưa nhập query)
final mobileNewsTrendingProvider =
    FutureProvider.autoDispose<List<NewsArticle>>((ref) async {
  return ref.watch(newsServiceProvider).fetchTechNews();
});

/// Mobile: search News theo query
final mobileNewsSearchProvider = FutureProvider.autoDispose
    .family<List<NewsArticle>, String>((ref, query) async {
  final service = ref.watch(newsServiceProvider);
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return service.fetchTechNews();
  }
  return service.searchNews(trimmed);
});
