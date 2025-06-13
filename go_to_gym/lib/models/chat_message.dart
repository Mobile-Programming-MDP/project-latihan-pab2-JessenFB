import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String sender;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'sender': sender,
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['timestamp'];
    final timestamp = raw is Timestamp
        ? raw.toDate()
        : DateTime.tryParse(raw.toString()) ?? DateTime.now();

    return ChatMessage(
      sender: json['sender'] ?? 'unknown',
      content: json['content'] ?? '',
      timestamp: timestamp,
    );
  }
}
