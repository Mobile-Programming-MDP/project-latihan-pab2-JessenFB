import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_to_gym/models/post.dart';
import 'package:intl/intl.dart';

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

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    return diff.inDays >= 365
        ? DateFormat('MMM dd, yyyy').format(date)
        : timeago.format(date);
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    final username = userDoc['username'] ?? 'User';

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
  }

  Future<void> _deleteCommentAndReplies(String commentId) async {
    final repliesSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .get();

    for (final reply in repliesSnapshot.docs) {
      await reply.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  void _showCommentOptions(String commentId) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Comment',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteCommentAndReplies(commentId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplies(
    String commentId,
    bool showReplies,
    VoidCallback toggleReplies,
  ) {
    if (!showReplies) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(left: 60, bottom: 8),
            child: GestureDetector(
              onTap: toggleReplies,
              child: const Text(
                "View replies",
                style: TextStyle(color: Colors.blue, fontSize: 13),
              ),
            ),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();

        final replies = snapshot.data!.docs;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 60, bottom: 4),
              child: GestureDetector(
                onTap: toggleReplies,
                child: const Text(
                  "Hide replies",
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ),
            ...replies.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final username = data['username'] ?? 'User';
              final text = data['text'] ?? '';
              final isReplyOwner = data['userId'] == currentUser?.uid;

              return Padding(
                padding: const EdgeInsets.only(left: 60, right: 16, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundImage: AssetImage(
                        'assets/profile_placeholder.png',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isReplyOwner || widget.isOwner)
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (_) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              title: const Text(
                                                'Delete Reply',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await FirebaseFirestore.instance
                                                    .collection('posts')
                                                    .doc(widget.post.id)
                                                    .collection('comments')
                                                    .doc(commentId)
                                                    .collection('replies')
                                                    .doc(doc.id)
                                                    .delete();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          Text(text),
                          if (createdAt != null)
                            Text(
                              timeago.format(createdAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _submitReply(
    String commentId,
    TextEditingController replyController,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || replyController.text.trim().isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final username = userDoc['username'] ?? 'User';

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
          'userId': user.uid,
          'username': username,
          'text': replyController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

    replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Post Details', style: TextStyle(color: textColor)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.post.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final data =
                            snapshot.data?.data() as Map<String, dynamic>?;
                        final base64Image = data?['profileImageBase64'] ?? '';
                        final username = data?['username'] ?? 'User';

                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: base64Image.isNotEmpty
                                  ? MemoryImage(base64Decode(base64Image))
                                  : const AssetImage(
                                          'assets/profile_placeholder.png',
                                        )
                                        as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              username,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (widget.post.imageBase64.isNotEmpty)
                    Image.memory(
                      base64Decode(widget.post.imageBase64),
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.description,
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatTimestamp(widget.post.createdAt),
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
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
                          final createdAt = (data['createdAt'] as Timestamp?)
                              ?.toDate();
                          final isCommentOwner =
                              data['userId'] == currentUser?.uid;
                          final replyController = TextEditingController();
                          bool showReplyField = false;
                          bool showReplies = false;

                          return StatefulBuilder(
                            builder: (context, setInnerState) =>
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(data['userId'])
                                      .snapshots(),
                                  builder: (context, userSnapshot) {
                                    final userData =
                                        userSnapshot.data?.data()
                                            as Map<String, dynamic>?;
                                    final profileBase64 =
                                        userData?['profileImageBase64'] ?? '';
                                    final username =
                                        userData?['username'] ?? 'User';

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                          title: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 14,
                                                backgroundImage:
                                                    profileBase64.isNotEmpty
                                                    ? MemoryImage(
                                                        base64Decode(
                                                          profileBase64,
                                                        ),
                                                      )
                                                    : const AssetImage(
                                                            'assets/profile_placeholder.png',
                                                          )
                                                          as ImageProvider,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      username,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      data['text'] ?? '',
                                                      style: TextStyle(
                                                        color: textColor,
                                                      ),
                                                    ),
                                                    if (createdAt != null)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                            ),
                                                        child: Text(
                                                          timeago.format(
                                                            createdAt,
                                                          ),
                                                          style: TextStyle(
                                                            color: textColor
                                                                .withOpacity(
                                                                  0.6,
                                                                ),
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                    GestureDetector(
                                                      onTap: () => setInnerState(
                                                        () => showReplyField =
                                                            !showReplyField,
                                                      ),
                                                      child: const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                              top: 4,
                                                            ),
                                                        child: Text(
                                                          'Reply',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.blue,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          trailing:
                                              (isCommentOwner || widget.isOwner)
                                              ? IconButton(
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: textColor
                                                        .withOpacity(0.5),
                                                  ),
                                                  onPressed: () =>
                                                      _showCommentOptions(
                                                        doc.id,
                                                      ),
                                                )
                                              : null,
                                        ),

                                        if (showReplyField)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 60,
                                              right: 16,
                                              bottom: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: replyController,
                                                    minLines: 1,
                                                    maxLines: null,
                                                    keyboardType:
                                                        TextInputType.multiline,
                                                    style: TextStyle(
                                                      color: textColor,
                                                    ),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Write a reply...',
                                                      hintStyle: TextStyle(
                                                        color: textColor
                                                            .withOpacity(0.7),
                                                      ),
                                                      filled: true,
                                                      fillColor: cardColor,
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        borderSide:
                                                            BorderSide.none,
                                                      ),
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.send),
                                                  onPressed: () => _submitReply(
                                                    doc.id,
                                                    replyController,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        _buildReplies(
                                          doc.id,
                                          showReplies,
                                          () => setInnerState(
                                            () => showReplies = !showReplies,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
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
                  child: TextFormField(
                    controller: _commentController,
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.7)),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onFieldSubmitted: (_) => _addComment(),
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
