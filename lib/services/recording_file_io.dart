import 'dart:io';
import 'dart:typed_data';

String recordingPath() =>
    '${Directory.systemTemp.path}/acquenta-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
Future<Uint8List> readAndDeleteRecording(String path) async {
  final file = File(path);
  try {
    return await file.readAsBytes();
  } finally {
    if (await file.exists()) await file.delete();
  }
}
