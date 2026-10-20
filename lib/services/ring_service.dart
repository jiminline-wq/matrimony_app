import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// RING SERVICE
// - Incoming call: Custom "ringtone.mp3" (loop + vibrate)
// - Outgoing call (ringback): Custom "ringback.mp3" (loop)
// ============================================================

class RingService {
  static bool _isRinging = false;
  static bool _isRingbackPlaying = false;

  // ✅ Incoming ringtone-এর জন্য আলাদা প্লেয়ার
  static final AudioPlayer _ringtonePlayer = AudioPlayer();

  // ✅ Outgoing ringback-এর জন্য আলাদা প্লেয়ার
  static final AudioPlayer _ringbackPlayer = AudioPlayer();

  // ============================================================
  // INCOMING — START RINGING (Custom Asset)
  // ============================================================
  static Future<void> start() async {
    if (_isRinging) return;
    _isRinging = true;

    try {
      // ✅ অডিও ফোকাস সেট করা (Agora যাতে ব্লক না করে)
      await _ringtonePlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );

      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop); // ✅ লুপ হবে
      await _ringtonePlayer.setVolume(1.0);

      // ✅ আপনার pubspec.yaml এর assets/ringtone.mp3 ফাইলটি এখানে বাজবে
      await _ringtonePlayer.play(AssetSource('ringtone.mp3'));

      debugPrint('🔔 Custom Incoming ring started');
    } catch (e) {
      debugPrint('❌ Custom Ringtone start failed: $e');
      _isRinging = false;
    }
  }

  // ============================================================
  // INCOMING — STOP RINGING
  // ============================================================
  static Future<void> stop() async {
    if (!_isRinging) return;
    _isRinging = false;

    try {
      await _ringtonePlayer.stop(); // ✅ কাস্টম প্লেয়ার স্টপ করা হলো
      debugPrint('🔕 Incoming ring stopped');
    } catch (e) {
      debugPrint('❌ Ringtone stop failed: $e');
    }
  }

  // ============================================================
  // OUTGOING — RINGBACK ("কু-কু" tone, custom asset)
  // ============================================================
  static Future<void> startRingback() async {
    if (_isRingbackPlaying) return;

    try {
      await _ringbackPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.voiceCommunication,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );

      await _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringbackPlayer.setVolume(1.0);

      await _ringbackPlayer.play(
        AssetSource('sounds/ringback.mp3'),
      );

      _isRingbackPlaying = true;
      debugPrint('🔔 Ringback started');
    } catch (e) {
      debugPrint('❌ Ringback start failed: $e');
      _isRingbackPlaying = false;
    }
  }

  // ============================================================
  // OUTGOING — STOP RINGBACK
  // ============================================================
  static Future<void> stopRingback() async {
    if (!_isRingbackPlaying) return;

    try {
      await _ringbackPlayer.stop();
      _isRingbackPlaying = false;
      debugPrint('🔕 Ringback stopped');
    } catch (e) {
      debugPrint('❌ Ringback stop failed: $e');
    }
  }

  // ============================================================
  // GLOBAL STOP — সব বন্ধ (call end, back press, dispose)
  // ============================================================
  static Future<void> stopAll() async {
    await stop();
    await stopRingback();
  }

  // ============================================================
  // DISPOSE — app kill / logout
  // ============================================================
  static Future<void> dispose() async {
    await stop();
    await stopRingback();
    await _ringtonePlayer.dispose(); // ✅ ডিসপোজ
    await _ringbackPlayer.dispose(); // ✅ ডিসপোজ
    debugPrint('🧹 RingService disposed');
  }

  // ============================================================
  // STATUS
  // ============================================================
  static bool get isRinging => _isRinging;
  static bool get isRingbackPlaying => _isRingbackPlaying;
}
