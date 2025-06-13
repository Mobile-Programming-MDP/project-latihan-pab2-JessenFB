import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/models/post.dart';
import 'package:go_to_gym/screens/profile_screen.dart';
import 'package:go_to_gym/screens/other_user_profile_screen.dart';
import 'package:go_to_gym/screens/post_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_to_gym/services/follow_service.dart';
import 'package:rxdart/rxdart.dart';

class PostSnapshotData {
  final bool isLiked;
  final int likeCount;
  final int commentCount;

  PostSnapshotData(this.isLiked, this.likeCount, this.commentCount);
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


class PostCard extends StatefulWidget {
  final Post post;
  final bool isOwner;
  final void Function(String postId) onDoubleTap;
  final bool showHeart;
  final void Function(BuildContext, Post) onShowOptions;

  const PostCard({
    super.key,
    required this.post,
    required this.isOwner,
    required this.onDoubleTap,
    required this.showHeart,
    required this.onShowOptions,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 365) {
      return DateFormat('MMM dd, yyyy').format(date);
    } else {
      return timeago.format(date);
    }
  }

  Future<void> _toggleLike(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final likeSnap = await likeRef.get();

    if (likeSnap.exists) {
      await likeRef.delete();
      await postRef.update({'likes': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      await postRef.update({'likes': FieldValue.increment(1)});
    }
  }

  void _showPostOptions(BuildContext context) {
    widget.onShowOptions(context, widget.post);
  }

  Widget _buildFollowButton(String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) return const SizedBox.shrink();

    final followDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    return StreamBuilder<DocumentSnapshot>(
      stream: followDocRef.snapshots(),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data?.exists ?? false;

        return ElevatedButton.icon(
          onPressed: () async {
            await FollowService.toggleFollow(currentUserId, targetUserId);
          },
          icon: Icon(
            isFollowing ? Icons.person_remove : Icons.person_add,
            size: 16,
          ),
          label: Text(
            isFollowing ? 'Following' : 'Follow',
            style: const TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isFollowing ? Colors.grey.shade700 : Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? '';
    final isSelf = userId == widget.post.userId;

    final likeStatusStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('likes')
        .doc(userId)
        .snapshots();

    final likeCountStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .snapshots();

    final commentCountStream = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .snapshots();

    final Stream<PostSnapshotData> combinedStream = Rx.combineLatest3(
      likeStatusStream,
      likeCountStream,
      commentCountStream,
      (DocumentSnapshot likeDoc, DocumentSnapshot postDoc, QuerySnapshot commentsSnap) {
        final isLiked = likeDoc.exists;
        final likeCount = (postDoc.data() as Map?)?['likes'] ?? widget.post.likes;
        final commentCount = commentsSnap.docs.length;
        return PostSnapshotData(isLiked, likeCount, commentCount);
      },
    );

    return StreamBuilder<PostSnapshotData>(
      stream: combinedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final isLiked = data.isLiked;
        final likeCount = data.likeCount;
        final commentCount = data.commentCount;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  post: widget.post,
                  isOwner: widget.isOwner,
                ),
              ),
            );
          },
          onDoubleTap: () async {
    await sendPostNotification("Seseorang menyukai postinganmu!", "Postinganmu mendapatkan like baru.");

            _toggleLike(widget.post.id, userId);
            widget.onDoubleTap(widget.post.id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.post.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final username = data?['username'] ?? widget.post.username;
                  final profileBase64 = data?['profileImageBase64'] ?? '';

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    leading: profileBase64.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage:
                                MemoryImage(base64Decode(profileBase64)),
                          )
                        : const CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/profile_placeholder.png'),
                          ),
                    title: GestureDetector(
                      onTap: () {
                        if (widget.isOwner) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OtherUserProfileScreen(
                                userId: widget.post.userId,
                                username: username,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        username,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    trailing: isSelf
                        ? IconButton(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white70),
                            onPressed: () => _showPostOptions(context),
                          )
                        : _buildFollowButton(userId, widget.post.userId),
                  );
                },
              ),
              if (widget.post.imageBase64.isNotEmpty)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.memory(
                      base64Decode(widget.post.imageBase64),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Image failed to load',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: widget.showHeart ? 1 : 0,
                      child: const Icon(
                        Icons.favorite,
                        size: 100,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(widget.post.id, userId),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.redAccent : Colors.white30,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$likeCount',
                        style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              post: widget.post,
                              isOwner: widget.isOwner,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mode_comment_outlined,
                            color: Color.fromARGB(77, 255, 255, 255),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$commentCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.post.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  formatTimestamp(widget.post.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}