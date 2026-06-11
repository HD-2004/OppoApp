import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'cv_file_selection.dart';

Future<CvFileSelection?> pickCvFile() {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept =
        '.pdf,.doc,.docx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ..multiple = false;

  final completer = Completer<CvFileSelection?>();

  input.addEventListener(
    'change',
    ((web.Event _) {
      if (completer.isCompleted) return;
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.addEventListener(
        'error',
        ((web.Event _) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Không thể đọc dữ liệu file.'));
          }
        }).toJS,
      );
      reader.addEventListener(
        'loadend',
        ((web.Event _) {
          if (completer.isCompleted) return;
          final result = reader.result;
          if (result.isA<JSArrayBuffer>()) {
            final buffer = (result as JSArrayBuffer).toDart;
            completer.complete(
              CvFileSelection(name: file.name, bytes: Uint8List.view(buffer)),
            );
          } else {
            completer.completeError(Exception('Không thể đọc dữ liệu file.'));
          }
        }).toJS,
      );
      reader.readAsArrayBuffer(file);
    }).toJS,
  );

  input.click();
  return completer.future;
}
