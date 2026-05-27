import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_providers.dart';
import '../../providers/community_providers.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();

  // Agora App ID thử nghiệm hỗ trợ chế độ App ID Only (Không cần sinh token động từ server)
  static const String agoraAppId = "dba3b612de9b41a9871f21c69d766d72";

  String _searchQuery = "";
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _sanitizeActiveUsersCounts();
  }

  /// Khôi phục số lượng học viên đang hoạt động về 0 cho tất cả các phòng
  /// để tránh hiển thị sai lệch số lượng từ các phiên làm việc cũ/bị crash/mock database ban đầu.
  Future<void> _sanitizeActiveUsersCounts() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('communities').get();
      final batch = FirebaseFirestore.instance.batch();
      bool hasChanges = false;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final currentCount = data['activeUsersCount'] ?? 0;
        if (currentCount != 0) {
          batch.update(doc.reference, {'activeUsersCount': 0});
          hasChanges = true;
        }
      }

      if (hasChanges) {
        await batch.commit();
        debugPrint("[Agora] Đã dọn dẹp và reset số lượng học viên hoạt động về 0.");
      }
    } catch (e) {
      debugPrint("[Agora] Lỗi khi dọn dẹp số lượng học viên: $e");
    }
  }

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


  /// Hiển thị Dialog tạo phòng học mới tích hợp Agora SDK
  void _showAddCommunityDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final appIdCtrl = TextEditingController();
    final channelCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
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
                  Text("Tạo phòng tự học 24/7", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Hệ thống sẽ tự động tạo một phòng học nhóm trực tuyến 24/7 thông qua Agora Video SDK.",
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: appIdCtrl,
                        decoration: InputDecoration(
                          labelText: "Agora App ID (Tùy chọn)",
                          hintText: "Mặc định sử dụng App ID thử nghiệm",
                          helperText: "Lấy App ID miễn phí tại console.agora.io để kích hoạt luồng camera thật của bạn",
                          helperMaxLines: 2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: channelCtrl,
                        decoration: InputDecoration(
                          labelText: "Agora Channel Name (Tùy chọn)",
                          hintText: "Nhập chính xác tên kênh khi tạo Token",
                          helperText: "Bắt buộc phải trùng với Channel Name dùng để sinh Temporary Token trên Agora Console",
                          helperMaxLines: 2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: tokenCtrl,
                        decoration: InputDecoration(
                          labelText: "Agora Token (Tùy chọn)",
                          hintText: "Mặc định để trống (Không bảo mật)",
                          helperText: "Nếu dự án của bạn bật bảo mật App ID + Token, hãy tạo Temporary Token rồi dán vào đây",
                          helperMaxLines: 2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

                              // 1. Tạo phòng học kết nối qua Agora Video RTC Channel
                              final docRef = FirebaseFirestore.instance.collection('communities').doc();

                              final room = CommunityRoom(
                                id: docRef.id,
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                agoraAppId: appIdCtrl.text.trim().isNotEmpty ? appIdCtrl.text.trim() : agoraAppId,
                                agoraChannelName: channelCtrl.text.trim().isNotEmpty
                                    ? channelCtrl.text.trim()
                                    : "channel_${docRef.id}", // Dùng input hoặc tự động sinh ngẫu nhiên
                                agoraToken: tokenCtrl.text.trim(), // Lưu Token bảo mật nếu có
                                creatorId: creatorId,
                                creatorName: creatorName,
                                activeUsersCount: 0, // Bắt đầu bằng 0, sẽ tự động tăng khi tham gia thành công
                                createdAt: DateTime.now(),
                                isMock: false, // Kết nối thời gian thực trực tuyến thật qua máy chủ Agora
                              );

                              await docRef.set(room.toFirestore());

                              // 2. Gửi tin nhắn chào mừng hệ thống đầu tiên
                              final msgRef = docRef.collection('messages').doc();
                              final welcomeMsg = CommunityMessage(
                                id: msgRef.id,
                                senderId: "system",
                                senderName: "Hệ thống",
                                senderAvatar: "",
                                text: "Chào mừng các bạn đến với phòng học cộng đồng: ${room.name}! Lưới camera thời gian thực 24/7 đã sẵn sàng, hãy bật camera ở trên để học nhóm trực tuyến cùng mọi người nhé! 🟢",
                                timestamp: DateTime.now(),
                              );
                              await msgRef.set(welcomeMsg.toFirestore());

                              if (mounted) {
                                // Chọn phòng mới tạo làm phòng active
                                ref.read(selectedCommunityIdProvider.notifier).state = docRef.id;
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text("Tạo phòng học cộng đồng thành công!")),
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
          // Nút tạo phòng tự học 24/7
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
              label: const Text("Tạo phòng tự học", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

          // Người dùng khi bấm vào Communities sẽ không tự chọn phòng nào cả để chỉ xem danh sách ban đầu

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
                      onTap: () async {
                        final currentActive = ref.read(selectedCommunityIdProvider);
                        if (currentActive == item.id) return;

                        if (currentActive != null) {
                          // Hiện hộp thoại hỏi ý kiến thoát phòng hiện tại
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Row(
                                  children: [
                                    Icon(Icons.logout, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text("Xác nhận", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                              ),
                              content: const Text("Bạn muốn thoát phòng hiện tại?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Không"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5A4FCF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text("Có, thoát phòng"),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            // Yes -> thoát phòng hiện tại và chuyển về danh sách
                            ref.read(selectedCommunityIdProvider.notifier).state = null;
                          }
                          return;
                        }

                        // Nếu chưa ở trong phòng nào, bấm vào thì vào phòng
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

  /// Giao diện bảng thảo luận chi tiết và học nhóm trực tuyến Agora
  Widget _buildCommunityDetailPane(CommunityRoom room) {
    const primaryColor = Color(0xFF5A4FCF);
    final messagesAsync = ref.watch(communityMessagesStreamProvider(room.id));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final isCreator = room.creatorId == currentUserId;

    return Column(
      children: [
        // 1. KHU VỰC THÔNG TIN PHÒNG & LƯỚI CAMERA AGORA
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
                  // Nút thoát phòng cho user
                  TextButton.icon(
                    onPressed: () {
                      ref.read(selectedCommunityIdProvider.notifier).state = null;
                    },
                    icon: const Icon(Icons.logout, size: 14, color: Colors.redAccent),
                    label: const Text(
                      "Thoát phòng",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
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
                            content: Text("Bạn có chắc chắn muốn xóa vĩnh viễn phòng học cộng đồng \"${room.name}\"? Hành động này không thể hoàn tác!"),
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
                                    // 1. Xóa tài liệu phòng học trên Firestore
                                    await FirebaseFirestore.instance
                                        .collection('communities')
                                        .doc(room.id)
                                        .delete();

                                    // 2. Reset ID được chọn
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
              // Lưới Camera Học Nhóm Trực Tuyến
              AgoraVideoGrid(
                key: ValueKey(room.id),
                roomId: room.id,
                appId: (room.agoraAppId.isNotEmpty && room.agoraAppId != "65988f15d85541c8b0dcc87b5f8c6fc0")
                    ? room.agoraAppId
                    : agoraAppId,
                channelName: room.agoraChannelName,
                token: room.agoraToken,
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
              "Hãy chọn một phòng học nhóm ở danh sách bên trái\nhoặc tự tạo phòng học trực tuyến mới để học tập cùng mọi người!",
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

// ===================================================================
//  AGORA VIDEO GRID VIEW WIDGET (Lưới Camera "Study With Me" 24/7)
// ===================================================================
class AgoraVideoGrid extends StatefulWidget {
  final String roomId;
  final String appId;
  final String channelName;
  final String token;

  const AgoraVideoGrid({
    super.key,
    required this.roomId,
    required this.appId,
    required this.channelName,
    required this.token,
  });

  @override
  State<AgoraVideoGrid> createState() => _AgoraVideoGridState();
}

class _AgoraVideoGridState extends State<AgoraVideoGrid> {
  static Future<void>? _disposalFuture;

  RtcEngine? _engine;
  bool _isJoined = false;
  bool _localUserMuted = true; // Mặc định tắt tiếng khi tham gia
  bool _localVideoMuted = true; // Mặc định tắt camera khi tham gia
  int? _localUid;
  final List<int> _remoteUids = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _disposalFuture = _disposeAgora();
    super.dispose();
  }

  Future<void> _initAgora() async {
    try {
      // 1. Chờ cho bất kỳ tiến trình giải phóng engine cũ nào hoàn tất
      if (_disposalFuture != null) {
        debugPrint("[Agora] Đang chờ engine cũ giải phóng hoàn toàn...");
        await _disposalFuture;
        debugPrint("[Agora] Engine cũ giải phóng thành công. Tiến hành khởi tạo mới.");
      }

      // 2. Xin quyền truy cập Camera và Microphone (trên mobile)
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      // 2. Khởi tạo RtcEngine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: widget.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // 3. Đăng ký các Event Handler
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("[Agora] Local user joined successfully with UID: ${connection.localUid}");
          if (mounted) {
            setState(() {
              _isJoined = true;
              _localUid = connection.localUid;
              _errorMessage = null;
            });
            _incrementUserCount(); // Tăng số người trong phòng thời gian thực
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("[Agora] Remote user joined: $remoteUid");
          if (mounted) {
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("[Agora] Remote user went offline: $remoteUid");
          if (mounted) {
            setState(() {
              _remoteUids.remove(remoteUid);
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("[Agora] Lỗi RTC Engine: err=$err, msg=$msg");
          if (mounted) {
            setState(() {
              _errorMessage = "Lỗi Agora: $msg (code: $err)";
            });
          }
        },
      ));

      // 4. Cấu hình vai trò và bật video
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableVideo();
      // Khởi động phòng với camera và micro tắt mặc định
      await _engine!.muteLocalAudioStream(true);
      await _engine!.muteLocalVideoStream(true);

      // 5. Tham gia kênh (Nếu token rỗng thì Agora sẽ chạy chế độ App ID Only bypass token)
      await _engine!.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0, // uid = 0 để Agora tự cấp ngẫu nhiên
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("[Agora] Lỗi khởi tạo hoặc kết nối Agora: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _disposeAgora() async {
    try {
      if (_isJoined) {
        await _decrementUserCount(); // Giảm số người khi rời phòng
      }
      if (_engine != null) {
        await _engine!.leaveChannel();
        await _engine!.release();
      }
    } catch (e) {
      debugPrint("[Agora] Lỗi giải phóng RtcEngine: $e");
    }
  }

  Future<void> _incrementUserCount() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('communities').doc(widget.roomId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data();
          final currentCount = data?['activeUsersCount'] ?? 0;
          transaction.update(docRef, {'activeUsersCount': currentCount + 1});
        }
      });
    } catch (e) {
      debugPrint("Lỗi tăng số lượng học viên: $e");
    }
  }

  Future<void> _decrementUserCount() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('communities').doc(widget.roomId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data();
          final currentCount = data?['activeUsersCount'] ?? 0;
          final newCount = (currentCount - 1) < 0 ? 0 : (currentCount - 1);
          transaction.update(docRef, {'activeUsersCount': newCount});
        }
      });
    } catch (e) {
      debugPrint("Lỗi giảm số lượng học viên: $e");
    }
  }

  // Tắt/Bật Micro
  Future<void> _toggleMute() async {
    if (_engine == null) return;
    try {
      await _engine!.muteLocalAudioStream(!_localUserMuted);
      setState(() {
        _localUserMuted = !_localUserMuted;
      });
    } catch (e) {
      debugPrint("Lỗi toggle mute mic: $e");
    }
  }

  // Tắt/Bật Camera
  Future<void> _toggleCamera() async {
    if (_engine == null) return;
    try {
      final bool newMuteState = !_localVideoMuted;
      await _engine!.muteLocalVideoStream(newMuteState);

      if (newMuteState) {
        // Tắt camera: dừng preview để tắt đèn cam và giải phóng phần cứng
        await _engine!.stopPreview();
      } else {
        // Bật camera: khởi động preview để thu hình từ phần cứng
        await _engine!.startPreview();
      }

      setState(() {
        _localVideoMuted = newMuteState;
      });
    } catch (e) {
      debugPrint("Lỗi toggle mute camera: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      final bool isAppIdError = _errorMessage!.contains("invalid vendor key") ||
                                _errorMessage!.contains("appid") ||
                                _errorMessage!.contains("CAN_NOT_GET_GATEWAY_SERVER") ||
                                _errorMessage!.contains("errJoinChannelRejected");

      final bool isTokenRequiredError = _errorMessage!.contains("dynamic use static key") ||
                                        _errorMessage!.contains("static use dynamic key") ||
                                        _errorMessage!.contains("token");

      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "Không thể kết nối phòng học Agora",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (isTokenRequiredError) ...[
                  Text(
                    "🔐 LỖI XÁC THỰC: Project đang bắt buộc sử dụng Token.\n(App ID đang chạy: ${widget.appId})",
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Dự án của bạn trên Agora Console đang bật chế độ bảo mật cao (APP ID + Token), yêu cầu Token để tham gia phòng học.\n\n"
                    "👉 HƯỚNG DẪN KHẮC PHỤC (Nhanh nhất):\n"
                    "1. Mở Agora Console (console.agora.io)\n"
                    "2. Vào project của bạn -> Click 'Cấu hình' (Config)\n"
                    "3. Tại mục 'App Certificate', hãy chuyển sang chế độ 'No-Certificate Mode' (Tắt Certificate) hoặc tạo một Project mới ở chế độ 'Testing Mode' (APP ID Only).\n"
                    "4. Sau khi chuyển đổi, bạn có thể tự do kết nối camera mà không cần Token bảo mật!",
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse("https://console.agora.io/");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text("Mở Agora Console"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A4FCF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ] else if (isAppIdError) ...[
                  Text(
                    "⚠️ LỖI KHỞI TẠO: Agora App ID không hợp lệ hoặc đã hết hạn.\n(Đang sử dụng App ID: ${widget.appId})",
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Để kích hoạt camera trực tuyến của riêng bạn, vui lòng thực hiện:\n"
                    "1. Truy cập console.agora.io và đăng ký tài khoản miễn phí.\n"
                    "2. Tạo một dự án mới và sao chép mã App ID (chuỗi 32 ký tự).\n"
                    "3. Click nút 'Tạo phòng tự học' màu tím ở góc trên và dán App ID mới của bạn vào form.",
                    textAlign: TextAlign.left,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse("https://console.agora.io/");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text("Mở Agora Console"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A4FCF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ] else ...[
                  Text(
                    "Chi tiết lỗi: $_errorMessage",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_engine == null || !_isJoined) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF5A4FCF)),
              SizedBox(height: 12),
              Text(
                "Đang kết nối camera thời gian thực...",
                style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    // Danh sách tất cả các view camera (bao gồm local user và remote users)
    final List<Widget> videoViews = [];

    // Kích thước cố định tinh tế dẹt chuẩn 16:9 của từng ô camera giống hệt StudyStream
    const double tileWidth = 260.0;
    const double tileHeight = 146.0; // Tỉ lệ 16:9 chuẩn (260 / 1.77)

    // 1. Thêm camera local (người dùng hiện tại)
    if (_localUid != null && !_localVideoMuted) {
      videoViews.add(_buildVideoTile(
        SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine!,
              canvas: const VideoCanvas(uid: 0, renderMode: RenderModeType.renderModeHidden),
            ),
          ),
        ),
        "Bạn (Tôi)",
        _localUserMuted,
        tileWidth,
        tileHeight,
      ));
    } else if (_localVideoMuted) {
      videoViews.add(_buildVideoPlaceholder(
        "Bạn (Đã tắt Camera)",
        _localUserMuted,
        tileWidth,
        tileHeight,
      ));
    }

    // 2. Thêm camera của các học viên khác trong phòng
    for (var uid in _remoteUids) {
      videoViews.add(_buildVideoTile(
        SizedBox(
          width: tileWidth,
          height: tileHeight,
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: uid, renderMode: RenderModeType.renderModeHidden),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
        ),
        "Học viên $uid",
        false, // Mặc định mic học viên khác bật
        tileWidth,
        tileHeight,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Lưới các ô camera tự xếp cạnh nhau bằng Wrap cực kỳ thoáng đãng, sang trọng
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Wrap(
            spacing: 12, // Khoảng cách ngang giữa các ô camera
            runSpacing: 12, // Khoảng cách dọc khi tự rớt dòng
            alignment: WrapAlignment.start, // Căn lề trái giống hệt StudyStream
            children: videoViews,
          ),
        ),
        const SizedBox(height: 12),
        // Thanh công cụ điều khiển cuộc gọi nhỏ gọn ở dưới lưới
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Nút Bật/Tắt Micro
            ElevatedButton.icon(
              onPressed: _toggleMute,
              icon: Icon(
                _localUserMuted ? Icons.mic_off : Icons.mic,
                color: _localUserMuted ? Colors.redAccent : const Color(0xFF5A4FCF),
                size: 16,
              ),
              label: Text(
                _localUserMuted ? "Bật tiếng" : "Tắt tiếng",
                style: TextStyle(
                  color: _localUserMuted ? Colors.redAccent : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            // Nút Bật/Tắt Camera
            ElevatedButton.icon(
              onPressed: _toggleCamera,
              icon: Icon(
                _localVideoMuted ? Icons.videocam_off : Icons.videocam,
                color: _localVideoMuted ? Colors.redAccent : const Color(0xFF5A4FCF),
                size: 16,
              ),
              label: Text(
                _localVideoMuted ? "Bật Camera" : "Tắt Camera",
                style: TextStyle(
                  color: _localVideoMuted ? Colors.redAccent : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Khung chứa camera có bo góc tròn, tiêu đề hiển thị tên học viên
  Widget _buildVideoTile(Widget agoraView, String label, bool isMuted, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5), // Viền sáng mỏng giống StudyStream
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(child: agoraView),
            // Tag thông tin học viên nằm đè lên luồng video sang trọng
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? Colors.redAccent : Colors.greenAccent,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Khung hiển thị khi không có video (Placeholder)
  Widget _buildVideoPlaceholder(String label, bool isMuted, double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off, color: Colors.grey, size: 24),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMuted ? Icons.mic_off : Icons.mic,
                  color: isMuted ? Colors.redAccent : Colors.grey,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
