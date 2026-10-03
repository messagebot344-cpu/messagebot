import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class MessageBotPrintPreviewScreen extends StatelessWidget {
  const MessageBotPrintPreviewScreen({
    super.key,
    required this.title,
    required this.bytes,
  });

  final String title;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangeOrientation: false,
        canChangePageFormat: true,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'Message_Bot.pdf',
      ),
    );
  }
}
