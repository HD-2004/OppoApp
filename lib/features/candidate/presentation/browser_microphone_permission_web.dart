import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestBrowserMicrophonePermission() async {
  final mediaDevices = web.window.navigator.mediaDevices;

  web.MediaStream? stream;
  try {
    stream = await mediaDevices
        .getUserMedia(
          web.MediaStreamConstraints(audio: true.toJS, video: false.toJS),
        )
        .toDart;
    return true;
  } catch (_) {
    return false;
  } finally {
    final tracks = stream?.getTracks().toDart;
    if (tracks != null) {
      for (final track in tracks) {
        track.stop();
      }
    }
  }
}
