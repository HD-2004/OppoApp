import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/wallet/data/repositories/api_wallet_repository.dart';

void main() {
  test('calculates the candidate wallet from the shared web APIs', () async {
    final requestedQuickJobIds = <String>[];
    final client = MockClient((request) async {
      if (request.url.path == '/profile/candidate-1') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'withdrawals': [
                {'id': 'w1', 'amount': -175, 'status': 'approved'},
                {'id': 'w2', 'amount': -50, 'status': 'rejected'},
                {'id': 'w3', 'amount': -100, 'status': 'approved'},
              ],
            },
          }),
          200,
        );
      }

      if (request.url.path == '/applications/candidate/candidate-1') {
        return http.Response(
          jsonEncode({
            'applications': [
              {
                'applicationId': 'a1',
                'jobId': 'job-in-list',
                'status': 'completed',
              },
              {
                'applicationId': 'a2',
                'jobId': 'job-missing',
                'status': 'COMPLETED',
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/quick-jobs') {
        expect(request.headers['Authorization'], isNull);
        expect(request.headers['Content-Type'], isNull);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'jobID': 'job-in-list',
                'totalSalary': 1000,
                'companyName': 'Company A',
                'title': 'Job A',
              },
            ],
          }),
          200,
        );
      }

      if (request.url.path == '/quick-jobs/job-missing') {
        requestedQuickJobIds.add('job-missing');
        expect(request.headers['Authorization'], isNull);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'idJob': 'job-missing',
              'totalSalary': 1000,
              'companyName': 'Company B',
              'title': 'Job B',
            },
          }),
          200,
        );
      }

      return http.Response('Not found', 404);
    });

    final repository = ApiWalletRepository(
      client: client,
      tokenProvider: () async => 'id-token',
      userIdProvider: () async => 'candidate-1',
      profileBaseUrl: 'https://profile.example.com',
      applicationsBaseUrl: 'https://applications.example.com',
      quickJobsBaseUrl: 'https://quick-jobs.example.com',
      notificationsBaseUrl: 'https://notifications.example.com',
    );

    final wallet = await repository.getWalletOverview();

    expect(wallet.totalEarnings, 1700);
    expect(wallet.availableBalance, 1425);
    expect(wallet.pendingBalance, 0);
    expect(requestedQuickJobIds, ['job-missing']);
  });
}
