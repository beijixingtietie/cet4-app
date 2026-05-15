import 'package:flutter/material.dart';
import '../models/question.dart';

class QuestionItem extends StatelessWidget {
  final Question question;
  final VoidCallback? onTap;
  final VoidCallback? onAiExplanation;
  final bool showAnswer;
  final int? selectedOptionIndex;
  final ValueChanged<int>? onOptionSelected;

  const QuestionItem({
    super.key,
    required this.question,
    this.onTap,
    this.onAiExplanation,
    this.showAnswer = false,
    this.selectedOptionIndex,
    this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(question.type).withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      question.type,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: _getTypeColor(question.type),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${question.year}年',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                  ),
                  const Spacer(),
                  if (onAiExplanation != null)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5)),
                        onPressed: onAiExplanation,
                        tooltip: 'AI解析',
                        iconSize: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                question.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.grey[200] : const Color(0xFF1F2937),
                      height: 1.5,
                    ),
              ),

              if (question.options != null) ...[
                const SizedBox(height: 16),
                ...question.options!.asMap().entries.map((entry) {
                  final isSelected = selectedOptionIndex == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: onOptionSelected != null
                          ? () => onOptionSelected!(entry.key)
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withOpacity(isDark ? 0.2 : 0.1)
                              : (isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : const Color(0xFFF8F9FC)),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                String.fromCharCode(65 + entry.key),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],

              if (showAnswer) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(isDark ? 0.3 : 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '答案: ${question.answer}',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '解析',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.green[300] : Colors.green[800],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        question.explanation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '听力':
        return Colors.blue;
      case '选词填空':
        return Colors.green;
      case '长篇阅读':
        return Colors.orange;
      case '仔细阅读':
        return Colors.purple;
      case '翻译':
        return Colors.red;
      case '写作':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
