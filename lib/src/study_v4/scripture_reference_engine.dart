import '../models/models.dart';
import '../services/corpus_repository.dart';

class ScriptureReferenceEngine {
  const ScriptureReferenceEngine(this.repository);
  final CorpusRepository repository;

  static final RegExp referencePattern = RegExp(
    r'\b(?:Gen(?:èse|ese)?|Exode|Lév(?:itique)?|Lev(?:itique)?|Nombres|Deut(?:éronome|eronome)?|Josué|Josue|Juges|Ruth|Samuel|Rois|Chroniques|Esdras|Néhémie|Nehemie|Esther|Job|Psaumes?|Proverbes|Ecclésiaste|Ecclesiaste|Ésaïe|Esaie|Jérémie|Jeremie|Ézéchiel|Ezechiel|Daniel|Osée|Osee|Joël|Joel|Amos|Abdias|Jonas|Michée|Michee|Nahum|Habacuc|Sophonie|Aggée|Aggee|Zacharie|Malachie|Matthieu|Marc|Luc|Jean|Actes|Romains|Corinthiens|Galates|Éphésiens|Ephesiens|Philippiens|Colossiens|Thessaloniciens|Timothée|Timothee|Tite|Philémon|Philemon|Hébreux|Hebreux|Jacques|Pierre|Jude|Apocalypse)\s+\d{1,3}\s*[:.]\s*\d{1,3}(?:\s*[-–]\s*\d{1,3})?',
    caseSensitive: false,
  );

  List<String> extract(String text) => referencePattern.allMatches(text).map((m) => m.group(0)!).toSet().toList(growable: false);

  List<StudyPassage> occurrences(String reference, {int limit = 300}) {
    final clean = reference.trim();
    if (clean.isEmpty) return const [];
    final rows = repository.db.select(
      'SELECT id FROM passages WHERE lower(text_display) LIKE ? ORDER BY id LIMIT ?',
      ['%${clean.toLowerCase()}%', limit],
    );
    final ids = rows.map((r) => r['id'] as int).toList(growable: false);
    final details = repository.studyDetailsForPassageIds(ids);
    return ids.where(details.containsKey).map((id) => details[id]!).toList(growable: false);
  }
}
