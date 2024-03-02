import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = Client(
    'SimpleMatrixChat',
    databaseBuilder: (_) async {
      final dir = await getApplicationDocumentsDirectory();
      final db = HiveCollectionsDatabase('simple_matrix_chat', dir.path);
      await db.open();
      return db;
    },
  );
  await client.init();
  runApp(SimpleMatrixChat(client: client));
}

class SimpleMatrixChat extends StatelessWidget {
  final Client client;
  const SimpleMatrixChat({required this.client, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Matrix Chat',
      home: Provider<Client>(
        create: (_) => client,
        child: client.isLogged() ? ChatInterface(client: client) : LoginPage(client: client),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final Client client;
  const LoginPage({required this.client, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      await widget.client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: _usernameController.text),
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatInterface(client: widget.client)));
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ElevatedButton(onPressed: _isLoading ? null : _login, child: Text(_isLoading ? 'Logging in...' : 'Login')),
          ],
        ),
      ),
    );
  }
}

class ChatInterface extends StatefulWidget {
  final Client client;
  const ChatInterface({required this.client, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatInterfaceState createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  List<Event> messages = [];

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  Future<void> _initRoom() async {
    String roomId = '!qGBHpIbHUSWjRAXydo:matrix.org'; // Replace with your actual room ID
    final room = widget.client.getRoomById(roomId);

    if (room != null) {
      room.onEvent.stream.listen((event) {
        if (event.type == 'm.room.message') {
          setState(() {
            messages.insert(0, event);
          });
        }
      });

      final timeline = await room.getTimeline();
      setState(() {
        messages = timeline.events.where((event) => event.type == 'm.room.message').toList().reversed.toList();
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      String roomId = 'your_room_id_here'; // Replace with your actual room ID
      widget.client.getRoomById(roomId)?.sendTextEvent(_messageController.text.trim());
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await widget.client.logout();
              // ignore: use_build_context_synchronously
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage(client: widget.client)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  // ignore: deprecated_member_use
                  title: Text(message.sender as String),
                  subtitle: Text(message.content['body'].toString() ?? 'Message not available'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(hintText: "Send a message..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
