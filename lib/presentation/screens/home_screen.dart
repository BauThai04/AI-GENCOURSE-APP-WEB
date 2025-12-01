import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_composer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Chỉ trả về MainFeed, không bọc Row hay Scaffold 3 cột nữa
    return const MainFeed(
        primaryColor: Color(0xFF5A4FCF), accentPink: Color(0xFFE04F5F));
  }
}

class MainFeed extends ConsumerWidget {
  final Color primaryColor;
  final Color accentPink;

  const MainFeed(
      {super.key, required this.primaryColor, required this.accentPink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(globalFeedProvider);
    // Kiểm tra mobile để hiện AppBar (Web không cần vì đã có sidebar)
    final isMobile = MediaQuery.of(context).size.width < 900;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,

        // AppBar chỉ hiện trên Mobile
        appBar: isMobile
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                      backgroundColor: primaryColor,
                      child: const Text("U",
                          style: TextStyle(color: Colors.white))),
                ),
                title: const Text("Home",
                    style: TextStyle(
                        color: Color(0xFF5A4FCF), fontWeight: FontWeight.bold)),
                centerTitle: true,
                actions: [
                  IconButton(
                      icon: const Icon(Icons.logout, color: Colors.black),
                      onPressed: () => AuthService().signOut())
                ],
              )
            : null,

        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFEFF3F4)))),
              child: TabBar(
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "For You"),
                  Tab(text: "Following"),
                  Tab(text: "Groups")
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  const PostComposer(),
                  const Divider(thickness: 8, color: Color(0xFFF5F8FA)),
                  feedAsync.when(
                    data: (posts) {
                      if (posts.isEmpty)
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text("No posts yet.")));
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) =>
                            PostCard(post: posts[index]),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
