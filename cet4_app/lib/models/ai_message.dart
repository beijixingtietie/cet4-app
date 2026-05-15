class AiMessage {
  final int id;
  final int userId;
  final String role; // user/assistant
  final String content;
  final DateTime timestamp;
  final String? requestId;

  AiMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.requestId,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      requestId: json['request_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'request_id': requestId,
    };
  }
}

class AiCorrection {
  final int id;
  final int userId;
  final String type; // writing/translation
  final String originalContent;
  final String correctedContent;
  final int score;
  final DateTime timestamp;

  AiCorrection({
    required this.id,
    required this.userId,
    required this.type,
    required this.originalContent,
    required this.correctedContent,
    required this.score,
    required this.timestamp,
  });

  factory AiCorrection.fromJson(Map<String, dynamic> json) {
    return AiCorrection(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      type: json['type'] as String,
      originalContent: json['original_content'] as String,
      correctedContent: json['corrected_content'] as String,
      score: json['score'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'original_content': originalContent,
      'corrected_content': correctedContent,
      'score': score,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
