import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/nav_provider.dart';
import '../../data/models/user_model.dart';

class UserSearchBox extends ConsumerStatefulWidget {
  const UserSearchBox({super.key});

  @override
  ConsumerState<UserSearchBox> createState() => _UserSearchBoxState();
}

class _UserSearchBoxState extends ConsumerState<UserSearchBox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<UserModel> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      // Mất focus và không có text -> ẩn list
      if (!_focusNode.hasFocus && _controller.text.isEmpty) {
        setState(() => _results = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ================== SEARCH + DEBOUNCE ==================

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final res = await ref.read(userRepoProvider).searchUsers(query);

      if (!mounted) return;

      setState(() {
        _results = res;
        _isLoading = false;
      });
    });
  }

  // ================== CHỌN USER ==================

  void _onUserTap(UserModel user) {
    // 1. Clear search & list
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _results = []);

    // 2. Set user profile đang xem
    ref.read(viewedProfileIdProvider.notifier).state = user.uid;

    // 3. Chuyển sang tab Profile
    ref.read(navProvider.notifier).state = AppSection.profile;
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ô nhập search
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3F4),
            borderRadius: BorderRadius.circular(30),
            border: _focusNode.hasFocus
                ? Border.all(
                    color: const Color(0xFF5A4FCF),
                    width: 1.5,
                  )
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon:
                          const Icon(Icons.close, size: 18, color: Colors.grey),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),

        // Danh sách kết quả ngay dưới ô search (không dùng Overlay, không dùng ListTile)
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                final hasAvatar = user.avatarUrl.isNotEmpty;
                final initial = user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : 'U';

                return InkWell(
                  onTap: () => _onUserTap(user),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Avatar ~ 32px, không bao giờ chiếm hết width
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage:
                                hasAvatar ? NetworkImage(user.avatarUrl) : null,
                            child: hasAvatar
                                ? null
                                : Text(
                                    initial,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tên + username
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                "@${user.username}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
