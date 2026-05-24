import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Sử dụng kDebugMode
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart'; // Dịch vụ Sinh trắc học độc lập
import '../layout/responsive_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    // Responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFF9F0F5), Color(0xFFE0E5FF)],
          ),
        ),
        child: isDesktop
            ? Row(children: const [
                Expanded(child: LeftPanel()),
                Expanded(child: RightPanel())
              ])
            : const LeftPanel(),
      ),
    );
  }
}

// ==========================================
// 1. LEFT PANEL (ĐÃ SỬA LỖI OVERFLOW MOBILE)
// ==========================================
class LeftPanel extends StatelessWidget {
  const LeftPanel({super.key});

  Future<void> _launchSocial(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
        debugPrint('Could not launch $url');
      }
    }
  }

  void _showAuthDialog(BuildContext context, {required bool isRegister}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 10,
        // Giới hạn chiều rộng dialog
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AuthDialogContent(isRegister: isRegister),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // GIẢM PADDING: 40 -> 24 để đỡ tốn diện tích trên mobile
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.white.withOpacity(0.95),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // RÀNG BUỘC: Max width 450 để đẹp trên desktop, nhưng co giãn trên mobile
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Row(
                  children: [
                    Text(
                      "AI GENCOURSE.",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 4),
                        color: Colors.blueAccent)
                  ],
                ),
                const SizedBox(height: 40),

                // Slogan (Dùng FittedBox để tự thu nhỏ font nếu màn hình quá bé)
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("AI",
                      style: TextStyle(
                          fontSize: 65,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: Colors.black)),
                ),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text("Knowledge.",
                      style: TextStyle(
                          fontSize: 65,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: Colors.black)),
                ),

                const SizedBox(height: 50),

                // --- NÚT CREATE ACCOUNT (SỬA LỖI OVERFLOW) ---
                SizedBox(
                  width: double.infinity, // Chiếm hết chiều ngang cho phép
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => _showAuthDialog(context, isRegister: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A4FCF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 5,
                    ),
                    child: const Text("Create Account",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                // --- NÚT SIGN IN (SỬA LỖI OVERFLOW) ---
                SizedBox(
                  width: double.infinity, // Chiếm hết chiều ngang cho phép
                  height: 55,
                  child: OutlinedButton(
                    onPressed: () =>
                        _showAuthDialog(context, isRegister: false),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Sign In",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "By continuing, you agree to our Terms of Service and Privacy Policy.",
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),

                const SizedBox(height: 40),

                // --- APP STORE BUTTONS (DÙNG WRAP THAY ROW ĐỂ TỰ XUỐNG DÒNG) ---
                Center(
                  child: Wrap(
                    spacing: 15, // Khoảng cách ngang
                    runSpacing: 15, // Khoảng cách dọc (khi xuống dòng)
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStoreButton(
                          Icons.apple, "Download on the", "App Store"),
                      _buildStoreButton(
                          Icons.android, "GET IT ON", "Google Play"),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                // Footer Links
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    InkWell(
                        onTap: () =>
                            _launchSocial("https://www.facebook.com/tbb295"),
                        child: const Text("Facebook",
                            style: TextStyle(
                                color: Color(0xFF1877F2),
                                fontWeight: FontWeight.bold))),
                    InkWell(
                        onTap: () => _launchSocial(
                            "https://www.instagram.com/babauthai"),
                        child: const Text("Instagram",
                            style: TextStyle(
                                color: Color(0xFFE4405F),
                                fontWeight: FontWeight.bold))),
                    InkWell(
                        onTap: () =>
                            _launchSocial("https://www.tiktok.com/@tbau2905"),
                        child: const Text("TikTok",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("©2025 AI GENCOURSE",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreButton(IconData icon, String sub, String main) {
    // Không fix width cứng 160 nữa, để nó tự co giãn theo nội dung hoặc max 160
    return Container(
      width: 160,
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sub,
                  style: const TextStyle(fontSize: 9, color: Colors.black54)),
              Text(main,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 2. RIGHT PANEL (GIỮ NGUYÊN)
// ==========================================
class RightPanel extends StatelessWidget {
  const RightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> leftPosts = [
      {
        "name": "Donald J. Trump",
        "handle": "@realDonaldTrump",
        "avatar":
            "https://upload.wikimedia.org/wikipedia/commons/5/56/Donald_Trump_official_portrait.jpg",
        "content":
            "MAKE EDUCATION GREAT AGAIN! AI GenCourse is a tremendous app.",
        "image":
            "https://images.pexels.com/photos/159613/ghettoblaster-radio-recorder-boombox-old-school-159613.jpeg?auto=compress&cs=tinysrgb&w=600"
      },
      {
        "name": "Central Cee",
        "handle": "@CeeRaper",
        "avatar":
            "https://tse3.mm.bing.net/th/id/OIP.hI8TdTVazj99kcCGc02K0AHaHZ?rs=1&pid=ImgDetMain&o=7&rm=3",
        "content": "I love this so much. Must use every day.",
        "image":
            "https://tse4.mm.bing.net/th/id/OIP.fEGPbvx067sdBjnVShvG4gHaFK?rs=1&pid=ImgDetMain&o=7&rm=3R"
      },
      {
        "name": "Elon Musk",
        "handle": "@elonmusk",
        "avatar":
            "https://upload.wikimedia.org/wikipedia/commons/9/99/Elon_Musk_Colorado_2022_%28cropped2%29.jpg",
        "content": "AI GenCourse to the Mars! 🚀",
        "image":
            "https://images.pexels.com/photos/256381/pexels-photo-256381.jpeg?auto=compress&cs=tinysrgb&w=1260"
      },
    ];

    final List<Map<String, String>> rightPosts = [
      {
        "name": "Coder Daily",
        "handle": "@coder_daily",
        "avatar":
            "https://tse2.mm.bing.net/th/id/OIP.wDHl1rtvUhASaeC-6PhTvgHaD4?rs=1&pid=ImgDetMain&o=7&rm=3",
        "content": "Top 1 ứng dụng học tập năm 2025 gọi tên AI GenCourse.",
        "image":
            "https://th.bing.com/th/id/R.af0bef721aaf3993358406a1dbda73fc?rik=OVrpjZzHoIKZpQ&pid=ImgRaw&r=0"
      },
      {
        "name": "Tim Cook",
        "handle": "@tim_cook",
        "avatar":
            "https://th.bing.com/th/id/OIP.MkdJ74qAmLLzocMFnCiRPQHaFj?o=7rm=3&rs=1&pid=ImgDetMain&o=7&rm=3",
        "content": "This is the best iPhone app ever created.",
        "image":
            "https://tse2.mm.bing.net/th/id/OIP.3js14AHTr9RK5kBGZlziTwHaFs?w=800&h=616&rs=1&pid=ImgDetMain&o=7&rm=3"
      },
      {
        "name": "Billie Eilish",
        "handle": "@BillieE",
        "avatar":
            "https://th.bing.com/th/id/R.d4c757465dde9358db508e3071c58818?rik=VfkgOZD%2bjvSZpw&pid=ImgRaw&r=0",
        "content": "I use this app every day! .",
        "image":
            "https://tse3.mm.bing.net/th/id/OIP.cAcmVOO-eKRZqYAhCM3fIAHaE9?rs=1&pid=ImgDetMain&o=7&rm=3"
      },
    ];

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: _NewsScrollColumn(
              items: leftPosts,
              scrollDirection: _NewsScrollDirection.up,
              speed: 1.0,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _NewsScrollColumn(
              items: rightPosts,
              scrollDirection: _NewsScrollDirection.down,
              speed: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Logic Cuộn (Giữ nguyên)
enum _NewsScrollDirection { up, down }

class _NewsScrollColumn extends StatefulWidget {
  final List<Map<String, String>> items;
  final _NewsScrollDirection scrollDirection;
  final double speed;

  const _NewsScrollColumn({
    required this.items,
    this.scrollDirection = _NewsScrollDirection.up,
    this.speed = 1.0,
  });

  @override
  State<_NewsScrollColumn> createState() => _NewsScrollColumnState();
}

class _NewsScrollColumnState extends State<_NewsScrollColumn> {
  late ScrollController _scrollController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double current = _scrollController.offset;
        double next = current + widget.speed;
        _scrollController.animateTo(
          next,
          duration: const Duration(milliseconds: 50),
          curve: Curves.linear,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent
        ],
        stops: [0.0, 0.05, 0.95, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        reverse: widget.scrollDirection == _NewsScrollDirection.down,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (widget.items.isEmpty) return const SizedBox.shrink();
          final post = widget.items[index % widget.items.length];
          return _buildCard(post);
        },
      ),
    );
  }

  Widget _buildCard(Map<String, String> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(post['avatar']!),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post['name']!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(post['handle']!,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),
          const Icon(Icons.verified, color: Colors.blue, size: 14),
        ]),
        const SizedBox(height: 8),
        Text(post['content']!,
            style: const TextStyle(fontSize: 13), maxLines: 4),
        if (post['image'] != "") ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(post['image']!,
                height: 120, width: double.infinity, fit: BoxFit.cover),
          ),
        ],
      ]),
    );
  }
}

// ==========================================
// 4. AUTH DIALOG CONTENT (ĐÃ GIỮ NGUYÊN)
// ==========================================
class AuthDialogContent extends StatefulWidget {
  final bool isRegister;
  const AuthDialogContent({required this.isRegister, super.key});

  @override
  State<AuthDialogContent> createState() => _AuthDialogContentState();
}

class _AuthDialogContentState extends State<AuthDialogContent> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  final BiometricService _bioService = BiometricService(); // Khởi tạo dịch vụ sinh trắc học độc lập

  bool _isLoading = false;
  bool _obscureText = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasDigits = false;

  // Trạng thái sinh trắc học
  bool _isBioAvailable = false;
  bool _hasSavedCredentials = false;
  bool _isBioChecking = false;
  IconData _biometricIcon = Icons.fingerprint;
  String _biometricLabel = "Sinh trắc học";

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_updatePasswordValidation);
    _checkBiometrics();
  }

  /// Kiểm tra phần cứng và cấu hình sinh trắc học trên thiết bị
  Future<void> _checkBiometrics() async {
    final available = await _bioService.isBiometricAvailable();
    if (!mounted) return;
    setState(() => _isBioAvailable = available);

    if (available) {
      final icon = await _bioService.getBiometricIcon();
      final label = await _bioService.getBiometricLabel();
      final credentials = await _bioService.getCredentials();
      if (!mounted) return;
      setState(() {
        _biometricIcon = icon;
        _biometricLabel = label;
        _hasSavedCredentials = credentials != null;
        // Nếu đã bật sinh trắc học và đây là màn hình Đăng nhập (không phải Đăng ký),
        // và không có Email nào đang được nhập thủ công thì tự động điền Email đã lưu
        if (_hasSavedCredentials && !widget.isRegister && credentials != null) {
          _emailCtrl.text = credentials['email'] ?? '';
        }
      });
    }
  }

  void _updatePasswordValidation() {
    final text = _passCtrl.text;
    setState(() {
      _hasMinLength = text.length >= 6;
      _hasUppercase = text.contains(RegExp(r'[A-Z]'));
      _hasDigits = text.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    _passCtrl.removeListener(_updatePasswordValidation);
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Gợi ý kích hoạt sinh trắc học cho lần đăng nhập sau
  Future<void> _promptToEnableBiometrics(String email, String password) async {
    final credentials = await _bioService.getCredentials();
    if (credentials != null) return; // Đã kích hoạt rồi thì bỏ qua

    if (!mounted) return;
    final bool? enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_biometricIcon, color: const Color(0xFF5A4FCF)),
            const SizedBox(width: 10),
            Text('Đăng nhập $_biometricLabel'),
          ],
        ),
        content: Text(
          'Bạn có muốn kích hoạt tính năng Đăng nhập nhanh bằng $_biometricLabel cho lần đăng nhập sau không?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A4FCF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kích hoạt'),
          ),
        ],
      ),
    );

    if (enable == true) {
      await _bioService.saveCredentials(email, password);
      if (kDebugMode) {
        debugPrint('Đã kích hoạt Đăng nhập Sinh trắc học thành công!');
      }
    }
  }

  /// Thực hiện đăng nhập nhanh bằng sinh trắc học
  Future<void> _loginWithBiometrics() async {
    if (_isBioChecking) return;

    setState(() => _isBioChecking = true);
    try {
      final success = await _bioService.authenticate();
      if (success) {
        final credentials = await _bioService.getCredentials();
        if (credentials != null) {
          final email = credentials['email']!;
          final password = credentials['password']!;

          if (mounted) {
            setState(() => _isLoading = true);
          }

          await _auth.signIn(email, password);

          if (mounted) {
            Navigator.pop(context); // Đóng Dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ResponsiveScaffold()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Không tìm thấy thông tin xác thực sinh trắc học đã lưu.")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Xác thực sinh trắc học thất bại hoặc bị hủy.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi đăng nhập sinh trắc học: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBioChecking = false;
          _isLoading = false;
        });
      }
    }
  }

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) return;

    if (widget.isRegister) {
      if (!_hasMinLength || !_hasUppercase || !_hasDigits) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mật khẩu chưa đủ mạnh!")));
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (widget.isRegister) {
        await _auth.signUp(email, password);
      } else {
        await _auth.signIn(email, password);
      }

      // Đăng nhập/Đăng ký thành công
      if (mounted) {
        // Nếu đăng nhập thành công và phần cứng hỗ trợ, gợi ý kích hoạt
        if (!widget.isRegister && _isBioAvailable) {
          await _promptToEnableBiometrics(email, password);
        }

        if (mounted) {
          Navigator.pop(context); // Đóng Dialog hộp thoại
          // Chuyển hướng đến khung sườn Responsive (có Sidebar)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResponsiveScaffold()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nút Đóng Dialog
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 24, color: Colors.black),
            ),
          ),
          const SizedBox(height: 10),
          Text(widget.isRegister ? "Create your account" : "Sign in",
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(
              widget.isRegister
                  ? "Join the community today."
                  : "Sign in to Truth Social.",
              style: const TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 30),

          // Ô Nhập Email
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: "Email",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 15),

          // Ô Nhập Mật khẩu
          TextField(
            controller: _passCtrl,
            obscureText: _obscureText,
            decoration: InputDecoration(
              labelText: "Password",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),

          if (widget.isRegister) ...[
            const SizedBox(height: 15),
            const Text("Password requirements:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 5),
            _buildCheckItem("At least 6 characters", _hasMinLength),
            _buildCheckItem("At least one uppercase letter", _hasUppercase),
            _buildCheckItem("At least one number", _hasDigits),
          ],

          const SizedBox(height: 25),

          // Luồng Đăng nhập Sinh trắc học & Nút Submit
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A4FCF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(widget.isRegister ? "Sign Up" : "Sign In",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              // Chỉ hiển thị nút Face ID/Sinh trắc học khi không phải chế độ đăng ký,
              // phần cứng khả dụng và người dùng đã lưu thông tin đăng nhập trước đó.
              if (!widget.isRegister && _isBioAvailable && _hasSavedCredentials) ...[
                const SizedBox(width: 15),
                InkWell(
                  onTap: _isBioChecking ? null : _loginWithBiometrics,
                  borderRadius: BorderRadius.circular(25),
                  child: Tooltip(
                    message: "Đăng nhập bằng $_biometricLabel",
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A4FCF).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF5A4FCF), width: 1.5),
                      ),
                      child: _isBioChecking
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5A4FCF)),
                            )
                          : Icon(
                              _biometricIcon, // Biểu tượng động phù hợp
                              color: const Color(0xFF5A4FCF),
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isValid ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isValid ? Colors.green : Colors.grey, size: 18),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: isValid ? Colors.black : Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
