import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/linked_bank_account.dart';
import '../../domain/entities/wallet.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/wallet_formatters.dart';

class WithdrawFundsScreen extends ConsumerStatefulWidget {
  const WithdrawFundsScreen({
    super.key,
    required this.wallet,
    required this.linkedBankAccount,
  });

  final WalletOverview wallet;
  final LinkedBankAccount? linkedBankAccount;

  @override
  ConsumerState<WithdrawFundsScreen> createState() =>
      _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends ConsumerState<WithdrawFundsScreen> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return double.tryParse(digits);
  }

  String? _validate(AppLocalizations l10n) {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      return l10n.text('invalidAmount');
    }
    if (widget.linkedBankAccount == null) {
      return l10n.text('bankAccountRequired');
    }
    if (!widget.wallet.isActive) {
      return l10n.text('walletLoadFailed');
    }
    if (amount > widget.wallet.availableBalance) {
      return l10n.text('insufficientBalance');
    }
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final error = _validate(l10n);
    if (error != null) {
      _showMessage(error);
      return;
    }
    final amount = _parseAmount()!;
    final bankAccount = widget.linkedBankAccount!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.text('confirmWithdrawal')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.text('amount')}: ${formatVnd(amount)}'),
              Text(
                '${l10n.text('linkedBankAccount')}: ${bankAccount.bankName} ${bankAccount.accountNumberMasked}',
              ),
              Text('${l10n.text('withdrawalFee')}: 0đ'),
              Text(
                '${l10n.text('estimatedProcessingTime')}: '
                '${l10n.text('processingTimeValue')}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(walletControllerProvider.notifier)
          .createWithdrawalRequest(
            amount: amount,
            bankAccountId: bankAccount.bankAccountId,
          );
      if (!mounted) {
        return;
      }
      _showMessage(l10n.text('withdrawalRequestSubmitted'));
      Navigator.of(context).pop();
    } catch (_) {
      _showMessage(l10n.unknownError);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bankAccount = widget.linkedBankAccount;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('withdrawFunds'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${l10n.text('availableBalance')}: ${formatVnd(widget.wallet.availableBalance)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.text('withdrawalAmount'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(l10n.text('linkedBankAccount')),
                subtitle: Text(
                  bankAccount == null
                      ? l10n.text('bankAccountRequired')
                      : '${bankAccount.bankName} ${bankAccount.accountNumberMasked}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.text('estimatedProcessingTime')}: '
              '${l10n.text('processingTimeValue')}',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.text('submitWithdrawalRequest')),
            ),
          ],
        ),
      ),
    );
  }
}
