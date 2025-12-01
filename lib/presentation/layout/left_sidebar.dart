import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/nav_provider.dart';
import '../widgets/user_search_box.dart';

class LeftSidebar extends ConsumerWidget {
  const LeftSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(navProvider);

    const primaryColor = Color(0xFF5A4FCF);

    return Container(
      // Giảm padding trái từ 30 xuống 20 cho cân đối
      padding: const EdgeInsets.only(left: 20, right: 10, top: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. LOGO APP (Thu nhỏ lại)
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 8),
            child: Text(
              "AI GENCOURSE.",
              style: GoogleFonts.inter(
                fontSize: 24, // Giảm từ 28 -> 24
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

          // 4. COMPOSE BUTTON (Thu nhỏ chiều cao và font)
          SizedBox(
            width: 200, // Thu gọn chiều rộng nút
            height: 48, // Giảm chiều cao từ 55 -> 48
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
                      fontSize: 16) // Font 16
                  ),
            ),
          ),

          const SizedBox(height: 20),

          // 5. USER INFO (Thu nhỏ avatar và text)
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 18, // Giảm từ 20 -> 18
                    backgroundImage: NetworkImage(
                        "https://ui-avatars.com/api/?name=Me&background=random"),
                  ),
                  const SizedBox(width: 10),

                  // Dùng Flexible để tên dài không bị overflow
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "My Name",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14), // Giảm font
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "@myusername",
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12), // Giảm font
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz, size: 20),
                ],
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
      padding:
          const EdgeInsets.only(bottom: 4), // Giảm khoảng cách giữa các item
      child: InkWell(
        onTap: () => ref.read(navProvider.notifier).state = item.section,
        borderRadius: BorderRadius.circular(30), // Bo góc nhỏ hơn xíu
        hoverColor: Colors.grey.shade100,
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: 10, horizontal: 12), // Giảm padding trong
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? item.activeIcon : item.icon,
                  size: 26, // Giảm Icon từ 32 -> 26 (Gọn gàng hơn)
                  color: itemColor),
              const SizedBox(width: 16), // Giảm khoảng cách icon và chữ

              // --- QUAN TRỌNG: SỬA LỖI OVERFLOW ---
              // Dùng Flexible để text tự co lại nếu không đủ chỗ
              Flexible(
                child: Text(
                  item.label,
                  style: GoogleFonts.inter(
                      fontSize:
                          19, // Giảm Font từ 22 -> 19 (Vẫn rõ nhưng không thô)
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: itemColor),
                  overflow: TextOverflow.ellipsis, // Cắt bớt nếu quá dài
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
