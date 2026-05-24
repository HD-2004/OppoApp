class LinkedBankAccount {
  const LinkedBankAccount({
    required this.bankAccountId,
    required this.bankName,
    required this.accountHolderName,
    required this.accountNumberMasked,
    required this.isDefault,
    this.branch,
  });

  final String bankAccountId;
  final String bankName;
  final String accountHolderName;
  final String accountNumberMasked;
  final bool isDefault;
  final String? branch;

  LinkedBankAccount copyWith({
    String? bankAccountId,
    String? bankName,
    String? accountHolderName,
    String? accountNumberMasked,
    bool? isDefault,
    String? branch,
  }) {
    return LinkedBankAccount(
      bankAccountId: bankAccountId ?? this.bankAccountId,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumberMasked: accountNumberMasked ?? this.accountNumberMasked,
      isDefault: isDefault ?? this.isDefault,
      branch: branch ?? this.branch,
    );
  }
}
