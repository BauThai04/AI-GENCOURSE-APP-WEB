import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../data/models/post_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/app_providers.dart';

class PostComposer extends ConsumerStatefulWidget {
  const PostComposer({super.key});

  @override
  ConsumerState<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<PostComposer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<dynamic> _selectedImages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _isUploading = false;
  bool _isExpanded = false;
  String _visibility = 'Public';
  final int _maxChars = 3000;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isExpanded = true;
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

  // ================== IMAGE PICKER ==================
  Future<void> _pickImage() async {
    setState(() => _isExpanded = true);
    if (_selectedImages.length >= 4) return;

    try {
      if (kIsWeb) {
        final result = await FilePicker.platform
            .pickFiles(type: FileType.image, allowMultiple: true);
        if (result != null) {
          setState(() {
            final newFiles =
                result.files.map((e) => e.bytes).whereType<Uint8List>();
            _selectedImages.addAll(newFiles);
          });
        }
      } else {
        final picker = ImagePicker();
        final images =
            await picker.pickMultiImage(limit: 4 - _selectedImages.length);
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images.map((e) => File(e.path)));
          });
        }
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
  }

  // ================== MIC ==================
  Future<void> _toggleListening() async {
    setState(() => _isExpanded = true);

    if (!_isListening) {
      final available = await _speech.initialize(
        onStatus: (status) => debugPrint('Mic status: $status'),
        onError: (errorNotification) =>
            debugPrint('Mic error: $errorNotification'),
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              final spacer = _textController.text.isNotEmpty ? " " : "";
              _textController.text =
                  "${_textController.text}$spacer${val.recognizedWords}";
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
              setState(() => _isListening = false);
            }
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Không quyền truy cập Micro hoặc thiết bị không hỗ trợ'),
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // ================== HANDLE POST ==================
  Future<void> _handlePost() async {
    final String rawText = _textController.text.trim();
    if (rawText.isEmpty && _selectedImages.isEmpty) return;

    // Lấy UserModel hiện tại từ provider
    final userAsync = ref.read(currentUserProfileProvider);
    final UserModel? user = userAsync.value;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin người dùng.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Tạo "template" của Post, repo sẽ gắn postId và createdAt chuẩn
      final newPostTemplate = PostModel(
        postId: '', // để trống, repository sẽ tự generate
        authorUid: user.uid,
        authorName: user.displayName,
        authorUsername: user.username,
        authorAvatarUrl: user.avatarUrl,
        visibility: _visibility.toLowerCase(),
        text: rawText,
        imageUrls: const [],
        likeCount: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
      );

      await ref
          .read(postRepositoryProvider)
          .createPost(newPostTemplate, _selectedImages);

      _textController.clear();
      setState(() {
        _selectedImages.clear();
        _isUploading = false;
        _isExpanded = false;
      });
      _focusNode.unfocus();
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const purpleColor = Color(0xFF5A4FCF);
    final charCount = _textController.text.length;
    final canPost =
        (charCount > 0 || _selectedImages.isNotEmpty) && !_isUploading;

    // Lấy avatar từ UserModel (nếu chưa load được thì fallback)
    final userAsync = ref.watch(currentUserProfileProvider);

    String _defaultAvatar(String name) =>
        "https://ui-avatars.com/api/?name=$name&background=random&color=fff";

    String currentAvatar = userAsync.maybeWhen(
      data: (user) {
        if (user == null) return _defaultAvatar("Me");
        if (user.avatarUrl.isNotEmpty) return user.avatarUrl;
        return _defaultAvatar(
            user.displayName.isNotEmpty ? user.displayName : user.username);
      },
      orElse: () => _defaultAvatar("Me"),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEFF3F4), width: 1),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isUploading)
              const LinearProgressIndicator(
                color: purpleColor,
                backgroundColor: Color(0xFFF3E5F5),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(currentAvatar),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        minLines: _isExpanded ? 3 : 1,
                        maxLines: null,
                        maxLength: _maxChars,
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          border: InputBorder.none,
                          counterText: "",
                          hintStyle: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade500,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 16),
                        onTap: () => setState(() => _isExpanded = true),
                      ),

                      // preview ảnh
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
                                        ? Image.memory(
                                            img as Uint8List,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            img as File,
                                            height: 100,
                                            width: 100,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedImages.removeAt(
                                                index,
                                              )),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
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

            // toolbar
            if (_isExpanded ||
                _selectedImages.isNotEmpty ||
                _textController.text.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(color: Color(0xFFEFF3F4)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    color: purpleColor,
                    onPressed: _pickImage,
                    tooltip: "Ảnh/Video",
                  ),
                  IconButton(
                    icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_outlined),
                    color: _isListening ? Colors.red : purpleColor,
                    onPressed: _toggleListening,
                    tooltip: "Nhập giọng nói",
                  ),
                  const Spacer(),
                  if (!_isUploading)
                    TextButton(
                      onPressed: () {
                        _textController.clear();
                        setState(() {
                          _selectedImages.clear();
                          _isExpanded = false;
                        });
                        _focusNode.unfocus();
                      },
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: canPost ? _handlePost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: purpleColor.withOpacity(0.5),
                      disabledForegroundColor: Colors.white.withOpacity(0.8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      _isUploading ? "..." : "AI GenCourse",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
