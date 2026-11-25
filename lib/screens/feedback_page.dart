import 'package:flutter/material.dart';
import '../services/supabase_backend.dart';
import '../l10n/app_localizations.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _controller = TextEditingController();
  String _type = 'question';
  bool _sending = false;
  static const _types = ['question', 'suggestion', 'bug_report', 'other'];

  String _typeLabel(String type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      'question' => l10n.feedbackQuestion,
      'suggestion' => l10n.feedbackSuggestion,
      'bug_report' => l10n.feedbackBugReport,
      _ => l10n.feedbackOther,
    };
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = SupabaseBackend.isAuthenticated
        ? SupabaseBackend.client.auth.currentUser
        : null;
    if (text.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      final subject = '${_typeLabel(_type)}: ${text.length > 140 ? text.substring(0, 140) : text}';
      final ticket = await SupabaseBackend.client.from('support_tickets')
          .insert({'user_id': user.id, 'category': 'GENERAL', 'subject': subject})
          .select('id').single();
      await SupabaseBackend.client.from('support_messages').insert({
        'ticket_id': ticket['id'],
        'sender_user_id': user.id,
        'sender_role': 'player',
        'body': '[${_typeLabel(_type)}] $text',
      });
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.feedbackSent)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.feedbackSendFailed)),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.feedbackTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(AppLocalizations.of(context)!.feedbackSendTitle, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)!.feedbackDescription),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: InputDecoration(labelText: AppLocalizations.of(context)!.feedbackType, border: const OutlineInputBorder()),
          items: [for (final type in _types) DropdownMenuItem(value: type, child: Text(_typeLabel(type)))],
          onChanged: (value) { if (value != null) setState(() => _type = value); },
        ),
        const SizedBox(height: 16),
        TextField(controller: _controller, minLines: 6, maxLines: 10, maxLength: 2000,
          decoration: InputDecoration(labelText: AppLocalizations.of(context)!.feedbackMessage, alignLabelWithHint: true, border: const OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: user == null || _sending ? null : _send,
          icon: const Icon(Icons.send_outlined), label: Text(_sending ? AppLocalizations.of(context)!.feedbackSending : AppLocalizations.of(context)!.feedbackSend)),
      ]),
    );
  }
}
