import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String repositorySource;
  late String screenSource;
  late String routerSource;

  setUpAll(() {
    repositorySource = File(
      'lib/features/candidate/data/ekyc_repository.dart',
    ).readAsStringSync();
    screenSource = File(
      'lib/features/candidate/presentation/kyc_verification_screen.dart',
    ).readAsStringSync();
    routerSource = File('lib/app/router.dart').readAsStringSync();
  });

  test('candidate ekyc repository uses Didit session flow only', () {
    expect(repositorySource, contains('/ekyc/session'));
    expect(repositorySource, contains('/ekyc/status/'));
    expect(repositorySource, contains('createVerificationSession'));

    expect(repositorySource, isNot(contains('/ekyc/ocr')));
    expect(repositorySource, isNot(contains('/ekyc/verify-face')));
    expect(repositorySource, isNot(contains('ocrCCCD')));
    expect(repositorySource, isNot(contains('verifyFace')));
  });

  test('candidate kyc screen follows Didit redirect and polling flow', () {
    expect(screenSource, contains('Mở Trang Xác Minh Didit'));
    expect(screenSource, contains('_KycPhase.polling'));
    expect(screenSource, contains('_pollMaxAttempts = 60'));
    expect(
      screenSource,
      contains('fragment: \'/candidate/kyc?status=completed\''),
    );
    expect(screenSource, contains('LaunchMode.externalApplication'));

    expect(screenSource, isNot(contains('ImagePicker')));
    expect(screenSource, isNot(contains('XFile')));
    expect(screenSource, isNot(contains('VNPT')));
    expect(screenSource, isNot(contains('Gửi Đọc Thông Tin CCCD')));
  });

  test('router allows Didit callback to open candidate kyc route', () {
    expect(routerSource, contains("path: '/candidate/kyc'"));
    expect(routerSource, contains('callbackStatus'));
    expect(routerSource, isNot(contains("location == '/candidate/kyc' ||")));
  });
}
