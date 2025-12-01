import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import thêm Firestore

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Khởi tạo Firestore

  // Đăng ký tài khoản mới + Lưu thông tin vào Database
  Future<User?> signUp(String email, String password) async {
    try {
      // 1. Tạo tài khoản bên Auth (Email/Pass)
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      User? user = result.user;

      // 2. Nếu tạo Auth thành công -> Ghi ngay vào Firestore
      if (user != null) {
        // Tách lấy phần tên trước @ của email làm username (VD: tuan@gmail.com -> tuan)
        String rawName = email.split('@')[0];

        // Tạo avatar mặc định theo tên
        String defaultAvatar =
            "https://ui-avatars.com/api/?name=$rawName&background=random&color=fff&size=128";

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'username': rawName, // Tên định danh (@username)
          'displayName': rawName, // Tên hiển thị
          'avatarUrl': defaultAvatar,
          'bio': "Thành viên mới của AI GenCourse",
          'followersCount': 0,
          'followingCount': 0,
          'createdAt': FieldValue.serverTimestamp(), // Thời gian tạo
          'searchKey': rawName.toLowerCase(), // Hỗ trợ tìm kiếm sau này
        });
      }

      return user;
    } catch (e) {
      print("Lỗi đăng ký: $e");
      throw e; // Ném lỗi để UI hiển thị (VD: Email đã tồn tại)
    }
  }

  // Đăng nhập
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print("Lỗi đăng nhập: $e");
      throw e; // Ném lỗi (VD: Sai mật khẩu)
    }
  }

  // Đăng nhập ẩn danh (Cho mục đích test nhanh)
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
