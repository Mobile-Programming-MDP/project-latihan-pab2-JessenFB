import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_to_gym/screens/user_post_list_screen.dart';



Future<void> sendNotificationToUser(String token, String title, String body) async {
  const String backendUrl = 'https://uas-cloud-six.vercel.app/send-to-device';

  try {
    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode != 200) {
      print("Failed to send notification: \${response.body}");
    }
  } catch (e) {
    print("Error sending notification: \$e");
  }
}


class OtherUserProfileScreen extends StatelessWidget {
  final String userId;
  final String username;

  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(username, style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final userData =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    if (userData != null &&
                        userData['profileImageBase64'] != null &&
                        userData['profileImageBase64'].toString().isNotEmpty) {
                      return CircleAvatar(
                        radius: 40,
                        backgroundImage: MemoryImage(
                            base64Decode(userData['profileImageBase64'])),
                      );
                    }
                    return const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFF334155),
                      child: Icon(Icons.person,
                          size: 40, color: Colors.white70),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Text(
                          username,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .where('userId', isEqualTo: userId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _ProfileStat(
                                count: '$count',
                                label: 'Posts',
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('followers')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _ProfileStat(
                                count: '$count',
                                label: 'Followers',
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('following')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _ProfileStat(
                                count: '$count',
                                label: 'Following',
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('followers')
                            .doc(currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          final isFollowing = snapshot.data?.exists ?? false;
                          if (currentUser?.uid == userId)
                            return const SizedBox();
                          return Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                final token = doc.data()?['fcmToken'];
                if (token != null) {
                  await sendNotificationToUser(token, "Kamu punya follower baru!", "Seseorang mulai mengikuti kamu.");
                }
                                  final followingRef = FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(currentUser?.uid)
                                      .collection('following')
                                      .doc(userId);
                                  final followersRef = FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('followers')
                                      .doc(currentUser?.uid);

                                  if (isFollowing) {
                                    await followingRef.delete();
                                    await followersRef.delete();
                                  } else {
                                    await followingRef.set({});
                                    await followersRef.set({});
                                  }
                                },
                                icon: Icon(
                                  isFollowing
                                      ? Icons.person_remove
                                      : Icons.person_add,
                                  size: 16,
                                ),
                                label: Text(
                                  isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing
                                      ? Colors.grey.shade700
                                      : Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Message',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No posts yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                final posts = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(2),
                  itemCount: posts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemBuilder: (context, index) {
                    final data = posts[index].data() as Map<String, dynamic>;
                    final base64Image = data['image'] ?? '';
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserPostListScreen(
                              userId: userId,
                              username: username,
                              initialPostId: posts[index].id,
                            ),
                          ),
                        );
                      },
                      child: base64Image.isNotEmpty
                          ? Image.memory(
                              base64Decode(base64Image),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            )
                          : Container(
                              color: const Color(0xFF334155),
                              child: const Icon(
                                Icons.image,
                                color: Colors.white30,
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
