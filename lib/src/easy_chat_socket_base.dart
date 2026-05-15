import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'models/chat_socket_status.dart';
import 'models/chat_message.dart';
import 'models/typing_event.dart';

/// A comprehensive WebSocket abstraction for real-time chat applications.
///
/// Features auto-reconnection, heartbeat, and event-driven messaging.
class EasyChatSocket {
  /// The WebSocket URL.
  final Uri uri;

  /// Optional protocols for the WebSocket connection.
  final Iterable<String>? protocols;

  /// Connection timeout duration.
  final Duration connectTimeout;

  /// Interval between heartbeat pings.
  final Duration heartbeatInterval;

  /// The payload to send for heartbeat pings.
  final dynamic pingPayload;

  /// Maximum number of reconnection attempts before giving up.
  /// Set to null for infinite retries.
  final int? maxRetries;

  /// Base delay for exponential backoff.
  final Duration initialRetryDelay;

  /// Maximum delay for exponential backoff.
  final Duration maxRetryDelay;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  final _statusController = StreamController<ChatSocketStatus>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  int _retryCount = 0;
  bool _isManuallyClosed = false;
  ChatSocketStatus _currentStatus = ChatSocketStatus.disconnected;

  /// Stream of connection status updates.
  Stream<ChatSocketStatus> get statusStream => _statusController.stream;

  /// Stream of incoming messages.
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Stream of filtered chat messages.
  Stream<Map<String, dynamic>> get onMessage => messageStream
      .where((event) => event is Map && (event['type'] == 'messageReceived' || event['type'] == 'newMessage'))
      .cast<Map<String, dynamic>>();

  /// Stream of typing indicators (someone started typing).
  Stream<Map<String, dynamic>> get onTyping => messageStream
      .where((event) => event is Map && event['type'] == 'typingResponse')
      .cast<Map<String, dynamic>>();

  /// Stream of typing indicators (someone stopped typing).
  Stream<Map<String, dynamic>> get onStopTyping => messageStream
      .where((event) => event is Map && event['type'] == 'stopTyping')
      .cast<Map<String, dynamic>>();

  /// Stream of read receipts.
  Stream<Map<String, dynamic>> get onReadReceipt => messageStream
      .where((event) => event is Map && event['type'] == 'messageRead')
      .cast<Map<String, dynamic>>();

  /// Stream of strongly-typed chat messages.
  Stream<ChatMessage> get onChatMessage => onMessage.map(ChatMessage.fromJson);

  /// Stream of strongly-typed typing events (combined typingResponse and stopTyping).
  Stream<TypingEvent> get onTypingEvent => messageStream
      .where((event) => event is Map && (event['type'] == 'typingResponse' || event['type'] == 'stopTyping'))
      .map((event) => TypingEvent.fromJson(event as Map<String, dynamic>));

  /// Returns a stream of messages filtered by a specific conversation (Chat ID or User ID).
  Stream<ChatMessage> inConversation(String id) =>
      onChatMessage.where((msg) => msg.chatId == id || msg.senderId == id);

  /// Current connection status.
  ChatSocketStatus get status => _currentStatus;

  /// Optional JWT token for authentication.
  final String? token;

