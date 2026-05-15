class Word {
  final int id;
  final String word;
  final String phoneticUk;
  final String phoneticUs;
  final String audioUk;
  final String audioUs;
  final String type;
  final String meaning;
  final String example;
  final String exampleTranslation;
  final String collocation;
  final String level;

  Word({
    required this.id,
    required this.word,
    required this.phoneticUk,
    required this.phoneticUs,
    required this.audioUk,
    required this.audioUs,
    required this.type,
    required this.meaning,
    required this.example,
    required this.exampleTranslation,
    required this.collocation,
    required this.level,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: (json['id'] as num?)?.toInt() ?? 0,
      word: (json['word'] as String?) ?? '',
      phoneticUk: (json['phonetic_uk'] as String?) ?? '',
      phoneticUs: (json['phonetic_us'] as String?) ?? '',
      audioUk: (json['audio_uk'] as String?) ?? '',
      audioUs: (json['audio_us'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      meaning: (json['meaning'] as String?) ?? '',
      example: (json['example'] as String?) ?? '',
      exampleTranslation: (json['example_translation'] as String?) ?? '',
      collocation: (json['collocation'] as String?) ?? '',
      level: (json['level'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'phonetic_uk': phoneticUk,
      'phonetic_us': phoneticUs,
      'audio_uk': audioUk,
      'audio_us': audioUs,
      'type': type,
      'meaning': meaning,
      'example': example,
      'example_translation': exampleTranslation,
      'collocation': collocation,
      'level': level,
    };
  }

  /// 从数据库行创建 Word（DB列名与JSON key相同，复用fromJson）
  factory Word.fromDbMap(Map<String, dynamic> map) {
    return Word.fromJson(map);
  }
}

class StudyRecord {
  final int id;
  final int wordId;
  final int userId;
  final String status; // 未学/学习中/已掌握/已遗忘
  final int correctCount;
  final int wrongCount;
  final DateTime lastStudyTime;
  final DateTime nextReviewTime;

  StudyRecord({
    required this.id,
    required this.wordId,
    required this.userId,
    required this.status,
    required this.correctCount,
    required this.wrongCount,
    required this.lastStudyTime,
    required this.nextReviewTime,
  });

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      id: json['id'] as int,
      wordId: json['word_id'] as int,
      userId: json['user_id'] as int,
      status: json['status'] as String,
      correctCount: json['correct_count'] as int,
      wrongCount: json['wrong_count'] as int,
      lastStudyTime: DateTime.parse(json['last_study_time'] as String),
      nextReviewTime: DateTime.parse(json['next_review_time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word_id': wordId,
      'user_id': userId,
      'status': status,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'last_study_time': lastStudyTime.toIso8601String(),
      'next_review_time': nextReviewTime.toIso8601String(),
    };
  }
}
