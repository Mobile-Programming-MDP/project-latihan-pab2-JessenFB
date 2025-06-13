import 'dart:convert';
import 'dart:typed_data';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text(
              'Edit Post',
              style: TextStyle(color: Colors.white),
            ),
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
            title: const Text(
              'Delete Post',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(post.id)
                  .delete();
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
              .map(
                (doc) =>
                    Post.fromMap(doc.id, doc.data() as Map<String, dynamic>),
              )
              .where((post) => followedIds.contains(post.userId))
              .toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Center(child: Text("Please sign in"));

    final userId = currentUser.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6), // 👇 Move logo downward
              child: Image.asset('assets/logo.png', width: 50, height: 50),
            ),
            const SizedBox(width: 6),
            const Text(
              'FitMedia',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _getFollowedPosts(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!;

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
      bottomNavigationBar: CustomBottomNavBar(currentIndex: 0),
    );
  }
}
