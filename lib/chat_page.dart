import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

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

  final int chunkSize = 16 * 1024; // 16 KB per chunk
  Map<String, List<Uint8List>> receivedChunks =
      {}; // Store received chunks by sender ID
  int totalChunks = 0;
  String? currentSender;

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

  Map<String, List<Uint8List?>> receivedChunks = {};
  int totalChunks = 0;
  String? sender;

  connection.on("data").listen((data) {
    if (data is Map) {
      if (data['type'] == 'imageMetadata') {
        // Metadata received
        sender = connection.peer;
        totalChunks = data['totalChunks'];
        receivedChunks[sender!] = List<Uint8List?>.filled(totalChunks, null);
      } else if (data['type'] == 'imageChunk') {
        // Handle image chunk
        if (sender != null) {
          // Convert data['data'] from List<dynamic> to List<int>
          List<int> chunkData = List<int>.from(data['data']);
          receivedChunks[sender!]![data['index']] = Uint8List.fromList(chunkData);

          // Check if all chunks are received
          if (!receivedChunks[sender!]!.contains(null)) {
            Uint8List fullImage = Uint8List.fromList(
              receivedChunks[sender!]!.expand((x) => x!).toList()
            );
            setState(() {
              messages.add({'type': 'image', 'data': fullImage});
            });

            receivedChunks.remove(sender); // Clear the stored chunks
            sender = null; // Reset sender
          }
        }
      }
    } else {
      setState(() {
        messages.add("Peer ${connection.peer}: $data");
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
          if (data is Map) {
            if (data['type'] == 'imageMetadata') {
              currentSender = peerIdToConnect;
              totalChunks = data['totalChunks'];
              receivedChunks[currentSender!] =
                  List<Uint8List>.filled(totalChunks, Uint8List(0));
            } else if (data['type'] == 'imageChunk') {
              if (currentSender != null) {
                receivedChunks[currentSender!]![data['index']] =
                    Uint8List.fromList(data['data']);

                if (!receivedChunks[currentSender!]!.contains(Uint8List(0))) {
                  Uint8List fullImage = Uint8List.fromList(
                      receivedChunks[currentSender!]!
                          .expand((x) => x)
                          .toList());
                  setState(() {
                    messages.add({'type': 'image', 'data': fullImage});
                  });

                  receivedChunks.remove(currentSender);
                  currentSender = null;
                }
              }
            }
          } else {
            setState(() {
              messages.add("Peer $peerIdToConnect: $data");
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

  
void sendImageInChunks(Uint8List imageBytes) {
  if (currentConnection != null) {
    const int chunkSize = 64 * 1024; // 64 KB
    int totalChunks = (imageBytes.length / chunkSize).ceil();

    // Send metadata first
    currentConnection!.send({
      'type': 'imageMetadata',
      'totalChunks': totalChunks,
    });

    // Send image chunks
    for (int i = 0; i < totalChunks; i++) {
      int start = i * chunkSize;
      int end = (start + chunkSize > imageBytes.length) ? imageBytes.length : start + chunkSize;
      Uint8List chunk = imageBytes.sublist(start, end);

      // Convert Uint8List to List<int> for sending
      List<int> chunkList = chunk.toList();

      // Send chunk with index and total number of chunks
      currentConnection!.send({
        'type': 'imageChunk',
        'data': chunkList,
        'index': i,
        'total': totalChunks,
      });
    }
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
        if (imageData.isNotEmpty) {
          sendImageInChunks(imageData);
          setState(() {
                messages.add({'type': 'image', 'data': imageData});
              });
        } else {
          print("Failed to send image: Image data is empty");
        }
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
                  connected
                      ? "Connected to: ${currentConnection?.peer}"
                      : "Not connected",
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
                if (message is String) {
                  return ListTile(
                    title: Text(message),
                  );
                } else if (message is Map && message['type'] == 'image') {
                  return ListTile(
                    title: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.8,
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.9,
                                ),
                                child: Image.memory(
                                  message['data'],
                                  fit: BoxFit.contain,
                                ),
                              ),
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
                    decoration:
                        const InputDecoration(labelText: "Enter Peer ID"),
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
                    decoration:
                        const InputDecoration(labelText: "Enter Message"),
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
