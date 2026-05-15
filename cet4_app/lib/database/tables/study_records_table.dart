class StudyRecordsTable {
  static const String tableName = 'study_records';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT '未学',
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_study_time TEXT,
        next_review_time TEXT,
        FOREIGN KEY (word_id) REFERENCES words (id),
        UNIQUE(word_id, user_id)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_study_records_word_id ON $tableName (word_id)',
    );
    await db.execute(
      'CREATE INDEX idx_study_records_user_id ON $tableName (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_study_records_status ON $tableName (status)',
    );
    await db.execute(
      'CREATE INDEX idx_study_records_next_review ON $tableName (next_review_time)',
    );
  }
}
