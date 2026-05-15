class EbbinghausAlgorithm {
  // 艾宾浩斯遗忘曲线复习间隔（单位：天）
  static const List<int> _reviewIntervals = [1, 2, 4, 7, 15, 30];

  // 计算下次复习时间
  static DateTime calculateNextReviewTime({
    required int correctCount,
    required DateTime lastStudyTime,
  }) {
    // 根据正确次数确定复习间隔
    int intervalIndex = correctCount.clamp(0, _reviewIntervals.length - 1);
    int intervalDays = _reviewIntervals[intervalIndex];

    // 计算下次复习时间
    return lastStudyTime.add(Duration(days: intervalDays));
  }

  // 判断是否需要复习
  static bool needsReview({
    required DateTime nextReviewTime,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    return now.isAfter(nextReviewTime) || now.isAtSameMomentAs(nextReviewTime);
  }

  // 更新学习记录
  static Map<String, dynamic> updateStudyRecord({
    required bool isCorrect,
    required int currentCorrectCount,
    required int currentWrongCount,
    required String currentStatus,
  }) {
    int newCorrectCount = currentCorrectCount;
    int newWrongCount = currentWrongCount;
    String newStatus = currentStatus;

    if (isCorrect) {
      newCorrectCount++;
      // 根据正确次数更新状态
      if (newCorrectCount >= 3) {
        newStatus = '已掌握';
      } else if (newCorrectCount >= 1) {
        newStatus = '学习中';
      }
    } else {
      newWrongCount++;
      newStatus = '已遗忘';
      // 错误时重置正确计数
      newCorrectCount = 0;
    }

    final now = DateTime.now();
    final nextReviewTime = calculateNextReviewTime(
      correctCount: newCorrectCount,
      lastStudyTime: now,
    );

    return {
      'correct_count': newCorrectCount,
      'wrong_count': newWrongCount,
      'status': newStatus,
      'last_study_time': now.toIso8601String(),
      'next_review_time': nextReviewTime.toIso8601String(),
    };
  }

  // 获取今日需要复习的单词数量
  static int getTodayReviewCount(List<Map<String, dynamic>> studyRecords) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    int count = 0;
    for (var record in studyRecords) {
      if (record['next_review_time'] != null) {
        final nextReviewTime = DateTime.parse(record['next_review_time'] as String);
        if (nextReviewTime.isAfter(todayStart) && nextReviewTime.isBefore(todayEnd)) {
          count++;
        }
      }
    }
    return count;
  }

  // 获取学习进度统计
  static Map<String, int> getStudyProgress(List<Map<String, dynamic>> studyRecords) {
    int notLearned = 0;
    int learning = 0;
    int mastered = 0;
    int forgotten = 0;

    for (var record in studyRecords) {
      final status = record['status'] as String;
      switch (status) {
        case '未学':
          notLearned++;
          break;
        case '学习中':
          learning++;
          break;
        case '已掌握':
          mastered++;
          break;
        case '已遗忘':
          forgotten++;
          break;
      }
    }

    return {
      'not_learned': notLearned,
      'learning': learning,
      'mastered': mastered,
      'forgotten': forgotten,
      'total': studyRecords.length,
    };
  }
}
