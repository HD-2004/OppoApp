import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/linked_bank_account.dart';
import '../../domain/entities/revenue_statistics.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/repositories/wallet_repository.dart';

class ApiWalletRepository implements WalletRepository {
  ApiWalletRepository();

  static const _profileBaseUrl =
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _applicationsBaseUrl =
      'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com';
  static const _quickJobsBaseUrl =
      'https://6zw89pkuxb.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _notificationsBaseUrl =
      'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com';

  // In-memory cache to prevent duplicate HTTP requests in parallel _load calls
  Map<String, dynamic>? _cachedProfile;
  List<dynamic>? _cachedApps;
  List<dynamic>? _cachedJobs;
  DateTime? _lastCacheTime;

  static const _cacheDuration = Duration(seconds: 5);

  Future<String?> _getAuthToken() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      return tokens?.idToken.raw;
    } catch (e) {
      safePrint('Error getting auth token: $e');
      return null;
    }
  }

  Future<String?> _getUserId() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      return tokens?.idToken.claims.subject;
    } catch (e) {
      safePrint('Error getting userId: $e');
      return null;
    }
  }

  Map<String, String> _buildHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> _fetchProfile(
    String userId,
    String? token,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$_profileBaseUrl/profile/$userId'),
        headers: _buildHeaders(token),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      safePrint('Error fetching profile: $e');
    }
    return null;
  }

  Future<List<dynamic>> _fetchApplications(String userId, String? token) async {
    try {
      final response = await http.get(
        Uri.parse('$_applicationsBaseUrl/applications/candidate/$userId'),
        headers: _buildHeaders(token),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['applications'] != null) {
          return body['applications'] as List<dynamic>;
        }
      }
    } catch (e) {
      safePrint('Error fetching applications: $e');
    }
    return [];
  }

  Future<List<dynamic>> _fetchQuickJobs(String? token) async {
    try {
      final response = await http.get(
        Uri.parse('$_quickJobsBaseUrl/quick-jobs'),
        headers: _buildHeaders(token),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (e) {
      safePrint('Error fetching quick jobs from base URL: $e');
    }

    // Fallback to active quick jobs
    try {
      final response = await http.get(
        Uri.parse('$_quickJobsBaseUrl/quick-jobs/active'),
        headers: _buildHeaders(token),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          return body['data'] as List<dynamic>;
        }
      }
    } catch (e) {
      safePrint('Error fetching active quick jobs: $e');
    }
    return [];
  }

  Future<void> _updateProfileFields(
    String userId,
    String? token,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.put(
      Uri.parse('$_profileBaseUrl/profile/$userId'),
      headers: _buildHeaders(token),
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update profile fields: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> _sendNotificationToAdmin(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$_notificationsBaseUrl/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        safePrint('Failed to send admin notification: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error sending admin notification: $e');
    }
  }

  Future<void> _ensureCache(String userId, String? token) async {
    final now = DateTime.now();
    if (_lastCacheTime != null &&
        now.difference(_lastCacheTime!) < _cacheDuration &&
        _cachedProfile != null &&
        _cachedApps != null &&
        _cachedJobs != null) {
      return;
    }

    final results = await Future.wait([
      _fetchProfile(userId, token),
      _fetchApplications(userId, token),
      _fetchQuickJobs(token),
    ]);

    _cachedProfile = results[0] as Map<String, dynamic>?;
    _cachedApps = results[1] as List<dynamic>;
    _cachedJobs = results[2] as List<dynamic>;
    _lastCacheTime = now;
  }

  void _invalidateCache() {
    _cachedProfile = null;
    _cachedApps = null;
    _cachedJobs = null;
    _lastCacheTime = null;
  }

  // Parses status string from DynamoDB into WalletTransactionStatus
  WalletTransactionStatus _parseStatus(String statusStr) {
    return switch (statusStr.toLowerCase()) {
      'approved' => WalletTransactionStatus.completed,
      'rejected' => WalletTransactionStatus.failed,
      'processing' => WalletTransactionStatus.processing,
      'cancelled' => WalletTransactionStatus.cancelled,
      _ => WalletTransactionStatus.pending,
    };
  }

  String _maskAccountNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final suffix = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    return '•••• $suffix';
  }

  // Internal helper to calculate wallet overview and transaction list from cached data
  Future<Map<String, dynamic>> _getCalculatedData() async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _ensureCache(userId, token);

    final profile = _cachedProfile;
    final apps = _cachedApps ?? [];
    final quickJobs = _cachedJobs ?? [];

    // 1. Calculate dynamic income transactions from completed applications in database
    final List<WalletTransaction> incomeTransactions = [];
    for (final app in apps) {
      if (app['status'] == 'completed') {
        final jobId = app['jobId']?.toString();
        // Find matching job
        final job = quickJobs.firstWhere(
          (j) =>
              j['idJob']?.toString() == jobId ||
              j['id']?.toString() == jobId ||
              j['jobID']?.toString() == jobId,
          orElse: () => null,
        );

        double totalSalary = 0;
        String companyName = 'Nhà tuyển dụng';
        String jobTitle = 'Công việc tuyển gấp';

        if (job != null) {
          totalSalary =
              double.tryParse(job['totalSalary']?.toString() ?? '') ?? 0;
          if (totalSalary == 0) {
            final hourlyRate =
                double.tryParse(job['hourlyRate']?.toString() ?? '') ?? 0;
            final totalHours =
                double.tryParse(job['totalHours']?.toString() ?? '') ?? 0;
            totalSalary = hourlyRate * totalHours;
          }
          companyName =
              job['companyName']?.toString() ??
              job['employerName']?.toString() ??
              'Nhà tuyển dụng';
          jobTitle = job['title']?.toString() ?? 'Công việc tuyển gấp';
        }

        final candidateAmount = (totalSalary * 0.85).roundToDouble();
        if (candidateAmount > 0) {
          final confirmedAtStr =
              app['candidateConfirmedAt']?.toString() ??
              app['updatedAt']?.toString() ??
              app['createdAt']?.toString();
          final date = confirmedAtStr != null
              ? DateTime.tryParse(confirmedAtStr) ?? DateTime.now()
              : DateTime.now();

          incomeTransactions.add(
            WalletTransaction(
              transactionId: 'income-${app['applicationId'] ?? app['id']}',
              type: WalletTransactionType.earning,
              amount: candidateAmount,
              currency: 'VND',
              status: WalletTransactionStatus.completed,
              description: 'Nhận tiền từ $companyName ($jobTitle)',
              createdAt: date,
            ),
          );
        }
      }
    }

    // 2. Get withdrawal transactions from database candidate profile
    final List<WalletTransaction> withdrawalTransactions = [];
    final List<dynamic> savedWithdrawals =
        profile?['withdrawals'] as List<dynamic>? ?? [];

    for (final w in savedWithdrawals) {
      final map = w as Map<String, dynamic>;
      final String id = map['id']?.toString() ?? 'withdraw-${map['date']}';
      final double amount = (map['amount'] as num?)?.toDouble() ?? 0;
      final String bankName = map['bankName']?.toString() ?? '';
      final String accountNumber = map['accountNumber']?.toString() ?? '';
      final String dateStr =
          map['date']?.toString() ?? DateTime.now().toIso8601String();
      final DateTime date = DateTime.tryParse(dateStr) ?? DateTime.now();

      final String statusStr = map['status']?.toString() ?? 'pending';
      final WalletTransactionStatus status = _parseStatus(statusStr);

      withdrawalTransactions.add(
        WalletTransaction(
          transactionId: id,
          type: WalletTransactionType.withdrawal,
          amount: -amount.abs(), // Ensure negative
          currency: 'VND',
          status: status,
          description: 'Rút tiền về tài khoản $bankName - $accountNumber',
          createdAt: date,
        ),
      );

      // Add Refund if rejected
      if (statusStr.toLowerCase() == 'rejected') {
        withdrawalTransactions.add(
          WalletTransaction(
            transactionId: 'refund-$id',
            type: WalletTransactionType.refund,
            amount: amount.abs(), // Positive refund amount
            currency: 'VND',
            status: WalletTransactionStatus.completed,
            description: 'Hoàn trả giao dịch rút tiền bị từ chối',
            createdAt: date,
          ),
        );
      }
    }

    // Combine and sort
    final List<WalletTransaction> mergedTx = [
      ...incomeTransactions,
      ...withdrawalTransactions,
    ];
    mergedTx.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Calculate balances
    double sumIncome = 0;
    for (final tx in incomeTransactions) {
      sumIncome += tx.amount;
    }

    double sumWithdrawn = 0;
    double pendingWithdrawals = 0;

    for (final w in savedWithdrawals) {
      final map = w as Map<String, dynamic>;
      final String statusStr = map['status']?.toString() ?? 'pending';
      if (statusStr.toLowerCase() != 'rejected') {
        final double amount = (map['amount'] as num?)?.toDouble() ?? 0;
        sumWithdrawn += amount.abs();
      }
      if (statusStr.toLowerCase() == 'pending') {
        final double amount = (map['amount'] as num?)?.toDouble() ?? 0;
        pendingWithdrawals += amount.abs();
      }
    }

    final double availableBalance = sumIncome - sumWithdrawn;
    final double totalEarnings = sumIncome;

    final wallet = WalletOverview(
      availableBalance: availableBalance,
      pendingBalance: pendingWithdrawals,
      totalEarnings: totalEarnings,
      currency: 'VND',
      status: WalletStatus.active,
    );

    return {
      'wallet': wallet,
      'transactions': mergedTx,
      'incomeTransactions': incomeTransactions,
    };
  }

  @override
  Future<WalletOverview> getWalletOverview() async {
    final data = await _getCalculatedData();
    return data['wallet'] as WalletOverview;
  }

  @override
  Future<List<WalletTransaction>> getTransactions({
    WalletTransactionType? type,
    WalletTransactionStatus? status,
  }) async {
    final data = await _getCalculatedData();
    final list = data['transactions'] as List<WalletTransaction>;
    return list.where((transaction) {
      final typeMatches = type == null || transaction.type == type;
      final statusMatches = status == null || transaction.status == status;
      return typeMatches && statusMatches;
    }).toList();
  }

  @override
  Future<LinkedBankAccount?> getLinkedBankAccount() async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    if (userId == null) {
      return null;
    }

    await _ensureCache(userId, token);
    final profile = _cachedProfile;

    if (profile != null && profile['linkedBankAccount'] != null) {
      final linkedBank = profile['linkedBankAccount'] as Map<String, dynamic>;
      final bankName = linkedBank['bankName']?.toString() ?? '';
      final accountNumber = linkedBank['accountNumber']?.toString() ?? '';
      final accountHolderName =
          linkedBank['accountHolderName']?.toString() ?? '';
      final branch = linkedBank['branch']?.toString();

      return LinkedBankAccount(
        bankAccountId: 'default_linked_bank',
        bankName: bankName,
        accountHolderName: accountHolderName,
        accountNumberMasked: _maskAccountNumber(accountNumber),
        isDefault: true,
        branch: branch,
      );
    }
    return null;
  }

  @override
  Future<LinkedBankAccount> linkBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? branch,
  }) async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final bankInfo = {
      'bankName': bankName,
      'accountHolderName': accountHolderName.toUpperCase(),
      'accountNumber': accountNumber,
      'branch': ?branch,
    };

    await _updateProfileFields(userId, token, {'linkedBankAccount': bankInfo});

    _invalidateCache();

    return LinkedBankAccount(
      bankAccountId: 'default_linked_bank',
      bankName: bankName,
      accountHolderName: accountHolderName.toUpperCase(),
      accountNumberMasked: _maskAccountNumber(accountNumber),
      isDefault: true,
      branch: branch,
    );
  }

  @override
  Future<void> removeBankAccount({required String bankAccountId}) async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _updateProfileFields(userId, token, {'linkedBankAccount': null});

    _invalidateCache();
  }

  @override
  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
    String? branch,
  }) async {
    final token = await _getAuthToken();
    final userId = await _getUserId();
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Fetch fresh profile to get withdrawals list
    final profile = await _fetchProfile(userId, token);
    if (profile == null) {
      throw Exception('Candidate profile not found');
    }

    final newWithdrawalId = 'WITHDRAW-${DateTime.now().millisecondsSinceEpoch}';
    final nowIso = DateTime.now().toIso8601String();

    final newWithdrawal = {
      'id': newWithdrawalId,
      'type': 'expense',
      'title': 'Rút tiền về ngân hàng',
      'description': 'Chuyển về tài khoản $bankName - $accountNumber',
      'amount': -amount.abs(),
      'date': nowIso,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountHolderName.toUpperCase(),
      'status': 'pending',
    };

    final existingWithdrawals = profile['withdrawals'] as List<dynamic>? ?? [];
    final updatedWithdrawals = [newWithdrawal, ...existingWithdrawals];

    await _updateProfileFields(userId, token, {
      'withdrawals': updatedWithdrawals,
    });

    // Send admin notification
    final notificationPayload = {
      'type': 'candidate_withdrawal_request',
      'title': 'Yêu cầu rút tiền từ ứng viên',
      'titleEn': 'New Candidate Withdrawal Request',
      'message':
          '${profile['fullName'] ?? 'Ứng viên'} yêu cầu rút số tiền ${amount.round()} VND về ngân hàng $bankName.',
      'messageEn':
          '${profile['fullName'] ?? 'Ứng viên'} requested to withdraw ${amount.round()} VND to bank $bankName.',
      'recipientId': 'admin',
      'recipientRole': 'admin',
      'senderId': userId,
      'senderName': profile['fullName'] ?? 'Ứng viên',
      'data': {
        'withdrawalId': newWithdrawalId,
        'amount': amount,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountHolderName.toUpperCase(),
        'candidateId': userId,
      },
      'icon': 'dollar-sign',
      'color': '#3b82f6',
      'actionUrl': '/admin/candidates',
      'actionText': 'Xem chi tiết',
      'actionTextEn': 'View Details',
    };

    await _sendNotificationToAdmin(notificationPayload);

    _invalidateCache();

    return WithdrawalRequest(
      withdrawalRequestId: newWithdrawalId,
      amount: amount,
      currency: 'VND',
      bankAccountId: 'direct_withdrawal',
      bankName: bankName,
      accountNumberMasked: _maskAccountNumber(accountNumber),
      status: WalletTransactionStatus.pending,
      requestedAt: DateTime.parse(nowIso),
    );
  }

  @override
  Future<RevenueStatistics> getRevenueStatistics() async {
    final data = await _getCalculatedData();
    final incomeTransactions =
        data['incomeTransactions'] as List<WalletTransaction>;
    final wallet = data['wallet'] as WalletOverview;

    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final currentMonthStart = DateTime(now.year, now.month, 1);

    double thisWeekIncome = 0;
    double thisMonthIncome = 0;

    for (final tx in incomeTransactions) {
      if (tx.createdAt.isAfter(oneWeekAgo)) {
        thisWeekIncome += tx.amount;
      }
      if (tx.createdAt.isAfter(currentMonthStart)) {
        thisMonthIncome += tx.amount;
      }
    }

    final completedShifts = incomeTransactions.length;
    final averageIncome = completedShifts > 0
        ? wallet.totalEarnings / completedShifts
        : 0.0;

    return RevenueStatistics(
      thisWeekIncome: thisWeekIncome,
      thisMonthIncome: thisMonthIncome,
      completedShifts: completedShifts,
      averageIncomePerShift: averageIncome,
    );
  }
}
