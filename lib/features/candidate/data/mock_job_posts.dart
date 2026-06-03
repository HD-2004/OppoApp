import '../domain/job_post.dart';

/// DEPRECATED — Mock data không còn được dùng trong production.
/// Tất cả job data phải lấy từ [AwsJobRepository] qua [activeJobsProvider]
/// và [activeQuickJobsProvider].
/// Giữ lại file này để tránh break references cũ. Đừng thêm data mới vào đây.
@Deprecated(
  'Use activeJobsProvider or activeQuickJobsProvider instead. '
  'This mock data must not be used in production builds.',
)
List<JobPost> get mockJobPosts {
  final now = DateTime.now();

  return [
    JobPost(
      id: 'job-highlands-evening-shift',
      idJob: 'mock-highlands-evening-shift',
      employerId: 'mock-employer-highlands',
      employerName: 'Highlands Coffee',
      title: 'Phục vụ quán cà phê ca tối',
      jobType: JobPostType.urgent,
      location: 'Quận 1, TP.HCM',
      salary: '30.000đ/giờ',
      shiftTime: '18:00 - 22:00 hôm nay',
      description:
          'Hỗ trợ phục vụ khách, dọn bàn và chuẩn bị khu vực làm việc trong ca tối.',
      tags: ['Cần gấp', 'Gần bạn', 'Trả theo ca'],
      postedAt: now.subtract(const Duration(minutes: 18)),
    ),
    JobPost(
      id: 'job-minimart-weekend-sales',
      idJob: 'mock-minimart-weekend-sales',
      employerId: 'mock-employer-minimart',
      employerName: 'Mini Mart',
      title: 'Nhân viên bán hàng cuối tuần',
      jobType: JobPostType.partTime,
      location: 'Bình Thạnh, TP.HCM',
      salary: '25.000đ/giờ',
      shiftTime: 'Thứ 7 - Chủ nhật',
      description:
          'Sắp xếp hàng hóa, hỗ trợ thanh toán và tư vấn sản phẩm cho khách.',
      tags: ['Part-time', 'Cuối tuần'],
      postedAt: now.subtract(const Duration(hours: 2)),
    ),
    JobPost(
      id: 'job-fastlogistics-warehouse',
      idJob: 'mock-fastlogistics-warehouse',
      employerId: 'mock-employer-fastlogistics',
      employerName: 'Fast Logistics',
      title: 'Phụ kho thời vụ',
      jobType: JobPostType.urgent,
      location: 'Thủ Đức, TP.HCM',
      salary: '220.000đ/ca',
      shiftTime: '08:00 - 16:00',
      description:
          'Phân loại kiện hàng, đóng gói đơn và hỗ trợ nhập xuất kho theo ca.',
      tags: ['Công việc gấp', 'Theo ca'],
      postedAt: now.subtract(const Duration(hours: 5)),
    ),
  ];
}
