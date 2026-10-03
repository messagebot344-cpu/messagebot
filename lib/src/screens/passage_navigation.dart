import 'package:flutter/material.dart';

import '../models/models.dart';
import 'book_reader_screen.dart';
import 'reader_screen.dart';

Future<void> openStudyPassage(BuildContext context, StudyPassage item) async {
  if (item.source.type == CorpusSourceType.book) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BookReaderScreen(
          source: item.source,
          initialPassageId: item.passage.id,
        ),
      ),
    );
    return;
  }

  final sermon = item.sermon;
  final edition = item.edition;
  if (sermon == null || edition == null) return;

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(
        sermon: sermon,
        initialEditionId: edition.id,
        initialOrdinal: item.passage.ordinal,
      ),
    ),
  );
}
