import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/models/post_model.dart';

// 1. Lấy thông tin chi tiết User (Real-time)
final userProfileProvider =
    StreamProvider.family.autoDispose<UserModel, String>((ref, uid) {
  final repo = ref.watch(userRepoProvider);
  return repo.getUserProfile(uid);
});

// 2. Lấy danh sách bài viết của User đó
final profilePostsProvider =
    StreamProvider.family.autoDispose<List<PostModel>, String>((ref, uid) {
  final repo = ref.watch(postRepositoryProvider);
  return repo.getUserPosts(uid);
});

// 3. Kiểm tra xem mình có đang Follow người này không
final isFollowingProvider =
    StreamProvider.family.autoDispose<bool, String>((ref, targetUid) {
  final repo = ref.watch(userRepoProvider);
  return repo.isFollowing(targetUid);
});
