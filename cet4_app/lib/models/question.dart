class Question {
  final int id;
  final String type; // 听力/选词填空/长篇阅读/仔细阅读/翻译/写作
  final String year;
  final String content;
  final String? passage;
  final List<String>? options;
  final String answer;
  final String explanation;
  final String? audioUrl;

  Question({
    required this.id,
    required this.type,
    required this.year,
    required this.content,
    this.passage,
    this.options,
    required this.answer,
    required this.explanation,
    this.audioUrl,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      type: json['type'] as String,
      year: json['year'] as String,
      content: json['content'] as String,
      passage: json['passage'] as String?,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      answer: json['answer'] as String,
      explanation: json['explanation'] as String,
      audioUrl: json['audio_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'year': year,
      'content': content,
      'passage': passage,
      'options': options,
      'answer': answer,
      'explanation': explanation,
      'audio_url': audioUrl,
    };
  }

  /// 转为数据库存储格式 (options 序列化为 JSON 字符串)
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'type': type,
      'year': year,
      'content': content,
      'passage': passage ?? '',
      'options': options != null ? _optionsToJson(options!) : '',
      'answer': answer,
      'explanation': explanation,
      'audio_url': audioUrl ?? '',
    };
  }

  /// 从数据库行创建 Question
  factory Question.fromDbMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as int,
      type: map['type'] as String,
      year: (map['year'] as String?) ?? '',
      content: map['content'] as String,
      passage: map['passage'] as String?,
      options: _optionsFromDb(map['options'] as String?),
      answer: (map['answer'] as String?) ?? '',
      explanation: (map['explanation'] as String?) ?? '',
      audioUrl: map['audio_url'] as String?,
    );
  }

  static String _optionsToJson(List<String> options) {
    return '["${options.join('","')}"]';
  }

  static List<String>? _optionsFromDb(String? dbValue) {
    if (dbValue == null || dbValue.isEmpty) return null;
    try {
      final decoded = RegExp(r'"([^"]*)"').allMatches(dbValue).map((m) => m.group(1)!).toList();
      return decoded.isNotEmpty ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

class ExamRecord {
  final int id;
  final int questionId;
  final int userId;
  final String? userAnswer;
  final bool isCorrect;
  final DateTime answerTime;

  ExamRecord({
    required this.id,
    required this.questionId,
    required this.userId,
    this.userAnswer,
    required this.isCorrect,
    required this.answerTime,
  });

  factory ExamRecord.fromJson(Map<String, dynamic> json) {
    return ExamRecord(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      userId: json['user_id'] as int,
      userAnswer: json['user_answer'] as String?,
      isCorrect: json['is_correct'] as bool,
      answerTime: DateTime.parse(json['answer_time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'user_id': userId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'answer_time': answerTime.toIso8601String(),
    };
  }
}

class WrongQuestion {
  final int id;
  final int questionId;
  final int userId;
  final String userAnswer;
  final DateTime addTime;

  WrongQuestion({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.userAnswer,
    required this.addTime,
  });

  factory WrongQuestion.fromJson(Map<String, dynamic> json) {
    return WrongQuestion(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      userId: json['user_id'] as int,
      userAnswer: json['user_answer'] as String,
      addTime: DateTime.parse(json['add_time'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'user_id': userId,
      'user_answer': userAnswer,
      'add_time': addTime.toIso8601String(),
    };
  }
}
