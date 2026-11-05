import 'package:flutter/material.dart';
import '../services/supabase_backend.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _controller = TextEditingController();
  String _type = 'Question';
  bool _sending = false;
  static const _types = ['Question', 'Suggestion', 'Bug Report', 'Other'];

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = SupabaseBackend.client.auth.currentUser;
    if (text.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      final subject = '$_type: ${text.length > 140 ? text.substring(0, 140) : text}';
      final ticket = await SupabaseBackend.client.from('support_tickets')
          .insert({'user_id': user.id, 'category': 'GENERAL', 'subject': subject})
          .select('id').single();
      await SupabaseBackend.client.from('support_messages').insert({
        'ticket_id': ticket['id'],
        'sender_user_id': user.id,
        'sender_role': 'player',
        'body': '[$_type] $text',
      });
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message has been sent.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your message. Please retry online.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseBackend.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Contact / Feedback')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Send a message', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Questions, suggestions and bug reports are welcome.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
          items: [for (final type in _types) DropdownMenuItem(value: type, child: Text(type))],
          onChanged: (value) { if (value != null) setState(() => _type = value); },
        ),
        const SizedBox(height: 16),
        TextField(controller: _controller, minLines: 6, maxLines: 10, maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true, border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: user == null || _sending ? null : _send,
          icon: const Icon(Icons.send_outlined), label: Text(_sending ? 'Sending...' : 'Send Message')),
      ]),
    );
  }
}
