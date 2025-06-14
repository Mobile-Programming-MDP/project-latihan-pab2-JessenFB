import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/screens/navigation_bar.dart';
import 'package:go_to_gym/screens/other_user_profile_screen.dart';
import 'package:go_to_gym/screens/user_post_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String currentUserId = '';

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Widget _buildUserTile(DocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    if (!data.containsKey('username')) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading:
          data['profileImageBase64'] != null &&
              data['profileImageBase64'].toString().isNotEmpty
          ? CircleAvatar(
              backgroundImage: MemoryImage(
                base64Decode(data['profileImageBase64']),
              ),
            )
          : const CircleAvatar(child: Icon(Icons.person)),
      title: Text(
        data['username'],
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherUserProfileScreen(
              userId: userDoc.id,
              username: data['username'],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data.containsKey('image') && data['image'] != null;
        }).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;
            final imageBase64 = data['image'];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserPostListScreen(
                      userId: data['userId'],
                      username: data['username'] ?? 'User',
                      initialPostId: post.id,
                    ),
                  ),
                );
              },
              child: imageBase64 != null && imageBase64.isNotEmpty
                  ? Image.memory(
                      base64Decode(imageBase64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, color: Colors.black45),
                    ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search user',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.grey.withOpacity(0.75),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white30 : Colors.black38,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _query.isNotEmpty
              ? Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .orderBy('username')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final username = (data['username'] ?? '')
                            .toString()
                            .toLowerCase();
                        return doc.id != currentUserId &&
                            username.contains(_query);
                      }).toList();

                      if (users.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No matching users found',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: users.length,
                        itemBuilder: (context, index) =>
                            _buildUserTile(users[index]),
                        separatorBuilder: (_, __) => Divider(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      );
                    },
                  ),
                )
              : Expanded(child: _buildPostGrid()),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
    );
  }
}
