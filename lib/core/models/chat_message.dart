import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String senderId;
  final String senderName;
  final String message;
  final String type; // 'text' | 'image' | 'video'
  final String? mediaUrl;
  final Timestamp sentAt;

  ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.message,
    this.type = 'text',
    this.mediaUrl,
    Timestamp? sentAt,
  }) : sentAt = sentAt ?? Timestamp.now();

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'message': message,
      'type': type,
      'mediaUrl': mediaUrl,
      'sentAt': sentAt,
    };
  }

  factory ChatMessage.fromSnapshot(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawSenderName = (data['senderName'] ?? '').toString().trim();

    return ChatMessage(
      senderId: (data['senderId'] ?? '').toString(),
      senderName: rawSenderName.isNotEmpty ? rawSenderName : 'Rescuer',
      message: (data['message'] ?? '').toString(),
      type: (data['type'] ?? 'text').toString(),
      mediaUrl: data['mediaUrl'] as String?,
      sentAt: data['sentAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
