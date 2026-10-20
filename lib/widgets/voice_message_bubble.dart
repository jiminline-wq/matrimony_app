import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

// ============================================================
// VOICE MESSAGE BUBBLE — WhatsApp-level experience
//
// ✅ Global coordination — একসাথে একটাই voice play হবে
// ✅ Loading + Error state
// ✅ Tap-to-seek on waveform
// ✅ Playback speed toggle (1x → 1.5x → 2x)
// ✅ Auto-stop on dispose
// ✅ Smooth time display (current / total)
// ============================================================

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final int duration; // seconds
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.url,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;

  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  double _speed = 1.0;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;

  // ✅ Global coordination — current playing instance
  static _VoiceMessageBubbleState? _currentlyPlaying;

  // Static waveform bar heights (visual only — same for all bubbles)
  static const List<int> _bars = [
    6,
    12,
    8,
    16,
    20,
    10,
    14,
    22,
    18,
    12,
    16,
    24,
    20,
    14,
    10,
    18,
    22,
    16,
    12,
    8,
    14,
    20,
    18,
    12,
    16,
    22,
    14,
    10,
    8,
    12,
  ];

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.duration);
    _setupListeners();
  }

  void _setupListeners() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.playing) {
          _isLoading = false;
          _hasError = false;
        }
      });
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _durSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      if (d.inMilliseconds > 0) {
        setState(() => _total = d);
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
        _speed = 1.0;
      });
      _player.setPlaybackRate(1.0);
      if (_currentlyPlaying == this) _currentlyPlaying = null;
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();

    // ✅ Stop if this was playing
    if (_currentlyPlaying == this) {
      _currentlyPlaying = null;
    }
    _player.dispose();
    super.dispose();
  }

  // ============================================================
  // STOP SILENTLY (called by other bubbles when they start)
  // ============================================================
  Future<void> _stopSilently() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _speed = 1.0;
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // TOGGLE PLAY / PAUSE
  // ============================================================
  Future<void> _togglePlay() async {
    if (_hasError) {
      // Retry
      setState(() {
        _hasError = false;
        _position = Duration.zero;
      });
    }

    try {
      if (_isPlaying) {
        await _player.pause();
        return;
      }

      // ✅ Stop any other playing bubble
      final other = _currentlyPlaying;
      if (other != null && other != this) {
        await other._stopSilently();
      }
      _currentlyPlaying = this;

      if (_position > Duration.zero) {
        // Resume from paused position
        await _player.resume();
        if (_speed != 1.0) await _player.setPlaybackRate(_speed);
      } else {
        // Fresh start
        setState(() => _isLoading = true);

        await _player.setPlaybackRate(_speed);
        await _player.play(
          UrlSource(widget.url),
          mode: PlayerMode.mediaPlayer,
        );
      }
    } catch (e) {
      debugPrint('❌ Voice play failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isPlaying = false;
        });
      }
      if (_currentlyPlaying == this) _currentlyPlaying = null;
    }
  }

  // ============================================================
  // SEEK BY TAP ON WAVEFORM
  // ============================================================
  Future<void> _seekToFraction(double fraction) async {
    if (_total.inMilliseconds == 0) return;
    final clamped = fraction.clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (_total.inMilliseconds * clamped).round(),
    );
    try {
      await _player.seek(target);
      if (mounted) setState(() => _position = target);
    } catch (e) {
      debugPrint('❌ Seek failed: $e');
    }
  }

  // ============================================================
  // SPEED TOGGLE
  // ============================================================
  Future<void> _cycleSpeed() async {
    double next;
    if (_speed == 1.0) {
      next = 1.5;
    } else if (_speed == 1.5) {
      next = 2.0;
    } else {
      next = 1.0;
    }
    try {
      await _player.setPlaybackRate(next);
      if (mounted) setState(() => _speed = next);
    } catch (e) {
      debugPrint('❌ Speed change failed: $e');
    }
  }

  // ============================================================
  // FORMAT
  // ============================================================
  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final activeCount = (_bars.length * progress).round();

    final primaryColor = widget.isMe ? Colors.white : primaryMaroon;
    final inactiveColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.35)
        : primaryMaroon.withValues(alpha: 0.25);

    // Time label
    final showProgress = _isPlaying || _position > Duration.zero;
    final timeLabel = showProgress
        ? _fmt(_position)
        : _fmt(Duration(seconds: widget.duration));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ============================================================
        // PLAY / PAUSE BUTTON
        // ============================================================
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : primaryMaroon.withValues(alpha: 0.1),
              border: Border.all(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : primaryMaroon.withValues(alpha: 0.2),
              ),
            ),
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                : Icon(
                    _hasError
                        ? Icons.refresh
                        : (_isPlaying ? Icons.pause : Icons.play_arrow),
                    color: _hasError ? Colors.redAccent : primaryColor,
                    size: 22,
                  ),
          ),
        ),
        const SizedBox(width: 10),

        // ============================================================
        // WAVEFORM + TIME
        // ============================================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform — tap to seek
              SizedBox(
                height: 26,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (_hasError) return;
                        final fraction =
                            details.localPosition.dx / constraints.maxWidth;
                        _seekToFraction(fraction);
                      },
                      onHorizontalDragUpdate: (details) {
                        if (_hasError) return;
                        final fraction =
                            details.localPosition.dx / constraints.maxWidth;
                        _seekToFraction(fraction);
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(_bars.length, (i) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0.5,
                              ),
                              child: Container(
                                height: _bars[i].toDouble(),
                                decoration: BoxDecoration(
                                  color: i < activeCount
                                      ? primaryColor
                                      : inactiveColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),

              // Time + Speed
              Row(
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.9)
                          : secondaryText,
                    ),
                  ),
                  if (_hasError) ...[
                    const SizedBox(width: 6),
                    const Text(
                      'Failed',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Speed toggle (only when playing or has progress)
                  if (_isPlaying || _position > Duration.zero)
                    GestureDetector(
                      onTap: _cycleSpeed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.2)
                              : primaryMaroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_speed % 1 == 0 ? _speed.toInt() : _speed}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
