import './call_example.dart';
import './data_connection_example.dart';
import './chat_page.dart'; // New Chat Page
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeerDart Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: "/",
      routes: {
        '/': (context) => const MyHomePage(title: "PeerDart Chat App"),
        '/chatPage': (context) => const ChatPage(),  // New unified chat page
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void onPressChat() async {
    await Navigator.of(context).pushNamed("/chatPage");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: ElevatedButton(
              onPressed: onPressChat,
              child: const Text("Open Chat")),
        ));
  }
}
