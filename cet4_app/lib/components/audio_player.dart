import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';

enum PlayerLoopMode {
  none,
  one,
  all,
}

class AudioPlayerWidget extends StatefulWidget {
  final String? audioUrl;
  final String? localPath;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool showNavigation;
  final String? title;

  const AudioPlayerWidget({
    super.key,
    this.audioUrl,
    this.localPath,
    this.onPrevious,
    this.onNext,
    this.showNavigation = true,
    this.title,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late ja.AudioPlayer _audioPlayer;
  bool _isLoading = false;
  String? _errorMessage;
  double _playbackSpeed = 1.0;
  PlayerLoopMode _loopMode = PlayerLoopMode.none;
  double _volume = 1.0;
  bool _showVolumeSlider = false;

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _processingStateSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ja.AudioPlayer();
    _initAudioSession();
    _setupListeners();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (e) {
      debugPrint('Audio session init error: $e');
    }
  }

  void _setupListeners() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen(
      (playerState) {
        if (mounted) setState(() {});
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = '播放错误: $error';
            _isLoading = false;
          });
        }
      },
    );

    _processingStateSubscription = _audioPlayer.processingStateStream.listen(
      (processingState) {
        if (processingState == ja.ProcessingState.completed) {
          if (_loopMode == PlayerLoopMode.one) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.play();
          }
        }
      },
    );
  }

  Future<void> _loadAudio() async {
    if (widget.audioUrl == null && widget.localPath == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _audioPlayer.stop();

      if (widget.localPath != null) {
        final file = File(widget.localPath!);
        if (await file.exists()) {
          await _audioPlayer.setFilePath(widget.localPath!);
        } else {
          throw Exception('本地文件不存在');
        }
      } else if (widget.audioUrl != null) {
        await _audioPlayer.setUrl(widget.audioUrl!);
      }

      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.setVolume(_volume);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载音频失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.localPath != widget.localPath) {
      _loadAudio();
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _processingStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      if (_audioPlayer.processingState == ja.ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
      }
      _audioPlayer.play();
    }
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _audioPlayer.setSpeed(speed);
  }

  void _toggleLoopMode() {
    setState(() {
      switch (_loopMode) {
        case PlayerLoopMode.none:
          _loopMode = PlayerLoopMode.one;
          _audioPlayer.setLoopMode(ja.LoopMode.one);
          break;
        case PlayerLoopMode.one:
          _loopMode = PlayerLoopMode.all;
          _audioPlayer.setLoopMode(ja.LoopMode.all);
          break;
        case PlayerLoopMode.all:
          _loopMode = PlayerLoopMode.none;
          _audioPlayer.setLoopMode(ja.LoopMode.off);
          break;
      }
    });
  }

  IconData _getLoopIcon() {
    switch (_loopMode) {
      case PlayerLoopMode.none:
        return Icons.repeat;
      case PlayerLoopMode.one:
        return Icons.repeat_one;
      case PlayerLoopMode.all:
        return Icons.repeat;
    }
  }

  String _getLoopLabel() {
    switch (_loopMode) {
      case PlayerLoopMode.none:
        return '不循环';
      case PlayerLoopMode.one:
        return '单曲循环';
      case PlayerLoopMode.all:
        return '列表循环';
    }
  }

  Color _getSpeedColor(double speed) {
    if (_playbackSpeed == speed) {
      return const Color(0xFF4F46E5);
    }
    return Colors.grey;
  }

  Color _getSpeedBackgroundColor(double speed, bool isDark) {
    if (_playbackSpeed == speed) {
      return const Color(0xFF4F46E5).withOpacity(0.12);
    }
    return isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4F46E5);
    final backgroundColor = isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8F9FC);
    final cardColor = isDark ? const Color(0xFF1A1F2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                widget.title!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.red, size: 20),
                      onPressed: _loadAudio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '加载音频中...',
                    style: TextStyle(
                      fontSize: 14,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 16),
            StreamBuilder<Duration?>(
              stream: _audioPlayer.durationStream,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: _audioPlayer.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final effectivePosition = position > duration ? duration : position;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: primaryColor,
                              inactiveTrackColor: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey[200],
                              thumbColor: primaryColor,
                              overlayColor: primaryColor.withOpacity(0.2),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                            ),
                            child: Slider(
                              value: effectivePosition.inMilliseconds.toDouble().clamp(
                                0,
                                duration.inMilliseconds.toDouble().max(1),
                              ),
                              max: duration.inMilliseconds.toDouble().max(1),
                              onChanged: (value) {
                                _audioPlayer.seek(
                                  Duration(milliseconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(effectivePosition),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subTextColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subTextColor,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showNavigation)
                  _buildControlButton(
                    icon: Icons.skip_previous,
                    onPressed: widget.onPrevious,
                    color: subTextColor,
                    size: 28,
                  ),
                if (widget.showNavigation) const SizedBox(width: 16),
                StreamBuilder<ja.PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final isPlaying = playerState?.playing ?? false;
                    final processingState = playerState?.processingState;

                    return GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause
                              : (processingState == ja.ProcessingState.completed
                                  ? Icons.replay
                                  : Icons.play_arrow),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
                if (widget.showNavigation) const SizedBox(width: 16),
                if (widget.showNavigation)
                  _buildControlButton(
                    icon: Icons.skip_next,
                    onPressed: widget.onNext,
                    color: subTextColor,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _speedOptions.map((speed) {
                  return GestureDetector(
                    onTap: () => _setSpeed(speed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getSpeedBackgroundColor(speed, isDark),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getSpeedColor(speed),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildIconButton(
                    icon: _getLoopIcon(),
                    label: _getLoopLabel(),
                    onPressed: _toggleLoopMode,
                    isActive: _loopMode != LoopMode.none,
                    primaryColor: primaryColor,
                    subTextColor: subTextColor,
                  ),
                  _buildIconButton(
                    icon: Icons.volume_up,
                    label: '音量',
                    onPressed: () {
                      setState(() {
                        _showVolumeSlider = !_showVolumeSlider;
                      });
                    },
                    isActive: _showVolumeSlider,
                    primaryColor: primaryColor,
                    subTextColor: subTextColor,
                  ),
                ],
              ),
            ),
            if (_showVolumeSlider)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Icon(
                      _volume == 0
                          ? Icons.volume_off
                          : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                      size: 18,
                      color: subTextColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: primaryColor,
                          inactiveTrackColor: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[200],
                          thumbColor: primaryColor,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 5,
                          ),
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            setState(() {
                              _volume = value;
                            });
                            _audioPlayer.setVolume(value);
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${(_volume * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: subTextColor,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color? color,
    double size = 24,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    required Color primaryColor,
    required Color? subTextColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? primaryColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? primaryColor : subTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? primaryColor : subTextColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension DoubleExtension on double {
  double max(double other) => this > other ? this : other;
}
