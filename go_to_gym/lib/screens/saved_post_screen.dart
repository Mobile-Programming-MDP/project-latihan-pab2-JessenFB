import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/models/post.dart';
import 'package:go_to_gym/screens/user_post_list_screen.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text('Please log in to see saved posts'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Posts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('savedPosts')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedPosts = snapshot.data!.docs;
          if (savedPosts.isEmpty) {
            return const Center(child: Text('No saved posts yet.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 posts per row
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: savedPosts.length,
            itemBuilder: (context, index) {
              final postId = savedPosts[index].id;
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .snapshots(),
                builder: (context, postSnapshot) {
                  if (!postSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final postData = postSnapshot.data!.data() as Map<String, dynamic>;
                  final post = Post.fromMap(postId, postData);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserPostListScreen(
                            userId: post.userId,
                            username: post.username,
                            initialPostId: postId,
                          ),
                        ),
                      );
                    },
                    child: Image.memory(
                      base64Decode(post.imageBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
