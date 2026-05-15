# Easy Chat Socket 🚀

A comprehensive, enterprise-ready Flutter package that abstracts WebSocket connections specifically for real-time chat applications. Built to handle auto-reconnection, heartbeats, and strongly-typed messaging for both P2P and Group chats.

---

## 📖 Table of Contents
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [EasyChatSocket](#easychatsocket)
  - [ChatMessage Model](#chatmessage-model)
  - [TypingEvent Model](#typingevent-model)
- [Advanced Usage](#advanced-usage)
  - [Authentication](#authentication)
  - [Reconnection Logic](#reconnection-logic)
  - [Heartbeat / Keep-Alive](#heartbeat--keep-alive)
- [UI Integration](#ui-integration)
- [Example Application](#example-application)

---

## Features

-   ✅ **Auto-Reconnection**: Intelligent exponential backoff strategy for network drops.
-   ✅ **Heartbeat (Ping/Pong)**: Background timer to prevent OS-level socket termination.
-   ✅ **Strongly-Typed Models**: Native models for Messages and Typing indicators.
-   ✅ **P2P & Group Support**: Native support for `chatId` and `receiverIds`.
-   ✅ **Reactive UI**: Dedicated broadcast streams for seamless `StreamBuilder` integration.
-   ✅ **Lifecycle Management**: Clean `dispose()` hooks for all timers and controllers.

---

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  easy_chat_socket:
    path: ./path/to/easy_chat_socket
```

Then run:
```bash
flutter pub get
```

---

## Quick Start

```dart
import 'package:easy_chat_socket/easy_chat_socket.dart';

// 1. Initialize
final chatSocket = EasyChatSocket(
  uri: Uri.parse('wss://your-api.com/chat'),
  token: 'YOUR_JWT_TOKEN',
);

// 2. Connect
await chatSocket.connect();

// 3. Join a chat room
chatSocket.joinChat('room_123');

// 4. Send a message
chatSocket.sendMessage('Hello World!', chatId: 'room_123');

// 5. Listen to messages
chatSocket.onChatMessage.listen((msg) {
  print('Received: ${msg.content}');
});
```

---

## API Reference

### `EasyChatSocket`

The core class managing the connection and event dispatching.

| Property | Type | Description |
| --- | --- | --- |
| `statusStream` | `Stream<ChatSocketStatus>` | Broadcast stream of connection state updates. |
| `onChatMessage` | `Stream<ChatMessage>` | Stream of incoming chat messages (strongly typed). |
| `onTypingEvent` | `Stream<TypingEvent>` | Stream of typing status updates. |
| `onReadReceipt` | `Stream<Map>` | Stream of message read receipts. |

**Methods:**
- `connect()`: Initializes the connection.
- `disconnect()`: Manually closes the connection and stops retries.
- `joinChat(chatId)`: Joins a specific room.
- `sendMessage(content, {chatId, receiverIds})`: Sends a message.
- `sendTyping({chatId, isTyping})`: Sends a typing status.
- `markAsRead(messageId, {chatId})`: Sends a read receipt.
- `inConversation(id)`: Returns a filtered stream for a specific room or user.
- `dispose()`: Completely cleans up all resources.

### `ChatMessage` Model

| Property | Type | Description |
| --- | --- | --- |
| `content` | `String` | The text content of the message. |
| `senderId` | `String?` | The unique ID of the sender. |
| `senderName` | `String?` | The display name of the sender. |
| `chatId` | `String?` | The ID of the chat room (null for P2P). |
| `timestamp` | `DateTime` | When the message was created. |
| `isGroup` | `bool` | Getter: returns true if `chatId != null`. |

### `TypingEvent` Model

| Property | Type | Description |
| --- | --- | --- |
| `isTyping` | `bool` | True if user started typing, False if they stopped. |
| `userId` | `String?` | The ID of the user typing. |
| `chatId` | `String?` | The ID of the room where the typing is happening. |

---

## Advanced Usage

### Authentication
Pass your JWT or Auth token in the constructor. The package uses this for secure handshaking.
```dart
EasyChatSocket(
  uri: Uri.parse('...'),
  token: 'my_secure_token',
);
```

### Reconnection Logic
You can configure how the socket behaves during failures:
```dart
EasyChatSocket(
  uri: Uri.parse('...'),
  maxRetries: 10, // Max attempts before giving up
  initialRetryDelay: Duration(seconds: 1),
  maxRetryDelay: Duration(seconds: 60), // Cap for exponential backoff
);
```

### Heartbeat / Keep-Alive
To prevent the OS from killing the socket during inactivity (especially on iOS/Android):
```dart
EasyChatSocket(
  uri: Uri.parse('...'),
  heartbeatInterval: Duration(seconds: 15),
  pingPayload: 'ping', // Custom payload if your server requires it
);
```

---

## UI Integration

Use `StreamBuilder` for a fully reactive UI that updates automatically.

```dart
StreamBuilder<ChatMessage>(
  stream: chatSocket.onChatMessage,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return LoadingWidget();
    return ListView(
      children: snapshot.data!.map((m) => Bubble(m)).toList(),
    );
  },
)
```

---

## Example Application
A full-featured example is located in the `example/` folder. It includes:
-   Reactive Connection Status Indicator.
-   Message History Simulation.
-   Typing Indicator UI.
-   Proper Dispose Lifecycle implementation.

To run it:
1. `cd example`
2. `flutter run`

---

## License
MIT
# easy_chat_socket
