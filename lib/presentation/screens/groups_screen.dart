import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';
import '../../providers/community_providers.dart';
import '../../services/zoom_service.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  final ZoomService _zoomService = ZoomService();

  String _searchQuery = "";
  bool _isCreatingRoom = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _msgCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Launch Zoom meeting URL using url_launcher
  Future<void> _joinZoomRoom(String urlString, {bool isWebClient = false}) async {
    final Uri url = Uri.parse(urlString.trim());
    try {
      if (isWebClient) {
        // Đối với link trình duyệt hoặc link của Host, mở bằng trình duyệt mặc định
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } else {
        // Đối với link Native app, thử mở trực tiếp bằng ứng dụng ngoài trước
        final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        if (!launched) {
          await launchUrl(url, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      try {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Không thể kết nối đến phòng Zoom: $err")),
          );
        }
      }
    }
  }

  /// Hiển thị Dialog tạo phòng học mới tích hợp Zoom API
  void _showAddCommunityDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: !_isCreatingRoom,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.video_call, color: Color(0xFF5A4FCF)),
                  SizedBox(width: 8),
                  Text("Tạo phòng học Zoom 24/7", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Hệ thống sẽ tự động tạo một phòng họp Zoom định kỳ 24/24 thông qua Zoom API.",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Tên phòng học cộng đồng",
                          hintText: "Ví dụ: Lớp Flutter cơ bản",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? "Vui lòng nhập tên phòng" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: "Mô tả phòng học",
                          hintText: "Ví dụ: Cùng trao đổi kiến thức lập trình di động...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? "Vui lòng nhập mô tả" : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: _isCreatingRoom
                  ? [
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(color: Color(0xFF5A4FCF)),
                        ),
                      )
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Hủy bỏ"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            setDialogState(() => _isCreatingRoom = true);

                            try {
                              final user = ref.read(currentUserProfileProvider).value;
                              final creatorId = FirebaseAuth.instance.currentUser?.uid ?? "";
                              final creatorName = user?.displayName ?? "Học viên";

                              // 1. Gọi Zoom API thông qua ZoomService
                              final zoomInfo = await _zoomService.create247Meeting(nameCtrl.text.trim());

                              // 2. Lưu thông tin phòng học cộng đồng vào Firestore
                              final docRef = FirebaseFirestore.instance.collection('communities').doc();
                              final bool isMockMeeting = zoomInfo['isMock'] == 'true';

                              final room = CommunityRoom(
                                id: docRef.id,
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                zoomUrl: zoomInfo['joinUrl'] ?? '',
                                startUrl: zoomInfo['startUrl'] ?? '',
                                meetingId: zoomInfo['meetingId'] ?? '',
                                passcode: zoomInfo['passcode'] ?? '',
                                creatorId: creatorId,
                                creatorName: creatorName,
                                activeUsersCount: 1, // Bắt đầu với chính người tạo
                                createdAt: DateTime.now(),
                                isMock: isMockMeeting,
                              );

                              await docRef.set(room.toFirestore());

                              // 3. Gửi tin nhắn chào mừng hệ thống đầu tiên
                              final msgRef = docRef.collection('messages').doc();
                              final welcomeMsg = CommunityMessage(
                                id: msgRef.id,
                                senderId: "system",
                                senderName: "Hệ thống",
                                senderAvatar: "",
                                text: "Chào mừng các bạn đến với phòng học cộng đồng: ${room.name}! Phòng họp Zoom 24/24 đã sẵn sàng, hãy bấm vào nút gia nhập ở trên để học trực tuyến cùng mọi người nhé! 🟢",
                                timestamp: DateTime.now(),
                              );
                              await msgRef.set(welcomeMsg.toFirestore());

                              if (mounted) {
                                // Chọn phòng mới tạo làm phòng active
                                ref.read(selectedCommunityIdProvider.notifier).state = docRef.id;
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text("Tạo phòng học Zoom 24/7 thành công!")),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text("Lỗi tạo phòng học: $e")),
                                );
                              }
                            } finally {
                              setDialogState(() => _isCreatingRoom = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A4FCF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Tạo ngay"),
                      ),
                    ],
            );
          },
        );
      },
    ).then((_) {
      _isCreatingRoom = false;
    });
  }

  /// Gửi tin nhắn thảo luận trong phòng học cộng đồng
  Future<void> _sendChatMessage(String communityId) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProfileProvider).value;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    _msgCtrl.clear();
    _scrollToBottom();

    try {
      final docRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('messages')
          .doc();

      final msg = CommunityMessage(
        id: docRef.id,
        senderId: currentUid,
        senderName: user?.displayName ?? 'Học viên',
        senderAvatar: user?.avatarUrl ?? '',
        text: text,
        timestamp: DateTime.now(),
      );

      await docRef.set(msg.toFirestore());

      // Cập nhật lastUpdatedAt trên community để thúc đẩy tương tác
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .update({'lastUpdatedAt': FieldValue.serverTimestamp()});

      _scrollToBottom();
    } catch (e) {
      debugPrint("Lỗi gửi tin nhắn cộng đồng: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5A4FCF);
    final communitiesAsync = ref.watch(communitiesStreamProvider);
    final selectedId = ref.watch(selectedCommunityIdProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Cộng Đồng Học Tập (Communities)",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Nút tạo phòng học Zoom 24/7
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _showAddCommunityDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              icon: const Icon(Icons.video_call, size: 18),
              label: const Text("Tạo phòng học Zoom", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
      body: communitiesAsync.when(
        data: (communities) {
          // Lọc danh sách theo truy vấn tìm kiếm
          final filtered = communities.where((c) {
            final query = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(query) || c.description.toLowerCase().contains(query);
          }).toList();

          // Thiết lập mặc định tự động chọn phòng đầu tiên trên Desktop nếu chưa chọn phòng nào
          if (isDesktop && selectedId == null && filtered.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedCommunityIdProvider.notifier).state = filtered.first.id;
            });
          }

          if (isDesktop) {
            // GIAO DIỆN DESKTOP (Layout 2 cột song song)
            return Row(
              children: [
                // Cột bên trái: Danh sách phòng học
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(right: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: _buildCommunitiesSidebar(filtered, selectedId),
                ),
                // Cột bên phải: Chi tiết và cuộc họp Zoom & Chat
                Expanded(
                  child: selectedId != null && communities.any((c) => c.id == selectedId)
                      ? _buildCommunityDetailPane(communities.firstWhere((c) => c.id == selectedId))
                      : _buildEmptyDetailPane(),
                ),
              ],
            );
          } else {
            // GIAO DIỆN MOBILE
            // Nếu trên Mobile đang chọn phòng, hiển thị chi tiết (nhấp Back để quay về danh sách)
            if (selectedId != null && communities.any((c) => c.id == selectedId)) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  ref.read(selectedCommunityIdProvider.notifier).state = null;
                },
                child: Scaffold(
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0.5,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () {
                        ref.read(selectedCommunityIdProvider.notifier).state = null;
                      },
                    ),
                    title: Text(
                      communities.firstWhere((c) => c.id == selectedId).name,
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  body: _buildCommunityDetailPane(communities.firstWhere((c) => c.id == selectedId)),
                ),
              );
            }

            // Giao diện mặc định Mobile: Chỉ hiển thị danh sách phòng học
            return _buildCommunitiesSidebar(filtered, null);
          }
        },
        loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
        error: (e, _) => Center(child: Text("Lỗi tải dữ liệu cộng đồng: $e")),
      ),
    );
  }

  /// Giao diện danh sách các phòng học
  Widget _buildCommunitiesSidebar(List<CommunityRoom> list, String? activeId) {
    const primaryColor = Color(0xFF5A4FCF);

    return Column(
      children: [
        // Thanh tìm kiếm phòng học
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: "Tìm phòng học cộng đồng...",
              prefixIcon: const Icon(Icons.search, size: 20),
              fillColor: Colors.white,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          "Chưa có phòng học nào hoạt động.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final bool isActive = item.id == activeId;

                    return InkWell(
                      onTap: () {
                        ref.read(selectedCommunityIdProvider.notifier).state = item.id;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor.withOpacity(0.08) : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                            left: BorderSide(
                              color: isActive ? primaryColor : Colors.transparent,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isActive ? primaryColor : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fiber_manual_record, color: Colors.green, size: 8),
                                      SizedBox(width: 4),
                                      Text(
                                        "LIVE 24/7",
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Tạo bởi: ${item.creatorName}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${item.activeUsersCount} đang học",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            )
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

  /// Giao diện bảng thảo luận chi tiết và tham gia Zoom
  Widget _buildCommunityDetailPane(CommunityRoom room) {
    const primaryColor = Color(0xFF5A4FCF);
    final messagesAsync = ref.watch(communityMessagesStreamProvider(room.id));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isCreator = room.creatorId == currentUserId;

    // Tạo link Zoom Web Client chạy trực tiếp trên browser
    final String webJoinUrl = "https://zoom.us/wc/join/${room.meetingId}?pwd=${room.passcode}";

    return Column(
      children: [
        // 1. KHU VỰC THÔNG TIN PHÒNG ZOOM & NÚT GIA NHẬP
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Tiêu đề phòng kèm nút Xóa nếu là Creator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isCreator)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                      tooltip: "Xóa phòng học này",
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text("Xác nhận xóa phòng", style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: Text("Bạn có chắc chắn muốn xóa vĩnh viễn phòng học cộng đồng \"${room.name}\" và phòng họp Zoom đi kèm không? Hành động này không thể hoàn tác!"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Hủy bỏ"),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  navigator.pop(); // Đóng dialog

                                  try {
                                    // 1. Xóa cuộc họp trên Zoom API
                                    if (room.meetingId.isNotEmpty) {
                                      await _zoomService.deleteMeeting(room.meetingId);
                                    }

                                    // 2. Xóa tài liệu phòng học trên Firestore
                                    await FirebaseFirestore.instance
                                        .collection('communities')
                                        .doc(room.id)
                                        .delete();

                                    // 3. Reset ID được chọn
                                    ref.read(selectedCommunityIdProvider.notifier).state = null;

                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("Đã xóa phòng học cộng đồng thành công!")),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(content: Text("Lỗi khi xóa phòng học: $e")),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("Xóa vĩnh viễn"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Zoom Call Information Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D8CFF), Color(0xFF1E6FD9)], // Màu thương hiệu Zoom xanh dương
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.video_camera_front_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Phòng Học Trực Tuyến Zoom",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: room.isMock ? Colors.orangeAccent : Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    room.isMock
                                        ? "Chế độ mô phỏng Offline (Mock)"
                                        : "Kết nối Zoom API thật (Live 24/7)",
                                    style: TextStyle(
                                      color: room.isMock ? Colors.orange.shade100 : Colors.green.shade100,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Meeting ID & Passcode
                    Row(
                      children: [
                        _buildZoomMetaTag("Meeting ID", room.meetingId),
                        const SizedBox(width: 16),
                        _buildZoomMetaTag("Passcode", room.passcode),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Nút Zoom linh hoạt theo vai trò và nền tảng
                    Column(
                      children: [
                        if (isCreator && room.startUrl.isNotEmpty) ...[
                          ElevatedButton.icon(
                            onPressed: () => _joinZoomRoom(room.startUrl, isWebClient: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 1,
                            ),
                            icon: const Icon(Icons.play_circle_fill, size: 18, color: Colors.white),
                            label: const Text(
                              "BẮT ĐẦU PHÒNG HỌP (HOST)",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: () => _joinZoomRoom(webJoinUrl, isWebClient: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF2D8CFF),
                            minimumSize: const Size.fromHeight(42),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 1,
                          ),
                          icon: const Icon(Icons.web, size: 18, color: Color(0xFF2D8CFF)),
                          label: const Text(
                            "THAM GIA TRÊN TRÌNH DUYỆT (WEB CLIENT)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _joinZoomRoom(room.zoomUrl, isWebClient: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1),
                            minimumSize: const Size.fromHeight(40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                          label: const Text(
                            "Mở bằng ứng dụng Zoom App",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Mô tả cộng đồng
              Text(
                "Mô tả phòng học:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                room.description,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4),
              ),
            ],
          ),
        ),

        // 2. KHU VỰC THẢO LUẬN NHÓM (CHAT BOX)
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          "Chưa có tin nhắn nào trong phòng học này.\nHãy đặt câu hỏi đầu tiên để mọi người cùng thảo luận!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Tự động cuộn xuống cuối khi có tin nhắn mới
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              final currentUid = FirebaseAuth.instance.currentUser?.uid;

              return ListView.builder(
                controller: _chatScrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == currentUid;
                  final isSystem = msg.senderId == "system";

                  if (isSystem) {
                    return Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          msg.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
                        ),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe) ...[
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: msg.senderAvatar.isNotEmpty ? NetworkImage(msg.senderAvatar) : null,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: msg.senderAvatar.isEmpty
                                ? const Icon(Icons.person, size: 18, color: primaryColor)
                                : null,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Text(
                                    msg.senderName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                constraints: const BoxConstraints(maxWidth: 400),
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
                                  msg.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                                child: Text(
                                  _formatTime(msg.timestamp),
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: primaryColor)),
            error: (e, _) => Center(child: Text("Không thể tải tin nhắn thảo luận: $e")),
          ),
        ),

        // 3. KHU VỰC NHẬP LIỆU CHAT
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: "Đặt câu hỏi hoặc thảo luận lớp học...",
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendChatMessage(room.id),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () => _sendChatMessage(room.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Khung hiển thị thông số Zoom
  Widget _buildZoomMetaTag(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Giao diện trống khi chưa chọn Community (Desktop)
  Widget _buildEmptyDetailPane() {
    const primaryColor = Color(0xFF5A4FCF);
    return Center(
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
              child: const Icon(Icons.groups, size: 72, color: primaryColor),
            ),
            const SizedBox(height: 20),
            const Text(
              "Cộng đồng Học tập 24/7",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Hãy chọn một phòng học nhóm ở danh sách bên trái\nhoặc tự tạo phòng học Zoom 24/7 mới để cùng trao đổi học tập!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
