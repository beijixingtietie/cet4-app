class Exam {
  final int id;
  final String name;
  final String year;
  final int totalTime; // 分钟
  final int totalScore;
  final List<ExamSection> sections;

  Exam({
    required this.id,
    required this.name,
    required this.year,
    required this.totalTime,
    required this.totalScore,
    required this.sections,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] as int,
      name: json['name'] as String,
      year: json['year'] as String,
      totalTime: json['total_time'] as int,
      totalScore: json['total_score'] as int,
      sections: (json['sections'] as List)
          .map((e) => ExamSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'year': year,
      'total_time': totalTime,
      'total_score': totalScore,
      'sections': sections.map((e) => e.toJson()).toList(),
    };
  }
}

class ExamSection {
  final String name;
  final String type;
  final int score;
  final List<int> questionIds;

  ExamSection({
    required this.name,
    required this.type,
    required this.score,
    required this.questionIds,
  });

  factory ExamSection.fromJson(Map<String, dynamic> json) {
    return ExamSection(
      name: json['name'] as String,
      type: json['type'] as String,
      score: json['score'] as int,
      questionIds: List<int>.from(json['question_ids'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'score': score,
      'question_ids': questionIds,
    };
  }
}

class ExamResult {
  final int id;
  final int examId;
  final int userId;
  final int totalScore;
  final Map<String, int> sectionScores;
  final DateTime examTime;
  final int duration; // 实际用时（分钟）

  ExamResult({
    required this.id,
    required this.examId,
    required this.userId,
    required this.totalScore,
    required this.sectionScores,
    required this.examTime,
    required this.duration,
  });

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    return ExamResult(
      id: json['id'] as int,
      examId: json['exam_id'] as int,
      userId: json['user_id'] as int,
      totalScore: json['total_score'] as int,
      sectionScores: Map<String, int>.from(json['section_scores'] as Map),
      examTime: DateTime.parse(json['exam_time'] as String),
      duration: json['duration'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exam_id': examId,
      'user_id': userId,
      'total_score': totalScore,
      'section_scores': sectionScores,
      'exam_time': examTime.toIso8601String(),
      'duration': duration,
    };
  }
}
