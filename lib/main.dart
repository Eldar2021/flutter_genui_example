import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_firebase_ai/genui_firebase_ai.dart';
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter GenUI Real Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GenUiDemoPage(),
    );
  }
}

class GenUiDemoPage extends StatefulWidget {
  const GenUiDemoPage({super.key});

  @override
  State<GenUiDemoPage> createState() => _GenUiDemoPageState();
}

class _GenUiDemoPageState extends State<GenUiDemoPage> {
  late final A2uiMessageProcessor _messageProcessor;
  late final GenUiConversation _conversation;
  late final FirebaseAiContentGenerator _contentGenerator;
  final TextEditingController _textController = TextEditingController();
  final List<String> _surfaceIds = [];
  final List<String> _history = [];

  // final String _apiKey = 'Your API KEY';

  @override
  void initState() {
    super.initState();

    final catalog = CoreCatalogItems.asCatalog();

    _messageProcessor = A2uiMessageProcessor(catalogs: [catalog]);

    _contentGenerator = FirebaseAiContentGenerator(
      catalog: catalog,
      systemInstruction: '''
You are a Flutter UI expert. You use GenUI to help users by providing interactive widgets.
When a user asks for something, try to provide a UI surface that helps them.
You have access to a catalog of widgets including: Column, Row, Text, Button, Card, TextField, etc.
Always respond using the GenUI protocol for UI components.
''',
      modelCreator:
          ({required configuration, systemInstruction, toolConfig, tools}) {
            return FirebaseAiContentGenerator.defaultGenerativeModelFactory(
              configuration: configuration,
              systemInstruction: systemInstruction,
              tools: tools,
              toolConfig: toolConfig,
            );
          },
    );

    _conversation = GenUiConversation(
      contentGenerator: _contentGenerator,
      a2uiMessageProcessor: _messageProcessor,
      onSurfaceAdded: (SurfaceAdded event) {
        setState(() {
          _surfaceIds.add(event.surfaceId);
        });
      },
      onSurfaceDeleted: (SurfaceRemoved event) {
        setState(() {
          _surfaceIds.remove(event.surfaceId);
        });
      },
    );

    _contentGenerator.textResponseStream.listen((text) {
      setState(() {
        _history.add('Assistant: $text');
      });
    });
  }

  @override
  void dispose() {
    _conversation.dispose();
    _contentGenerator.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      setState(() {
        _history.add('User: $text');
      });
      _conversation.sendRequest(UserMessage.text(text));
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GenUI Real Agent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _surfaceIds.clear();
                _history.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._history.map((line) {
                  final isUser = line.startsWith('User:');
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(line),
                    ),
                  );
                }),
                ..._surfaceIds.map(
                  (id) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: GenUiSurface(host: _messageProcessor, surfaceId: id),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _contentGenerator.isProcessing,
            builder: (context, isProcessing, child) {
              if (isProcessing) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Ask for a form, a list, or a button...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
