import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';

abstract class PostRepository {
  Future<void> createPost(PostModel postTemplate, List<dynamic> imageFiles);
  Stream<List<PostModel>> getGlobalFeed({int limit = 50});
  Stream<List<PostModel>> getUserPosts(String uid);

  // Like Features
  Future<void> toggleLike(
      {required String postId,
      required UserModel currentUser,
      required String postAuthorUid});
  Stream<bool> isPostLiked(String postId, String uid);

  // Comment Features
  Stream<List<CommentModel>> getComments(String postId);
  Future<void> addComment(
      {required String postId,
      required UserModel author,
      required String text,
      required String postAuthorUid});
}

class PostRepositoryImpl implements PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  PostRepositoryImpl();

  // --- POST LOGIC ---
  @override
  Future<void> createPost(
      PostModel postTemplate, List<dynamic> mediaFiles) async {
    final String postId = _uuid.v4();
    List<String> imageUrls = [];

    try {
      if (mediaFiles.isNotEmpty) {
        for (var file in mediaFiles) {
          final String fileName = "${_uuid.v4()}.jpg";
          final String path =
              'posts/${postTemplate.authorUid}/$postId/$fileName';
          final ref = _storage.ref().child(path);

          if (kIsWeb) {
            await ref.putData(
                file as Uint8List, SettableMetadata(contentType: 'image/jpeg'));
          } else {
            await ref.putFile(file as File);
          }
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      }

      final PostModel finalPost = PostModel(
        postId: postId,
        authorUid: postTemplate.authorUid,
        authorName: postTemplate.authorName,
        authorUsername: postTemplate.authorUsername,
        authorAvatarUrl: postTemplate.authorAvatarUrl,
        visibility: postTemplate.visibility,
        text: postTemplate.text,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('posts').doc(postId).set(finalPost.toMap());
    } catch (e) {
      debugPrint("Error creating post: $e");
      rethrow;
    }
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

  // --- LIKE LOGIC ---
  @override
  Future<void> toggleLike(
      {required String postId,
      required UserModel currentUser,
      required String postAuthorUid}) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(currentUser.uid);

    await _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        // Like
        transaction.set(likeRef, {
          'uid': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likeCount': FieldValue.increment(1)});

        // Tạo notification nếu không phải tự like bài mình
        if (currentUser.uid != postAuthorUid) {
          final notifRef = _firestore
              .collection('users')
              .doc(postAuthorUid)
              .collection('notifications')
              .doc();
          final notif = NotificationModel(
            id: notifRef.id,
            type: 'like',
            fromUid: currentUser.uid,
            fromDisplayName: currentUser.displayName,
            fromAvatarUrl: currentUser.avatarUrl,
            postId: postId,
            createdAt: DateTime.now(),
          );
          transaction.set(notifRef, notif.toMap());
        }
      }
    });
  }

  @override
  Stream<bool> isPostLiked(String postId, String uid) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // --- COMMENT LOGIC ---
  @override
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false) // Comment cũ nhất lên đầu
        .snapshots()
        .map((q) => q.docs.map((d) => CommentModel.fromFirestore(d)).toList());
  }

  @override
  Future<void> addComment(
      {required String postId,
      required UserModel author,
      required String text,
      required String postAuthorUid}) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();

    await _firestore.runTransaction((transaction) async {
      final newComment = CommentModel(
        id: commentRef.id,
        postId: postId,
        authorUid: author.uid,
        authorDisplayName: author.displayName,
        authorAvatarUrl: author.avatarUrl,
        content: text,
        createdAt: DateTime.now(),
      );

      transaction.set(commentRef, newComment.toMap());
      transaction.update(postRef, {'commentCount': FieldValue.increment(1)});

      // Tạo notification
      if (author.uid != postAuthorUid) {
        final notifRef = _firestore
            .collection('users')
            .doc(postAuthorUid)
            .collection('notifications')
            .doc();
        final notif = NotificationModel(
          id: notifRef.id,
          type: 'comment',
          fromUid: author.uid,
          fromDisplayName: author.displayName,
          fromAvatarUrl: author.avatarUrl,
          postId: postId,
          commentPreview:
              text.length > 30 ? "${text.substring(0, 30)}..." : text,
          createdAt: DateTime.now(),
        );
        transaction.set(notifRef, notif.toMap());
      }
    });
  }
}
