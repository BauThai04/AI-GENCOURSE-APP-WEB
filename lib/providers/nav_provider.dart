import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Enum định danh các màn hình
enum AppSection {
  home,
  alerts,
  aiStudio, // Thay cho aiGenCourse
  messages,
  communities, // Thay cho groups
  bookmarks,
  profile,
  search, // 👈 Màn hình Search (chủ yếu dùng cho mobile)
}

final viewedProfileIdProvider = StateProvider<String?>((ref) => null);

// 2. State Provider quản lý màn hình đang chọn
final navProvider = StateProvider<AppSection>((ref) => AppSection.home);

// 3. Class cấu hình cho một mục Menu
class NavItem {
  final AppSection section;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItem({
    required this.section,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// 4. DANH SÁCH MENU ĐẦY ĐỦ (Dùng cho Desktop / Left sidebar)
// 👉 KHÔNG thêm Search vào đây để sidebar trái không có item Search riêng.
final List<NavItem> allNavItems = [
  const NavItem(
    section: AppSection.home,
    label: "Home",
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),
  const NavItem(
    section: AppSection.alerts,
    label: "Alerts",
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
  ),
  const NavItem(
    section: AppSection.aiStudio,
    label: "AI Studio",
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
  ),
  const NavItem(
    section: AppSection.messages,
    label: "Messages",
    icon: Icons.mail_outline,
    activeIcon: Icons.mail,
  ),
  const NavItem(
    section: AppSection.communities,
    label: "Communities",
    icon: Icons.group_outlined,
    activeIcon: Icons.group,
  ),
  const NavItem(
    section: AppSection.bookmarks,
    label: "Bookmarks",
    icon: Icons.bookmark_border,
    activeIcon: Icons.bookmark,
  ),
  const NavItem(
    section: AppSection.profile,
    label: "Profile",
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];

// 5. DANH SÁCH MENU MOBILE (6 mục – dùng cho BottomNavigationBar)
// Ở đây tạo LIST RIÊNG để chèn thêm nút Search ở giữa.
final List<NavItem> mobileNavItems = [
  // Home
  const NavItem(
    section: AppSection.home,
    label: "Home",
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),

  // Communities (People icon giống app mẫu)
  const NavItem(
    section: AppSection.communities,
    label: "Communities",
    icon: Icons.group_outlined,
    activeIcon: Icons.group,
  ),

  // 👇 NEW: Search tab cho mobile
  const NavItem(
    section: AppSection.search,
    label: "Search",
    icon: Icons.search_outlined,
    activeIcon: Icons.search,
  ),

  // AI Studio
  const NavItem(
    section: AppSection.aiStudio,
    label: "AI Studio",
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
  ),

  // Alerts
  const NavItem(
    section: AppSection.alerts,
    label: "Alerts",
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
  ),

  // Messages
  const NavItem(
    section: AppSection.messages,
    label: "Messages",
    icon: Icons.mail_outline,
    activeIcon: Icons.mail,
  ),
];
