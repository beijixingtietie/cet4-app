class QuestionsTable {
  static const String tableName = 'questions';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        year TEXT,
        content TEXT NOT NULL,
        passage TEXT,
        options TEXT,
        answer TEXT,
        explanation TEXT,
        audio_url TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_questions_type ON $tableName (type)',
    );
    await db.execute(
      'CREATE INDEX idx_questions_year ON $tableName (year)',
    );
  }
}
