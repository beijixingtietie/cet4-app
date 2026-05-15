class UserSettingsTable {
  static const String tableName = 'user_settings';

  static Future<void> createTable(dynamic db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 1,
        api_key TEXT,
        base_url TEXT DEFAULT 'https://api.openai.com/v1',
        model_name TEXT DEFAULT 'gpt-4o-mini',
        api_timeout INTEGER DEFAULT 60,
        daily_word_count INTEGER DEFAULT 50,
        theme_mode TEXT DEFAULT 'system',
        font_size REAL DEFAULT 1.0,
        sound_enabled INTEGER DEFAULT 1,
        checkin_days INTEGER DEFAULT 0,
        total_study_days INTEGER DEFAULT 0,
        last_checkin_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(user_id)
      )
    ''');
  }
}
