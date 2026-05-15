class WordBookmarksTable {
  static const String tableName = 'word_bookmarks';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        UNIQUE(word_id, user_id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_word_bookmarks_user_id ON $tableName (user_id)',
    );
  }
}
