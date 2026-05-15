class WrongQuestionsTable {
  static const String tableName = 'wrong_questions';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL DEFAULT 1,
        user_answer TEXT NOT NULL,
        add_time TEXT NOT NULL,
        UNIQUE(question_id, user_id)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_wrong_questions_question_id ON $tableName (question_id)',
    );
    await db.execute(
      'CREATE INDEX idx_wrong_questions_user_id ON $tableName (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_wrong_questions_add_time ON $tableName (add_time)',
    );
  }
}
