import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/voice_service.dart';
import '../../services/ai_chat_service.dart';
import '../../providers/chat_providers.dart';

class AiGenCourseScreen extends ConsumerStatefulWidget {
  const AiGenCourseScreen({super.key});

  @override
  ConsumerState<AiGenCourseScreen> createState() => _AiGenCourseScreenState();
}

class _AiGenCourseScreenState extends ConsumerState<AiGenCourseScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final VoiceService _voiceService = VoiceService();
  final AiChatService _chatService = AiChatService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // API Key và Model của Gemini
  final String _geminiApiKey = "AIzaSyBvW-hqp8GEsPhT3pIKyjCv4JrSk_P0eso";

  bool _isTyping = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  String? _currentlySpeakingId; // Lưu tin nhắn nào đang được đọc bằng giọng nói
  bool _hasAutoSelected = false; // Tránh tự động chọn lại session khi người dùng bấm chat mới

  @override
  void initState() {
    super.initState();
    _initSpeechToText();
  }

  Future<void> _initSpeechToText() async {
    try {
      final available = await _voiceService.initSpeech();
      setState(() {
        _speechInitialized = available;
      });
    } catch (e) {
      debugPrint("Lỗi khởi tạo Speech to Text: $e");
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _voiceService.stopSpeaking();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Thực hiện giao tiếp bằng giọng nói
  void _toggleListening() async {
    if (!_speechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tính năng nhận diện giọng nói chưa sẵn sàng.")),
      );
      return;
    }

    if (_isListening) {
      _voiceService.stopListening();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _voiceService.startListening((text) {
        setState(() {
          _messageCtrl.text = text;
        });
      });

      // Tự động dừng sau 6 giây nếu không nói nữa để an toàn
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _isListening) {
          _voiceService.stopListening();
          setState(() => _isListening = false);
        }
      });
    }
  }

  // Đọc văn bản bằng AI (Text-to-Speech)
  void _speakMessage(String text, String msgId) async {
    if (_currentlySpeakingId == msgId) {
      // Nếu đang đọc chính tin này thì bấm lại để Dừng
      await _voiceService.stopSpeaking();
      setState(() {
        _currentlySpeakingId = null;
      });
    } else {
      // Đọc tin mới
      setState(() {
        _currentlySpeakingId = msgId;
      });

      // Làm sạch markdown cơ bản để AI phát âm chuẩn
      String cleanText = text
          .replaceAll(RegExp(r'\*+'), '')
          .replaceAll(RegExp(r'#+'), '')
          .replaceAll(RegExp(r'`+'), '')
          .trim();

      await _voiceService.speak(cleanText);

      if (mounted) {
        setState(() {
          _currentlySpeakingId = null;
        });
      }
    }
  }

  // Gửi tin nhắn lên Gemini API
  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đăng nhập để sử dụng tính năng này.")),
      );
      return;
    }

    _messageCtrl.clear();
    setState(() {
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Đảm bảo có session hoạt động. Nếu chưa có, tự động tạo mới lấy câu hỏi đầu làm tiêu đề
      String sessionId = ref.read(activeAiSessionIdProvider) ?? '';
      if (sessionId.isEmpty) {
        final String sessionTitle = text.length > 25 ? "${text.substring(0, 25)}..." : text;
        sessionId = await _chatService.createSession(userId, sessionTitle);

        // Lưu tin nhắn chào mừng mặc định sang Firestore
        await _chatService.saveMessage(
          sessionId,
          'Xin chào! Tôi là Trợ lý Học tập AI thông minh của bạn. Hôm nay bạn muốn tìm hiểu kiến thức gì, giải bài tập hay lập trình ngôn ngữ nào? Tôi ở đây để hỗ trợ bạn!',
          false,
        );

        ref.read(activeAiSessionIdProvider.notifier).state = sessionId;
      }

      // 1. Lưu tin nhắn của user vào Firestore
      await _chatService.saveMessage(sessionId, text, true);

      // 2. Tự động cập nhật tiêu đề nếu vẫn đang là "Cuộc trò chuyện mới" (Dùng .get() thay vì .first trên Stream để tránh bị nghẽn giao diện)
      final doc = await FirebaseFirestore.instance.collection('ai_chats').doc(sessionId).get();
      if (doc.exists) {
        final data = doc.data();
        final currentTitle = data?['title'] ?? '';
        if (currentTitle == 'Cuộc trò chuyện mới') {
          final String newTitle = text.length > 25 ? "${text.substring(0, 25)}..." : text;
          await _chatService.updateSessionTitle(sessionId, newTitle);
        }
      }

      // 3. Gọi API Gemini
      final response = await _callGeminiApi(text);

      // 4. Lưu phản hồi của AI vào Firestore
      await _chatService.saveMessage(sessionId, response, false);

      if (mounted) {
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        String sessionId = ref.read(activeAiSessionIdProvider) ?? '';
        if (sessionId.isNotEmpty) {
          // Lưu tin nhắn báo lỗi của AI vào Firestore
          await _chatService.saveMessage(
            sessionId,
            'Rất tiếc, đã xảy ra lỗi kết nối với máy chủ AI. Xin bạn vui lòng thử lại nhé! (Chi tiết: $e)',
            false,
          );
        }
        setState(() {
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  // Hàm gọi API Gemini Pro thực tế
  Future<String> _callGeminiApi(String userPrompt) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$_geminiApiKey');

    // System Instruction thông minh để định hình chatbot
    const systemInstruction = """
      Bạn là Trợ lý Học tập AI thông minh và tận tâm của ứng dụng học tập AI GenCourse.
      Nhiệm vụ của bạn là giải thích bài tập, giải đáp các thắc mắc về kiến thức (lập trình, toán học, ngoại ngữ, lịch sử...) và hướng dẫn học viên một cách khoa học, ngắn gọn, dễ hiểu dưới 150 từ.
      Hãy trả lời bằng tiếng Việt thân thiện, tự nhiên. Sử dụng định dạng xuống dòng và gạch đầu dòng rõ ràng để dễ đọc.
    """;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": "$systemInstruction\n\nCâu hỏi của học viên: $userPrompt"}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 2048,
          "thinkingConfig": {
            "thinkingBudget": 0
          }
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] ?? '';
    } else {
      throw Exception('Không phản hồi từ Gemini API (Status: ${response.statusCode})');
    }
  }

  /// Tạo cuộc trò chuyện hoàn toàn mới (Chuyển sang màn hình chào mừng tĩnh, không ghi Firestore ngay)
  void _createNewChat() {
    ref.read(activeAiSessionIdProvider.notifier).state = null;
    // Đóng drawer nếu trên mobile
    if (mounted && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.pop(context);
    }
  }

  /// Xác nhận và xóa cuộc trò chuyện
  void _confirmDeleteSession(String sessionId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử trò chuyện'),
        content: Text('Bạn có chắc chắn muốn xóa vĩnh viễn đoạn hội thoại "$title" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy bỏ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteSession(sessionId);
                if (ref.read(activeAiSessionIdProvider) == sessionId) {
                  ref.read(activeAiSessionIdProvider.notifier).state = null;
                }
              } catch (e) {
                debugPrint("Lỗi xóa cuộc trò chuyện: $e");
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Giao diện danh sách các cuộc trò chuyện (Dùng chung cho Desktop Sidebar và Mobile Drawer)
  Widget _buildChatSessionsList(List<AiChatSession> sessions) {
    const primaryColor = Color(0xFF5A4FCF);
    final activeSessionId = ref.watch(activeAiSessionIdProvider);

    return Column(
      children: [
        // Nút thêm cuộc trò chuyện mới
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _createNewChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Cuộc trò chuyện mới', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const Divider(height: 1),
        // Danh sách
        Expanded(
          child: sessions.isEmpty
              ? const Center(child: Text('Chưa có lịch sử chat', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final bool isActive = session.id == activeSessionId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: InkWell(
                        onTap: () {
                          ref.read(activeAiSessionIdProvider.notifier).state = session.id;
                          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                            Navigator.pop(context); // Đóng drawer trên mobile
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? primaryColor.withOpacity(0.2) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  session.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    color: isActive ? primaryColor : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                                onPressed: () => _confirmDeleteSession(session.id, session.title),
                                hoverColor: Colors.red.withOpacity(0.1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5A4FCF);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("Vui lòng đăng nhập để bắt đầu học tập cùng Trợ lý AI.")),
      );
    }

    final activeSessionId = ref.watch(activeAiSessionIdProvider);

    // Kiểm tra kích thước màn hình
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return StreamBuilder<List<AiChatSession>>(
      stream: _chatService.getSessions(userId),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.hasError) {
          debugPrint("Lỗi Firestore trong StreamBuilder: ${sessionSnapshot.error}");
        }
        final sessions = sessionSnapshot.data ?? [];

        // HÀM TỰ ĐỘNG CHỌN SESSION PHẢN ỨNG (REACTIVE AUTO-SELECT - CHỈ TỰ ĐỘNG CHỌN LẦN ĐẦU TIÊN KHI LOAD TRANG)
        if (sessionSnapshot.connectionState != ConnectionState.waiting && sessions.isNotEmpty) {
          if (!_hasAutoSelected) {
            _hasAutoSelected = true;
            final hasActive = sessions.any((s) => s.id == activeSessionId);
            if (!hasActive) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(activeAiSessionIdProvider.notifier).state = sessions.first.id;
              });
            }
          }
        }

        // Widget giao diện khu vực chat chính
        Widget chatArea() {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: !isDesktop
                  ? IconButton(
                      icon: const Icon(Icons.menu, color: Colors.black87),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    )
                  : null,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology, color: primaryColor, size: 28),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeSessionId != null && sessions.isNotEmpty && sessions.any((s) => s.id == activeSessionId)
                              ? sessions.firstWhere((s) => s.id == activeSessionId).title
                              : "Trợ lý Học tập AI",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            const Text("Sẵn sàng trợ giúp", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                // 1. DANH SÁCH BONG BÓNG CHAT HOẶC GIAO DIỆN CHÀO MỪNG TĨNH
                Expanded(
                  child: activeSessionId == null
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.psychology,
                                    size: 80,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  "Trợ lý Học tập AI",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "Xin chào! Tôi là Trợ lý Học tập AI của GenCourse.\nHãy gửi một câu hỏi bất kỳ ở khung bên dưới\nđể chúng ta bắt đầu hành trình học tập nhé!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildSuggestionChip("Giải bài tập toán 12"),
                                    _buildSuggestionChip("Học tiếng Anh giao tiếp"),
                                    _buildSuggestionChip("Lập trình Flutter cơ bản"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : StreamBuilder<List<AiChatMessage>>(
                          stream: _chatService.getMessages(activeSessionId),
                          builder: (context, messageSnapshot) {
                            if (messageSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final messages = messageSnapshot.data ?? [];
                            if (messages.isEmpty) {
                              return const Center(child: Text("Bắt đầu cuộc trò chuyện học tập mới"));
                            }

                            // Tự động cuộn xuống cuối khi có tin nhắn mới
                            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                            return ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe = msg.isMe;
                                final text = msg.text;
                                final id = msg.id;

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe) ...[
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: primaryColor.withOpacity(0.1),
                                            child: const Icon(Icons.android, size: 18, color: primaryColor),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                constraints: const BoxConstraints(maxWidth: 480),
                                                decoration: BoxDecoration(
                                                  color: isMe ? primaryColor : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: const Radius.circular(16),
                                                    topRight: const Radius.circular(16),
                                                    bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                                    bottomRight: !isMe ? const Radius.circular(16) : Radius.zero,
                                                  ),
                                                  border: Border.all(
                                                    color: isMe ? Colors.transparent : Colors.grey.shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  text,
                                                  style: TextStyle(
                                                    color: isMe ? Colors.white : Colors.black87,
                                                    fontSize: 15,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _formatTime(msg.timestamp),
                                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                                  ),
                                                  if (!isMe) ...[
                                                    const SizedBox(width: 8),
                                                    InkWell(
                                                      onTap: () => _speakMessage(text, id),
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Padding(
                                                        padding: const EdgeInsets.all(2.0),
                                                        child: Icon(
                                                          _currentlySpeakingId == id ? Icons.stop_circle : Icons.volume_up,
                                                          size: 14,
                                                          color: _currentlySpeakingId == id ? Colors.red : primaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _currentlySpeakingId == id ? "Đang đọc..." : "Nghe",
                                                      style: TextStyle(fontSize: 10, color: _currentlySpeakingId == id ? Colors.red : primaryColor),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // HIỆU ỨNG AI ĐANG SUY NGHĨ (TYPING INDICATOR)
                if (_isTyping)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: const Icon(Icons.android, size: 18, color: primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _DotIndicator(delay: 0),
                                _DotIndicator(delay: 200),
                                _DotIndicator(delay: 400),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. THANH NHẬP LIỆU (INPUT BAR)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Tooltip(
                          message: _isListening ? "Đang ghi âm... Bấm để dừng" : "Nhập bằng giọng nói",
                          child: IconButton(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none_outlined,
                              color: _isListening ? Colors.red : primaryColor,
                              size: 26,
                            ),
                            onPressed: _toggleListening,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageCtrl,
                            minLines: 1,
                            maxLines: 4,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: _isListening ? "Đang lắng nghe..." : "Hỏi Trợ lý AI bất cứ điều gì...",
                              fillColor: Colors.grey.shade100,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Nếu là màn hình rộng (Desktop), tích hợp sidebar chia đôi màn hình
        if (isDesktop) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.white,
            body: Row(
              children: [
                // Sidebar Danh sách lịch sử
                Container(
                  width: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(right: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildChatSessionsList(sessions),
                ),
                // Vùng chat chính
                Expanded(child: chatArea()),
              ],
            ),
          );
        }

        // Nếu là Mobile, sử dụng Drawer truyền thống cực kỳ mượt mà
        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            child: SafeArea(
              child: _buildChatSessionsList(sessions),
            ),
          ),
          body: chatArea(),
        );
      },
    );
  }

  /// Widget hiển thị chip gợi ý chủ đề tĩnh
  Widget _buildSuggestionChip(String text) {
    const primaryColor = Color(0xFF5A4FCF);
    return ActionChip(
      label: Text(text),
      labelStyle: const TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
      backgroundColor: primaryColor.withOpacity(0.05),
      side: BorderSide(color: primaryColor.withOpacity(0.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: () {
        setState(() {
          _messageCtrl.text = text;
        });
      },
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

// HIỆU ỨNG DẤU CHẤM NHẤP NHÁY
class _DotIndicator extends StatefulWidget {
  final int delay;
  const _DotIndicator({required this.delay});

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _animCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
