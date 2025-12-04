import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../screens/profile_screen.dart';
import '../screens/profile_screen.dart';

class UserSearchBox extends ConsumerStatefulWidget {
  const UserSearchBox({super.key});

  @override
  ConsumerState<UserSearchBox> createState() => _UserSearchBoxState();
}

class _UserSearchBoxState extends ConsumerState<UserSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink(); // Để neo vị trí dropdown

  Timer? _debounce;
  OverlayEntry? _overlayEntry;
  List<UserModel> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _removeOverlay(); // Mất focus thì ẩn dropdown
      } else if (_searchResults.isNotEmpty && _controller.text.isNotEmpty) {
        _showOverlay(); // Có focus và có kết quả cũ thì hiện lại
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  // Hàm gọi API search với Debounce
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Ẩn dropdown nếu xóa hết chữ
    if (query.isEmpty) {
      _removeOverlay();
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    // Đợi 500ms sau khi ngừng gõ mới gọi API
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final results = await ref.read(userRepoProvider).searchUsers(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
        // Có kết quả thì hiện dropdown
        if (results.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay(); // Không có kết quả thì ẩn
        }
      }
    });
  }

  // Hàm hiển thị Dropdown (Overlay)
  void _showOverlay() {
    _removeOverlay(); // Xóa cái cũ trước nếu có

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 240, // Độ rộng dropdown (bằng hoặc nhỏ hơn sidebar)
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(
                0, 50), // Xuất hiện ngay dưới ô input (chiều cao input ~45)
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: TapRegion(
                // Bấm ra ngoài vùng này thì đóng
                onTapOutside: (event) {
                  // Chỉ đóng nếu không bấm vào ô input (Input đã có logic focus node xử lý riêng)
                  // Nhưng ở đây Overlay nằm đè lên, nên TapRegion này xử lý bấm ra ngoài dropdown
                },
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(user.avatarUrl),
                          radius: 16,
                        ),
                        title: Text(user.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("@${user.username}",
                            style: const TextStyle(fontSize: 12)),
                        onTap: () {
                          _removeOverlay();
                          _controller.clear();
                          _focusNode.unfocus();

                          // Điều hướng sang Profile
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(userId: user.uid)));
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F4),
          borderRadius: BorderRadius.circular(30),
          border: _focusNode.hasFocus
              ? Border.all(
                  color: const Color(0xFF5A4FCF),
                  width: 1.5) // Viền tím khi focus
              : null,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search users...",
            hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            prefixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged(''); // Clear search
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }
}
