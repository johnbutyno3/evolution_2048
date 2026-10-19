import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _localizedType(AppLocalizations l10n, String type) {
    switch (type) {
      case 'Question':
        return l10n.feedbackQuestion;
      case 'Suggestion':
        return l10n.feedbackSuggestion;
      case 'Bug Report':
        return l10n.feedbackBugReport;
      default:
        return l10n.feedbackOther;
    }
  }

  Future<void> _send(AppLocalizations l10n) async {
    final message = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (_sending) return;
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackEmpty)),
      );
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackSignInRequired)),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid': user.uid,
        'type': _type,
        'message': message,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackSent)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.feedbackSendFailed)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedbackTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.feedbackHeading,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(l10n.feedbackDescription),
          if (user == null) ...[
            const SizedBox(height: 8),
            Text(l10n.feedbackSignInRequired),
          ],
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: l10n.feedbackType,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final type in _types)
                DropdownMenuItem(
                  value: type,
                  child: Text(_localizedType(l10n, type)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 10,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: l10n.feedbackMessage,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: user == null || _sending ? null : () => _send(l10n),
            icon: const Icon(Icons.send_outlined),
            label: Text(_sending ? l10n.feedbackSending : l10n.feedbackSend),
          ),
        ],
      ),
    );
  }
}
