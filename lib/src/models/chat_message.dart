class ChatMessage {
  final String content;
  final String? senderId;
  final String? senderName;
  final String? chatId;
  final DateTime timestamp;
  final Map<String, dynamic> raw;

  ChatMessage({
    required this.content,
    this.senderId,
    this.senderName,
    this.chatId,
    required this.timestamp,
    required this.raw,
  });

  /// Returns true if this is a group chat message (has a chatId).
  bool get isGroup => chatId != null;

  /// Returns true if this is a p2p/direct message (no chatId).
  bool get isP2P => chatId == null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Check if payload exists (nodmac usually sends flat or nested)
    final sender = json['sender'] as Map<String, dynamic>?;
    return ChatMessage(
      content: json['content'] ?? '',
      senderId: sender != null ? sender['id']?.toString() : json['senderId']?.toString(),
      senderName: sender != null ? sender['username'] : null,
      chatId: json['chatId']?.toString(),
      timestamp: DateTime.tryParse(json['createdAt'] ?? json['timestamp'] ?? '') ?? DateTime.now(),
      raw: json,
    );
  }
}
