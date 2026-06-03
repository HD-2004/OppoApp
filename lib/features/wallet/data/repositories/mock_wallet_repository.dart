import '../../domain/entities/linked_bank_account.dart';
import '../../domain/entities/revenue_statistics.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/repositories/wallet_repository.dart';

class MockWalletRepository implements WalletRepository {
  WalletOverview _wallet = const WalletOverview(
    availableBalance: 520000,
    pendingBalance: 180000,
    totalEarnings: 2450000,
    currency: 'VND',
    status: WalletStatus.active,
  );

  LinkedBankAccount? _linkedBankAccount = const LinkedBankAccount(
    bankAccountId: 'bank_001',
    bankName: 'BIDV',
    accountHolderName: 'NGUYEN VAN A',
    accountNumberMasked: '•••• 1234',
    isDefault: true,
    branch: 'Ho Chi Minh',
  );

  final List<WalletTransaction> _transactions = [
    WalletTransaction(
      transactionId: 'txn_001',
      type: WalletTransactionType.earning,
      amount: 220000,
      currency: 'VND',
      status: WalletTransactionStatus.completed,
      description: 'Completed shift: Warehouse assistant',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    WalletTransaction(
      transactionId: 'txn_002',
      type: WalletTransactionType.withdrawal,
      amount: -300000,
      currency: 'VND',
      status: WalletTransactionStatus.pending,
      description: 'Withdrawal to BIDV •••• 1234',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    WalletTransaction(
      transactionId: 'txn_003',
      type: WalletTransactionType.earning,
      amount: 180000,
      currency: 'VND',
      status: WalletTransactionStatus.completed,
      description: 'Completed shift: Cafe evening shift',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  @override
  Future<WalletOverview> getWalletOverview() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _wallet;
  }

  @override
  Future<List<WalletTransaction>> getTransactions({
    WalletTransactionType? type,
    WalletTransactionStatus? status,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _transactions.where((transaction) {
      final typeMatches = type == null || transaction.type == type;
      final statusMatches = status == null || transaction.status == status;
      return typeMatches && statusMatches;
    }).toList();
  }

  @override
  Future<LinkedBankAccount?> getLinkedBankAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _linkedBankAccount;
  }

  @override
  Future<LinkedBankAccount> linkBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? branch,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final account = LinkedBankAccount(
      bankAccountId: 'bank_${DateTime.now().millisecondsSinceEpoch}',
      bankName: bankName.trim(),
      accountHolderName: accountHolderName.trim().toUpperCase(),
      accountNumberMasked: _maskAccountNumber(accountNumber),
      isDefault: true,
      branch: branch?.trim().isEmpty == true ? null : branch?.trim(),
    );
    _linkedBankAccount = account;
    return account;
  }

  @override
  Future<void> removeBankAccount({required String bankAccountId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (_linkedBankAccount?.bankAccountId == bankAccountId) {
      _linkedBankAccount = null;
    }
  }

  @override
  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
    String? branch,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_wallet.isActive) {
      throw StateError('wallet_inactive');
    }
    if (amount <= 0 || amount > _wallet.availableBalance) {
      throw StateError('insufficient_balance');
    }

    final requestId = 'withdraw_${DateTime.now().millisecondsSinceEpoch}';
    final request = WithdrawalRequest(
      withdrawalRequestId: requestId,
      amount: amount,
      currency: _wallet.currency,
      bankAccountId: 'mock_bank_id',
      bankName: bankName,
      accountNumberMasked: _maskAccountNumber(accountNumber),
      status: WalletTransactionStatus.pending,
      requestedAt: DateTime.now(),
    );

    _transactions.insert(
      0,
      WalletTransaction(
        transactionId: 'txn_$requestId',
        type: WalletTransactionType.withdrawal,
        amount: -amount,
        currency: _wallet.currency,
        status: WalletTransactionStatus.pending,
        description:
            'Withdrawal to $bankName ${_maskAccountNumber(accountNumber)}',
        createdAt: request.requestedAt,
      ),
    );
    _wallet = _wallet.copyWith(
      availableBalance: _wallet.availableBalance - amount,
    );
    return request;
  }

  @override
  Future<RevenueStatistics> getRevenueStatistics() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const RevenueStatistics(
      thisWeekIncome: 450000,
      thisMonthIncome: 2450000,
      completedShifts: 12,
      averageIncomePerShift: 204000,
    );
  }

  String _maskAccountNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final suffix = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    return '•••• $suffix';
  }
}
