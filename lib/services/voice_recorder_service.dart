import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// ============================================================
// VOICE RECORDER SERVICE
//
// ✅ Lazy + nullable recorder (dispose-safe)
// ✅ Auto re-create on next start
// ✅ Safe dispose (no more "already disposed" exception)
// ============================================================

class VoiceRecorderService {
  // ✅ Nullable + lazy — never create until needed
  static AudioRecorder? _recorder;

  static String? _currentPath;
  static DateTime? _startTime;
  static Timer? _durationTimer;
  static int _seconds = 0;
  static bool _isRecording = false;

  static bool get isRecording => _isRecording;
  static int get currentSeconds => _seconds;

  static const String _cloudName = 'acctuglm';
  static const String _uploadPreset = 'jibon_sathi_chat';

  // ============================================================
  // LAZY GETTER — always returns a valid instance
  // ============================================================
  static AudioRecorder _getRecorder() {
    _recorder ??= AudioRecorder();
    return _recorder!;
  }

  // ============================================================
  // START RECORDING
  // ============================================================
  static Future<bool> start() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        debugPrint('❌ Mic permission denied');
        return false;
      }

      final recorder = _getRecorder();

      if (await recorder.hasPermission() == false) {
        return false;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _currentPath = path;
      _startTime = DateTime.now();
      _seconds = 0;
      _isRecording = true;

      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
      });

      debugPrint('🎤 Recording started: $path');
      return true;
    } catch (e) {
      debugPrint('❌ Start recording failed: $e');
      _isRecording = false;
      return false;
    }
  }

  // ============================================================
  // STOP + UPLOAD
  // ============================================================
  static Future<Map<String, dynamic>?> stopAndUpload() async {
    if (_currentPath == null) return null;

    try {
      _durationTimer?.cancel();

      String? filePath;
      try {
        filePath = await _getRecorder().stop();
      } catch (e) {
        debugPrint('⚠️ Recorder stop failed: $e');
        filePath = _currentPath;
      }

      final finalPath = filePath ?? _currentPath!;
      final duration = _seconds;

      _currentPath = null;
      _startTime = null;
      _seconds = 0;
      _isRecording = false;

      if (duration < 1) {
        debugPrint('⚠️ Too short — cancelled');
        return null;
      }

      debugPrint('🎤 Recording stopped: ${duration}s');

      final url = await _uploadToCloudinary(File(finalPath));
      if (url == null) {
        debugPrint('❌ Upload failed');
        return null;
      }

      return {'url': url, 'duration': duration};
    } catch (e) {
      debugPrint('❌ Stop+Upload failed: $e');
      _isRecording = false;
      _currentPath = null;
      _seconds = 0;
      return null;
    }
  }

  // ============================================================
  // CANCEL RECORDING
  // ============================================================
  static Future<void> cancel() async {
    try {
      _durationTimer?.cancel();

      if (_recorder != null) {
        try {
          if (await _recorder!.isRecording()) {
            await _recorder!.stop();
          }
        } catch (_) {}
      }

      _currentPath = null;
      _startTime = null;
      _seconds = 0;
      _isRecording = false;
      debugPrint('🎤 Recording cancelled');
    } catch (e) {
      debugPrint('❌ Cancel failed: $e');
    }
  }

  // ============================================================
  // UPLOAD TO CLOUDINARY
  // ============================================================
  static Future<String?> _uploadToCloudinary(File file) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/video/upload',
      );
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset;
      req.files.add(await http.MultipartFile.fromPath('file', file.path));

      final res = await req.send();
      final bytes = await res.stream.toBytes();
      final body = String.fromCharCodes(bytes);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final match = RegExp(r'"secure_url":"([^"]+)"').firstMatch(body);
        if (match != null) {
          return match.group(1);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Cloudinary upload failed: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ SAFE DISPOSE — no more exception
  // ============================================================
  static Future<void> dispose() async {
    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      // Stop if currently recording
      if (_recorder != null) {
        try {
          if (await _recorder!.isRecording()) {
            await _recorder!.stop();
          }
        } catch (_) {}

        // Dispose + null it out
        try {
          await _recorder!.dispose();
        } catch (e) {
          debugPrint('⚠️ Recorder dispose skipped: $e');
        }
        _recorder = null; // ✅ Next call to _getRecorder() re-creates
      }

      _currentPath = null;
      _startTime = null;
      _seconds = 0;
      _isRecording = false;
    } catch (e) {
      debugPrint('⚠️ VoiceRecorderService dispose skipped: $e');
      _recorder = null;
      _isRecording = false;
    }
  }
}
