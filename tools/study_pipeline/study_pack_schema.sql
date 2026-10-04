PRAGMA foreign_keys=ON;

CREATE TABLE study_pack_meta(
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE study_packs(
  sermon_id INTEGER NOT NULL,
  sermon_code TEXT NOT NULL,
  title TEXT NOT NULL,
  pack_version INTEGER NOT NULL,
  pack_schema_version INTEGER NOT NULL,
  corpus_version TEXT NOT NULL,
  corpus_canonical_sha256 TEXT NOT NULL,
  primary_edition_id TEXT NOT NULL,
  bible_pack_version TEXT,
  status TEXT NOT NULL,
  validation_status TEXT NOT NULL,
  generated_at INTEGER NOT NULL,
  published_at INTEGER,
  PRIMARY KEY(sermon_id,pack_version)
);
CREATE INDEX idx_study_packs_status ON study_packs(status,sermon_id);

CREATE TABLE study_paragraphs(
  paragraph_key TEXT PRIMARY KEY,
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  edition_id TEXT NOT NULL,
  passage_id INTEGER NOT NULL,
  global_ordinal INTEGER NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset INTEGER NOT NULL,
  source_page_start INTEGER NOT NULL,
  source_page_end INTEGER NOT NULL,
  text_sha256 TEXT NOT NULL,
  character_count INTEGER NOT NULL,
  printed_paragraph_number TEXT,
  UNIQUE(sermon_id,pack_version,global_ordinal)
);
CREATE INDEX idx_study_paragraphs_sermon ON study_paragraphs(sermon_id,pack_version,global_ordinal);
CREATE INDEX idx_study_paragraphs_passage ON study_paragraphs(passage_id,start_offset,end_offset);

CREATE TABLE study_sections(
  id INTEGER PRIMARY KEY,
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  required_for_exam INTEGER NOT NULL DEFAULT 1,
  minimum_reading_percent REAL NOT NULL DEFAULT 0.90,
  UNIQUE(sermon_id,pack_version,ordinal)
);
CREATE INDEX idx_study_sections_sermon ON study_sections(sermon_id,pack_version,ordinal);

CREATE TABLE study_section_paragraphs(
  section_id INTEGER NOT NULL,
  paragraph_key TEXT NOT NULL,
  position INTEGER NOT NULL,
  PRIMARY KEY(section_id,paragraph_key),
  FOREIGN KEY(section_id) REFERENCES study_sections(id) ON DELETE CASCADE,
  FOREIGN KEY(paragraph_key) REFERENCES study_paragraphs(paragraph_key) ON DELETE CASCADE
);
CREATE INDEX idx_section_paragraphs_position ON study_section_paragraphs(section_id,position);

CREATE TABLE study_learning_objectives(
  id INTEGER PRIMARY KEY,
  section_id INTEGER NOT NULL,
  label TEXT NOT NULL,
  validation_status TEXT NOT NULL,
  FOREIGN KEY(section_id) REFERENCES study_sections(id) ON DELETE CASCADE
);

CREATE TABLE study_concepts(
  id INTEGER PRIMARY KEY,
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  normalized_label TEXT NOT NULL,
  display_label TEXT NOT NULL,
  doctrinal_tag TEXT,
  validation_status TEXT NOT NULL
);
CREATE INDEX idx_study_concepts_sermon ON study_concepts(sermon_id,pack_version);

CREATE TABLE study_scripture_references(
  id INTEGER PRIMARY KEY,
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  normalized_reference TEXT NOT NULL,
  display_reference TEXT NOT NULL,
  translation_id TEXT,
  validation_status TEXT NOT NULL,
  UNIQUE(sermon_id,pack_version,normalized_reference)
);

CREATE TABLE study_section_scripture_refs(
  section_id INTEGER NOT NULL,
  scripture_reference_id INTEGER NOT NULL,
  PRIMARY KEY(section_id,scripture_reference_id),
  FOREIGN KEY(section_id) REFERENCES study_sections(id) ON DELETE CASCADE,
  FOREIGN KEY(scripture_reference_id) REFERENCES study_scripture_references(id) ON DELETE CASCADE
);

CREATE TABLE study_source_evidence(
  id INTEGER PRIMARY KEY,
  sermon_id INTEGER,
  pack_version INTEGER,
  source_kind TEXT NOT NULL,
  evidence_role TEXT NOT NULL,
  edition_id TEXT,
  passage_id INTEGER,
  paragraph_key TEXT,
  start_offset INTEGER,
  end_offset INTEGER,
  exact_quote TEXT,
  quote_sha256 TEXT,
  source_page_start INTEGER,
  source_page_end INTEGER,
  translation_id TEXT,
  normalized_reference TEXT,
  verse_range TEXT,
  exact_bible_text TEXT,
  bible_text_sha256 TEXT
);
CREATE INDEX idx_study_evidence_sermon ON study_source_evidence(sermon_id,pack_version);
CREATE INDEX idx_study_evidence_passage ON study_source_evidence(passage_id,start_offset,end_offset);

CREATE TABLE study_questions(
  id INTEGER PRIMARY KEY,
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  section_id INTEGER,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  difficulty INTEGER NOT NULL CHECK(difficulty BETWEEN 1 AND 5),
  prompt TEXT NOT NULL,
  pedagogical_explanation TEXT NOT NULL DEFAULT '',
  correct_answer_payload TEXT NOT NULL,
  scoring_payload TEXT NOT NULL,
  validation_status TEXT NOT NULL,
  certification_eligible INTEGER NOT NULL DEFAULT 0,
  generator_kind TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  reviewed_at INTEGER,
  reviewer TEXT
);
CREATE INDEX idx_study_questions_pool ON study_questions(sermon_id,pack_version,validation_status,certification_eligible,category,difficulty);

CREATE TABLE study_question_options(
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  option_text TEXT NOT NULL,
  is_correct INTEGER NOT NULL DEFAULT 0,
  rationale TEXT,
  UNIQUE(question_id,ordinal),
  FOREIGN KEY(question_id) REFERENCES study_questions(id) ON DELETE CASCADE
);

CREATE TABLE study_question_evidence(
  question_id INTEGER NOT NULL,
  evidence_id INTEGER NOT NULL,
  evidence_role TEXT NOT NULL,
  PRIMARY KEY(question_id,evidence_id,evidence_role),
  FOREIGN KEY(question_id) REFERENCES study_questions(id) ON DELETE CASCADE,
  FOREIGN KEY(evidence_id) REFERENCES study_source_evidence(id) ON DELETE CASCADE
);

CREATE TABLE study_question_scripture_refs(
  question_id INTEGER NOT NULL,
  scripture_reference_id INTEGER NOT NULL,
  PRIMARY KEY(question_id,scripture_reference_id),
  FOREIGN KEY(question_id) REFERENCES study_questions(id) ON DELETE CASCADE,
  FOREIGN KEY(scripture_reference_id) REFERENCES study_scripture_references(id) ON DELETE CASCADE
);

CREATE TABLE study_question_tags(
  question_id INTEGER NOT NULL,
  tag TEXT NOT NULL,
  PRIMARY KEY(question_id,tag),
  FOREIGN KEY(question_id) REFERENCES study_questions(id) ON DELETE CASCADE
);

CREATE TABLE study_exam_rules(
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  exam_size INTEGER NOT NULL,
  pass_threshold REAL NOT NULL,
  recent_question_exclusion_count INTEGER NOT NULL DEFAULT 0,
  minimum_reading_percent REAL NOT NULL DEFAULT 0.95,
  minimum_bank_multiplier REAL NOT NULL DEFAULT 2.4,
  PRIMARY KEY(sermon_id,pack_version)
);

CREATE TABLE study_exam_category_rules(
  sermon_id INTEGER NOT NULL,
  pack_version INTEGER NOT NULL,
  category TEXT NOT NULL,
  weight REAL NOT NULL,
  question_count INTEGER NOT NULL,
  minimum_score REAL,
  PRIMARY KEY(sermon_id,pack_version,category)
);

CREATE TABLE study_validation_issues(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sermon_id INTEGER,
  pack_version INTEGER,
  entity_kind TEXT NOT NULL,
  entity_id TEXT,
  validator_code TEXT NOT NULL,
  severity TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_study_validation_issues_pack ON study_validation_issues(sermon_id,pack_version,severity);

CREATE TABLE study_pack_migrations(
  sermon_id INTEGER NOT NULL,
  from_version INTEGER NOT NULL,
  to_version INTEGER NOT NULL,
  old_section_id INTEGER,
  new_section_id INTEGER,
  migration_kind TEXT NOT NULL,
  reason TEXT NOT NULL,
  PRIMARY KEY(sermon_id,from_version,to_version,old_section_id)
);
