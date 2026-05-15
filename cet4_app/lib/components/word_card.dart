import 'package:flutter/material.dart';
import '../models/word.dart';

class WordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTap;
  final VoidCallback? onAiExplanation;
  final VoidCallback? onPlayAudio;
  final bool showActions;
  final bool isSelected;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const WordCard({
    super.key,
    required this.word,
    this.onTap,
    this.onAiExplanation,
    this.onPlayAudio,
    this.showActions = true,
    this.isSelected = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: primaryColor, width: 2)
            : null,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1F2937),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${word.type} ${word.phoneticUk}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (showActions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onFavoriteToggle != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isFavorite
                                  ? Colors.red.withOpacity(0.1)
                                  : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                              onPressed: onFavoriteToggle,
                              tooltip: '收藏',
                              iconSize: 20,
                            ),
                        if (onAiExplanation != null)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5)),
                              onPressed: onAiExplanation,
                              tooltip: 'AI讲解',
                              iconSize: 20,
                            ),
                          ),
                        if (onPlayAudio != null)
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.volume_up,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              onPressed: onPlayAudio,
                              tooltip: '播放发音',
                              iconSize: 20,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                word.meaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                    ),
              ),
              if (word.example.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    word.example,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
