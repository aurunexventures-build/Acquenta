import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class CardOcrService {
  static bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  Future<String> read(String path) async {
    if (!supported) {
      throw UnsupportedError(
        'Photo text recognition is available on Android and iPhone.',
      );
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      if (result.text.trim().isEmpty) {
        throw const FormatException(
          'No readable text. Try a brighter, sharper photo.',
        );
      }
      return result.text;
    } finally {
      await recognizer.close();
    }
  }

  static Map<String, String> extract(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final email =
        RegExp(
          r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
          caseSensitive: false,
        ).firstMatch(text)?.group(0) ??
        '';
    final phone =
        RegExp(r'\+?[\d][\d ()\-.]{6,}[\d]')
            .allMatches(text)
            .map((m) => m.group(0)!)
            .where((s) => s.replaceAll(RegExp(r'\D'), '').length >= 7)
            .firstOrNull ??
        '';
    return {
      'fullName':
          lines
              .where(
                (l) =>
                    !l.contains('@') &&
                    !RegExp(
                      r'\d|https?://|www\.',
                      caseSensitive: false,
                    ).hasMatch(l),
              )
              .firstOrNull ??
          '',
      'email': email,
      'phone': phone,
    };
  }
}
