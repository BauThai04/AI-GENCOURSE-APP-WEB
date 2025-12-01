import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/nav_provider.dart';
import 'left_sidebar.dart';
import '../screens/home_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/ai_gencourse_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponsiveScaffold extends ConsumerWidget {
  const ResponsiveScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSection = ref.watch(navProvider);

    Widget getContent() {
      switch (currentSection) {
        case AppSection.home:
          return const HomeScreen();
        case AppSection.alerts:
          return const AlertsScreen();
        case AppSection.aiStudio:
          return const AiGenCourseScreen();
        case AppSection.messages:
          return const MessagesScreen();
        case AppSection.communities:
          return const GroupsScreen();
        case AppSection.bookmarks:
          return const Center(child: Text("Bookmarks – Coming soon"));
        case AppSection.profile:
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            return const Center(child: Text("Không tìm thấy user hiện tại"));
          }
          return ProfileScreen(userId: uid);
      }
    }

    // 🔧 FIX: Dùng LayoutBuilder thay vì MediaQuery trực tiếp
    // LayoutBuilder đảm bảo constraints được tính toán đúng
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isDesktop = width >= 1000;

        // 🔍 DEBUG
        debugPrint('🖥️ Layout width: $width | isDesktop: $isDesktop');

        // ================= DESKTOP LAYOUT =================
        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar trái
                const SizedBox(
                  width: 255,
                  child: LeftSidebar(),
                ),

                // Nội dung chính
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    decoration: BoxDecoration(
                      border: Border.symmetric(
                        vertical: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: getContent(),
                  ),
                ),

                // Sidebar phải
                const SizedBox(
                  width: 310,
                  child: RightSidebarContent(),
                ),
              ],
            ),
          );
        }

        // ================= MOBILE LAYOUT =================
        return Scaffold(
          backgroundColor: Colors.white,
          body: getContent(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _mobileIndexFromSection(currentSection),
            onTap: (index) {
              ref.read(navProvider.notifier).state =
                  _sectionFromMobileIndex(index);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF5A4FCF),
            unselectedItemColor: Colors.grey,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: mobileNavItems
                .map(
                  (item) => BottomNavigationBarItem(
                    icon: Icon(item.icon),
                    activeIcon: Icon(item.activeIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  // Helper functions
  int _mobileIndexFromSection(AppSection section) {
    final idx = mobileNavItems.indexWhere((item) => item.section == section);
    if (idx == -1) return 0;
    return idx;
  }

  AppSection _sectionFromMobileIndex(int index) {
    return mobileNavItems[index].section;
  }
}

// ==========================================
// RIGHT SIDEBAR CONTENT
// ==========================================
class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Search Bar
            Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F4),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: "Search",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. Banner "Get Premium+"
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Get Premium+",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Unlock exclusive AI features and remove ads.",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text("Subscribe"),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Trending Section
            _buildSectionContainer(
              title: "Trends for you",
              children: [
                _trendItem("#AI_GenCourse", "125k Posts"),
                _trendItem("#FlutterDev", "54k Posts"),
                _trendItem("#VietnamTech", "12k Posts"),
                _trendItem("#StartupLife", "8k Posts"),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Who to follow
            _buildSectionContainer(
              title: "Who to follow",
              children: [
                _followItem("Elon Musk", "@elonmusk"),
                _followItem("Donald Trump", "@realDonaldTrump"),
                _followItem("OpenAI", "@OpenAI"),
              ],
            ),
            const SizedBox(height: 20),

            const Wrap(
              spacing: 10,
              children: [
                Text("Terms",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Privacy",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("Cookie",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text("© 2025 AI GenCourse",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 12),
            child: Text(
              "Show more",
              style: TextStyle(color: Colors.purple.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendItem(String tag, String count) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        tag,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        count,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _followItem(String name, String handle) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const CircleAvatar(radius: 18, backgroundColor: Colors.grey),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(
        handle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(60, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
        ),
        child: const Text("Follow", style: TextStyle(fontSize: 11)),
      ),
    );
  }
}
