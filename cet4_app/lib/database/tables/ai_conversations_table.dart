class AiConversationsTable {
  static const String tableName = 'ai_conversations';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 1,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        request_id TEXT,
        FOREIGN KEY (user_id) REFERENCES user_settings (user_id)
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX idx_ai_conversations_user_id ON $tableName (user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_ai_conversations_timestamp ON $tableName (timestamp)',
    );
  }
}
