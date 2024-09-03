import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';

class DataConnectionExample extends StatefulWidget {
  const DataConnectionExample({Key? key}) : super(key: key);

  @override
  State<DataConnectionExample> createState() => _DataConnectionExampleState();
}

class _DataConnectionExampleState extends State<DataConnectionExample> {
  Peer peer = Peer(options: PeerOptions(debug: LogLevel.All));
  final TextEditingController _controller = TextEditingController();
  String? peerId;
  DataConnection? currentConnection; // Track the current connection
  bool connected = false;
  List<String> messages = []; // List to store chat messages
  Map<String, DataConnection> connections = {}; // Track multiple connections

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
    connections[connection.peer] = connection;
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
        connections.remove(connection.peer); // Remove closed connection
      });
    });
  }

  void connect() {
    final peerIdToConnect = _controller.text;
    if (peerIdToConnect.isNotEmpty) {
      final connection = peer.connect(peerIdToConnect);
      connection.on("open").listen((_) {
        setState(() {
          connected = true;
          currentConnection = connection;
          connections[peerIdToConnect] = connection;
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
            connections.remove(peerIdToConnect); // Remove closed connection
          });
        });
      });
    }
  }

  void sendHelloWorld() {
    if (currentConnection != null) {
      currentConnection!.send("Hello world!");
      setState(() {
        messages.add("You: Hello world!"); // Add sent message to the list
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data Connection Example")),
      body: Column(
        children: <Widget>[
          // Header displaying connection status
          Container(
            padding: const EdgeInsets.all(8.0),
            color: connected ? Colors.green : Colors.red,
            child: Text(
              connected ? "Connected to: ${currentConnection?.peer}" : "Not connected",
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          Expanded(
            child: ListView.builder(
              reverse: true, // Display messages from bottom to top
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
                  icon: const Icon(Icons.send),
                  onPressed: connect,
                  tooltip: "Connect",
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
