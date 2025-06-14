import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_to_gym/screens/navigation_bar.dart';
import 'package:go_to_gym/screens/setting_screen.dart';
import 'package:go_to_gym/screens/user_post_list_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  String username = '';
  String? base64ProfileImage;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (currentUser == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    if (snapshot.exists && mounted) {
      final data = snapshot.data()!;
      setState(() {
        username = data['username'] ?? currentUser!.email ?? 'Anonymous';
        base64ProfileImage = data['profileImageBase64'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileBgColor =
        isDark ? const Color(0xFF334155) : Colors.grey.shade400;

    Uint8List? profileBytes;
    if (base64ProfileImage != null && base64ProfileImage!.isNotEmpty) {
      try {
        profileBytes = base64Decode(base64ProfileImage!);
      } catch (_) {
        profileBytes = null;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text('Profile',
            style: Theme.of(context).appBarTheme.titleTextStyle),
        iconTheme: Theme.of(context).iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: profileBgColor,
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: profileBytes != null
                        ? MemoryImage(profileBytes)
                        : null,
                    backgroundColor:
                        Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                    child: profileBytes == null
                        ? Icon(Icons.person,
                            size: 40,
                            color: Theme.of(context)
                                .iconTheme
                                .color
                                ?.withOpacity(0.7))
                        : null,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Posts', 'posts'),
                      _buildStat('Followers', 'followers'),
                      _buildStat('Following', 'following'),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                username.isNotEmpty ? username : 'Loading...',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                  ).then((_) => fetchUserData());
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.grey.withOpacity(0.75),
                  side: BorderSide.none,
                  foregroundColor:
                      Theme.of(context).textTheme.bodyMedium?.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor),
          _buildUserPosts(),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildStat(String label, String type) {
    final query = type == 'posts'
        ? FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: currentUser?.uid)
        : FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser?.uid)
            .collection(type);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _ProfileStat(count: '$count', label: label);
      },
    );
  }

  Widget _buildUserPosts() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Text(
                'No posts yet',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white54),
              ),
            );
          }

          final sortedPosts = posts.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('createdAt') && data['createdAt'] != null;
          }).toList()
            ..sort((a, b) {
              final aTime = (a['createdAt'] as Timestamp).toDate();
              final bTime = (b['createdAt'] as Timestamp).toDate();
              return bTime.compareTo(aTime);
            });

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            itemCount: sortedPosts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final post = sortedPosts[index];
              final data = post.data() as Map<String, dynamic>;
              final imageBase64 = data['image'];
              final userId = data['userId'];
              final username = data['username'];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserPostListScreen(
                        userId: userId,
                        username: username,
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.1),
                        child: Icon(
                          Icons.image,
                          color: Theme.of(context)
                              .iconTheme
                              .color
                              ?.withOpacity(0.3),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String count;
  final String label;

  const _ProfileStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
