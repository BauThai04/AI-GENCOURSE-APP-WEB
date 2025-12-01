import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';

abstract class PostRepository {
  Future<void> createPost(PostModel postTemplate, List<dynamic> mediaFiles);
  Stream<List<PostModel>> getGlobalFeed({int limit = 50});
  Stream<List<PostModel>> getUserPosts(String uid);
}

class PostRepositoryImpl implements PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Không cần truyền tham số nữa → đơn giản, sạch
  PostRepositoryImpl();

  @override
  Future<void> createPost(
      PostModel postTemplate, List<dynamic> mediaFiles) async {
    // SINH POSTID TRƯỚC KHI UPLOAD ẢNH → BẮT BUỘC!
    final String postId = _uuid.v4();
    final DateTime createdAt = DateTime.now().toUtc();
    final List<String> imageUrls = [];

    try {
      // 1. UPLOAD ẢNH (dùng postId đã sinh)
      if (mediaFiles.isNotEmpty) {
        final List<Future<void>> uploadFutures = [];

        for (var file in mediaFiles) {
          final String fileId = _uuid.v4();
          final String ext = _getExtension(file);
          final String fileName = '$fileId$ext';
          final String path =
              'posts/${postTemplate.authorUid}/$postId/$fileName'; // ĐÚNG!

          final ref = _storage.ref().child(path);
          UploadTask task;

          if (kIsWeb) {
            if (file is Uint8List) {
              task = ref.putData(
                  file, SettableMetadata(contentType: _guessMime(ext)));
            } else
              continue;
          } else {
            if (file is File) {
              task = ref.putFile(
                  file, SettableMetadata(contentType: _guessMime(ext)));
            } else
              continue;
          }

          uploadFutures.add(
            task.whenComplete(() => null).then((_) async {
              final url = await ref.getDownloadURL();
              imageUrls.add(url);
            }).catchError((e) => debugPrint("Upload lỗi 1 file: $e")),
          );
        }

        if (uploadFutures.isNotEmpty) {
          await Future.wait(uploadFutures);
        }
      }

      // 2. TẠO POST HOÀN CHỈNH
      final PostModel finalPost = PostModel(
        postId: postId,
        authorUid: postTemplate.authorUid,
        authorName: postTemplate.authorName,
        authorUsername: postTemplate.authorUsername,
        authorAvatarUrl: postTemplate.authorAvatarUrl,
        visibility: postTemplate.visibility,
        text: (postTemplate.text ?? '').trim(),
        imageUrls: imageUrls,
        createdAt: createdAt,
        likeCount: 0,
        commentCount: 0,
      );

      // 3. LƯU VÀO FIRESTORE
      await _firestore
          .collection('posts')
          .doc(postId)
          .set(finalPost.toMap(), SetOptions(merge: false));

      debugPrint("Đăng bài thành công: $postId");
    } catch (e, s) {
      debugPrint("Lỗi createPost: $e\n$s");
      rethrow;
    }
  }

  // Helper: đoán MIME type
  String _guessMime(String ext) {
    switch (ext.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      default:
        return 'image/jpeg';
    }
  }

  // Helper: lấy đuôi file
  String _getExtension(dynamic file) {
    if (file is File) {
      final path = file.path.toLowerCase();
      final ext =
          path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg';
      return ext;
    }
    return '.jpg'; // Web hoặc fallback
  }

  @override
  Stream<List<PostModel>> getGlobalFeed({int limit = 50}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => PostModel.fromFirestore(d)).toList());
  }

  @override
  Stream<List<PostModel>> getUserPosts(String uid) {
    return _firestore
        .collection('posts')
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((q) => q.docs.map((d) => PostModel.fromFirestore(d)).toList());
  }
}
