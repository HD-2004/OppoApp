import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../domain/shift_booking.dart';
import '../domain/urgent_shift_job.dart';
import 'urgent_shift_repository.dart';

class AwsUrgentShiftRepository implements UrgentShiftRepository {
  AwsUrgentShiftRepository({http.Client? client})
    : _client = client ?? http.Client();

  static const _quickJobsBaseUrl =
      'https://6zw89pkuxb.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _applicationsBaseUrl =
      'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com';
  static const _cvBaseUrl =
      'https://v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod';

  final http.Client _client;

  void close() => _client.close();

  @override
  Stream<List<UrgentShiftJob>> watchOpenJobs() async* {
    yield await _fetchJobs();
    yield* Stream<void>.periodic(
      const Duration(seconds: 15),
    ).asyncMap((_) => _fetchJobs());
  }

  @override
  Stream<List<UrgentShiftJob>> watchEmployerJobs(String employerId) async* {
    yield await _fetchJobs(employerId: employerId);
    yield* Stream<void>.periodic(
      const Duration(seconds: 15),
    ).asyncMap((_) => _fetchJobs(employerId: employerId));
  }

  @override
  Stream<ShiftBooking?> watchBooking(String bookingId) async* {
    yield await _fetchBooking(bookingId);
    yield* Stream<void>.periodic(
      const Duration(seconds: 15),
    ).asyncMap((_) => _fetchBooking(bookingId));
  }

  @override
  Future<ShiftBooking> claimShift({
    required String jobId,
    required String workerId,
  }) async {
    final auth = await _authContext();
    final cvs = await _fetchCvs(auth.userId, auth.token);
    if (cvs.isEmpty) {
      throw StateError('Vui lòng tải CV trước khi ứng tuyển.');
    }

    final cv = cvs.first;
    final response = await _client.post(
      Uri.parse('$_applicationsBaseUrl/applications'),
      headers: _headers(auth.token),
      body: jsonEncode({
        'jobId': jobId,
        'cvUrl': cv['cvUrl'],
        'cvFilename': cv['cvFileName'] ?? 'CV.pdf',
      }),
    );
    final body = _decode(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StateError(
        body['error']?.toString() ?? 'Không thể ứng tuyển công việc.',
      );
    }

    final raw = body['application'];
    if (raw is Map) {
      return _mapBooking(Map<String, dynamic>.from(raw));
    }
    return ShiftBooking(
      bookingId: body['applicationId']?.toString() ?? '',
      jobId: jobId,
      workerId: auth.userId,
      status: ShiftBookingStatus.accepted,
      paymentStatus: PaymentStatus.holdPending,
    );
  }

