class ExamRecordsTable {
  static const String tableName = 'exam_records';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL DEFAULT 1,
        user_answer TEXT,
        is_correct INTEGER NOT NULL DEFAULT 0,
        answer_time TEXT NOT NULL
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_exam_records_question_id ON $tableName (question_id)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_records_user_id ON $tableName (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_exam_records_answer_time ON $tableName (answer_time)',
    );
  }
}
