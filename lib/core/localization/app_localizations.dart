import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('vi'), Locale('en')];
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  bool get isVietnamese => locale.languageCode == 'vi';

  String text(String key) {
    final language = _localizedValues[locale.languageCode] ?? _vi;
    return language[key] ?? _vi[key] ?? key;
  }

  String format(String key, Map<String, String> values) {
    var value = text(key);
    for (final entry in values.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  String get appName => text('appName');
  String get loading => text('loading');
  String get error => text('error');
  String get success => text('success');
  String get cancel => text('cancel');
  String get confirm => text('confirm');
  String get save => text('save');
  String get submit => text('submit');
  String get retry => text('retry');
  String get back => text('back');
  String get continueText => text('continueText');
  String get search => text('search');
  String get signIn => text('signIn');
  String get signUp => text('signUp');
  String get signOut => text('signOut');
  String get email => text('email');
  String get password => text('password');
  String get confirmPassword => text('confirmPassword');
  String get fullName => text('fullName');
  String get forgotPassword => text('forgotPassword');
  String get resetPassword => text('resetPassword');
  String get currentPassword => text('currentPassword');
  String get newPassword => text('newPassword');
  String get confirmNewPassword => text('confirmNewPassword');
  String get changePassword => text('changePassword');
  String get confirmSignUp => text('confirmSignUp');
  String get verificationCode => text('verificationCode');
  String get resendCode => text('resendCode');
  String get home => text('home');
  String get jobs => text('jobs');
  String get notifications => text('notifications');
  String get profile => text('profile');
  String get settings => text('settings');
  String get partTime => text('partTime');
  String get nearby => text('nearby');
  String get highSalary => text('highSalary');
  String get todayShift => text('todayShift');
  String get saveJob => text('saveJob');
  String get jobDetails => text('jobDetails');
  String get noJobsFound => text('noJobsFound');
  String get apply => text('apply');
  String get salary => text('salary');
  String get checkIn => text('checkIn');
  String get checkOut => text('checkOut');
  String get candidate => text('candidate');
  String get employer => text('employer');
  String get support => text('support');
  String get digitalWallet => text('digitalWallet');
  String get location => text('location');
  String get available => text('available');
  String get off => text('off');
  String get weakPassword => text('weakPassword');
  String get passwordMismatch => text('passwordMismatch');
  String get unknownError => text('unknownError');
  String get networkError => text('networkError');
  String get wrongCurrentPassword => text('wrongCurrentPassword');
  String get emailRequired => text('emailRequired');
  String get passwordRequired => text('passwordRequired');
  String get appearance => text('appearance');
  String get themeMode => text('themeMode');
  String get systemDefault => text('systemDefault');
  String get lightMode => text('lightMode');
  String get darkMode => text('darkMode');
  String get language => text('language');
  String get appLanguage => text('appLanguage');
  String get security => text('security');
  String get notificationPreferences => text('notificationPreferences');
  String get account => text('account');
  String get deleteAccountRequest => text('deleteAccountRequest');
  String get deleteAccountWarning => text('deleteAccountWarning');
  String get deleteAccountReason => text('deleteAccountReason');
  String get deleteAccountConfirmText => text('deleteAccountConfirmText');
  String get submitRequest => text('submitRequest');
  String get jobRecommendations => text('jobRecommendations');
  String get employerMessages => text('employerMessages');
  String get applicationUpdates => text('applicationUpdates');
  String get paymentUpdates => text('paymentUpdates');
  String get systemAnnouncements => text('systemAnnouncements');
  String get postsTabTitle => text('postsTabTitle');
  String get myProfileTabTitle => text('myProfileTabTitle');
  String get homeWelcomeSubtitle => text('homeWelcomeSubtitle');
  String get findJobsButton => text('findJobsButton');
  String get updateCvButton => text('updateCvButton');
  String get statsAppliedJobs => text('statsAppliedJobs');
  String get statsSavedJobs => text('statsSavedJobs');
  String get statsProfileViews => text('statsProfileViews');
  String get statsMatchedJobs => text('statsMatchedJobs');
  String get recentLabel => text('recentLabel');
  String get thisWeekLabel => text('thisWeekLabel');
  String get thisMonthLabel => text('thisMonthLabel');
  String get currentJobsTitle => text('currentJobsTitle');
  String get noCurrentJobs => text('noCurrentJobs');
  String get notificationViewed => text('notificationViewed');
  String get notificationMessage => text('notificationMessage');
  String get notificationAccepted => text('notificationAccepted');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['vi', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _vi = {
  'appName': 'Ốp Pờ',
  'loading': 'Đang tải...',
  'error': 'Lỗi',
  'success': 'Thành công',
  'cancel': 'Hủy',
  'confirm': 'Xác nhận',
  'save': 'Lưu',
  'submit': 'Gửi',
  'retry': 'Thử lại',
  'back': 'Quay lại',
  'continueText': 'Tiếp tục',
  'search': 'Tìm kiếm',
  'signIn': 'Đăng nhập',
  'signUp': 'Đăng ký',
  'signOut': 'Đăng xuất',
  'email': 'Email',
  'password': 'Mật khẩu',
  'confirmPassword': 'Xác nhận mật khẩu',
  'fullName': 'Họ và tên',
  'forgotPassword': 'Quên mật khẩu',
  'resetPassword': 'Đặt lại mật khẩu',
  'currentPassword': 'Mật khẩu hiện tại',
  'newPassword': 'Mật khẩu mới',
  'confirmNewPassword': 'Xác nhận mật khẩu mới',
  'changePassword': 'Đổi mật khẩu',
  'confirmSignUp': 'Xác nhận đăng ký',
  'verificationCode': 'Mã xác nhận',
  'resendCode': 'Gửi lại mã',
  'home': 'Trang chủ',
  'jobs': 'Việc làm',
  'notifications': 'Thông báo',
  'profile': 'Hồ sơ',
  'settings': 'Cài đặt',
  'jobFeed': 'Bảng tin việc làm',
  'employer': 'Nhà tuyển dụng',
  'candidate': 'Ứng viên',
  'apply': 'Ứng tuyển',
  'saveJob': 'Lưu việc',
  'savedJob': 'Đã lưu việc',
  'unsaveJob': 'Bỏ lưu',
  'jobSaved': 'Đã lưu công việc.',
  'jobUnsaved': 'Đã bỏ lưu công việc.',
  'details': 'Chi tiết',
  'jobDetails': 'Chi tiết công việc',
  'urgentShift': 'Ca gấp',
  'partTime': 'Bán thời gian',
  'available': 'Sẵn sàng nhận việc',
  'off': 'Tạm tắt nhận việc',
  'location': 'Vị trí',
  'digitalWallet': 'Ví điện tử',
  'appearance': 'Giao diện',
  'themeMode': 'Chế độ giao diện',
  'systemDefault': 'Theo hệ thống',
  'lightMode': 'Chế độ sáng',
  'darkMode': 'Chế độ tối',
  'language': 'Ngôn ngữ',
  'appLanguage': 'Ngôn ngữ ứng dụng',
  'security': 'Bảo mật',
  'notificationPreferences': 'Tùy chọn thông báo',
  'account': 'Tài khoản',
  'deleteAccountRequest': 'Yêu cầu xóa tài khoản',
  'deleteAccountWarning':
      'Việc xóa tài khoản không diễn ra ngay lập tức. Yêu cầu của bạn sẽ được xem xét vì tài khoản có thể liên quan đến lịch sử ứng tuyển, lịch sử làm việc, ví điện tử, thanh toán hoặc dữ liệu pháp lý.',
  'deleteAccountReason': 'Lý do bạn muốn xóa tài khoản',
  'deleteAccountConfirmText':
      'Tôi hiểu rằng yêu cầu này có thể ảnh hưởng đến tài khoản và dữ liệu của tôi.',
  'deleteAccountRequestSubmitted':
      'Yêu cầu xóa tài khoản của bạn đã được ghi nhận.',
  'submitRequest': 'Gửi yêu cầu',
  'jobRecommendations': 'Gợi ý việc làm',
  'employerMessages': 'Tin nhắn từ nhà tuyển dụng',
  'applicationUpdates': 'Cập nhật ứng tuyển',
  'paymentUpdates': 'Cập nhật thanh toán',
  'systemAnnouncements': 'Thông báo hệ thống',
  'wallet': 'Ví',
  'balance': 'Số dư',
  'availableBalance': 'Số dư khả dụng',
  'pendingBalance': 'Đang chờ xử lý',
  'totalEarnings': 'Tổng thu nhập',
  'hideBalance': 'Ẩn số dư',
  'showBalance': 'Hiện số dư',
  'quickActions': 'Thao tác nhanh',
  'withdraw': 'Rút tiền',
  'withdrawFunds': 'Rút tiền',
  'linkBank': 'Liên kết ngân hàng',
  'linkedBankAccount': 'Tài khoản ngân hàng liên kết',
  'walletLinking': 'Liên kết ví',
  'eBanking': 'Ngân hàng điện tử',
  'bankName': 'Tên ngân hàng',
  'accountHolderName': 'Tên chủ tài khoản',
  'accountNumber': 'Số tài khoản',
  'branchOptional': 'Chi nhánh (không bắt buộc)',
  'saveBankAccount': 'Lưu tài khoản ngân hàng',
  'confirmRemoveBankAccount': 'Gỡ tài khoản ngân hàng',
  'removeBankAccountWarning':
      'Sau khi gỡ tài khoản này, bạn sẽ không thể rút tiền cho đến khi liên kết tài khoản ngân hàng khác.',
  'noLinkedBankAccount': 'Bạn chưa liên kết tài khoản ngân hàng.',
  'linkBankAccountToWithdraw': 'Liên kết tài khoản để rút tiền',
  'bankAccountLinked': 'Liên kết tài khoản ngân hàng thành công.',
  'bankAccountRemoved': 'Đã gỡ tài khoản ngân hàng.',
  'invalidAccountNumber': 'Số tài khoản không hợp lệ.',
  'removeLinkedAccount': 'Gỡ tài khoản liên kết',
  'revenueStatistics': 'Thống kê thu nhập',
  'transactionHistory': 'Lịch sử giao dịch',
  'recentTransactions': 'Giao dịch gần đây',
  'viewAll': 'Xem tất cả',
  'incomeSummary': 'Tổng quan thu nhập',
  'thisWeekIncome': 'Thu nhập tuần này',
  'thisMonthIncome': 'Thu nhập tháng này',
  'completedShifts': 'Ca đã hoàn thành',
  'averageIncomePerShift': 'Trung bình mỗi ca',
  'amount': 'Số tiền',
  'withdrawalAmount': 'Số tiền muốn rút',
  'estimatedProcessingTime': 'Thời gian xử lý dự kiến',
  'processingTimeValue': '1-3 ngày làm việc',
  'confirmWithdrawal': 'Xác nhận rút tiền',
  'withdrawalFee': 'Phí rút tiền',
  'submitWithdrawalRequest': 'Gửi yêu cầu rút tiền',
  'withdrawalRequestSubmitted': 'Yêu cầu rút tiền đã được gửi.',
  'insufficientBalance': 'Số dư không đủ.',
  'bankAccountRequired': 'Vui lòng liên kết tài khoản ngân hàng.',
  'invalidAmount': 'Số tiền không hợp lệ.',
  'transactionCompleted': 'Hoàn tất',
  'transactionPending': 'Đang chờ',
  'transactionProcessing': 'Đang xử lý',
  'transactionFailed': 'Thất bại',
  'transactionCancelled': 'Đã hủy',
  'earnings': 'Thu nhập',
  'withdrawals': 'Rút tiền',
  'all': 'Tất cả',
  'failed': 'Thất bại',
  'noTransactions': 'Chưa có giao dịch.',
  'walletLoadFailed': 'Không thể tải dữ liệu ví. Vui lòng thử lại.',
  'manage': 'Quản lý',
  'homeGreeting': 'Xin chào, {name}',
  'homeSubtitle': 'Tìm công việc phù hợp với bạn hôm nay',
  'searchJobsOrEmployers': 'Tìm công việc, nhà tuyển dụng...',
  'nearby': 'Gần bạn',
  'highSalary': 'Lương cao',
  'todayShift': 'Ca hôm nay',
  'urgentJobs': 'Công việc gấp',
  'noJobsFound': 'Chưa có công việc phù hợp.',
  'tryChangeFilters': 'Hãy thử thay đổi vị trí hoặc bộ lọc.',
  'salary': 'Mức lương',
  'shiftTime': 'Thời gian làm việc',
  'workStatus': 'Trạng thái làm việc',
  'availableDescription': 'Bạn đang sẵn sàng nhận công việc mới.',
  'offDescription': 'Bạn đang tạm tắt nhận việc.',
  'currentLocation': 'Vị trí hiện tại',
  'updateLocation': 'Cập nhật vị trí',
  'jobFilters': 'Bộ lọc việc làm',
  'jobsIntro': 'Quản lý trạng thái tìm việc và khám phá cơ hội mới.',
  'searchJobs': 'Tìm việc làm...',
  'searchWillBeBuilt': 'Tìm kiếm sẽ được xây ở giai đoạn sau.',
  'filterWillBeBuilt': 'Bộ lọc "{filter}" sẽ được xây sau.',
  'recommendedJobs': 'Việc làm gợi ý',
  'recommendedJobsPlaceholder':
      'Danh sách công việc sẽ được xây dựng chi tiết ở giai đoạn sau.',
  'editProfile': 'Chỉnh sửa hồ sơ',
  'loginSecurity': 'Đăng nhập & bảo mật',
  'support': 'Hỗ trợ',
  'policyTerms': 'Chính sách & điều khoản',
  'emailRequired': 'Vui lòng nhập email.',
  'passwordRequired': 'Vui lòng nhập mật khẩu.',
  'requiredField': 'Không được để trống',
  'passwordMismatch': 'Mật khẩu xác nhận không khớp.',
  'invalidEmail': 'Email không hợp lệ.',
  'weakPassword': 'Mật khẩu không đáp ứng yêu cầu bảo mật.',
  'networkError': 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.',
  'unknownError': 'Đã có lỗi xảy ra. Vui lòng thử lại.',
  'wrongCurrentPassword': 'Mật khẩu hiện tại không đúng.',
  'languageUpdated': 'Đã cập nhật ngôn ngữ.',
  'themeUpdated': 'Đã cập nhật giao diện.',
  'preferencesSaved': 'Đã lưu cài đặt.',
  'confirmSignOutTitle': 'Đăng xuất',
  'confirmSignOutMessage': 'Bạn có chắc chắn muốn đăng xuất không?',
  'signOutFailed': 'Đăng xuất thất bại. Vui lòng thử lại.',
  'alreadyHaveAccount': 'Đã có tài khoản? Đăng nhập',
  'noAccountSignUp': 'Chưa có tài khoản? Đăng ký',
  'showPassword': 'Hiện mật khẩu',
  'hidePassword': 'Ẩn mật khẩu',
  'role': 'Vai trò',
  'userCandidate': 'Người dùng / Ứng viên',
  'employerNtd': 'Nhà tuyển dụng',
  'verificationSent': 'Mã xác nhận đã được gửi đến email của bạn.',
  'resetPasswordSuccess': 'Đặt lại mật khẩu thành công. Hãy đăng nhập lại.',
  'confirmSignUpSuccess': 'Xác nhận thành công. Hãy đăng nhập.',
  'resendCodeSuccess': 'Mã xác nhận đã được gửi lại.',
  'forgotPasswordInstruction': 'Nhập email tài khoản để nhận mã xác nhận.',
  'backToSignIn': 'Quay lại đăng nhập',
  'sendVerificationCode': 'Gửi mã xác nhận',
  'kycVerification': 'Xác minh KYC',
  'completeKyc': 'Hoàn thành KYC',
  'updateProfile': 'Cập nhật hồ sơ',
  'completeProfile': 'Hoàn thành hồ sơ',
  'pendingReviewTitle': 'Đang xét duyệt',
  'rejectedTitle': 'Không được duyệt',
  'contactSupport': 'Liên hệ hỗ trợ',
  'missingRoleTitle': 'Thiếu vai trò',
  'changePasswordSuccess': 'Đổi mật khẩu thành công.',
  'deleteReasonRequired': 'Vui lòng nhập lý do xóa tài khoản.',
  'deleteConfirmRequired':
      'Vui lòng xác nhận rằng bạn hiểu tác động của yêu cầu này.',
  'checkIn': 'Vào ca',
  'checkOut': 'Rời ca',
  'postsTabTitle': 'Bài đăng',
  'myProfileTabTitle': 'Hồ sơ của tôi',
  'homeWelcomeSubtitle': 'Chúc bạn một ngày làm việc hiệu quả!',
  'findJobsButton': 'Tìm Việc Làm',
  'updateCvButton': 'Cập nhật CV',
  'statsAppliedJobs': 'HỒ SƠ ĐÃ NỘP',
  'statsSavedJobs': 'VIỆC ĐÃ LƯU',
  'statsProfileViews': 'LƯỢT XEM HỒ SƠ',
  'statsMatchedJobs': 'JOB MATCH THÀNH CÔNG',
  'recentLabel': 'gần đây',
  'thisWeekLabel': 'tuần này',
  'thisMonthLabel': 'tháng này',
  'currentJobsTitle': 'Công việc hiện tại',
  'noCurrentJobs': 'Chưa có công việc tuyển gấp nào.',
  'notificationViewed': 'Hồ sơ đã được xem',
  'notificationMessage': 'Tin nhắn mới',
  'notificationAccepted': 'CV được chấp nhận',
};

const _en = {
  'appName': 'Ốp Pờ',
  'loading': 'Loading...',
  'error': 'Error',
  'success': 'Success',
  'cancel': 'Cancel',
  'confirm': 'Confirm',
  'save': 'Save',
  'submit': 'Submit',
  'retry': 'Retry',
  'back': 'Back',
  'continueText': 'Continue',
  'search': 'Search',
  'signIn': 'Sign in',
  'signUp': 'Sign up',
  'signOut': 'Sign out',
  'email': 'Email',
  'password': 'Password',
  'confirmPassword': 'Confirm password',
  'fullName': 'Full name',
  'forgotPassword': 'Forgot password',
  'resetPassword': 'Reset password',
  'currentPassword': 'Current password',
  'newPassword': 'New password',
  'confirmNewPassword': 'Confirm new password',
  'changePassword': 'Change Password',
  'confirmSignUp': 'Confirm sign up',
  'verificationCode': 'Verification code',
  'resendCode': 'Resend code',
  'home': 'Home',
  'jobs': 'Jobs',
  'notifications': 'Notifications',
  'profile': 'Profile',
  'settings': 'Settings',
  'jobFeed': 'Job Feed',
  'employer': 'Employer',
  'candidate': 'Candidate',
  'apply': 'Apply',
  'saveJob': 'Save job',
  'savedJob': 'Saved',
  'unsaveJob': 'Unsave',
  'jobSaved': 'Job saved.',
  'jobUnsaved': 'Job removed from saved list.',
  'details': 'Details',
  'jobDetails': 'Job details',
  'urgentShift': 'Urgent shift',
  'partTime': 'Part-time',
  'available': 'Available',
  'off': 'OFF',
  'location': 'Location',
  'digitalWallet': 'Digital Wallet',
  'appearance': 'Appearance',
  'themeMode': 'Theme Mode',
  'systemDefault': 'System Default',
  'lightMode': 'Light Mode',
  'darkMode': 'Dark Mode',
  'language': 'Language',
  'appLanguage': 'App Language',
  'security': 'Security',
  'notificationPreferences': 'Notification Preferences',
  'account': 'Account',
  'deleteAccountRequest': 'Delete Account Request',
  'deleteAccountWarning':
      'Account deletion is not immediate. Your request will be reviewed because your account may be linked to applications, work history, wallet, payments, or legal records.',
  'deleteAccountReason': 'Why do you want to delete your account?',
  'deleteAccountConfirmText':
      'I understand that this request may affect my account and data.',
  'deleteAccountRequestSubmitted':
      'Your account deletion request has been submitted.',
  'submitRequest': 'Submit request',
  'jobRecommendations': 'Job recommendations',
  'employerMessages': 'Employer messages',
  'applicationUpdates': 'Application updates',
  'paymentUpdates': 'Payment updates',
  'systemAnnouncements': 'System announcements',
  'wallet': 'Wallet',
  'balance': 'Balance',
  'availableBalance': 'Available Balance',
  'pendingBalance': 'Pending Balance',
  'totalEarnings': 'Total Earnings',
  'hideBalance': 'Hide balance',
  'showBalance': 'Show balance',
  'quickActions': 'Quick actions',
  'withdraw': 'Withdraw',
  'withdrawFunds': 'Withdraw funds',
  'linkBank': 'Link Bank',
  'linkedBankAccount': 'Linked Bank Account',
  'walletLinking': 'Wallet linking',
  'eBanking': 'E-banking',
  'bankName': 'Bank name',
  'accountHolderName': 'Account holder name',
  'accountNumber': 'Account number',
  'branchOptional': 'Branch (optional)',
  'saveBankAccount': 'Save bank account',
  'confirmRemoveBankAccount': 'Remove linked account',
  'removeBankAccountWarning':
      'After removing this account, you cannot withdraw funds until you link another bank account.',
  'noLinkedBankAccount': 'You have not linked a bank account.',
  'linkBankAccountToWithdraw': 'Link a bank account to withdraw',
  'bankAccountLinked': 'Bank account linked successfully.',
  'bankAccountRemoved': 'Linked bank account removed.',
  'invalidAccountNumber': 'Invalid account number.',
  'removeLinkedAccount': 'Remove linked account',
  'revenueStatistics': 'Revenue statistics',
  'transactionHistory': 'Transaction history',
  'recentTransactions': 'Recent Transactions',
  'viewAll': 'View All',
  'incomeSummary': 'Income Summary',
  'thisWeekIncome': 'This Week Income',
  'thisMonthIncome': 'This Month Income',
  'completedShifts': 'Completed Shifts',
  'averageIncomePerShift': 'Average Income Per Shift',
  'amount': 'Amount',
  'withdrawalAmount': 'Withdrawal amount',
  'estimatedProcessingTime': 'Estimated processing time',
  'processingTimeValue': '1-3 business days',
  'confirmWithdrawal': 'Confirm withdrawal',
  'withdrawalFee': 'Withdrawal fee',
  'submitWithdrawalRequest': 'Submit withdrawal request',
  'withdrawalRequestSubmitted': 'Withdrawal request submitted.',
  'insufficientBalance': 'Insufficient balance.',
  'bankAccountRequired': 'Please link a bank account.',
  'invalidAmount': 'Invalid amount.',
  'transactionCompleted': 'Completed',
  'transactionPending': 'Pending',
  'transactionProcessing': 'Processing',
  'transactionFailed': 'Failed',
  'transactionCancelled': 'Cancelled',
  'earnings': 'Earnings',
  'withdrawals': 'Withdrawals',
  'all': 'All',
  'failed': 'Failed',
  'noTransactions': 'No transactions yet.',
  'walletLoadFailed': 'Unable to load wallet data. Please try again.',
  'manage': 'Manage',
  'homeGreeting': 'Hi, {name}',
  'homeSubtitle': 'Find the right job for you today',
  'searchJobsOrEmployers': 'Search jobs, employers...',
  'nearby': 'Nearby',
  'highSalary': 'High salary',
  'todayShift': 'Today shift',
  'urgentJobs': 'Urgent jobs',
  'noJobsFound': 'No matching jobs yet.',
  'tryChangeFilters': 'Try changing your location or filters.',
  'salary': 'Salary',
  'shiftTime': 'Shift time',
  'workStatus': 'Work status',
  'availableDescription': 'You are ready to receive new jobs.',
  'offDescription': 'You have paused receiving jobs.',
  'currentLocation': 'Current location',
  'updateLocation': 'Update location',
  'jobFilters': 'Job filters',
  'jobsIntro': 'Manage your work status and explore new opportunities.',
  'searchJobs': 'Search jobs...',
  'searchWillBeBuilt': 'Search will be built in a later phase.',
  'filterWillBeBuilt': 'Filter "{filter}" will be built later.',
  'recommendedJobs': 'Recommended jobs',
  'recommendedJobsPlaceholder':
      'The job list will be built in detail in a later phase.',
  'editProfile': 'Edit Profile',
  'loginSecurity': 'Login & Security',
  'support': 'Support',
  'policyTerms': 'Policy & Terms',
  'emailRequired': 'Please enter your email.',
  'passwordRequired': 'Please enter your password.',
  'requiredField': 'This field is required.',
  'passwordMismatch': 'Passwords do not match.',
  'invalidEmail': 'Invalid email address.',
  'weakPassword': 'Password does not meet the security requirements.',
  'networkError': 'Network error. Please check your internet connection.',
  'unknownError': 'Something went wrong. Please try again.',
  'wrongCurrentPassword': 'Current password is incorrect.',
  'languageUpdated': 'Language updated.',
  'themeUpdated': 'Theme updated.',
  'preferencesSaved': 'Preferences saved.',
  'confirmSignOutTitle': 'Sign out',
  'confirmSignOutMessage': 'Are you sure you want to sign out?',
  'signOutFailed': 'Sign out failed. Please try again.',
  'alreadyHaveAccount': 'Already have an account? Sign in',
  'noAccountSignUp': 'No account yet? Sign up',
  'showPassword': 'Show password',
  'hidePassword': 'Hide password',
  'role': 'Role',
  'userCandidate': 'User / Candidate',
  'employerNtd': 'Employer',
  'verificationSent': 'A verification code has been sent to your email.',
  'resetPasswordSuccess': 'Password reset successfully. Please sign in again.',
  'confirmSignUpSuccess': 'Account confirmed. Please sign in.',
  'resendCodeSuccess': 'Verification code has been resent.',
  'forgotPasswordInstruction':
      'Enter your account email to receive a verification code.',
  'backToSignIn': 'Back to sign in',
  'sendVerificationCode': 'Send verification code',
  'kycVerification': 'KYC Verification',
  'completeKyc': 'Complete KYC',
  'updateProfile': 'Update Profile',
  'completeProfile': 'Complete profile',
  'pendingReviewTitle': 'Pending review',
  'rejectedTitle': 'Not approved',
  'contactSupport': 'Contact support',
  'missingRoleTitle': 'Missing role',
  'changePasswordSuccess': 'Password changed successfully.',
  'deleteReasonRequired': 'Please enter a reason for deleting your account.',
  'deleteConfirmRequired':
      'Please confirm that you understand the impact of this request.',
  'checkIn': 'Check in',
  'checkOut': 'Check out',
  'postsTabTitle': 'Posts',
  'myProfileTabTitle': 'My Profile',
  'homeWelcomeSubtitle': 'Have a productive working day!',
  'findJobsButton': 'Find Jobs',
  'updateCvButton': 'Update CV',
  'statsAppliedJobs': 'APPLIED JOBS',
  'statsSavedJobs': 'SAVED JOBS',
  'statsProfileViews': 'PROFILE VIEWS',
  'statsMatchedJobs': 'SUCCESSFUL MATCHES',
  'recentLabel': 'recent',
  'thisWeekLabel': 'this week',
  'thisMonthLabel': 'this month',
  'currentJobsTitle': 'Current Jobs',
  'noCurrentJobs': 'No urgent jobs at the moment.',
  'notificationViewed': 'Profile viewed',
  'notificationMessage': 'New message',
  'notificationAccepted': 'CV accepted',
};

const _localizedValues = {'vi': _vi, 'en': _en};