  @override
  Future<ShiftBooking> checkIn(String bookingId) {
    return _updateBooking(bookingId, 'checked_in', {
      'checkInAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<ShiftBooking> checkOut(String bookingId) {
    return _updateBooking(bookingId, 'checked_out', {
      'checkOutAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<ShiftBooking> confirm(String bookingId) {
    return _updateBooking(bookingId, 'completed', {
      'employerConfirmedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<ShiftBooking> dispute(String bookingId) {
    return _updateBooking(bookingId, 'disputed');
  }

  Future<List<UrgentShiftJob>> _fetchJobs({String? employerId}) async {
    final path = employerId == null
        ? '/quick-jobs/active'
        : '/quick-jobs/employer/${Uri.encodeComponent(employerId)}';
    final response = await _client.get(Uri.parse('$_quickJobsBaseUrl$path'));
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body['message']?.toString() ??
            'Không thể tải danh sách công việc tuyển gấp.',
      );
    }
    final raw = body['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => _mapJob(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<ShiftBooking?> _fetchBooking(String bookingId) async {
    final auth = await _authContext();
    final response = await _client.get(
      Uri.parse(
        '$_applicationsBaseUrl/applications/candidate/'
        '${Uri.encodeComponent(auth.userId)}',
      ),
      headers: _headers(auth.token),
    );
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body['error']?.toString() ?? 'Không thể tải trạng thái ứng tuyển.',
      );
    }
    final applications = body['applications'];
    if (applications is! List) return null;
    for (final raw in applications.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      if (item['applicationId']?.toString() == bookingId) {
        return _mapBooking(item);
      }
    }
    return null;
  }

  Future<ShiftBooking> _updateBooking(
    String bookingId,
    String status, [
    Map<String, dynamic> extra = const {},
  ]) async {
    final auth = await _authContext();
    final response = await _client.put(
      Uri.parse(
        '$_applicationsBaseUrl/applications/'
        '${Uri.encodeComponent(bookingId)}/status',
      ),
      headers: _headers(auth.token),
      body: jsonEncode({'status': status, ...extra}),
    );
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        body['error']?.toString() ?? 'Không thể cập nhật trạng thái công việc.',
      );
    }
    final raw = body['application'] ?? body['data'];
    if (raw is Map) {
      return _mapBooking(Map<String, dynamic>.from(raw));
    }
    final booking = await _fetchBooking(bookingId);
    if (booking == null) {
      throw StateError('Không tìm thấy dữ liệu ứng tuyển sau khi cập nhật.');
    }
    return booking;
  }

  Future<List<Map<String, dynamic>>> _fetchCvs(
    String userId,
    String token,
  ) async {
    final response = await _client.get(
      Uri.parse('$_cvBaseUrl/cv/${Uri.encodeComponent(userId)}'),
      headers: _headers(token),
    );
    final body = _decode(response);
    if (response.statusCode == 404) return const [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(body['error']?.toString() ?? 'Không thể tải CV.');
    }
    final list = body['cvList'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return body['cvUrl'] == null ? const [] : [body];
  }

  Future<_AuthContext> _authContext() async {
    final plugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
    final session = await plugin.fetchAuthSession();
    final tokens = session.userPoolTokensResult.valueOrNull;
    final token = tokens?.idToken.raw;
    final userId = tokens?.idToken.claims.subject;
    if (token == null || userId == null || userId.isEmpty) {
      throw StateError('Không tìm thấy phiên đăng nhập.');
    }
    return _AuthContext(token: token, userId: userId);
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  UrgentShiftJob _mapJob(Map<String, dynamic> job) {
    final requiredWorkers = _int(
      job['requiredWorkers'] ?? job['numberOfWorkers'] ?? 1,
    ).clamp(1, 999);
    final acceptedWorkers = _int(job['applicants']).clamp(0, requiredWorkers);
    final start = _jobDateTime(job['workDate'], job['startTime']);
    var end = _jobDateTime(job['workDate'], job['endTime']);
    if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));
    return UrgentShiftJob(
      jobId: (job['jobID'] ?? job['idJob'] ?? '').toString(),
      employerId: job['employerId']?.toString() ?? '',
      title: job['title']?.toString() ?? 'Công việc tuyển gấp',
      category: job['category']?.toString() ?? 'Tuyển gấp',
      address: job['location']?.toString() ?? '',
      latitude: _double(job['latitude'] ?? job['lat']),
      longitude: _double(job['longitude'] ?? job['lng']),
      startTime: start,
      endTime: end,
      payAmount: _int(job['totalSalary']),
      currency: 'VND',
      requiredWorkers: requiredWorkers,
      acceptedWorkers: acceptedWorkers,
      status: _jobStatus(job['status']?.toString()),
    );
  }

  ShiftBooking _mapBooking(Map<String, dynamic> item) {
    final status = _bookingStatus(item['status']?.toString());
    return ShiftBooking(
      bookingId: item['applicationId']?.toString() ?? '',
      jobId: item['jobId']?.toString() ?? '',
      workerId: item['candidateId']?.toString() ?? '',
      status: status,
      paymentStatus: _paymentStatus(status),
      checkInAt: DateTime.tryParse(item['checkInAt']?.toString() ?? ''),
      checkOutAt: DateTime.tryParse(item['checkOutAt']?.toString() ?? ''),
      employerConfirmedAt: DateTime.tryParse(
        item['employerConfirmedAt']?.toString() ?? '',
      ),
    );
  }

  DateTime _jobDateTime(dynamic date, dynamic time) {
    final dateText = date?.toString().trim() ?? '';
    final timeText = time?.toString().trim() ?? '';
    return DateTime.tryParse(
          timeText.isEmpty ? dateText : '${dateText}T$timeText',
        ) ??
        DateTime.now();
  }

  UrgentShiftStatus _jobStatus(String? raw) {
    return switch (raw?.toLowerCase()) {
      'draft' || 'pending' => UrgentShiftStatus.draft,
      'filled' => UrgentShiftStatus.filled,
      'in_progress' || 'in-progress' => UrgentShiftStatus.inProgress,
      'completed' => UrgentShiftStatus.completed,
      'cancelled' || 'canceled' => UrgentShiftStatus.cancelled,
      _ => UrgentShiftStatus.open,
    };
  }

  ShiftBookingStatus _bookingStatus(String? raw) {
    return switch (raw?.toLowerCase()) {
      'checked_in' || 'checked-in' => ShiftBookingStatus.checkedIn,
      'checked_out' || 'checked-out' => ShiftBookingStatus.checkedOut,
      'completed' => ShiftBookingStatus.completed,
      'cancelled' || 'canceled' || 'rejected' => ShiftBookingStatus.cancelled,
      'disputed' => ShiftBookingStatus.disputed,
      _ => ShiftBookingStatus.accepted,
    };
  }

  PaymentStatus _paymentStatus(ShiftBookingStatus status) {
    return switch (status) {
      ShiftBookingStatus.accepted => PaymentStatus.holdPending,
      ShiftBookingStatus.checkedIn => PaymentStatus.held,
      ShiftBookingStatus.checkedOut => PaymentStatus.releasePending,
      ShiftBookingStatus.completed => PaymentStatus.released,
      ShiftBookingStatus.cancelled => PaymentStatus.refundPending,
      ShiftBookingStatus.disputed => PaymentStatus.disputed,
    };
  }

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  double _double(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class _AuthContext {
  const _AuthContext({required this.token, required this.userId});

  final String token;
  final String userId;
}
