import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Peer peer = Peer(options: PeerOptions(debug: LogLevel.All));
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _message_controller = TextEditingController();

  String? peerId;
  DataConnection? currentConnection; // Track the current connection
  bool connected = false;
  List<String> messages = []; // List to store chat messages

  @override
  void initState() {
    super.initState();

    peer.on("open").listen((id) {
      setState(() {
        peerId = peer.id;
      });
    });

    // Listen for incoming connections
    peer.on<DataConnection>("connection").listen((event) {
      handleConnection(event);
    });
  }

  void handleConnection(DataConnection connection) {
    setState(() {
      connected = true;
    });

    connection.on("data").listen((data) {
      setState(() {
        messages.add("Peer ${connection.peer}: $data"); // Add received message to the list
      });
    });

    connection.on("binary").listen((data) {
      setState(() {
        messages.add("Peer ${connection.peer} sent binary data");
      });
    });

    connection.on("close").listen((_) {
      setState(() {
        connected = false;
      });
    });

    if (currentConnection == null) {
      currentConnection = connection;
    }
  }

  void connect() {
    final peerIdToConnect = _controller.text;
    if (peerIdToConnect.isNotEmpty) {
      final connection = peer.connect(peerIdToConnect);
      connection.on("open").listen((_) {
        setState(() {
          connected = true;
          currentConnection = connection;
        });

        connection.on("data").listen((data) {
          setState(() {
            messages.add("Peer $peerIdToConnect: $data"); // Add received message to the list
          });
        });

        connection.on("binary").listen((data) {
          setState(() {
            messages.add("Peer $peerIdToConnect sent binary data");
          });
        });

        connection.on("close").listen((_) {
          setState(() {
            connected = false;
          });
        });
      });
    }
  }

  void sendHelloWorld() {
    sendMessage("Hello World!");
  }

void sendMessageFromInput() {
    final message = _message_controller.text;
    sendMessage(message);
  }

  void sendMessage(String message) {
    if (currentConnection != null) {
      currentConnection!.send(message);
      setState(() {
        messages.add("You:" + message); // Add sent message to the list
      });
    }
  }

  void sendBinary() {
    if (currentConnection != null) {
      final bytes = Uint8List(30);
      currentConnection!.sendBinary(bytes);
      setState(() {
        messages.add("You sent binary data");
      });
    }
  }

  void copyAddress() {
    if (peerId != null) {
      Clipboard.setData(ClipboardData(text: peerId!)); // Use 'peerId!' to handle nullability
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Address copied to clipboard")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chat Example")),
      body: Column(
        children: <Widget>[
          // Header displaying connection status
          Container(
            padding: const EdgeInsets.all(8.0),
            color: connected ? Colors.green : Colors.red,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  connected ? "Connected to: ${currentConnection?.peer}" : "Not connected",
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                if (peerId != null)
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: copyAddress,
                    tooltip: "Copy Address",
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: false, 
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(labelText: "Enter Peer ID"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.connect_without_contact),
                  onPressed: connect,
                  tooltip: "Connect",
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _message_controller,
                    decoration: const InputDecoration(labelText: "Enter Message"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessageFromInput,
                  tooltip: "Send",
                ),
              ],
            ),
          ),
          if (connected)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                ElevatedButton(
                  onPressed: sendHelloWorld,
                  child: const Text("Send Hello World"),
                ),
                ElevatedButton(
                  onPressed: sendHelloWorld,
                  child: const Text("Send Message"),
                ),
                ElevatedButton(
                  onPressed: sendBinary,
                  child: const Text("Send Binary"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
