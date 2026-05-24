import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../controllers/wallet_controller.dart';

class LinkedBankAccountScreen extends ConsumerStatefulWidget {
  const LinkedBankAccountScreen({super.key});

  @override
  ConsumerState<LinkedBankAccountScreen> createState() =>
      _LinkedBankAccountScreenState();
}

class _LinkedBankAccountScreenState
    extends ConsumerState<LinkedBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bankNameController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchController = TextEditingController();
  bool _isSaving = false;
  bool _isRemoving = false;

  @override
  void dispose() {
    _bankNameController.dispose();
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(walletControllerProvider.notifier)
          .linkBankAccount(
            bankName: _bankNameController.text.trim(),
            accountHolderName: _holderNameController.text.trim(),
            accountNumber: _accountNumberController.text.trim(),
            branch: _branchController.text.trim().isEmpty
                ? null
                : _branchController.text.trim(),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.text('bankAccountLinked'))));
      Navigator.of(context).pop();
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmRemove(String bankAccountId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.text('confirmRemoveBankAccount')),
          content: Text(l10n.text('removeBankAccountWarning')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.text('removeLinkedAccount')),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _remove(bankAccountId);
    }
  }

  Future<void> _remove(String bankAccountId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isRemoving = true);
    try {
      await ref
          .read(walletControllerProvider.notifier)
          .removeBankAccount(bankAccountId: bankAccountId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.text('bankAccountRemoved'))));
      Navigator.of(context).pop();
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).text('requiredField');
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) {
      return requiredError;
    }
    final text = value!.trim();
    if (!RegExp(r'^\d{6,20}$').hasMatch(text)) {
      return AppLocalizations.of(context).text('invalidAccountNumber');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final walletState = ref.watch(walletControllerProvider).asData?.value;
    final account = walletState?.linkedBankAccount;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('linkedBankAccount'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (account != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            child: Icon(Icons.account_balance),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.bankName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(account.accountNumberMasked),
                                Text(account.accountHolderName),
                                if (account.branch?.isNotEmpty == true)
                                  Text(account.branch!),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isRemoving
                            ? null
                            : () => _confirmRemove(account.bankAccountId),
                        icon: const Icon(Icons.link_off),
                        label: Text(
                          _isRemoving
                              ? l10n.loading
                              : l10n.text('removeLinkedAccount'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _bankNameController,
                    decoration: InputDecoration(
                      labelText: l10n.text('bankName'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _holderNameController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.text('accountHolderName'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.text('accountNumber'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateAccountNumber,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _branchController,
                    decoration: InputDecoration(
                      labelText: l10n.text('branchOptional'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(
                        _isSaving ? l10n.loading : l10n.text('saveBankAccount'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
