import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import để check đăng nhập
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

// --- IMPORT CÁC MÀN HÌNH VÀ LAYOUT ---
import 'presentation/layout/responsive_scaffold.dart'; // Giao diện chính 3 cột
import 'presentation/screens/login_screen.dart'; // Giao diện đăng nhập

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. CẤU HÌNH FIREBASE (GIỮ NGUYÊN CODE CỦA BẠN) ---
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAuwq4awbmGDMnKWwqrRLxE5JOLrDY9uGQ",
        authDomain: "ai-gencourse.firebaseapp.com",
        projectId: "ai-gencourse",
        storageBucket: "ai-gencourse.firebasestorage.app",
        messagingSenderId: "156421724700",
        appId: "1:156421724700:web:53c7c879d882aae8305dd9",
        measurementId: "G-QMXEN8PZV2",
      ),
    );
  } else if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAijuL_LfG7Zmx4xShxCgX9tJ5p1YCAGmk",
        appId: "1:156421724700:android:fe7c13276e01e30d305dd9",
        messagingSenderId: "156421724700",
        projectId: "ai-gencourse",
        storageBucket: "ai-gencourse.firebasestorage.app",
      ),
    );
  } else {
    // iOS hoặc MacOS
    await Firebase.initializeApp();
  }

  // --- 2. KHỞI CHẠY APP ---
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI GenCourse Social',
      theme: ThemeData(
        useMaterial3: true,
        // Màu tím chủ đạo giống Truth Social
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A4FCF)),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      // --- 3. ĐIỀU HƯỚNG THÔNG MINH (Auth Gate) ---
      // Kiểm tra luồng Auth: Nếu có user -> Vào App chính, Không -> Vào Login
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Đang kiểm tra...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          // 2. Đã đăng nhập -> Vào giao diện chính (ResponsiveScaffold)
          if (snapshot.hasData) {
            return const ResponsiveScaffold();
          }

          // 3. Chưa đăng nhập -> Vào màn hình Login
          return const LoginScreen();
        },
      ),
    );
  }
}
