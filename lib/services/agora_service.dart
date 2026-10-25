import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// AGORA SERVICE
// Token fetch + Engine initialize + Join/Leave channel
// Samsung audio fix সহ
// ============================================================

class AgoraService {
  // 🔴 তোমার আসল Agora App ID
  static const String _appId = 'e0a672384d9d4fac9f73a05ce9ab93c1';

  static final _functions = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  static RtcEngine? _engine;
  static String? _currentChannel;

  static RtcEngine? get engine => _engine;
  static String? get currentChannel => _currentChannel;

  // ✅ Event callbacks — CallScreen এগুলো listen করবে
  static void Function(String channel)? onJoined;
  static void Function(int remoteUid)? onUserJoined;
  static void Function(int remoteUid)? onUserOffline;
  static void Function(ErrorCodeType err, String msg)? onError;

  // ============================================================
  // TOKEN FROM CLOUD FUNCTION
  // ============================================================
  static Future<Map<String, dynamic>?> getToken({
    required String channelName,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final numericUid = _uidToInt(uid);

      final callable = _functions.httpsCallable('generateAgoraToken');
      final result = await callable.call({
        'channelName': channelName,
        'uid': numericUid.toString(),
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      debugPrint('✅ Token received for channel: $channelName');
      return data;
    } catch (e) {
      debugPrint('❌ Failed to get Agora token: $e');
      return null;
    }
  }

  // ============================================================
  // UID -> INT (deterministic hash)
  // ============================================================
  static int _uidToInt(String uid) {
    int hash = 0;
    for (int i = 0; i < uid.length; i++) {
      hash = (hash * 31 + uid.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  // ============================================================
  // INITIALIZE ENGINE
  // ============================================================
  static Future<void> initialize({required String appId}) async {
    if (_engine != null) return;

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    // ✅ 1-on-1 call-এর জন্য communication profile
    await _engine!.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );

    // Event handlers
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        // ✅ FIX: join সফল হওয়ার পর স্পিকার চালু করা
        onJoinChannelSuccess: (connection, elapsed) async {
          debugPrint('✅ Joined channel: ${connection.channelId}');
          onJoined?.call(connection.channelId ?? '');

          // ৩০০ms ডিলে দিয়ে স্পিকার চালু করা হচ্ছে
          await Future.delayed(const Duration(milliseconds: 300));
          try {
            await _engine?.setEnableSpeakerphone(true);
            debugPrint('🔊 Speakerphone enabled after join');
          } catch (e) {
            debugPrint('⚠️ Speakerphone enable failed: $e');
          }
        },

        // ✅ FIX: রিমোট ইউজার join হলে আবার স্পিকার নিশ্চিত করা
        onUserJoined: (connection, remoteUid, elapsed) async {
          debugPrint('✅ Remote user joined: $remoteUid');
          onUserJoined?.call(remoteUid);

          await Future.delayed(const Duration(milliseconds: 200));
          try {
            await _engine?.setEnableSpeakerphone(true);
            debugPrint('🔊 Speakerphone re-enabled after remote join');
          } catch (e) {
            debugPrint('⚠️ Speakerphone re-enable failed: $e');
          }
        },

        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('⚠️ Remote user left: $remoteUid (reason: $reason)');
          onUserOffline?.call(remoteUid);
        },
        onLeaveChannel: (connection, stats) {
          debugPrint('👋 Left channel');
        },
        onError: (err, msg) {
          debugPrint('❌ Agora error: $err - $msg');
          onError?.call(err, msg);
        },
        // ✅ Token renewal
        onTokenPrivilegeWillExpire: (connection, token) async {
          debugPrint('⚠️ Token expiring soon');
          final newData = await getToken(
            channelName: connection.channelId ?? '',
          );
          if (newData?['token'] != null) {
            await _engine!.renewToken(newData!['token'] as String);
            debugPrint('✅ Token renewed');
          }
        },
        onRequestToken: (connection) async {
          debugPrint('⚠️ Token requested');
          final newData = await getToken(
            channelName: connection.channelId ?? '',
          );
          if (newData?['token'] != null) {
            await _engine!.renewToken(newData!['token'] as String);
          }
        },
      ),
    );

    await _engine!.enableAudio();
    await _engine!.enableVideo();

    // ============================================================
    // ✅ SAMSUNG AUDIO FIXES
    // ============================================================

    // 1. Audio profile (ভয়েসের কোয়ালিটি ভালো করার জন্য default ব্যবহার)
    try {
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
      debugPrint('🔊 Audio profile set to Default');
    } catch (e) {
      debugPrint('⚠️ setAudioProfile skipped: $e');
    }

    // 2. Volume
    try {
      await _engine!.adjustPlaybackSignalVolume(100);
      await _engine!.adjustRecordingSignalVolume(100);
      debugPrint('🔊 Volumes set');
    } catch (e) {
      debugPrint('⚠️ Volume adjust skipped: $e');
    }

    // ⚠️ setDefaultAudioRouteToSpeakerphone এখানে call করা হয়নি
    // কারণ join-এর আগে এটি call করলে কাজ করে না।
  }

  // ============================================================
  // JOIN CHANNEL
  // ============================================================
  static Future<bool> joinChannel({
    required String channelName,
    required String token,
    required int uid,
    required bool isVideoCall,
  }) async {
    try {
      await initialize(appId: _appId);

      // ✅ আগের channel active থাকলে leave করো
      if (_currentChannel != null) {
        await _engine!.leaveChannel();
        _currentChannel = null;
      }

      if (isVideoCall) {
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      } else {
        await _engine!.disableVideo();
        await _engine!.enableAudio();
      }

      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: isVideoCall,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: isVideoCall,
        ),
      );

      _currentChannel = channelName;

      debugPrint('✅ Join channel success: $channelName');
      return true;
    } catch (e) {
      debugPrint('❌ Join channel failed: $e');
      return false;
    }
  }

  // ============================================================
  // LEAVE CHANNEL
  // ============================================================
  static Future<void> leaveChannel() async {
    if (_currentChannel == null) return; // ✅ already left
    try {
      await _engine?.leaveChannel();
      _currentChannel = null;
      debugPrint('👋 Left channel');
    } catch (e) {
      debugPrint('❌ Leave channel error: $e');
    }
  }

  // ============================================================
  // MUTE / UNMUTE
  // ============================================================
  static Future<void> muteAudio(bool mute) async {
    await _engine?.muteLocalAudioStream(mute);
  }

  static Future<void> muteVideo(bool mute) async {
    await _engine?.muteLocalVideoStream(mute);
  }

  // ============================================================
  // SPEAKER TOGGLE (সাধারণ)
  // ============================================================
  static Future<void> setSpeaker(bool on) async {
    try {
      await _engine?.setEnableSpeakerphone(on);
      debugPrint('🔊 Speaker: $on');
    } catch (e) {
      debugPrint('⚠️ Speaker toggle skipped: $e');
    }
  }

  // ============================================================
  // SET AUDIO ROUTE (Samsung-specific)
  // ============================================================
  static Future<void> setAudioRoute(bool speakerOn) async {
    try {
      await _engine?.setEnableSpeakerphone(speakerOn);
      debugPrint('🔊 Audio route: ${speakerOn ? "speaker" : "earpiece"}');
    } catch (e) {
      // -3 NOT_READY হলেও চুপচাপ ignore করো
      debugPrint('⚠️ setAudioRoute skipped: $e');
    }
  }

  // ============================================================
  // SWITCH CAMERA
  // ============================================================
  static Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  // ============================================================
  // CLEAR CALLBACKS
  // ============================================================
  static void clearCallbacks() {
    onJoined = null;
    onUserJoined = null;
    onUserOffline = null;
    onError = null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  static Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _currentChannel = null;
    clearCallbacks();
  }
}
