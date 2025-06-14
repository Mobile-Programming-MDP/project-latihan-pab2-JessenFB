import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String username;
  final String description;
  final String imageBase64;
  final String location;
  final String? category;
  final DateTime createdAt;
  final int likes;
  final double? lat;
  final double? lng;
  bool saved; // Added field to track if the post is saved

  Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.description,
    required this.imageBase64,
    required this.location,
    required this.createdAt,
    required this.likes,
    this.category,
    this.lat,
    this.lng,
    this.saved = false, // Default value for saved is false
  });

  factory Post.fromMap(String id, Map<String, dynamic> data) {
    return Post(
      id: id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? data['fullName'] ?? 'Unknown',
      description: data['description'] ?? '',
      imageBase64: data['image'] ?? '',
      location: data['location'] ?? '',
      category: data['category'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      lat: (data['lat'] ?? data['latitude']) is num
          ? (data['lat'] ?? data['latitude']).toDouble()
          : null,
      lng: (data['lng'] ?? data['longitude']) is num
          ? (data['lng'] ?? data['longitude']).toDouble()
          : null,
      saved: data['saved'] ?? false, // Add saved as a field, default is false
    );
  }
}
