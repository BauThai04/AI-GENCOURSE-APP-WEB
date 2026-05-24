import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart'; // currentUser, hasUnread, viewedProfileId
import '../../services/auth_service.dart'; // Import AuthService để thực hiện đăng xuất
import '../screens/login_screen.dart'; // Import LoginScreen để thực hiện chuyển hướng sau đăng xuất
import '../widgets/user_search_box.dart';

class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(navProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final hasUnread = ref.watch(hasUnreadNotificationsProvider);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 10, top: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo - Truth Social style
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 8),
            child: Row(
              children: [
                Text(
                  "*AI_GenCourse",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFE04F5F), // Red accent
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  ".",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Search users
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: UserSearchBox(),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: allNavItems.map((item) {
                final bool showBadge =
                    (item.section == AppSection.alerts && hasUnread);
                return _buildMenuItem(ref, item, currentSection,
                    showBadge: showBadge);
              }).toList(),
            ),
          ),

          // Nút Compose (Truth Social style)
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE04F5F), // Truth Social red
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text(
                "Compose",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ô hiển thị user hiện tại và nút Đăng xuất ở góc dưới
          currentUserAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Icon(Icons.error),
            ),
            data: (user) {
              final String initial = (user?.displayName.isNotEmpty ?? false)
                  ? user!.displayName[0].toUpperCase()
                  : "U";
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Click vào Avatar và tên để chuyển sang trang Profile của mình
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          ref.read(viewedProfileIdProvider.notifier).state = null;
                          ref.read(navProvider.notifier).state = AppSection.profile;
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                                    ? NetworkImage(user!.avatarUrl)
                                    : null,
                                child: (user?.avatarUrl.isEmpty ?? true)
                                    ? Text(initial)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  user?.displayName ?? "User",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Nút Đăng xuất
                    Tooltip(
                      message: "Đăng xuất",
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.grey, size: 22),
                        onPressed: () async {
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Đăng xuất'),
                              content: const Text(
                                  'Bạn có chắc chắn muốn đăng xuất khỏi AI GenCourse?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Hủy bỏ'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Đăng xuất',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          if (shouldLogout == true) {
                            await AuthService().signOut();
                            if (context.mounted) {
                              // Chuyển hướng người dùng dứt khoát về trang đăng nhập và làm sạch stack
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                                (Route<dynamic> route) => false,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    WidgetRef ref,
    NavItem item,
    AppSection current, {
    bool showBadge = false,
  }) {
    final bool isActive = item.section == current;
    final bool isAiStudio = item.section == AppSection.aiStudio;
    final Color itemColor = isAiStudio
        ? const Color(0xFF5A4FCF)
        : (isActive ? Colors.black : Colors.black87);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Nếu bấm vào Profile trong menu -> xem profile của mình
            if (item.section == AppSection.profile) {
              ref.read(viewedProfileIdProvider.notifier).state = null;
            }
            ref.read(navProvider.notifier).state = item.section;
          },
          borderRadius: BorderRadius.circular(30),
          hoverColor: Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      size: 26,
                      color: itemColor,
                    ),
                    if (showBadge)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: itemColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
