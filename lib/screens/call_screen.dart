import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/colors.dart';
import '../services/agora_service.dart';
import '../services/call_service.dart';
import '../services/ring_service.dart';
import '../services/call_history_service.dart';
import '../services/chat_service.dart'; // ✅ নতুন ইমপোর্ট

// ============================================================
// CALL SCREEN — Agora based Voice + Video
//
// ✅ Samsung audio fix (speaker set in onJoined callback)
// ✅ Duration tracking + Firestore save
// ✅ cancelCall for caller-hungup-before-answer
// ✅ Ring timeout for incoming (30s)
// ✅ Guard against duplicate joins
// ✅ Timer.periodic for duration counter (no leak)
// ============================================================

class CallScreen extends StatefulWidget {
  final bool isBangla;
  final String channelName;
  final String otherUserName;
  final String? otherUserPhoto;
  final bool isVideoCall;
  final bool isCaller;

  final String? callId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.isBangla,
    required this.channelName,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.isVideoCall,
    this.isCaller = true,
    this.callId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  int? _remoteUid;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  bool _isConnecting = true;
  String? _errorMessage;
  int _callDuration = 0;

  // Incoming ringing state
  bool _isIncomingRinging = false;
  String? _callId;
  StreamSubscription<DocumentSnapshot>? _callListener;
  bool _callEnded = false;

  // ✅ Duplicate join/leave প্রতিরোধ
  bool _isStartingJoin = false;
  bool _hasJoined = false;

  // ✅ Ring timeout (incoming side)
  Timer? _ringTimeout;

  // ✅ Duration counter
  Timer? _durationTimer;

  // ✅ Call history duration tracking
  DateTime? _callStartTime;

  // ✅ Ring timeout duration
  static const Duration _ringDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();

    _callId = widget.callId;
    _isIncomingRinging = widget.isIncoming;

    _registerCallbacks();

