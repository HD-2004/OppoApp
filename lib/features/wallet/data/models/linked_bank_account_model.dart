import '../../domain/entities/linked_bank_account.dart';

class LinkedBankAccountModel extends LinkedBankAccount {
  const LinkedBankAccountModel({
    required super.bankAccountId,
    required super.bankName,
    required super.accountHolderName,
    required super.accountNumberMasked,
    required super.isDefault,
    super.branch,
  });

  factory LinkedBankAccountModel.fromJson(Map<String, dynamic> json) {
    return LinkedBankAccountModel(
      bankAccountId: json['bankAccountId'] as String,
      bankName: json['bankName'] as String,
      accountHolderName: json['accountHolderName'] as String,
      accountNumberMasked: json['accountNumberMasked'] as String,
      isDefault: json['isDefault'] as bool? ?? true,
      branch: json['branch'] as String?,
    );
  }
}
