import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://YOUR-SERVER-DOMAIN.example.com',
);

void main() => runApp(const JinniApp());

class JinniApp extends StatelessWidget {
  const JinniApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'جني الكاسر AI',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF070B18),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFC857), secondary: Color(0xFF20B8FF),
        surface: Color(0xFF101A30),
      ),
    ),
    home: const ChatPage(),
  );
}

class ChatMessage {
  final String role, content;
  ChatMessage(this.role, this.content);
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(j['role'] as String, j['content'] as String);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[];
  bool busy = false;
  String status = 'جاهز للاتصال';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('chat_history');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() => messages.addAll(list.map(ChatMessage.fromJson)));
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('chat_history', jsonEncode(messages.map((m) => m.toJson()).toList()));
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    if (backendUrl.contains('YOUR-SERVER-DOMAIN')) {
      setState(() => status = 'يلزم نشر الخادم ووضع رابطه في BACKEND_URL');
      return;
    }
    setState(() { messages.add(ChatMessage('user', text)); busy = true; status = 'جاري الاتصال بالخادم…'; });
    input.clear(); await _save(); _scrollDown();
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 90));
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? 'خطأ من الخادم (${response.statusCode})');
      }
      final answer = (data['reply'] ?? '').toString();
      setState(() { messages.add(ChatMessage('assistant', answer)); status = 'متصل بالخادم'; });
      await _save();
    } catch (e) {
      setState(() { status = 'تعذر الاتصال'; messages.add(ChatMessage('assistant', 'تعذر الحصول على رد: $e')); });
      await _save();
    } finally {
      setState(() => busy = false); _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> clearChat() async {
    setState(messages.clear);
    final p = await SharedPreferences.getInstance();
    await p.remove('chat_history');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF0C1428),
      title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جني الكاسر AI', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFD36A))),
        Text('الذكاء الاصطناعي العالمي', style: TextStyle(fontSize: 11, color: Color(0xFF31BFFF))),
      ]),
      actions: [IconButton(tooltip: 'مسح المحادثة', onPressed: clearChat, icon: const Icon(Icons.delete_outline))],
    ),
    body: Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF182B50), Color(0xFF10182B)]),
          border: Border(bottom: BorderSide(color: Color(0xFFB98B32), width: 0.6)),
        ),
        child: Column(children: [
          const Icon(Icons.auto_awesome, size: 34, color: Color(0xFFFFC857)),
          const SizedBox(height: 5),
          const Text('مرحباً بك في عقل الكاسر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(status, style: const TextStyle(fontSize: 11, color: Color(0xFF43C5FF))),
        ]),
      ),
      Expanded(child: messages.isEmpty
        ? const Center(child: Text('اكتب سؤالك… وسيجيبك جني الكاسر عند ربط الخادم.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)))
        : ListView.builder(controller: scroll, padding: const EdgeInsets.all(12),
          itemCount: messages.length, itemBuilder: (c, i) {
            final m = messages[i]; final user = m.role == 'user';
            return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: user ? const Color(0xFF173D60) : const Color(0xFF172039),
                  border: Border.all(color: user ? const Color(0xFF20B8FF) : const Color(0xFFB98B32), width: .7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(m.content, textDirection: TextDirection.rtl),
              ));
          })),
      if (busy) const LinearProgressIndicator(minHeight: 2, color: Color(0xFFFFC857), backgroundColor: Color(0xFF14223B)),
      SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(children: [
          Expanded(child: TextField(controller: input, minLines: 1, maxLines: 5,
            textDirection: TextDirection.rtl, decoration: InputDecoration(
              hintText: 'اكتب رسالتك لجني الكاسر…',
              filled: true, fillColor: const Color(0xFF121D34),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ), onSubmitted: (_) => send())),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: busy ? null : send,
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFB9872D), foregroundColor: Colors.black),
            icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
        ]))),
    ]),
  );

  @override
  void dispose() { input.dispose(); scroll.dispose(); super.dispose(); }
}
