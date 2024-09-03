import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Peer peer = Peer(options: PeerOptions(debug: LogLevel.All));
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? peerId;
  DataConnection? currentConnection;
  bool connected = false;
  List<dynamic> messages = []; // Allow dynamic content for text or image data

  @override
  void initState() {
    super.initState();

    peer.on("open").listen((id) {
      setState(() {
        peerId = peer.id;
      });
    });

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
        messages.add("Peer ${connection.peer}: $data");
      });
    });

    connection.on("binary").listen((data) {
      // Check if the data is a Uint8List (which could represent an image)
      if (data is Uint8List) {
        setState(() {
          messages.add({'type': 'image', 'data': data}); // Add image data to the list
        });
      } else {
        setState(() {
          messages.add("Peer ${connection.peer} sent binary data");
        });
      }
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
            messages.add("Peer $peerIdToConnect: $data");
          });
        });

        connection.on("binary").listen((data) {
          // Handle received binary data
          if (data is Uint8List) {
            setState(() {
              messages.add({'type': 'image', 'data': data});
            });
          } else {
            setState(() {
              messages.add("Peer $peerIdToConnect sent binary data");
            });
          }
        });

        connection.on("close").listen((_) {
          setState(() {
            connected = false;
          });
        });
      });
    }
  }

  void sendMessage(String message) {
    if (currentConnection != null) {
      currentConnection!.send(message);
      setState(() {
        messages.add("You: $message");
      });
    }
  }

  void sendBinary(Uint8List data) {
    if (currentConnection != null) {
      currentConnection!.sendBinary(data);
      setState(() {
        messages.add({'type': 'image', 'data': data}); // Add sent image to the list
      });
    }
  }

  Future<void> pickAndSendImage() async {
    if (currentConnection == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.isNotEmpty) {
      Uint8List? imageData = result.files.single.bytes;
      if (imageData != null) {
        sendBinary(imageData);
      } else {
        print("Failed to send image: No image data found");
      }
    } else {
      print("No image selected.");
    }
  }

  void copyAddress() {
    if (peerId != null) {
      Clipboard.setData(ClipboardData(text: peerId!));
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
              // Inside your ListView.builder's itemBuilder:
itemBuilder: (context, index) {
  final message = messages[index];
  if (message is String) {
    return ListTile(
      title: Text(message),
    );
  } else if (message is Map && message['type'] == 'image') {
    return ListTile(
      title: InkWell(
        onTap: () {
          // Open full-size image dialog
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.memory(
                    message['data'],
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          );
        },
        child: Image.memory(
          message['data'],
          width: 150,
          height: 150,
          fit: BoxFit.cover,
        ),
      ),
    );
  } else {
    return const ListTile(
      title: Text("Unknown message type"),
    );
  }
}

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
                    controller: _messageController,
                    decoration: const InputDecoration(labelText: "Enter Message"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => sendMessage(_messageController.text),
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
                  onPressed: pickAndSendImage,
                  child: const Text("Send Image"),
                ),
                ElevatedButton(
                  onPressed: () => sendMessage("Hello World!"),
                  child: const Text("Send Hello World"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
