import 'dart:convert';
import 'dart:io';
import 'package:qr/qr.dart';

void main() {
  final qr = QrImage(
    QrCode.fromData(
      data:
          'BEGIN:VCARD\nVERSION:3.0\nFN:Anit Singh\nTITLE:Founder\nEMAIL:hello@aurunex.com\nEND:VCARD',
      errorCorrectLevel: QrErrorCorrectLevel.M,
    ),
  );
  File('/private/tmp/metcue-figma-qr.json').writeAsStringSync(
    jsonEncode(
      List.generate(
        qr.moduleCount,
        (r) => List.generate(qr.moduleCount, (c) => qr.isDark(r, c) ? 1 : 0),
      ),
    ),
  );
}
