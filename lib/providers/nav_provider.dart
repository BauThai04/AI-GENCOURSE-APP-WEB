import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Enum định danh các màn hình (Đã đổi tên theo yêu cầu)
enum AppSection {
  home,
  alerts,
  aiStudio, // Thay cho aiGenCourse
  messages,
  communities, // Thay cho groups
  bookmarks,
  profile
}

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

// 4. DANH SÁCH MENU ĐẦY ĐỦ (7 mục - Dùng cho Desktop)
final List<NavItem> allNavItems = [
  const NavItem(
      section: AppSection.home,
      label: "Home",
      icon: Icons.home_outlined,
      activeIcon: Icons.home),
  const NavItem(
      section: AppSection.alerts,
      label: "Alerts",
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications),
  const NavItem(
      section: AppSection.aiStudio,
      label: "AI Studio",
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome),
  const NavItem(
      section: AppSection.messages,
      label: "Messages",
      icon: Icons.mail_outline,
      activeIcon: Icons.mail),
  const NavItem(
      section: AppSection.communities,
      label: "Communities",
      icon: Icons.group_outlined,
      activeIcon: Icons.group),
  const NavItem(
      section: AppSection.bookmarks,
      label: "Bookmarks",
      icon: Icons.bookmark_border,
      activeIcon: Icons.bookmark),
  const NavItem(
      section: AppSection.profile,
      label: "Profile",
      icon: Icons.person_outline,
      activeIcon: Icons.person),
];

// 5. DANH SÁCH MENU MOBILE (5 mục - Lọc từ danh sách gốc)
// Đảm bảo thứ tự và dữ liệu luôn đồng bộ với Desktop
final List<NavItem> mobileNavItems = [
  allNavItems.firstWhere((e) => e.section == AppSection.home),
  allNavItems.firstWhere((e) => e.section == AppSection.alerts),
  allNavItems.firstWhere((e) => e.section == AppSection.aiStudio),
  allNavItems.firstWhere((e) => e.section == AppSection.messages),
  allNavItems.firstWhere((e) => e.section == AppSection.communities),
];
