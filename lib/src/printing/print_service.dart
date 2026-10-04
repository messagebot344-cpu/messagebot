import 'dart:typed_data';

import 'package:printing/printing.dart';

class PrintService {
  const PrintService();

  Future<void> printPdf(Uint8List bytes, {String name = 'Le_Grenier_du_Message.pdf'}) async {
    await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
  }

  Future<void> exportPdf(Uint8List bytes, {String name = 'Le_Grenier_du_Message.pdf'}) async {
    await Printing.sharePdf(bytes: bytes, filename: name);
  }
}