  EasyChatSocket({
    required this.uri,
    this.token,
    this.protocols,
    this.connectTimeout = const Duration(seconds: 10),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.pingPayload = 'ping',
    this.maxRetries,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 60),
  });

  /// Initializes the connection.
  Future<void> connect() async {
    if (_currentStatus == ChatSocketStatus.connected ||
        _currentStatus == ChatSocketStatus.connecting) {
      return;
    }

    _isManuallyClosed = false;
    await _establishConnection();
  }

  Future<void> _establishConnection() async {
    _updateStatus(ChatSocketStatus.connecting);

    try {
      dev.log('Connecting to $uri...', name: 'EasyChatSocket');
      
      _channel = WebSocketChannel.connect(uri, protocols: protocols);

      // Wait for the connection to be established or timeout
      // Note: web_socket_channel doesn't have a built-in 'onConnected' future easily accessible
      // without listening to the stream.
      
      _channelSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onConnectionClosed,
        onError: _onConnectionError,
        cancelOnError: false,
      );

      _updateStatus(ChatSocketStatus.connected);
      _retryCount = 0;
      _startHeartbeat();
      
      dev.log('Connected to $uri', name: 'EasyChatSocket');
    } catch (e, stack) {
      dev.log('Connection failed: $e', name: 'EasyChatSocket', error: e, stackTrace: stack);
      _onConnectionError(e);
    }
  }

  void _onMessageReceived(dynamic message) {
    dev.log('Received message: $message', name: 'EasyChatSocket');
    
    dynamic decodedMessage = message;
    if (message is String) {
      try {
        decodedMessage = jsonDecode(message);
      } catch (_) {
        // Not a JSON string, keep as is
      }
    }
    
    _messageController.add(decodedMessage);
  }

  void _onConnectionClosed() {
    dev.log('Connection closed', name: 'EasyChatSocket');
    _stopHeartbeat();
    _updateStatus(ChatSocketStatus.disconnected);

    if (!_isManuallyClosed) {
      _scheduleReconnection();
    }
  }

  void _onConnectionError(dynamic error) {
    dev.log('Connection error: $error', name: 'EasyChatSocket');
    _stopHeartbeat();
    _updateStatus(ChatSocketStatus.error);

    if (!_isManuallyClosed) {
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    if (maxRetries != null && _retryCount >= maxRetries!) {
      dev.log('Max retries reached. Giving up.', name: 'EasyChatSocket');
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff: base * 2^retryCount
    final delayMs = min(
      maxRetryDelay.inMilliseconds,
      initialRetryDelay.inMilliseconds * pow(2, _retryCount).toInt(),
    );
    final delay = Duration(milliseconds: delayMs);

    dev.log('Scheduling reconnection in ${delay.inSeconds}s (Attempt ${_retryCount + 1})', 
        name: 'EasyChatSocket');

    _reconnectTimer = Timer(delay, () {
      _retryCount++;
      _establishConnection();
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_currentStatus == ChatSocketStatus.connected) {
        send(pingPayload);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Sends a message over the WebSocket.
  ///
  /// Supports [String] and [Map] (which will be JSON encoded).
  void send(dynamic message) {
    if (_channel == null || _currentStatus != ChatSocketStatus.connected) {
      dev.log('Cannot send message: Not connected', name: 'EasyChatSocket');
      return;
    }

    try {
      if (message is Map || message is List) {
        final encoded = jsonEncode(message);
        _channel!.sink.add(encoded);
      } else {
        _channel!.sink.add(message);
      }
    } catch (e) {
      dev.log('Error sending message: $e', name: 'EasyChatSocket');
    }
  }

  /// Sends a JSON encoded map.
  void sendJson(Map<String, dynamic> json) => send(json);

  /// Explicitly disconnects the socket and stops reconnection logic.
  void disconnect() {
    _isManuallyClosed = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _updateStatus(ChatSocketStatus.disconnected);
    dev.log('Manually disconnected', name: 'EasyChatSocket');
  }

  void _updateStatus(ChatSocketStatus newStatus) {
    if (_currentStatus == newStatus) return;
    _currentStatus = newStatus;
    _statusController.add(newStatus);
  }

  /// Sends a chat message.
  void sendMessage(
    String content, {
    List<String>? receiverIds,
    String? chatId,
    Map<String, dynamic>? metadata,
  }) {
    send({
      'type': 'sendMessage',
      'receiverIds': receiverIds ?? [],
      'content': content,
      'chatId': chatId,
      if (metadata != null) ...metadata,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Sends a typing indicator status.
  void sendTyping({
    bool isTyping = true,
    String? chatId,
  }) {
    send({
      'type': isTyping ? 'typing' : 'stopTyping',
      'chatId': chatId,
    });
  }

  /// Sends a "mark as read" event.
  void markAsRead(String messageId, {String? chatId}) {
    send({
      'type': 'markRead',
      'messageId': messageId,
      'chatId': chatId,
    });
  }

  /// Joins a chat room.
  void joinChat(String chatId, {int page = 1, int limit = 20}) {
    send({
      'type': 'joinChat',
      'chatId': chatId,
      'page': page,
      'limit': limit,
    });
  }

  /// Closes all streams and cleans up resources.
  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
  }
}
