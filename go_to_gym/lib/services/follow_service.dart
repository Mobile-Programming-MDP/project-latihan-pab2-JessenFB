import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  static Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);

    final followerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);

    final isFollowing = await followingRef.get().then((doc) => doc.exists);

    if (isFollowing) {
      await followingRef.delete();
      await followerRef.delete();
    } else {
      final timestamp = FieldValue.serverTimestamp();
      await followingRef.set({'followedAt': timestamp});
      await followerRef.set({'followedAt': timestamp});
    }
  }

  static Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final followingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);
    return followingRef.get().then((doc) => doc.exists);
  }
}
