import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/policies/data/policy_document_parser.dart';
import 'package:oppo_temp_jobs/features/policies/data/policy_repository.dart';

void main() {
  const source = '''
ỐP PỜ
Nền tảng tuyển dụng thời vụ F&B
TÀI LIỆU CHÍNH SÁCH NỀN TẢNG

Phiên bản 1.0  |  Cập nhật: 2026
Áp dụng cho: Ứng viên • Nhà tuyển dụng • Đối tác

CHÍNH SÁCH 01:
ĐIỀU KHOẢN SỬ DỤNG CHUNG
Áp dụng cho: Tất cả người dùng (Ứng viên & Nhà tuyển dụng)
Nền tảng: Web & App
Hiệu lực: Ngay khi đăng ký tài khoản

Khi đăng ký và sử dụng Ốp Pờ, bạn đồng ý tuân thủ toàn bộ các điều khoản dưới đây.

CHÍNH SÁCH 02:
BẢO MẬT & DỮ LIỆU CÁ NHÂN
Áp dụng cho: Tất cả người dùng
Nền tảng: Web & App
Tiêu chuẩn: Tuân thủ Luật An ninh mạng và Nghị định 13/2023/NĐ-CP

Ốp Pờ hiểu rằng thông tin cá nhân của bạn rất quan trọng.
''';

  test('parses supplied policy document without rewriting content', () {
    final document = PolicyDocumentParser.parse(source);

    expect(document.version, 'Phiên bản 1.0');
    expect(document.updatedAt, 'Cập nhật: 2026');
    expect(document.policies, hasLength(2));
    expect(document.policies.first.slug, 'dieu-khoan-su-dung-chung');
    expect(document.policies.first.title, 'ĐIỀU KHOẢN SỬ DỤNG CHUNG');
    expect(document.policies.first.effectiveDate, 'Ngay khi đăng ký tài khoản');
    expect(
      document.policies.first.content,
      contains(
        'Khi đăng ký và sử dụng Ốp Pờ, bạn đồng ý tuân thủ toàn bộ các điều khoản dưới đây.',
      ),
    );
    expect(
      document.policies.first.content,
      isNot(contains('Tìm kiếm sẽ được')),
    );
  });

  test('returns an empty document when source content is blank', () {
    final document = PolicyDocumentParser.parse('   ');

    expect(document.policies, isEmpty);
    expect(document.version, isNull);
    expect(document.updatedAt, isNull);
  });

  test('loads the supplied Oppo policy content', () async {
    final document = await const BundledPolicyRepository().loadPolicies();

    expect(document.version, 'Phiên bản 1.0');
    expect(document.updatedAt, 'Cập nhật: 2026');
    expect(document.policies, hasLength(9));
    expect(
      document.policies.map((policy) => policy.title),
      containsAll([
        'ĐIỀU KHOẢN SỬ DỤNG CHUNG',
        'BẢO MẬT & DỮ LIỆU CÁ NHÂN',
        'VI PHẠM & XỬ LÝ TÀI KHOẢN',
      ]),
    );
  });
}
