import 'package:flutter/material.dart';
import 'package:easy_chat_socket/easy_chat_socket.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Easy Chat Socket Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late EasyChatSocket _chatSocket;
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    // 1. Initialize the socket (using a publicly available echo server for demonstration)
    _chatSocket = EasyChatSocket(
      uri: Uri.parse('wss://your-chat-server.com'), // Replace with your WebSocket URL
      heartbeatInterval: const Duration(seconds: 15),
    );

    // 2. Listen to messages
    _chatSocket.onChatMessage.listen((msg) {
      setState(() {
        _messages.add("Echo: ${msg.content}");
      });
    });

    // 3. Connect
    _chatSocket.connect();
  }

  @override
  void dispose() {
    _chatSocket.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      _chatSocket.sendMessage(_controller.text, chatId: 'chat_room_1');
      setState(() {
        _messages.add("Me: ${_controller.text}");
        _controller.clear();
      });
      // Stop typing indicator after sending
      _chatSocket.sendTyping(isTyping: false, chatId: 'chat_room_1');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Easy Chat Socket'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Connection Status Indicator
          StreamBuilder<ChatSocketStatus>(
            stream: _chatSocket.statusStream,
            builder: (context, snapshot) {
              final status = snapshot.data ?? ChatSocketStatus.disconnected;
              Color color;
              switch (status) {
                case ChatSocketStatus.connected:
                  color = Colors.green;
                  break;
                case ChatSocketStatus.connecting:
                  color = Colors.orange;
                  break;
                case ChatSocketStatus.error:
                  color = Colors.red;
                  break;
                case ChatSocketStatus.disconnected:
                  color = Colors.grey;
                  break;
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircleAvatar(backgroundColor: color, radius: 8),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_messages[index]),
                  ),
                );
              },
            ),
          ),

          // Typing Indicator
          StreamBuilder<TypingEvent>(
            stream: _chatSocket.onTypingEvent,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isTyping) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Someone is typing...', 
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Input Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // Send typing indicator
                      _chatSocket.sendTyping(
                        isTyping: value.isNotEmpty, 
                        chatId: 'chat_room_1',
                      );
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
