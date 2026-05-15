import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AiMessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime? timestamp;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;

  const AiMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.timestamp,
    this.onCopy,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUser) ...[
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: primaryColor,
                ),
              ),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withBlue(220),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUser
                          ? null
                          : (isDark
                              ? const Color(0xFF0B0F19)
                              : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20.0),
                        topRight: const Radius.circular(20.0),
                        bottomLeft: Radius.circular(isUser ? 20.0 : 4.0),
                        bottomRight: Radius.circular(isUser ? 4.0 : 20.0),
                      ),
                    ),
                    child: isUser
                        ? Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                          )
                        : MarkdownBody(
                            data: message,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark ? Colors.grey[200] : const Color(0xFF1F2937),
                                    height: 1.6,
                                  ),
                              h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
                                  ),
                              h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
                                  ),
                              h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                    fontWeight: FontWeight.bold,
                                  ),
                              code: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.green[300] : Colors.green[800],
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : const Color(0xFFF8F9FC),
                                    fontFamily: 'monospace',
                                  ),
                              codeblockDecoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                              blockquoteDecoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: primaryColor.withOpacity(0.5),
                                    width: 3,
                                  ),
                                ),
                              ),
                              listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: isDark ? Colors.grey[300] : const Color(0xFF374151),
                                  ),
                              a: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _formatTime(timestamp!),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[600] : Colors.grey[500],
                              fontSize: 11,
                            ),
                      ),
                    ),
                  if (!isUser && (onCopy != null || onRetry != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onCopy != null)
                            InkWell(
                              onTap: onCopy,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '复制',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (onRetry != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: onRetry,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 14,
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '重试',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isUser) ...[
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
