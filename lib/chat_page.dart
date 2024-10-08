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
  final Peer peer = Peer(options: PeerOptions(debug: LogLevel.All));
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? peerId;
  DataConnection? currentConnection;
  bool connected = false;
  List<Map<String, dynamic>> messages = [];

  final int chunkSize = 16 * 1024;
  final Map<String, List<Uint8List?>> receivedChunks = {};
  String? currentSender;

  @override
  void initState() {
    super.initState();

    peer.on("open").listen((id) {
      setState(() {
        peerId = peer.id;
      });
    });

    // Handle incoming connections
    peer.on<DataConnection>("connection").listen((connection) {
      handleConnection(connection);
    });
  }

  void handleConnection(DataConnection connection) {
    setState(() {
      connected = true;
    });

    currentConnection = connection; // Store the current connection

    // Initialize variables needed for image data handling
    String sender = "";
    // sender = "";
    int totalChunks = 0;
    Map<String, List<Uint8List?>> receivedChunks = {};

    connection.on("data").listen((data) {
      // Handle data received
      if (data is Map) {
        if (data['type'] == 'imageMetadata') {
          // Metadata received
          sender = connection.peer; // Set the sender ID
          totalChunks = data['totalChunks']; // Total chunks to receive
          // Initialize the list to store received chunks
          receivedChunks[sender] = List<Uint8List?>.filled(totalChunks, null);
        } else if (data['type'] == 'imageChunk' && sender != null) {
          // Handle image chunk
          List<int> chunkData =
              List<int>.from(data['data']); // Convert data to List<int>
          receivedChunks[sender]![data['index']] =
              Uint8List.fromList(chunkData);

          // Check if all chunks are received
          if (!receivedChunks[sender]!.contains(null)) {
            Uint8List fullImage = Uint8List.fromList(
              receivedChunks[sender]!
                  .whereType<Uint8List>()
                  .expand((x) => x)
                  .toList(),
            );
            setState(() {
              messages.add({'type': 'image', 'data': fullImage});
            });

            // Clear the stored chunks and reset the sender
            receivedChunks.remove(sender);
            // sender = null;
          }
        }
      } else {
        setState(() {
          messages
              .add({"type": "text", "data": "Peer ${connection.peer}: $data"});
        });
      }
    });

    connection.on("close").listen((_) {
      setState(() {
        connected = false;
      });
    });
  }

  void _handleData(Map data, String sender) {
    switch (data['type']) {
      case 'imageMetadata':
        currentSender = sender;
        // Initialize receivedChunks with nullable Uint8List
        receivedChunks[sender] =
            List<Uint8List?>.filled(data['totalChunks'], null);
        break;
      case 'imageChunk':
        if (currentSender != null && receivedChunks[currentSender] != null) {
          // Ensure conversion from List<dynamic> to List<int>
          receivedChunks[currentSender]![data['index']] =
              Uint8List.fromList(List<int>.from(data['data']));
          if (!receivedChunks[currentSender]!.contains(null)) {
            _assembleImage(currentSender!);
          }
        }
        break;
    }
  }

  void _assembleImage(String sender) {
    // Flatten the list and remove the null check safely
    Uint8List fullImage = Uint8List.fromList(receivedChunks[sender]!
        .whereType<Uint8List>()
        .expand((x) => x)
        .toList());
    setState(() => messages.add({'type': 'image', 'data': fullImage}));
    receivedChunks.remove(sender);
    currentSender = null;
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

        handleConnection(
            connection); // Reuse handleConnection to listen for data
      });
    }
  }

  void sendMessage(String message) {
    if (currentConnection != null) {
      currentConnection!.send(message);
      setState(() => messages.add({'type': 'text', 'data': "You: $message"}));
    }
  }

  void sendImageInChunks(Uint8List imageBytes) async {
    if (currentConnection != null) {
      const int chunkSize = 64 * 1024; // 64 KB per chunk
      int totalChunks = (imageBytes.length / chunkSize).ceil();

      // Send metadata first
      currentConnection!.send({
        'type': 'imageMetadata',
        'totalChunks': totalChunks,
      });

      // Send image chunks with a delay to avoid overloading the data channel
      for (int i = 0; i < totalChunks; i++) {
        int start = i * chunkSize;
        int end = (start + chunkSize > imageBytes.length)
            ? imageBytes.length
            : start + chunkSize;
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

        // Add a small delay to prevent overloading the send queue
        await Future.delayed(const Duration(milliseconds: 2));
      }
    }
  }

  Future<void> pickAndSendImage() async {
    if (currentConnection == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result?.files.isNotEmpty ?? false) {
      final imageData = result!.files.single.bytes;
      if (imageData != null) {
        sendImageInChunks(imageData);
        setState(() => messages.add({'type': 'image', 'data': imageData}));
      }
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
          _buildConnectionStatus(),
          _buildMessageList(),
          _buildPeerIdInput(),
          _buildMessageInput(),
          if (connected) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
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
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          if (message['type'] == 'text') {
            return ListTile(title: Text(message['data']));
          } else if (message['type'] == 'image') {
            return _buildImageMessage(message['data']);
          }
          return const ListTile(title: Text("Unknown message type"));
        },
      ),
    );
  }

  Widget _buildImageMessage(Uint8List data) {
    return ListTile(
      title: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) => Dialog(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Image.memory(data, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        child: Image.memory(data, width: 150, height: 150, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPeerIdInput() {
    return Padding(
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
    );
  }

  Widget _buildMessageInput() {
    return Padding(
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
    );
  }
}
