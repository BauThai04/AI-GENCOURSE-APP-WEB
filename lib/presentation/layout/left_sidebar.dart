import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart'; // Chứa currentUserProfileProvider
import '../widgets/user_search_box.dart';

class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(navProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);

    const primaryColor = Color(0xFF5A4FCF);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 10, top: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. LOGO APP
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 8),
            child: Text(
              "GENCOURSE.",
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: primaryColor,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // 2. SEARCH BOX
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: UserSearchBox(),
          ),

          // 3. MENU LIST
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: allNavItems.map((item) {
                return _buildMenuItem(
                  ref,
                  item,
                  currentSection,
                );
              }).toList(),
            ),
          ),

          // 4. COMPOSE BUTTON
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Open Compose Dialog
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE04F5F),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Post",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),

          const SizedBox(height: 20),

          // 5. USER INFO (ĐÃ KẾT NỐI REAL-TIME DATA)
          InkWell(
            onTap: () {
              // Chuyển sang màn hình Profile thông qua navProvider
              ref.read(navProvider.notifier).state = AppSection.profile;
            },
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: currentUserAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, stack) =>
                    const Icon(Icons.error_outline, color: Colors.red),
                data: (user) {
                  // Xử lý dữ liệu hiển thị
                  final String displayName =
                      (user?.displayName.isNotEmpty ?? false)
                          ? user!.displayName
                          : (user?.username ?? "User");
                  final String username = user?.username ?? "";
                  final String avatarUrl = user?.avatarUrl ?? "";
                  final String initial = displayName.isNotEmpty
                      ? displayName[0].toUpperCase()
                      : "U";

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar Logic
                      if (avatarUrl.isNotEmpty)
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(avatarUrl),
                          onBackgroundImageError: (_, __) {},
                        )
                      else
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: primaryColor,
                          child: Text(initial,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),

                      const SizedBox(width: 10),

                      // Name & Handle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "@$username",
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.more_horiz, size: 20),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMenuItem(WidgetRef ref, NavItem item, AppSection current) {
    final bool isActive = item.section == current;
    final bool isAiStudio = item.section == AppSection.aiStudio;

    final Color itemColor = isAiStudio
        ? const Color(0xFF5A4FCF)
        : (isActive ? Colors.black : Colors.black87);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => ref.read(navProvider.notifier).state = item.section,
        borderRadius: BorderRadius.circular(30),
        hoverColor: Colors.grey.shade100,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? item.activeIcon : item.icon,
                  size: 26, color: itemColor),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: itemColor),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