    if (widget.isIncoming) {
      debugPrint('📞 Incoming call — waiting for accept');
      _listenToCallStatus();

      // ✅ Ring + vibrate শুরু
      RingService.start();

      // ✅ 30 সেকেন্ড পর auto-stop → missed mark
      _ringTimeout = Timer(_ringDuration, () async {
        if (mounted && _isIncomingRinging && !_callEnded) {
          debugPrint('⏰ Ring timeout — marking as missed');
          _callEnded = true;

          if (_callId != null) {
            await CallService.missedCall(_callId!);
          }

          RingService.stop();
          if (mounted) Navigator.pop(context);
        }
      });
    } else {
      // ✅ NEW — Outgoing call: start ringback
      // (will stop automatically when callee accepts/rejects)
      // Ringback starts in _startCall() after permissions succeed
      _startCall();
      _listenToCallStatus();
    }
  }

  // ============================================================
  // AGORA CALLBACKS
  // ============================================================
  void _registerCallbacks() {
    AgoraService.onJoined = (channel) {
      if (!mounted) return;
      debugPrint('🎯 Callback: joined $channel');
      _hasJoined = true;

      // ✅ Duration tracking শুরু
      _callStartTime = DateTime.now();

      // ✅ Samsung audio fix — fire-and-forget (await করব না)
      // setEnableSpeakerphone join সম্পূর্ণ হওয়ার পরে safe
      AgoraService.setAudioRoute(widget.isVideoCall);

      setState(() {
        _isJoined = true;
        _isConnecting = false;
        _isSpeakerOn = widget.isVideoCall;
      });
      _startTimer();
    };

    AgoraService.onUserJoined = (remoteUid) {
      if (!mounted) return;
      debugPrint('🎯 Callback: remote joined $remoteUid');
      setState(() => _remoteUid = remoteUid);
    };

    AgoraService.onUserOffline = (remoteUid) {
      if (!mounted) return;
      debugPrint('🎯 Callback: remote left $remoteUid');
      setState(() => _remoteUid = null);
    };

    AgoraService.onError = (err, msg) {
      debugPrint('🎯 Callback: Agora error $err - $msg');
    };
  }

  // ============================================================
  // LISTEN TO FIRESTORE CALL STATUS
  // ============================================================
  void _listenToCallStatus() {
    if (_callId == null) return;

    _callListener = CallService.callStream(_callId!).listen((snap) async {
      if (!mounted) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;
      debugPrint('📞 Call status update: $status');

      switch (status) {
        // ------------------------------------------------------

        case CallService.statusAccepted:
          RingService.stop();
          RingService.stopRingback();
          RingService.stopRingback(); // ✅ NEW
          _ringTimeout?.cancel();

          // Guard: একবারই join করবে
          if (!_hasJoined && !_isStartingJoin) {
            _isStartingJoin = true;
            setState(() => _isIncomingRinging = false);
            _startCall();
          }
          break;

        // ------------------------------------------------------
        case CallService.statusRejected:
        case CallService.statusCancelled:
          RingService.stop();
          RingService.stopRingback();
          _ringTimeout?.cancel();

          final myUid = FirebaseAuth.instance.currentUser?.uid;
          if (myUid != null) {
            final callerId = data['callerId'] ?? '';
            final receiverId = data['receiverId'] ?? '';
            await ChatService.logCallMessage(
              senderId: callerId,
              receiverId: receiverId,
              isVideo: widget.isVideoCall,
              status: 'rejected',
            );
          }

          // Caller side — receiver declined
          if (!widget.isIncoming && mounted && !_callEnded) {
            _callEnded = true;
            _showAndPop(widget.isBangla ? 'কল বাতিল হয়েছে' : 'Call declined');
          }
          // Receiver side — caller hung up before accept
          else if (widget.isIncoming && mounted && !_callEnded) {
            _callEnded = true;
            _showAndPop(widget.isBangla ? 'কল বাতিল হয়েছে' : 'Call cancelled');
          }
          break;

        // ------------------------------------------------------
        case CallService.statusEnded:
        case CallService.statusMissed:
          RingService.stop();
          RingService.stopRingback(); // ✅ NEW
          _ringTimeout?.cancel();

          if (mounted && !_callEnded) {
            _callEnded = true;

            // ✅ কল লগ সেভ করুন
            final myUid = FirebaseAuth.instance.currentUser?.uid;
            if (myUid != null && _callId != null) {
              if (status == CallService.statusMissed) {
                await ChatService.logCallMessage(
                  senderId: widget.isCaller ? myUid : data['callerId'] ?? '',
                  receiverId:
                      widget.isCaller ? data['receiverId'] ?? '' : myUid,
                  isVideo: widget.isVideoCall,
                  status: 'missed',
                );
              } else if (status == CallService.statusEnded && _isJoined) {
                final duration =
                    DateTime.now().difference(_callStartTime!).inSeconds;
                await ChatService.logCallMessage(
                  senderId: widget.isCaller ? myUid : data['callerId'] ?? '',
                  receiverId:
                      widget.isCaller ? data['receiverId'] ?? '' : myUid,
                  isVideo: widget.isVideoCall,
                  status: 'ended',
                  duration: duration,
                );
              }
            }

            await AgoraService.leaveChannel();
            if (mounted) Navigator.pop(context);
          }
          break;
      }
    });
  }

  // ============================================================
  // SHOW MESSAGE + POP
  // ============================================================
  void _showAndPop(String msg) {
    AgoraService.leaveChannel();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryMaroon,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  // ============================================================
  // START CALL (join Agora channel)
  // ============================================================
  Future<void> _startCall() async {
    // Guard: already joined হলে return
    if (_hasJoined) {
      debugPrint('⚠️ Already joined — skip');
      _isStartingJoin = false;
      return;
    }

    // 1. Permissions
    final permissionsGranted = await _requestPermissions();
    if (!mounted) return;

    if (!permissionsGranted) {
      setState(() {
        _isConnecting = false;
        _errorMessage = widget.isBangla
            ? 'Camera ও Microphone permission দরকার'
            : 'Camera and Microphone permission required';
      });
      _isStartingJoin = false;
      return;
    }

    // 2. Get token
    final tokenData = await AgoraService.getToken(
      channelName: widget.channelName,
    );

    if (!mounted) return;

    if (tokenData == null) {
      setState(() {
        _isConnecting = false;
        _errorMessage =
            widget.isBangla ? 'Token পাওয়া যায়নি' : 'Failed to get token';
      });
      _isStartingJoin = false;
      return;
    }

    final token = tokenData['token'] as String;
    final uid = tokenData['uid'] as int;
    final appId = tokenData['appId'] as String;

    // 3. Initialize engine
    await AgoraService.initialize(appId: appId);

    if (!mounted) return;

    // Guard আবার চেক
    if (_hasJoined) {
      _isStartingJoin = false;
      return;
    }

    // 4. Join channel
    // 4. ✅ NEW — Start ringback for OUTGOING call
    // (only caller side, and only if not already joined)
    if (!widget.isIncoming && !_hasJoined) {
      await RingService.startRingback();
    }

    // 5. Join channel
    final joined = await AgoraService.joinChannel(
      channelName: widget.channelName,
      token: token,
      uid: uid,
      isVideoCall: widget.isVideoCall,
    );
    if (!mounted) return;

    if (!joined) {
      setState(() {
        _isConnecting = false;
        _errorMessage = widget.isBangla
            ? 'Call এ যুক্ত হতে পারছি না'
            : 'Could not join call';
      });
    }

    _isStartingJoin = false;
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================
  Future<bool> _requestPermissions() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (!widget.isVideoCall) {
      return mic.isGranted;
    }
    return camera.isGranted && mic.isGranted;
  }

  // ============================================================
  // TIMER (duration counter)
  // ============================================================
  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isJoined) {
        setState(() => _callDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ============================================================
  // END CALL (with duration or cancel depending on state)
  // ============================================================
  Future<void> _endCall() async {
    RingService.stop();
    RingService.stopRingback();
    _ringTimeout?.cancel();

    if (_callId != null && !_callEnded) {
      _callEnded = true;
      final myUid = FirebaseAuth.instance.currentUser?.uid;

      if (_isJoined && _callStartTime != null) {
        // ✅ Call connected ছিলো → ended with duration
        final duration = DateTime.now().difference(_callStartTime!).inSeconds;
        await CallService.endCall(_callId!, durationSeconds: duration);

        // ✅ কল লগ সেভ করুন
        if (myUid != null) {
          final callDoc = await FirebaseFirestore.instance
              .collection('calls')
              .doc(_callId)
              .get();
          final callData = callDoc.data() ?? {};
          await ChatService.logCallMessage(
            senderId: callData['callerId'] ?? '',
            receiverId: callData['receiverId'] ?? '',
            isVideo: widget.isVideoCall,
            status: 'ended',
            duration: duration,
          );
        }
      } else if (widget.isCaller) {
        // ✅ Caller receiver ধরার আগেই কেটে দিয়েছে → cancelled
        await CallService.cancelCall(_callId!);
        if (myUid != null) {
          final callDoc = await FirebaseFirestore.instance
              .collection('calls')
              .doc(_callId)
              .get();
          final callData = callDoc.data() ?? {};
          await ChatService.logCallMessage(
            senderId: callData['callerId'] ?? '',
            receiverId: callData['receiverId'] ?? '',
            isVideo: widget.isVideoCall,
            status: 'rejected',
          );
        }
      } else {
        // ✅ Receiver join হওয়ার আগেই (edge case) → rejected
        await CallService.rejectCall(_callId!);
        if (myUid != null) {
          final callDoc = await FirebaseFirestore.instance
              .collection('calls')
              .doc(_callId)
              .get();
          final callData = callDoc.data() ?? {};
          await ChatService.logCallMessage(
            senderId: callData['callerId'] ?? '',
            receiverId: callData['receiverId'] ?? '',
            isVideo: widget.isVideoCall,
            status: 'rejected',
          );
        }
      }
    }

    await AgoraService.leaveChannel();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ============================================================
  // ACCEPT INCOMING
  // ============================================================
  Future<void> _acceptCall() async {
    RingService.stop();
    _ringTimeout?.cancel();

    if (_callId == null) return;
    await CallService.acceptCall(_callId!);
    // বাকিটা Firestore listener handle করবে (statusAccepted → _startCall)
  }

  // ============================================================
  // REJECT INCOMING
  // ============================================================
  Future<void> _rejectCall() async {
    RingService.stop();
    RingService.stopRingback();
    _ringTimeout?.cancel();

    if (_callId != null) {
      await CallService.rejectCall(_callId!);
    }
    _callEnded = true;
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ============================================================
  // TOGGLES
  // ============================================================
  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await AgoraService.muteAudio(_isMuted);
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoOff = !_isVideoOff);
    await AgoraService.muteVideo(_isVideoOff);
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await AgoraService.setAudioRoute(_isSpeakerOn);
  }

  Future<void> _switchCamera() async {
    setState(() => _isFrontCamera = !_isFrontCamera);
    await AgoraService.switchCamera();
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    RingService.stop();
    _ringTimeout?.cancel();
    _durationTimer?.cancel(); // ✅ NEW

    _callListener?.cancel();
    AgoraService.clearCallbacks();
    AgoraService.leaveChannel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isIncomingRinging) {
      return _buildIncomingCallUI();
    }
    if (widget.isVideoCall) {
      return _buildVideoCallUI();
    }
    return _buildVoiceCallUI();
  }

  // ============================================================
  // INCOMING CALL UI
  // ============================================================
  Widget _buildIncomingCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8B1E3F), Color(0xFF1A0000)],
            ),
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryGold, primaryMaroon],
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: widget.otherUserPhoto != null &&
                            widget.otherUserPhoto!.isNotEmpty
                        ? Image.network(
                            widget.otherUserPhoto!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 60,
                              color: primaryMaroon,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: primaryMaroon,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                widget.isVideoCall
                    ? (widget.isBangla
                        ? 'ভিডিও কল আসছে...'
                        : 'Incoming video call...')
                    : (widget.isBangla ? 'কল আসছে...' : 'Incoming call...'),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCallActionBtn(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: widget.isBangla ? 'বাতিল' : 'Decline',
                    onTap: _rejectCall,
                  ),
                  _buildCallActionBtn(
                    icon: widget.isVideoCall ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: widget.isBangla ? 'উত্তর' : 'Accept',
                    onTap: _acceptCall,
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    );
  }

  // ============================================================
  // VIDEO CALL UI
  // ============================================================
  Widget _buildVideoCallUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _remoteUid != null
                  ? AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: AgoraService.engine!,
                        canvas: VideoCanvas(uid: _remoteUid),
                        connection: RtcConnection(
                          channelId: widget.channelName,
                        ),
                      ),
                    )
                  : _buildWaitingScreen(),
            ),

            // Local preview
            if (!_isVideoOff && _isJoined)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: AgoraService.engine!,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    ),
                  ),
                ),
              ),

            // Top info
            Positioned(
              top: 16,
              left: 20,
              right: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isConnecting
                        ? (widget.isBangla ? 'যুক্ত হচ্ছে...' : 'Connecting...')
                        : _remoteUid != null
                            ? _formatDuration(_callDuration)
                            : (widget.isBangla
                                ? 'অপেক্ষা করা হচ্ছে...'
                                : 'Waiting...'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: _buildVideoCallActions(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VOICE CALL UI
  // ============================================================
  Widget _buildVoiceCallUI() {
    return Scaffold(
      backgroundColor: warmWhite,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lightMaroon, warmWhite],
            ),
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryGold, primaryMaroon],
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: widget.otherUserPhoto != null &&
                            widget.otherUserPhoto!.isNotEmpty
                        ? Image.network(
                            widget.otherUserPhoto!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 60,
                              color: primaryMaroon,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 60,
                            color: primaryMaroon,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: mainText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _isConnecting
                    ? (widget.isBangla ? 'যুক্ত হচ্ছে...' : 'Connecting...')
                    : _remoteUid != null
                        ? _formatDuration(_callDuration)
                        : (widget.isBangla
                            ? 'অপেক্ষা করা হচ্ছে...'
                            : 'Waiting...'),
                style: const TextStyle(
                  fontSize: 16,
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 3),
              _buildVoiceCallActions(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WAITING SCREEN
  // ============================================================
  Widget _buildWaitingScreen() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: primaryGold.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: widget.otherUserPhoto != null &&
                        widget.otherUserPhoto!.isNotEmpty
                    ? Image.network(
                        widget.otherUserPhoto!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isConnecting
                  ? (widget.isBangla ? 'যুক্ত হচ্ছে...' : 'Connecting...')
                  : (widget.isBangla
                      ? 'অপেক্ষা করা হচ্ছে...'
                      : 'Waiting for ${widget.otherUserName}...'),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VIDEO ACTIONS
  // ============================================================
  Widget _buildVideoCallActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: widget.isBangla
              ? (_isMuted ? 'আনমিউট' : 'মিউট')
              : (_isMuted ? 'Unmute' : 'Mute'),
          onTap: _toggleMute,
          isActive: _isMuted,
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
          label: widget.isBangla
              ? (_isVideoOff ? 'ভিডিও চালু' : 'ভিডিও বন্ধ')
              : (_isVideoOff ? 'Cam On' : 'Cam Off'),
          onTap: _toggleVideo,
          isActive: _isVideoOff,
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: Icons.flip_camera_ios,
          label: widget.isBangla ? 'ফ্লিপ' : 'Flip',
          onTap: _switchCamera,
        ),
        const SizedBox(width: 16),
        _buildActionButton(
          icon: Icons.call_end,
          label: widget.isBangla ? 'শেষ' : 'End',
          onTap: _endCall,
          isEndCall: true,
        ),
      ],
    );
  }

  // ============================================================
  // VOICE ACTIONS
  // ============================================================
  Widget _buildVoiceCallActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildVoiceButton(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: widget.isBangla ? 'স্পিকার' : 'Speaker',
          onTap: _toggleSpeaker,
          isActive: _isSpeakerOn,
        ),
        const SizedBox(width: 24),
        _buildVoiceButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: widget.isBangla
              ? (_isMuted ? 'আনমিউট' : 'মিউট')
              : (_isMuted ? 'Unmute' : 'Mute'),
          onTap: _toggleMute,
          isActive: _isMuted,
        ),
        const SizedBox(width: 24),
        _buildVoiceButton(
          icon: Icons.call_end,
          label: widget.isBangla ? 'শেষ' : 'End',
          onTap: _endCall,
          isEndCall: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEndCall
                  ? Colors.red
                  : isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.25),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isEndCall
                  ? Colors.white
                  : isActive
                      ? primaryMaroon
                      : Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEndCall
                  ? Colors.red
                  : isActive
                      ? primaryMaroon
                      : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: (isEndCall ? Colors.red : primaryMaroon).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isEndCall || isActive ? Colors.white : primaryMaroon,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: mainText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
