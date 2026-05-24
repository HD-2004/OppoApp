import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/linked_bank_account.dart';

class LinkedBankAccountCard extends StatelessWidget {
  const LinkedBankAccountCard({
    super.key,
    required this.account,
    required this.onManage,
  });

  final LinkedBankAccount? account;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bankAccount = account;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: bankAccount == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.text('linkedBankAccount'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.text('noLinkedBankAccount')),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.text('linkBankAccountToWithdraw')),
                  ),
                ],
              )
            : Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.account_balance)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bankAccount.bankName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(bankAccount.accountNumberMasked),
                        Text(bankAccount.accountHolderName),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onManage,
                    child: Text(l10n.text('manage')),
                  ),
                ],
              ),
      ),
    );
  }
}
