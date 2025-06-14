import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_to_gym/main.dart';
import 'package:go_to_gym/screens/signin_screen.dart';
import 'package:go_to_gym/utils/theme_storage.dart';
import 'package:go_to_gym/screens/saved_post_screen.dart'; 

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool isDarkMode = themeNotifier.value == ThemeMode.dark;

  void _toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
      final selectedMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      themeNotifier.value = selectedMode;
      ThemeStorage.saveThemeMode(selectedMode);
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notifications'),
        content: const Text('Notification settings will be available soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _forgotPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset link sent to your email.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to delete this account and all your data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // Delete user subcollections
      for (final sub in ['followers', 'following', 'chat_history']) {
        final subDocs = await firestore.collection('users').doc(uid).collection(sub).get();
        for (var doc in subDocs.docs) {
          await doc.reference.delete();
        }
      }

      final posts = await firestore.collection('posts').where('userId', isEqualTo: uid).get();
      for (var post in posts.docs) {
        final comments = await post.reference.collection('comments').get();
        for (var c in comments.docs) {
          await c.reference.delete();
        }

        final likes = await post.reference.collection('likes').get();
        for (var l in likes.docs) {
          await l.reference.delete();
        }

        await post.reference.delete();
      }

      final allPosts = await firestore.collection('posts').get();
      for (var post in allPosts.docs) {
        final likeRef = post.reference.collection('likes').doc(uid);
        final likeDoc = await likeRef.get();
        if (likeDoc.exists) {
          await likeRef.delete();
          final currentLikes = post['likes'] ?? 0;
          await post.reference.update({'likes': (currentLikes > 0) ? currentLikes - 1 : 0});
        }

        final commentQuery = await post.reference.collection('comments').where('userId', isEqualTo: uid).get();
        for (var comment in commentQuery.docs) {
          await comment.reference.delete();
        }
      }

      await firestore.collection('users').doc(uid).delete();
      await user.delete();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final iconColor = Theme.of(context).iconTheme.color;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: ListView(
        children: [
          // 🔁 DARK MODE
          SwitchListTile(
            title: Text('Dark Mode', style: textStyle),
            value: isDarkMode,
            onChanged: _toggleTheme,
          ),

          // ✅ SAVED POSTS — tambahan di sini
          ListTile(
            leading: Icon(Icons.bookmark, color: iconColor),
            title: Text('Saved Posts', style: textStyle),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedPostsScreen()),
              );
            },
          ),

          // 🔔 NOTIFICATIONS
          ListTile(
            leading: Icon(Icons.notifications, color: iconColor),
            title: Text('Notifications', style: textStyle),
            onTap: _showNotificationSettings,
          ),

          // 🔒 FORGOT PASSWORD
          ListTile(
            leading: Icon(Icons.lock_reset, color: iconColor),
            title: Text('Forgot Password', style: textStyle),
            onTap: _forgotPassword,
          ),

          // 🚪 LOGOUT
          ListTile(
            leading: Icon(Icons.logout, color: errorColor),
            title: Text(
              'Log Out',
              style: textStyle?.copyWith(color: errorColor),
            ),
            onTap: _signOut,
          ),

          // 🗑️ DELETE ACCOUNT
          ListTile(
            leading: Icon(Icons.delete, color: errorColor),
            title: Text(
              'Delete Account',
              style: textStyle?.copyWith(color: errorColor),
            ),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
