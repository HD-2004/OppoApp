import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class DeleteAccountRequestScreen extends StatefulWidget {
  const DeleteAccountRequestScreen({super.key});

  @override
  State<DeleteAccountRequestScreen> createState() =>
      _DeleteAccountRequestScreenState();
}

class _DeleteAccountRequestScreenState
    extends State<DeleteAccountRequestScreen> {
  final _reasonController = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    final strings = AppLocalizations.of(context);
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).text('deleteReasonRequired'),
          ),
        ),
      );
      return;
    }

    if (!_understood) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).text('deleteConfirmRequired'),
          ),
        ),
      );
      return;
    }

    // TODO: Save delete account request to DynamoDB/Admin review system later.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.text('deleteAccountRequestSubmitted'))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.deleteAccountRequest)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  strings.deleteAccountWarning,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: strings.deleteAccountReason,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _understood,
              onChanged: (value) {
                setState(() {
                  _understood = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              title: Text(strings.deleteAccountConfirmText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitRequest,
              child: Text(strings.submitRequest),
            ),
          ],
        ),
      ),
    );
  }
}
