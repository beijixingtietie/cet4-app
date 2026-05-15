class AiCorrectionsTable {
  static const String tableName = 'ai_corrections';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 1,
        type TEXT NOT NULL,
        original_content TEXT NOT NULL,
        corrected_content TEXT NOT NULL,
        score INTEGER,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_settings (user_id)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_ai_corrections_user_id ON $tableName (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_corrections_type ON $tableName (type)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_corrections_timestamp ON $tableName (timestamp)',
    );
  }
}
