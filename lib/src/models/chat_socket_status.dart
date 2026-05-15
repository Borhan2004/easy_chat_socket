/// Represents the various states of the WebSocket connection.
enum ChatSocketStatus {
  /// The socket is currently attempting to establish a connection.
  connecting,

  /// The socket is successfully connected and ready to send/receive messages.
  connected,

  /// The socket is disconnected.
  disconnected,

  /// An error occurred during connection or while the connection was active.
  error,
}
