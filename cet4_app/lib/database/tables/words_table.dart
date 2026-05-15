class WordsTable {
  static const String tableName = 'words';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        phonetic_uk TEXT,
        phonetic_us TEXT,
        audio_uk TEXT,
        audio_us TEXT,
        type TEXT,
        meaning TEXT NOT NULL,
        example TEXT,
        example_translation TEXT,
        collocation TEXT,
        level TEXT,
        UNIQUE(word)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_words_word ON $tableName (word)',
    );
    await db.execute(
      'CREATE INDEX idx_words_level ON $tableName (level)',
    );
  }
}
