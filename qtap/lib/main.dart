import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Entry point of the application.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the client with a custom database location.
  final client = Client(
    'SimpleMatrixChat',
    databaseBuilder: (_) async {
      final dir = await getApplicationDocumentsDirectory();
      final db = HiveCollectionsDatabase('simple_matrix_chat', dir.path);
      await db.open();
      return db;
    },
  );
  // Initialize the client before running the app.
  await client.init();
  runApp(SimpleMatrixChat(client: client));
}

// Main widget of the application.
class SimpleMatrixChat extends StatelessWidget {
  final Client client;

  const SimpleMatrixChat({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    // Use Provider to make the client available to child widgets.
    return Provider<Client>(
      create: (_) => client,
      child: MaterialApp(
        title: 'Simple Matrix Chat',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        // Display ChatInterface if logged in, otherwise show LoginPage.
        home: client.isLogged() ? ChatInterface(client: client) : LoginPage(client: client),
      ),
    );
  }
}

// LoginPage widget for user authentication.
class LoginPage extends StatefulWidget {
  final Client client;

  const LoginPage({super.key, required this.client});

  @override
  // ignore: library_private_types_in_public_api
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Login function with Matrix client.
  void _login() async {
    setState(() => _isLoading = true);
    try {
      await widget.client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: _usernameController.text),
        password: _passwordController.text,
      );
      if (mounted) {
        // Navigate to the ChatInterface on successful login.
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatInterface(client: widget.client)));
      }
    } catch (e) {
      // Display error message on login failure.
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      // Stop the loading indicator.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI for login page.
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

// ChatInterface widget for displaying chat messages.
class ChatInterface extends StatefulWidget {
  final Client client;

  const ChatInterface({super.key, required this.client});

  @override
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

  // Initializes the room and sets up listeners for new messages.
  Future<void> _initRoom() async {
    // Replace with your actual room ID.
    String roomId = 'YOUR_ROOM_ID';
    final room = widget.client.getRoomById(roomId);

    if (room != null) {
      // Listen for new messages and update the UI accordingly.
      room.onUpdate.stream.listen((dynamic event) {
        final MatrixEvent matrixEvent = event as MatrixEvent;
        if (matrixEvent.type == 'm.room.message') {
          setState(() {
            messages.insert(0, event as Event);
          });
        }
      });

      // Fetch existing messages and display them.
      final timeline = await room.getTimeline();
      setState(() {
        messages = timeline.events.where((event) => event.type == 'm.room.message').toList().reversed.toList();
      });
    }
  }

  // Send message function.
  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      // Send the message to the room.
      widget.client.getRoomById('YOUR_ROOM_ID')?.sendTextEvent(_messageController.text.trim());
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI for chat interface.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              // Logout and navigate back to login page.
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
                  subtitle: Text(message.content['body'].toString()),
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
