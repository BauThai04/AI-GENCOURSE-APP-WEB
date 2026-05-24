import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dịch vụ Xác thực Sinh trắc học (Face ID / Vân tay) độc lập và thông minh
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Kiểm tra xem thiết bị có hỗ trợ phần cứng sinh trắc học hay không
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false; // Nền tảng Web không hỗ trợ local_auth native API

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('Lỗi kiểm tra tính khả dụng của sinh trắc học: $e');
      return false;
    }
  }

  /// Kiểm tra xem thiết bị có hỗ trợ và đã cài đặt quét sinh trắc học cụ thể không
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];

    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Lỗi lấy danh sách sinh trắc học khả dụng: $e');
      return [];
    }
  }

  /// Trả về Icon Flutter phù hợp với loại sinh trắc học an toàn được hệ thống hỗ trợ
  Future<IconData> getBiometricIcon() async {
    if (kIsWeb) return Icons.fingerprint;

    // Trên nền tảng iOS, Face ID là phương thức chủ đạo và bảo mật rất cao
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final available = await getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        return Icons.face;
      }
      return Icons.fingerprint;
    }

    // Trên Android, mặc dù có nhận diện khuôn mặt 2D (Class 2 - Weak) nhưng hệ thống
    // chỉ cho phép các ứng dụng bên thứ ba sử dụng Vân tay (Class 3 - Strong) để bảo mật.
    // Vì vậy, để hướng dẫn chính xác hành động của người dùng Android (chạm tay vào cảm biến),
    // chúng ta sẽ ưu tiên hiển thị biểu tượng Vân tay.
    return Icons.fingerprint;
  }

  /// Trả về mô tả hoặc nhãn phù hợp với loại sinh trắc học khả dụng
  Future<String> getBiometricLabel() async {
    if (kIsWeb) return "Sinh trắc học";

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final available = await getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        return "Face ID";
      }
      return "Touch ID";
    }

    // Trên Android, đa số các thiết bị sẽ yêu cầu Vân tay hoặc mã khóa
    return "Vân tay / Mã PIN";
  }

  /// Thực hiện hành động quét sinh trắc học (Face ID / Vân tay) hệ thống
  Future<bool> authenticate() async {
    if (kIsWeb) return false; // Nền tảng Web không hỗ trợ local_auth native API

    try {
      // Sử dụng trực tiếp class từ package local_auth gốc
      return await _auth.authenticate(
        localizedReason: 'Vui lòng xác thực khuôn mặt hoặc vân tay để đăng nhập',
        options: const AuthenticationOptions(
          stickyAuth: true,      // Giữ phiên quét nếu người dùng thoát tạm thời (ví dụ có cuộc gọi)
          biometricOnly: false,  // Đổi thành false để Android cho phép gọi cả các sinh trắc học Class 2 (Khuôn mặt 2D) và mã PIN dự phòng của máy
          useErrorDialogs: true, // Cho phép hiển thị hộp thoại báo lỗi mặc định của hệ thống
        ),
      );
    } catch (e) {
      debugPrint('Lỗi khi thực hiện quét sinh trắc học: $e');
      return false;
    }
  }

  /// Lưu trữ Email & Mật khẩu mã hóa khi người dùng kích hoạt đăng nhập khuôn mặt
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _storage.write(key: 'bio_email', value: email);
      await _storage.write(key: 'bio_password', value: password);
      await _storage.write(key: 'use_biometrics', value: 'true');
    } catch (e) {
      debugPrint('Lỗi lưu trữ thông tin mã hóa sinh trắc học: $e');
    }
  }

  /// Lấy thông tin tài khoản đã lưu nếu người dùng đã bật sinh trắc học
  Future<Map<String, String>?> getCredentials() async {
    try {
      final String? isEnabled = await _storage.read(key: 'use_biometrics');
      if (isEnabled != 'true') return null;

      final String? email = await _storage.read(key: 'bio_email');
      final String? password = await _storage.read(key: 'bio_password');

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('Lỗi đọc thông tin mã hóa sinh trắc học: $e');
    }
    return null;
  }

  /// Vô hiệu hóa và xóa toàn bộ dữ liệu sinh trắc học đã lưu
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: 'bio_email');
      await _storage.delete(key: 'bio_password');
      await _storage.delete(key: 'use_biometrics');
    } catch (e) {
      debugPrint('Lỗi xóa thông tin sinh trắc học: $e');
    }
  }
}
