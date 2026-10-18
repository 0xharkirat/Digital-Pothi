import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// First line of the ਸੋਚੈ shabad in the fixture (order_id 10).
const kLineA = 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ';

/// Second line of that shabad (order_id 20).
const kLineB = 'ਭੁਖਿਆ ਭੁਖ ਨ ਉਤਰੀ ਜੇ ਬੰਨਾ ਪੁਰੀਆ ਭਾਰ';

/// A line in a different shabad (order_id 30).
const kLineC = 'ਹੋਰ ਸ਼ਬਦ ਦੀ ਬਿਲਕੁਲ ਵਖਰੀ ਤੁਕ';

/// A line in a second source (Dasam) on the same page number as [kLineA] -
/// proves Ang search stays source-scoped. Far order_id keeps it out of the
/// tracker's ±150 windows. NULL source_line, true to the Dasam corpus.
const kLineD = 'ਦਸਮ ਤੁਕ ਪੰਨਾ ਚਾਰ';

/// A kirtan-shaped shabad (S4, ids k0..k6) for the intelligent spacebar:
/// [Sirlekh, Manglacharan] headers on ang line 1, an antara couplet sharing
/// line 2, the rahao (home) line on line 3, a second couplet sharing line 4.
const kKirtanShabad = 'S4';

/// A three-line in-memory stand-in for the 141k-line corpus: same schema, same
/// FTS5 index, so `locate` / `windowAround` / `search*` run for real in tests.
GurbaniDatabase openTestCorpus() {
  final db = sqlite3.openInMemory()
    ..execute(
      'CREATE TABLE lines (id TEXT PRIMARY KEY, shabad_id TEXT, '
      'gurmukhi_uni TEXT, source_page INTEGER, order_id INTEGER, '
      'first_letters TEXT, first_letters_uni TEXT, '
      'type_id INTEGER, source_line INTEGER)',
    )
    ..execute(
      'CREATE TABLE bani_lines (line_id TEXT, bani_id INTEGER, line_group INTEGER)',
    )
    // Inserted out of order_id order, to prove the queries sort by it. Columns:
    // id, shabad, gurmukhi, ang, order_id, first_letters (GurbaniAkhar font
    // codes, faithful: ਭ=B, ਤ=q, ੳ=a), first_letters_uni, type_id, source_line.
    ..execute(
      "INSERT INTO lines VALUES "
      "('b','S1','$kLineB',4,20,'BBnajbpB','ਭਭਨਉਜਬਪਭ',4,2),"
      "('a','S1','$kLineA',4,10,'ssnhjslv','ਸਸਨਹਜਸਲਵ',4,1),"
      "('c','S2','$kLineC',9,30,'hsdbvq','ਹਸਦਬਵਤ',4,1),"
      "('d','S3','$kLineD',4,5000,'dqpc','ਦਤਪਚ',4,NULL)",
    )
    // The kirtan shabad: types 2,1 = headers; 3 = rahao; 4 = pankti. Couplets
    // share a source_line; the rahao sits alone on its own line.
    ..execute(
      "INSERT INTO lines VALUES "
      "('k0','S4','ਸਿਰਲੇਖ ਮਹਲਾ ੫ ॥',100,10100,'k0f','ਕ',2,1),"
      "('k1','S4','ੴ ਸਤਿਗੁਰ ਪ੍ਰਸਾਦਿ ॥',100,10101,'k1f','ਕ',1,1),"
      "('k2','S4','ਪਹਿਲੀ ਅੰਤਰਾ ਤੁਕ ਇਕ ॥',100,10102,'k2f','ਕ',4,2),"
      "('k3','S4','ਪਹਿਲੀ ਅੰਤਰਾ ਤੁਕ ਦੋ ॥',100,10103,'k3f','ਕ',4,2),"
      "('k4','S4','ਘਰ ਦੀ ਤੁਕ ॥ ਰਹਾਉ ॥',100,10104,'k4f','ਕ',3,3),"
      "('k5','S4','ਦੂਜੀ ਅੰਤਰਾ ਤੁਕ ਇਕ ॥',100,10105,'k5f','ਕ',4,4),"
      "('k6','S4','ਦੂਜੀ ਅੰਤਰਾ ਤੁਕ ਦੋ ॥',100,10106,'k6f','ਕ',4,4)",
    )
    ..execute("INSERT INTO bani_lines VALUES ('a',1,0),('b',1,0)")
    // Self-contained Sundar Gutka tables (built by fetch_bani_lengths.py). Bani 1
    // has no length variation; bani 2 does (line 1 only in extralong).
    ..execute(
      'CREATE TABLE sg_banis (id INTEGER, ord INTEGER, grp TEXT, gurmukhi TEXT, '
      'roman TEXT, english TEXT, has_lengths INTEGER)',
    )
    ..execute(
      "INSERT INTO sg_banis VALUES "
      "(1,0,'nitnem','ਜਪੁਜੀ ਸਾਹਿਬ','japji','Japji Sahib',0),"
      "(2,1,'nitnem','ਰਹਿਰਾਸ ਸਾਹਿਬ','rehras','Rehras Sahib',1)",
    )
    ..execute(
      'CREATE TABLE sg_lines (bani_id INTEGER, seq INTEGER, gurmukhi TEXT, '
      'roman TEXT, english TEXT, punjabi TEXT, page INTEGER, is_header INTEGER, '
      'len_short INTEGER, len_medium INTEGER, len_long INTEGER, '
      'len_extralong INTEGER)',
    )
    ..execute(
      "INSERT INTO sg_lines VALUES "
      "(1,0,'ਜਪੁ ਲਾਈਨ','jap laain','Jap line one','',1,0,1,1,1,1),"
      "(1,1,'ਦੂਜੀ ਤੁਕ','dhoojee tuk','','',1,0,1,1,1,1),"
      "(2,0,'ਰਹਿਰਾਸ ਤੁਕ','raharaas','','',9,0,1,1,1,1),"
      "(2,1,'ਵਾਧੂ ਤੁਕ','vaadhoo','','',9,0,0,0,0,1)",
    )
    // shabads + writers + sections + sources so search results carry author +
    // raag and searches can filter. S1/S2 are in source 1 (SGGS); S3 is in
    // source 2 (Dasam) with a line on the same page as S1's - the Ang
    // collision case.
    ..execute(
      'CREATE TABLE shabads (id TEXT, source_id INTEGER, writer_id INTEGER, '
      'section_id INTEGER)',
    )
    ..execute(
      "INSERT INTO shabads VALUES "
      "('S1',1,1,1),('S2',1,2,2),('S3',2,1,1),('S4',1,1,1)",
    )
    ..execute(
      'CREATE TABLE sources (id INTEGER, name_gurmukhi TEXT, name_english TEXT)',
    )
    ..execute(
      "INSERT INTO sources VALUES "
      "(1,'ਸ੍ਰੀ ਗੁਰੂ ਗ੍ਰੰਥ ਸਾਹਿਬ','Sri Guru Granth Sahib Ji'),"
      "(2,'ਦਸਮ ਗ੍ਰੰਥ','Sri Dasam Granth')",
    )
    ..execute(
      'CREATE TABLE writers (id INTEGER, name_gurmukhi TEXT, name_english TEXT)',
    )
    ..execute(
      "INSERT INTO writers VALUES "
      "(1,'ਗੁਰੂ ਨਾਨਕ','Guru Nanak Dev Ji'),(2,'ਗੁਰੂ ਅਰਜਨ','Guru Arjan Dev Ji')",
    )
    ..execute(
      'CREATE TABLE sections (id INTEGER, name_gurmukhi TEXT, name_english TEXT)',
    )
    ..execute(
      "INSERT INTO sections VALUES "
      "(1,'ਤੁਖਾਰੀ','Raag Tukhaari'),(2,'ਗਉੜੀ','Raag Gauri')",
    )
    // Display data (enrich_corpus.py output): line 'a' has both translations and
    // both transliterations; line 'c' has none (as Dasam/Bhai Gurdas lines do).
    ..execute(
      'CREATE TABLE translations (line_id TEXT, lang TEXT, source TEXT, text TEXT)',
    )
    ..execute(
      "INSERT INTO translations VALUES "
      "('a','en','SSK','By thinking, He cannot be reduced to thought'),"
      "('a','pa','Sahib Singh','ਸੋਚਿ ਵਿਚਾਰ ਕੀਤਿਆਂ')",
    )
    ..execute(
      'CREATE TABLE transliterations (line_id TEXT, script TEXT, text TEXT)',
    )
    ..execute(
      "INSERT INTO transliterations VALUES "
      "('a','roman','sochai soch na hovee'),('a','devnagri','सोचै सोचि न होवई')",
    )
    ..execute(
      'CREATE VIRTUAL TABLE lines_fts USING fts5(gurmukhi_uni, first_letters_uni, '
      "content='lines', content_rowid='rowid')",
    )
    ..execute(
      'INSERT INTO lines_fts(rowid, gurmukhi_uni, first_letters_uni) '
      'SELECT rowid, gurmukhi_uni, first_letters_uni FROM lines',
    );
  return GurbaniDatabase.forTesting(db);
}
