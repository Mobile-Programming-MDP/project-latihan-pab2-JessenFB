import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/screens/post_card.dart';
import 'package:intl/intl.dart';
import 'package:go_to_gym/screens/edit_post_screen.dart';
import 'package:go_to_gym/models/post.dart';

class UserPostListScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String initialPostId;

  const UserPostListScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.initialPostId,
  });

  @override
  State<UserPostListScreen> createState() => _UserPostListScreenState();
}

class _UserPostListScreenState extends State<UserPostListScreen>
    with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  final _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String animatingPostId = '';
  bool scrolledToInitial = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _toggleLike(String postId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

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
          animatingPostId = postId;
          _animationController.forward(from: 0);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update like.", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPostOptions(BuildContext context, String postId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final post = Post.fromMap(postId, data);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: textColor),
            title: Text('Edit', style: TextStyle(color: textColor)),
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
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final appBarColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0);

    final uid = currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text("User not signed in", style: TextStyle(color: textColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Text(
              "Posts",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.blue,
              ),
            );
          }

          final posts = snapshot.data!.docs;
          final index = posts.indexWhere((doc) => doc.id == widget.initialPostId);
          if (index >= 0 && !scrolledToInitial) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  index * 330.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
            scrolledToInitial = true;
          }

          return ListView.builder(
            controller: _scrollController,
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final doc = posts[index];
              final data = doc.data() as Map<String, dynamic>;
              final postId = doc.id;
              final isOwner = uid == data['userId'];

              return PostCard(
                post: Post.fromMap(postId, data),
                isOwner: isOwner,
                showHeart: animatingPostId == postId,
                onDoubleTap: (id) {
                  _toggleLike(id);
                  setState(() => animatingPostId = id);
                  _animationController.forward(from: 0);
                },
                onShowOptions: (context, post) {
                  _showPostOptions(context, post.id, {
                    'image': post.imageBase64,
                    'description': post.description,
                    'createdAt': Timestamp.fromDate(post.createdAt),
                    'userId': post.userId,
                    'likes': post.likes,
                    'username': post.username,
                    'location': post.location,
                    'category': post.category,
                    'lat': post.lat,
                    'lng': post.lng,
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}
