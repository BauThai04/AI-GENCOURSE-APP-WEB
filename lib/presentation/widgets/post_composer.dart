import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import '../../data/models/post_model.dart';
import '../../providers/app_providers.dart';

class PostComposer extends ConsumerStatefulWidget {
  const PostComposer({super.key});

  @override
  ConsumerState<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<PostComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Dùng để bắt sự kiện bấm vào text
  final List<dynamic> _selectedImages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isUploading = false;
  bool _isExpanded = false; // Biến trạng thái Co/Giãn
  String _visibility = 'Public';
  final int _maxChars = 3000;

  @override
  void initState() {
    super.initState();
    // Lắng nghe tiêu điểm (Focus)
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isExpanded = true; // Bấm vào thì mở rộng
        });
      }
    });

    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- HÀM THU GỌN GIAO DIỆN ---
  void _collapse() {
    // Chỉ thu gọn nếu không có nội dung và không có ảnh
    if (_textController.text.isEmpty && _selectedImages.isEmpty) {
      _focusNode.unfocus(); // Bỏ chọn
      setState(() {
        _isExpanded = false;
      });
    }
  }

  // --- XỬ LÝ CHỌN ẢNH ---
  Future<void> _pickImage() async {
    setState(() => _isExpanded = true); // Chọn ảnh thì phải mở rộng form
    if (_selectedImages.length >= 4) return;

    try {
      if (kIsWeb) {
        var result = await FilePicker.platform
            .pickFiles(type: FileType.image, allowMultiple: true);
        if (result != null) {
          setState(() {
            var newFiles =
                result.files.map((e) => e.bytes).whereType<Uint8List>();
            _selectedImages.addAll(newFiles);
          });
        }
      } else {
        final ImagePicker picker = ImagePicker();
        final List<XFile> images =
            await picker.pickMultiImage(limit: 4 - _selectedImages.length);
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((e) => File(e.path)));
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi ảnh: $e");
    }
  }

  // --- XỬ LÝ VOICE (Đã Fix lỗi logic) ---
  Future<void> _toggleListening() async {
    setState(() => _isExpanded = true); // Bấm mic thì mở rộng form

    if (!_isListening) {
      // Khởi tạo
      bool available = await _speech.initialize(
        onStatus: (status) => print('Mic status: $status'),
        onError: (errorNotification) => print('Mic error: $errorNotification'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            // Cập nhật text liên tục khi nói
            setState(() {
              // Lưu lại text cũ trước khi nối chuỗi mới để tránh bị duplicate nếu logic sai
              // Tuy nhiên speech_to_text trả về recognizedWords là toàn bộ câu từ lúc bắt đầu listen
              // Nên ta cần xử lý khéo một chút hoặc chỉ hiển thị kết quả cuối cùng.
              // Cách đơn giản nhất cho Chat/Post:

              if (val.finalResult) {
                // Nếu đã chốt câu, cộng dồn vào controller
                String spacer = _textController.text.isNotEmpty ? " " : "";
                _textController.text =
                    "${_textController.text}$spacer${val.recognizedWords}";
                // Di chuyển con trỏ xuống cuối
                _textController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _textController.text.length));
                _isListening = false;
              }
            });
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Không quyền truy cập Micro hoặc thiết bị không hỗ trợ')),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // --- XỬ LÝ ĐĂNG BÀI ---
  Future<void> _handlePost() async {
    final authUser = ref.read(authProvider).currentUser;
    if (authUser == null) {
      try {
        await ref.read(authProvider).signInAnonymously();
      } catch (_) {}
    }

    // Lấy lại user
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser == null) return;

    final String uid = currentUser.uid;
    final String name = currentUser.displayName ?? "User";
    final String username = "user_${uid.substring(0, 5)}";
    final String avatar = currentUser.photoURL ??
        "https://ui-avatars.com/api/?name=$name&background=random";

    setState(() => _isUploading = true);

    try {
      final newPost = PostModel(
        postId: const Uuid().v4(),
        authorUid: uid,
        authorName: name,
        authorUsername: username,
        authorAvatarUrl: avatar,
        visibility: _visibility.toLowerCase(),
        text: _textController.text.trim(),
        imageUrls: [],
      );

      await ref
          .read(postRepositoryProvider)
          .createPost(newPost, _selectedImages);

      _textController.clear();
      setState(() {
        _selectedImages.clear();
        _isUploading = false;
        _isExpanded = false; // Đăng xong thì thu gọn lại
      });
      _focusNode.unfocus(); // Ẩn bàn phím
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final int charCount = _textController.text.length;
    final bool canPost =
        (charCount > 0 || _selectedImages.isNotEmpty) && !_isUploading;

    // Lấy avatar
    final user = ref.watch(authProvider).currentUser;
    final String currentAvatar = user?.photoURL ??
        "https://ui-avatars.com/api/?name=Me&background=random&color=fff";

    // Màu tím chủ đạo
    const purpleColor = Color(0xFF5A4FCF);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEFF3F4), width: 1),
      ),
      // Animation mượt mà khi co giãn
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isUploading)
              const LinearProgressIndicator(
                  color: purpleColor, backgroundColor: Color(0xFFF3E5F5)),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(currentAvatar),
                ),
                const SizedBox(width: 12),

                // --- KHUNG NHẬP LIỆU ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        // Nếu đang mở rộng thì tối thiểu 3 dòng, ngược lại 1 dòng
                        minLines: _isExpanded ? 3 : 1,
                        maxLines: null,
                        maxLength: _maxChars,
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          border: InputBorder.none,
                          counterText: "",
                          hintStyle: TextStyle(
                              fontSize: 18, color: Colors.grey.shade500),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 16),
                        onTap: () {
                          // Đảm bảo bấm vào là mở rộng
                          setState(() => _isExpanded = true);
                        },
                      ),

                      // --- PREVIEW ẢNH ---
                      if (_selectedImages.isNotEmpty)
                        Container(
                          height: 100,
                          margin: const EdgeInsets.only(top: 12),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final img = _selectedImages[index];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: kIsWeb
                                        ? Image.memory(img as Uint8List,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover)
                                        : Image.file(img as File,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() =>
                                          _selectedImages.removeAt(index)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // --- THANH CÔNG CỤ (CHỈ HIỆN KHI EXPANDED) ---
            if (_isExpanded ||
                _selectedImages.isNotEmpty ||
                _textController.text.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Color(0xFFEFF3F4)),
              ),
              Row(
                children: [
                  // Image Icon
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    color: purpleColor,
                    onPressed: _pickImage,
                    tooltip: "Ảnh/Video",
                  ),
                  // Mic Icon (Thay đổi màu khi đang nghe)
                  IconButton(
                    icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_outlined),
                    color: _isListening ? Colors.red : purpleColor,
                    onPressed: _toggleListening,
                    tooltip: "Nhập giọng nói",
                  ),

                  const Spacer(),

                  // Nút Hủy (Thu gọn)
                  if (!_isUploading)
                    TextButton(
                      onPressed: () {
                        // Xóa text và thu gọn
                        _textController.clear();
                        setState(() {
                          _selectedImages.clear();
                          _isExpanded = false;
                        });
                        _focusNode.unfocus();
                      },
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.grey)),
                    ),

                  const SizedBox(width: 8),

                  // Nút Đăng (Truth)
                  ElevatedButton(
                    onPressed: canPost ? _handlePost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: purpleColor.withOpacity(0.5),
                      disabledForegroundColor: Colors.white.withOpacity(0.8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                    ),
                    child: Text(_isUploading ? "..." : "AI GenCourse",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
