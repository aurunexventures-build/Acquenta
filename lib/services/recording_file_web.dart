import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

String recordingPath() => 'acquenta-search.wav';
Future<Uint8List> readAndDeleteRecording(String path) async {
  try {
    final response = await web.window.fetch(path.toJS).toDart;
    final buffer = await response.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(path);
  }
}
