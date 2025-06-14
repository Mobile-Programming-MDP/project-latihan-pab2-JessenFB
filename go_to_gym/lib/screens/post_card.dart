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

  Future<void> _toggleSavePost(String postId, String userId) async {
    final savedPostsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('savedPosts');

    final savedPostRef = savedPostsRef.doc(postId);
    final savedPostSnap = await savedPostRef.get();

    if (savedPostSnap.exists) {
      await savedPostRef.delete();
      setState(() {
        widget.post.saved = false;
      });
    } else {
      await savedPostRef.set({'savedAt': FieldValue.serverTimestamp()});
      setState(() {
        widget.post.saved = true;
      });
    }
  }

  Widget _buildFollowButton(String currentUserId, String targetUserId, Color textColor) {
    if (currentUserId == targetUserId) return const SizedBox.shrink();

    final followDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    return StreamBuilder<DocumentSnapshot>(
      stream: followDocRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final isFollowing = snapshot.data?.exists ?? false;

        return ElevatedButton.icon(
          onPressed: () async {
            await FollowService.toggleFollow(currentUserId, targetUserId);
          },
          icon: Icon(
            isFollowing ? Icons.person_remove : Icons.person_add,
            size: 16,
            color: Colors.white,
          ),
          label: Text(
            isFollowing ? 'Following' : 'Follow',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing
                ? Colors.grey.shade700
                : Colors.blueAccent,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? '';
    final isSelf = userId == widget.post.userId;

    final mainTextColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black;
    final fadedTextColor = isDark ? Colors.white38 : Colors.black54;
    final iconColor = isDark ? Colors.white70 : Colors.black;

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
        .snapshots()
        .asyncMap((snapshot) async {
          int totalCount = snapshot.docs.length;
          for (var doc in snapshot.docs) {
            final repliesSnap = await doc.reference.collection('replies').get();
            totalCount += repliesSnap.docs.length;
          }
          return totalCount;
        });

    final savedPostStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(widget.post.id)
        .snapshots();

    final combinedStream = Rx.combineLatest3(
      likeStatusStream,
      likeCountStream,
      commentCountStream,
      (
        DocumentSnapshot likeDoc,
        DocumentSnapshot postDoc,
        int commentCount,
      ) {
        final isLiked = likeDoc.exists;
        final likeCount =
            (postDoc.data() as Map?)?['likes'] ?? widget.post.likes;
        return PostSnapshotData(isLiked, likeCount, commentCount);
      },
    );

    return StreamBuilder<PostSnapshotData>(
      stream: combinedStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final data = snapshot.data!;
        final isLiked = data.isLiked;
        final likeCount = data.likeCount;
        final commentCount = data.commentCount;

        return StreamBuilder<DocumentSnapshot>(
          stream: savedPostStream,
          builder: (context, savedSnapshot) {
            bool isSaved = savedSnapshot.data?.exists ?? false;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.post.userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final userData = snapshot.data?.data() as Map<String, dynamic>?;
                    final username = userData?['username'] ?? widget.post.username;
                    final profileBase64 = userData?['profileImageBase64'] ?? '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      leading: profileBase64.isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: MemoryImage(
                                base64Decode(profileBase64),
                              ),
                            )
                          : const CircleAvatar(child: Icon(Icons.person)),
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
                          style: TextStyle(
                            color: mainTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      trailing: isSelf
                          ? IconButton(
                              icon: Icon(Icons.more_vert, color: iconColor),
                              onPressed: () => widget.onShowOptions(context, widget.post),
                            )
                          : _buildFollowButton(
                              userId,
                              widget.post.userId,
                              mainTextColor,
                            ),
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
                        errorBuilder: (context, error, stackTrace) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Image failed to load',
                            style: TextStyle(color: fadedTextColor),
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
                          color: isLiked ? Colors.redAccent : iconColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$likeCount', style: TextStyle(color: mainTextColor)),
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
                            Icon(Icons.mode_comment_outlined, color: iconColor),
                            const SizedBox(width: 4),
                            Text(
                              '$commentCount',
                              style: TextStyle(color: mainTextColor, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _toggleSavePost(widget.post.id, userId),
                        child: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.blue : iconColor,
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
                    style: TextStyle(color: subTextColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    formatTimestamp(widget.post.createdAt),
                    style: TextStyle(
                      color: isDark ? Colors.white38 : const Color.fromARGB(202, 0, 0, 0),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
