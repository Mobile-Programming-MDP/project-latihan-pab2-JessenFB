import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatHistoryService {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatHistoryService(this.userId);

  Future<void> saveMessage(ChatMessage message) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .add(message.toJson());
  }

  Future<List<ChatMessage>> getMessages() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .orderBy('timestamp')
        .get();

    return snapshot.docs.map((doc) {
      try {
        return ChatMessage.fromJson(doc.data());
      } catch (_) {
        return null;
      }
    }).whereType<ChatMessage>().toList();
  }

  Future<void> clearHistory() async {
    final batch = _firestore.batch();
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .get();

    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
