import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/nav_provider.dart';
import '../../providers/app_providers.dart'; // Chứa currentUser & hasUnread
import '../widgets/user_search_box.dart';

class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(navProvider);
    final currentUserAsync = ref.watch(currentUserProfileProvider);
    final hasUnread =
        ref.watch(hasUnreadNotificationsProvider); // Lấy trạng thái unread

    const primaryColor = Color(0xFF5A4FCF);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 10, top: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: UserSearchBox(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: allNavItems.map((item) {
                // Check Badge
                final bool showBadge =
                    (item.section == AppSection.alerts && hasUnread);
                return _buildMenuItem(ref, item, currentSection,
                    showBadge: showBadge);
              }).toList(),
            ),
          ),
          // ... (Phần Compose & User Info giữ nguyên như cũ) ...
          SizedBox(
            width: 200,
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
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
          InkWell(
            onTap: () =>
                ref.read(navProvider.notifier).state = AppSection.profile,
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: currentUserAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Icon(Icons.error),
                  data: (user) {
                    final String initial =
                        (user?.displayName.isNotEmpty ?? false)
                            ? user!.displayName[0]
                            : "U";
                    return Row(
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
                        Text(user?.displayName ?? "User",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    );
                  }),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMenuItem(WidgetRef ref, NavItem item, AppSection current,
      {bool showBadge = false}) {
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isActive ? item.activeIcon : item.icon,
                      size: 26, color: itemColor),
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
                            border: Border.all(color: Colors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(item.label,
                    style: GoogleFonts.inter(
                        fontSize: 19,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: itemColor),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
