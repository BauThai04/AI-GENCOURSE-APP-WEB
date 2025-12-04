import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRepository(this._firestore, this._auth);

  // ... (Các hàm searchUsers, getUserProfile, isFollowing, toggleFollow GIỮ NGUYÊN) ...
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final String searchTerm = query.toLowerCase();
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThan: '$searchTerm\uf8ff')
          .limit(5)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    } catch (e) {
      print("Lỗi search user: $e");
      return [];
    }
  }

  Stream<UserModel> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) throw Exception('User not found');
      return UserModel.fromMap(doc.data()!);
    });
  }

  Stream<bool> isFollowing(String targetUid) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleFollow(String targetUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) throw Exception('Must be logged in');
    final userRef = _firestore.collection('users').doc(currentUid);
    final targetRef = _firestore.collection('users').doc(targetUid);
    final myFollowingRef = userRef.collection('following').doc(targetUid);
    final targetFollowersRef =
        targetRef.collection('followers').doc(currentUid);

    await _firestore.runTransaction((transaction) async {
      final myFollowingDoc = await transaction.get(myFollowingRef);
      if (myFollowingDoc.exists) {
        transaction.delete(myFollowingRef);
        transaction.delete(targetFollowersRef);
        transaction
            .update(userRef, {'followingCount': FieldValue.increment(-1)});
        transaction
            .update(targetRef, {'followersCount': FieldValue.increment(-1)});
      } else {
        transaction
            .set(myFollowingRef, {'createdAt': FieldValue.serverTimestamp()});
        transaction.set(
            targetFollowersRef, {'createdAt': FieldValue.serverTimestamp()});
        transaction
            .update(userRef, {'followingCount': FieldValue.increment(1)});
        transaction
            .update(targetRef, {'followersCount': FieldValue.increment(1)});
      }
    });
  }

  // --- MỚI: ĐÁNH DẤU TẤT CẢ THÔNG BÁO LÀ ĐÃ ĐỌC ---
  Future<void> markAllNotificationsRead() async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    // Lấy các notif chưa đọc
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    // Dùng Batch để update nhanh và tiết kiệm write
    WriteBatch batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
