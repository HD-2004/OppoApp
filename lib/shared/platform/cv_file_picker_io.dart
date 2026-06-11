import 'package:file_picker/file_picker.dart';

import 'cv_file_selection.dart';

Future<CvFileSelection?> pickCvFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowMultiple: false,
    withData: true,
    allowedExtensions: const ['pdf', 'doc', 'docx'],
  );

  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes == null) return CvFileSelection(name: file.name, bytes: const []);
  return CvFileSelection(name: file.name, bytes: bytes);
}
