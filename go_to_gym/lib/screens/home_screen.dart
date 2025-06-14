import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_to_gym/models/post.dart';
import 'package:go_to_gym/screens/post_card.dart';
import 'package:go_to_gym/screens/signin_screen.dart';
import 'package:go_to_gym/screens/edit_post_screen.dart';
import 'package:go_to_gym/screens/navigation_bar.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, bool> _showHeart = {};

  Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  Future<void> _toggleLike(String postId, String userId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postSnap = await transaction.get(postRef);
        final likeSnap = await transaction.get(likeRef);
        final currentLikes = (postSnap.data()?['likes'] ?? 0) as int;

        if (likeSnap.exists) {
          transaction.delete(likeRef);
          transaction.update(postRef, {
            'likes': currentLikes > 0 ? currentLikes - 1 : 0,
          });
        } else {
          transaction.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'likes': currentLikes + 1});
        }
      });
    } catch (e) {
      debugPrint('Like error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _triggerHeart(String postId) {
    setState(() => _showHeart[postId] = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showHeart[postId] = false);
      }
    });
  }

  String formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 365) {
      return DateFormat('MMM dd, yyyy').format(date);
    } else {
      return timeago.format(date);
    }
  }

  void _showPostOptions(BuildContext context, Post post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
            title: Text('Edit Post', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('posts').doc(post.id).delete();
            },
          ),
        ],
      ),
    );
  }

  Stream<List<Post>> _getFollowedPosts(String userId) async* {
    final followingSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('following')
        .get();

    final followedIds = followingSnapshot.docs.map((doc) => doc.id).toList();
    followedIds.add(userId); // Include own posts

    yield* FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Post.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .where((post) => followedIds.contains(post.userId))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: const Center(child: Text("Please sign in")),
      );
    }

    final userId = currentUser.uid;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 16),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Image.asset(
                      'assets/new_logo.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'FitMedia',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                  onPressed: () {
                    // TODO: Navigate to notifications screen
                  },
                  tooltip: 'Notifikasi',
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _getFollowedPosts(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.blue,
              ),
            );
          }

          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'No posts yet.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final isOwner = post.userId == userId;

              return PostCard(
                post: post,
                isOwner: isOwner,
                showHeart: _showHeart[post.id] ?? false,
                onDoubleTap: _triggerHeart,
                onShowOptions: _showPostOptions,
              );
            },
          );
        },
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }
}
