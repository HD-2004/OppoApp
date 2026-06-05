import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/wallet.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/wallet_formatters.dart';

class WithdrawFundsScreen extends ConsumerStatefulWidget {
  const WithdrawFundsScreen({super.key, required this.wallet});

  final WalletOverview wallet;

  @override
  ConsumerState<WithdrawFundsScreen> createState() =>
      _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends ConsumerState<WithdrawFundsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _branchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _holderNameController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  double? _parseAmount() {
    final digits = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    return double.tryParse(digits);
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).text('requiredField');
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).text('requiredField');
    }
    final text = value.trim();
    if (!RegExp(r'^\d{6,20}$').hasMatch(text)) {
      return AppLocalizations.of(context).text('invalidAccountNumber');
    }
    return null;
  }

  String? _validateAmount(String? value) {
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      return AppLocalizations.of(context).text('invalidAmount');
    }
    if (amount > widget.wallet.availableBalance) {
      return AppLocalizations.of(context).text('insufficientBalance');
    }
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _parseAmount()!;
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountHolderName = _holderNameController.text.trim().toUpperCase();
    final branch = _branchController.text.trim().isEmpty
        ? null
        : _branchController.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            l10n.text('confirmWithdrawal'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.text('amount')}: ${formatVnd(amount)}'),
              const SizedBox(height: 4),
              Text('${l10n.text('bankName')}: $bankName'),
              const SizedBox(height: 4),
              Text('${l10n.text('accountNumber')}: $accountNumber'),
              const SizedBox(height: 4),
              Text('${l10n.text('accountHolderName')}: $accountHolderName'),
              if (branch != null) ...[
                const SizedBox(height: 4),
                Text('${l10n.text('branch')}: $branch'),
              ],
              const Divider(height: 24),
              Text(
                '${l10n.text('estimatedProcessingTime')}: ${l10n.text('processingTimeValue')}',
                style: theme.textTheme.bodySmall,
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
            bankName: bankName,
            accountNumber: accountNumber,
            accountHolderName: accountHolderName,
            branch: branch,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.text('withdrawalRequestSubmitted')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unknownError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.text('withdrawFunds'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Modern Balance Display
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 5,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.text('availableBalance').toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatVnd(widget.wallet.availableBalance),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title Section
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.text('withdrawalAmount'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.text('withdrawalAmount'),
                  suffixText: 'VND',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateAmount,
              ),
              const SizedBox(height: 24),

              // Title Section for Bank Details
              Row(
                children: [
                  Icon(
                    Icons.credit_card_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thông tin ngân hàng nhận tiền',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: l10n.text('bankName'),
                  hintText: 'Ví dụ: Vietcombank, Techcombank, MB...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.text('accountNumber'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _validateAccountNumber,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _holderNameController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.text('accountHolderName'),
                  hintText: 'VIET HOA KHONG DAU',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _branchController,
                decoration: InputDecoration(
                  labelText: l10n.text('branchOptional'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                '• ${l10n.text('estimatedProcessingTime')}: ${l10n.text('processingTimeValue')}\n• Phí chuyển tiền: Miễn phí',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          l10n.text('submitWithdrawalRequest'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
