-- Digital Pothi corpus schema, version 1.0.0 (db_meta.schema_semver).
-- Mirrors the shipped asset exactly; build_corpus.py is the only writer.
CREATE TABLE lines(
  id TEXT,
  shabad_id TEXT,
  source_page INT,
  source_line INT,
  first_letters TEXT,
  vishraam_first_letters TEXT,
  gurmukhi TEXT,
  pronunciation TEXT,
  type_id INT,
  order_id INT,
  gurmukhi_uni TEXT,
  first_letters_uni TEXT
);
CREATE TABLE shabads(
  id TEXT,
  source_id INT,
  writer_id INT,
  section_id INT,
  subsection_id INT,
  sttm_id INT,
  order_id INT
);
CREATE TABLE banis(
  id INT,
  name_gurmukhi TEXT,
  name_english TEXT
);
CREATE TABLE bani_lines(
  line_id TEXT,
  bani_id INT,
  line_group INT
);
CREATE TABLE sources(
  id INT,
  name_gurmukhi TEXT,
  name_english TEXT,
  length INT,
  page_name_english TEXT,
  page_name_gurmukhi TEXT
);
CREATE TABLE line_types(
  id INT,
  name_gurmukhi TEXT,
  name_english TEXT
);
CREATE TABLE translations (
  line_id TEXT NOT NULL, lang TEXT NOT NULL,
  source TEXT NOT NULL, text TEXT NOT NULL);
CREATE TABLE transliterations (
  line_id TEXT NOT NULL, script TEXT NOT NULL, text TEXT NOT NULL);
CREATE TABLE writers (
  id INTEGER PRIMARY KEY, name_gurmukhi TEXT, name_english TEXT);
CREATE TABLE sections (
  id INTEGER PRIMARY KEY, name_gurmukhi TEXT, name_english TEXT);
CREATE TABLE db_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX idx_lines_shabad ON lines(shabad_id);
CREATE INDEX idx_lines_order ON lines(order_id);
CREATE INDEX idx_lines_fl ON lines(first_letters);
CREATE INDEX idx_banilines ON bani_lines(bani_id, line_group);
CREATE INDEX idx_lines_fl_uni ON lines(first_letters_uni);
CREATE INDEX idx_translations_line ON translations(line_id);
CREATE INDEX idx_transliterations_line ON transliterations(line_id);
CREATE VIRTUAL TABLE lines_fts USING fts5(gurmukhi_uni, first_letters_uni, content='lines', content_rowid='rowid');
