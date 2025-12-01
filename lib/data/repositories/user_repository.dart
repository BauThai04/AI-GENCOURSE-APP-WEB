import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth; // Thêm auth để biết ai đang thực hiện hành động

  UserRepository(this._firestore, this._auth);

  // --- 1. TÌM KIẾM USER (Code của bạn đã được tích hợp vào đây) ---
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final String searchTerm = query.toLowerCase();

    try {
      final snapshot = await _firestore
          .collection('users')
          // Tìm theo username hoặc display name (tùy bạn chọn field nào lưu lowercase)
          // Giả sử bạn đã lưu field 'username' là chữ thường
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

  // --- 2. LẤY THÔNG TIN CHI TIẾT USER (Cho ProfileScreen) ---
  Stream<UserModel> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        // Trả về user rỗng hoặc ném lỗi nếu không tìm thấy
        throw Exception('User not found');
      }
      return UserModel.fromMap(doc.data()!);
    });
  }

  // --- 3. KIỂM TRA ĐANG FOLLOW HAY KHÔNG (Cho nút Follow) ---
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

  // --- 4. HÀM FOLLOW / UNFOLLOW (Xử lý Logic) ---
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
        // Đang follow -> Hủy Follow
        transaction.delete(myFollowingRef);
        transaction.delete(targetFollowersRef);
        transaction
            .update(userRef, {'followingCount': FieldValue.increment(-1)});
        transaction
            .update(targetRef, {'followersCount': FieldValue.increment(-1)});
      } else {
        // Chưa follow -> Follow
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
}
