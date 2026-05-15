class TypingEvent {
  final bool isTyping;
  final String? userId;
  final String? chatId;
  final Map<String, dynamic> raw;

  TypingEvent({
    required this.isTyping,
    this.userId,
    this.chatId,
    required this.raw,
  });

  factory TypingEvent.fromJson(Map<String, dynamic> json) {
    return TypingEvent(
      // In nodmac, type: 'typingResponse' means isTyping=true, type: 'stopTyping' means isTyping=false
      isTyping: json['type'] == 'typingResponse' || (json['isTyping'] ?? false),
      userId: json['userId']?.toString() ?? json['sender_id']?.toString(),
      chatId: json['chatId']?.toString(),
      raw: json,
    );
  }
}
