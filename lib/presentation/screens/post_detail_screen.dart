import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart'
    as timeago; // Cần thêm package timeago hoặc dùng intl

import '../../data/models/post_model.dart';
import '../../providers/app_providers.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendComment() async {
    if (_commentCtrl.text.trim().isEmpty) return;

    final user = ref.read(currentUserProfileProvider).value;
    if (user == null) return;

    setState(() => _isSending = true);
    try {
      await ref.read(postRepositoryProvider).addComment(
            postId: widget.post.postId,
            author: user,
            text: _commentCtrl.text.trim(),
            postAuthorUid: widget.post.authorUid,
          );
      _commentCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.post.postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Posts",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 1. Original Post
                PostCard(post: widget.post),
                const Divider(thickness: 1),

                // 2. Comments List
                commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty)
                      return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text("Chưa có bình luận nào.")));
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage(comment.authorAvatarUrl),
                          ),
                          title: Row(
                            children: [
                              Text(comment.authorDisplayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 5),
                              if (comment.createdAt != null)
                                Text(timeago.format(comment.createdAt!),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          subtitle: Text(comment.content),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text("Lỗi tải comment: $e")),
                )
              ],
            ),
          ),

          // 3. Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: "Write your reply",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: Color(0xFF5A4FCF)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
