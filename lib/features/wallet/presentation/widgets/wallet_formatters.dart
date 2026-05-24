import 'package:intl/intl.dart';

String formatVnd(double value, {bool hidden = false}) {
  if (hidden) {
    return '••••••••';
  }
  final formatter = NumberFormat.decimalPattern('vi_VN');
  return '${formatter.format(value.round())}đ';
}
