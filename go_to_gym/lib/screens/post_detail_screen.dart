import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/models/post.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final Post post;
  final bool isOwner;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.isOwner,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}


Future<void> sendPostNotification(String title, String body) async {
  const String serverKey = 'YOUR_SERVER_KEY_FROM_FIREBASE'; // Ganti dengan server key dari Firebase

  try {
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': '/topics/all',
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      }),
    );
  } catch (e) {
    print("Error sending notification: \$e");
  }
}


class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 365) {
      return DateFormat('MMM dd, yyyy').format(date);
    } else {
      return timeago.format(date);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    final username = userDoc.exists ? userDoc['username'] : currentUser!.email;

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .add({
      'userId': currentUser!.uid,
      'username': username,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
      await sendPostNotification("Komentar Baru!", "Postinganmu mendapat komentar baru.");

  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      print("🔥 Failed to delete comment: $e");
    }
  }

  Future<void> _editComment(String commentId, String currentText) async {
    final controller = TextEditingController(text: currentText);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Edit Comment",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: null,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Update your comment",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF334155),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final newText = controller.text.trim();
                      if (newText.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.post.id)
                            .collection('comments')
                            .doc(commentId)
                            .update({'text': newText});
                      }
                      Navigator.pop(context);
                    },
                    child: const Text("Save"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCommentOptions(String commentId, String currentText, bool isOwner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Wrap(
        children: [
          if (isOwner) ...[
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.amber),
              title: const Text("Edit", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editComment(commentId, currentText);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text("Delete", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _deleteComment(commentId);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orangeAccent),
              title: const Text("Report", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Comment reported.")),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.post.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();

                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        final base64Image = data?['profileImageBase64'] ?? '';
                        final username = data?['username'] ?? 'User';

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: base64Image.isNotEmpty
                                  ? MemoryImage(base64Decode(base64Image))
                                  : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  if (widget.post.imageBase64.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                        minHeight: 200,
                      ),
                      child: Image.memory(
                        base64Decode(widget.post.imageBase64),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.description,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatTimestamp(widget.post.createdAt),
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final doc = comments[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          final isOwner = data['userId'] == currentUser?.uid;

                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(data['userId'])
                                .snapshots(),
                            builder: (context, userSnapshot) {
                              final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                              final profileBase64 = userData?['profileImageBase64'] ?? '';
                              final username = userData?['username'] ?? 'User';

                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: profileBase64.isNotEmpty
                                      ? MemoryImage(base64Decode(profileBase64))
                                      : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                                ),
                                title: Text(
                                  username,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['text'] ?? '',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    if (createdAt != null)
                                      Text(
                                        timeago.format(createdAt),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white60),
                                  onPressed: () => _showCommentOptions(
                                    doc.id,
                                    data['text'] ?? '',
                                    isOwner,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF38BDF8)),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
