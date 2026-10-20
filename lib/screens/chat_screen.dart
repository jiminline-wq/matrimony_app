import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/colors.dart';
import '../models/user_profile.dart';
import '../services/call_service.dart';
import '../services/voice_recorder_service.dart';
import '../services/chat_presence_service.dart';
import '../widgets/premium_message_bubble.dart';
import '../widgets/verified_badge.dart';
import 'call_screen.dart';
import 'user_profile_view_screen.dart';
import '../utils/chat_icebreakers.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

// ============================================================
// CHAT SCREEN — WhatsApp-style
// ============================================================

class ChatScreen extends StatefulWidget {
  final bool isBangla;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;

  const ChatScreen({
    super.key,
    required this.isBangla,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<String> _icebreakers = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  String? _chatId;
  bool _isSending = false;
  bool _showScrollButton = false;
  bool _isAtBottom = true;
  bool _showSendButton = false;
  String? _lastMsgId;
  Map<String, dynamic>? _replyTo;

  Timer? _typingStartTimer;
  Timer? _typingStopTimer;
  bool _isMeTyping = false;

  StreamSubscription<QuerySnapshot>? _messagesReadSub;
  bool _isStartingCall = false;
  final List<Map<String, dynamic>> _pendingMessages = [];

  static const int _pageSize = 30;
  final Map<String, Map<String, dynamic>> _messagesMap = {};
  Timestamp? _oldestTimestamp;
  bool _hasMoreMessages = true;
  bool _isLoadingOlder = false;

  bool _isOtherUserVerified = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordTimer;

  static const String cloudinaryCloudName = 'acctuglm';
  static const String cloudinaryUploadPreset = 'jibon_sathi_chat';

  static const Color _chatBg = Color(0xFFECE5DD);
  static const Color _myBubble = Color(0xFF075E54);
  static const Color _myBubbleAlt = Color(0xFF8B1E3F);

  @override
  void initState() {
    super.initState();
    _initChatId();
    _loadOtherUserVerified();
    _icebreakers = ChatIcebreakers.getRandom(widget.isBangla, count: 4);

    ChatPresenceService.enterChat(
      chatId: _chatId ?? '',
      otherUserId: widget.otherUserId,
    );

    _scrollController.addListener(_onScroll);
    _inputFocus.addListener(_onFocusChanged);
    _messageController.addListener(_onTextChangeForSendButton);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    ChatPresenceService.exitChat();
    _messagesReadSub?.cancel();
    _typingStartTimer?.cancel();
    _typingStopTimer?.cancel();
    _recordTimer?.cancel();
    VoiceRecorderService.dispose();

    _messageController.removeListener(_onTextChangeForSendButton);
    _inputFocus.removeListener(_onFocusChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null && _chatId != null) {
      FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'typing.$myUid': FieldValue.delete(),
      }, SetOptions(merge: true)).catchError((_) {});
    }

    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChangeForSendButton() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _showSendButton) {
      setState(() => _showSendButton = hasText);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;

    final showBtn = offset > 250;
    if (showBtn != _showScrollButton) {
      setState(() => _showScrollButton = showBtn);
    }
    _isAtBottom = offset < 100;

    if (offset > 500 &&
        _hasMoreMessages &&
        !_isLoadingOlder &&
        _oldestTimestamp != null) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder ||
        !_hasMoreMessages ||
        _oldestTimestamp == null ||
        _chatId == null) {
      return;
    }

    setState(() => _isLoadingOlder = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfter([_oldestTimestamp])
          .limit(_pageSize)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingOlder = false;
        });
        return;
      }

      for (final doc in snap.docs) {
        final data = doc.data();
        _messagesMap[doc.id] = {...data, '_docId': doc.id};
      }

      final lastData = snap.docs.last.data() as Map<String, dynamic>?;
      final lastTs = lastData?['timestamp'] as Timestamp?;
      if (lastTs != null) _oldestTimestamp = lastTs;

      setState(() {
        _isLoadingOlder = false;
        if (snap.docs.length < _pageSize) _hasMoreMessages = false;
      });
    } catch (e) {
      debugPrint('❌ _loadOlderMessages failed: $e');
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _initChatId() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ids = [myUid, widget.otherUserId]..sort();
    _chatId = '${ids[0]}_${ids[1]}';
  }

  Future<void> _loadOtherUserVerified() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _isOtherUserVerified = doc.data()?['isVerified'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _chatId == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .limit(50)
          .get();

      if (snap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        int count = 0;
        for (final doc in snap.docs) {
          final senderId = (doc.data()['senderId'] ?? '') as String;
          if (senderId != myUid) {
            batch.update(doc.reference, {'read': true, 'delivered': true});
            count++;
          }
        }
        if (count > 0) {
          await batch.commit();
        }
      }

      await _resetUnreadCount();

      _messagesReadSub?.cancel();
      _messagesReadSub = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .limit(20)
          .snapshots()
          .listen((snap) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || snap.docs.isEmpty) return;

        final b = FirebaseFirestore.instance.batch();
        int c = 0;
        for (final doc in snap.docs) {
          final senderId = (doc.data()['senderId'] ?? '') as String;
          if (senderId != uid) {
            b.update(doc.reference, {'read': true, 'delivered': true});
            c++;
          }
        }
        if (c > 0) {
          b.commit().then((_) {
            if (mounted) _resetUnreadCount();
          }).catchError((_) {});
        }
      }, onError: (_) {});
    } catch (e) {
      debugPrint('❌ _markMessagesAsRead failed: $e');
    }
  }

  Future<void> _resetUnreadCount() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _chatId == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'unreadCounts.$myUid': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _onTextChanged(String text) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _chatId == null) return;

    if (text.trim().isEmpty) {
      _typingStartTimer?.cancel();
      _typingStopTimer?.cancel();
      if (_isMeTyping) {
        _isMeTyping = false;
        _setTypingStatus(myUid, false);
      }
      return;
    }

    _typingStartTimer?.cancel();
    _typingStartTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_isMeTyping) {
        _isMeTyping = true;
        _setTypingStatus(myUid, true);
      }
    });

    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 3), () {
      if (_isMeTyping) {
        _isMeTyping = false;
        _setTypingStatus(myUid, false);
      }
    });
  }

  Future<void> _setTypingStatus(String uid, bool isTyping) async {
    if (_chatId == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'typing.$uid':
            isTyping ? FieldValue.serverTimestamp() : FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  bool _isOtherUserTyping(Map<String, dynamic>? chatData) {
    if (chatData == null) return false;
    final typingMap = Map<String, dynamic>.from(chatData['typing'] ?? {});
    final otherTyping = typingMap[widget.otherUserId];
    if (otherTyping == null) return false;
    if (otherTyping is Timestamp) {
      final diff = DateTime.now().difference(otherTyping.toDate());
      return diff.inSeconds < 5;
    }
    return false;
  }

  Future<void> _startVoiceCall() async {
    if (_isStartingCall) return;
    _isStartingCall = true;
    try {
      if (await CallService.hasActiveCall()) {
        if (!mounted) return;
        _showError(widget.isBangla
            ? 'আপনি ইতিমধ্যে একটি কলে আছেন'
            : 'You are already in a call');
        return;
      }
      final roomId = _generateCallRoomId();
      if (roomId.isEmpty) return;
      final callId = await CallService.startCall(
        channelName: roomId,
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        receiverPhoto: widget.otherUserPhoto,
        isVideoCall: false,
      );
      if (!mounted || callId == null) {
        _showError(widget.isBangla ? 'কল শুরু করা যায়নি' : 'Could not start');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            isBangla: widget.isBangla,
            channelName: roomId,
            otherUserName: widget.otherUserName,
            otherUserPhoto: widget.otherUserPhoto,
            isVideoCall: false,
            isCaller: true,
            callId: callId,
          ),
        ),
      );
    } finally {
      _isStartingCall = false;
    }
  }

  Future<void> _startVideoCall() async {
    if (_isStartingCall) return;
    _isStartingCall = true;
    try {
      if (await CallService.hasActiveCall()) {
        if (!mounted) return;
        _showError(widget.isBangla
            ? 'আপনি ইতিমধ্যে একটি কলে আছেন'
            : 'You are already in a call');
        return;
      }
      final roomId = _generateCallRoomId();
      if (roomId.isEmpty) return;
      final callId = await CallService.startCall(
        channelName: roomId,
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        receiverPhoto: widget.otherUserPhoto,
        isVideoCall: true,
      );
      if (!mounted || callId == null) {
        _showError(widget.isBangla ? 'কল শুরু করা যায়নি' : 'Could not start');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            isBangla: widget.isBangla,
            channelName: roomId,
            otherUserName: widget.otherUserName,
            otherUserPhoto: widget.otherUserPhoto,
            isVideoCall: true,
            isCaller: true,
            callId: callId,
          ),
        ),
      );
    } finally {
      _isStartingCall = false;
    }
  }

  String _generateCallRoomId() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (myUid.isEmpty || widget.otherUserId.isEmpty) return '';
    final ids = [myUid, widget.otherUserId]..sort();
    final combined = '${ids[0]}_${ids[1]}';
    int hash = 0x811c9dc5;
    for (int i = 0; i < combined.length; i++) {
      hash ^= combined.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 'js_${hash.toRadixString(36).padLeft(7, '0')}';
  }

  Future<void> _openOtherUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      if (!doc.exists || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileViewScreen(
            isBangla: widget.isBangla,
            user: UserProfile.fromMap(doc.data()!, docId: doc.id),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      _isMeTyping = false;
      _typingStartTimer?.cancel();
      _typingStopTimer?.cancel();
      _setTypingStatus(myUid, false);
    }
    _messageController.clear();
    await _sendMessage(type: 'text', text: text, replyTo: _replyTo);
    if (mounted) setState(() => _replyTo = null);
  }

  Future<void> _sendMessage({
    required String type,
    String? text,
    String? mediaUrl,
    String? fileName,
    int? fileSize,
    int? duration,
    Map<String, dynamic>? replyTo,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || _chatId == null) return;

    final clientId =
        'c_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

    final pendingMsg = <String, dynamic>{
      'clientId': clientId,
      'senderId': myUid,
      'type': type,
      if (text != null) 'text': text,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (duration != null) 'duration': duration,
      if (replyTo != null) 'replyTo': replyTo,
      'timestamp': Timestamp.now(),
      'read': false,
      'delivered': false,
      '_status': 'sending',
    };

    setState(() => _pendingMessages.add(pendingMsg));
    _scrollToBottom();

    try {
      final batch = FirebaseFirestore.instance.batch();

      final msgRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc();

      final firestoreData = <String, dynamic>{
        'clientId': clientId,
        'senderId': myUid,
        'receiverId': widget.otherUserId,
        'type': type,
        if (text != null) 'text': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (duration != null) 'duration': duration,
        if (replyTo != null) 'replyTo': replyTo,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'delivered': false,
      };

      batch.set(msgRef, firestoreData);

      final lastMsg = type == 'text'
          ? text
          : type == 'voice'
              ? '🎤 Voice'
              : type == 'image'
                  ? '📷 Photo'
                  : type == 'video'
                      ? '🎥 Video'
                      : '📎 File';

      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc(_chatId);

      batch.set(
          chatRef,
          {
            'lastMessage': lastMsg,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastSenderId': myUid,
            'users': [myUid, widget.otherUserId],
            'unreadCounts.$myUid': 0,
            'unreadCounts.${widget.otherUserId}': FieldValue.increment(1),
            'deletedFor.${widget.otherUserId}': false,
            'archivedFor.${widget.otherUserId}': false,
          },
          SetOptions(merge: true));

      await batch.commit();

      _messagesMap[msgRef.id] = {
        ...firestoreData,
        '_docId': msgRef.id,
        'timestamp': Timestamp.now(),
      };
    } catch (e) {
      debugPrint('❌ Send failed: $e');
      if (mounted) {
        setState(() {
          final idx =
              _pendingMessages.indexWhere((m) => m['clientId'] == clientId);
          if (idx != -1) {
            _pendingMessages[idx] = {
              ..._pendingMessages[idx],
              '_status': 'failed',
            };
          }
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final started = await VoiceRecorderService.start();
    if (!started) {
      if (mounted) {
        _showError(widget.isBangla
            ? 'Mic permission প্রয়োজন'
            : 'Mic permission required');
      }
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    final result = await VoiceRecorderService.stopAndUpload();
    if (result == null) {
      if (mounted) {
        _showError(widget.isBangla ? 'Voice পাঠানো যায়নি' : 'Could not send');
      }
      return;
    }
    await _sendMessage(
      type: 'voice',
      mediaUrl: result['url'] as String,
      duration: result['duration'] as int,
      replyTo: _replyTo,
    );
    if (mounted) setState(() => _replyTo = null);
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    await VoiceRecorderService.cancel();
  }

  String _formatRecordDuration(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _addReaction(String messageId, String emoji) async {
    if (_chatId == null || messageId.isEmpty) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(messageId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return;

        final data = doc.data() ?? {};
        final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});

        if (reactions[myUid] == emoji) {
          reactions.remove(myUid);
        } else {
          reactions[myUid] = emoji;
        }

        transaction.update(docRef, {'reactions': reactions});
      });
    } catch (e) {
      debugPrint('❌ _addReaction failed: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    if (_chatId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
      _messagesMap.remove(messageId);
    } catch (_) {}
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(picked.path);
      final url = await _uploadToCloudinary(file, 'image');

      if (url == null || url.trim().isEmpty) {
        if (mounted) {
          _showError(
            widget.isBangla
                ? 'ছবি upload করা যায়নি। আবার চেষ্টা করুন।'
                : 'Image upload failed. Try again.',
          );
        }
        return;
      }

      await _sendMessage(type: 'image', mediaUrl: url, replyTo: _replyTo);
      if (mounted) setState(() => _replyTo = null);
    } catch (_) {
      if (mounted) {
        _showError(
          widget.isBangla ? 'ছবি পাঠানো যায়নি।' : 'Could not send image.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(picked.path);
      final url = await _uploadToCloudinary(file, 'video');

      if (url == null || url.trim().isEmpty) {
        if (mounted) {
          _showError(
            widget.isBangla
                ? 'ভিডিও upload করা যায়নি। আবার চেষ্টা করুন।'
                : 'Video upload failed. Try again.',
          );
        }
        return;
      }

      await _sendMessage(type: 'video', mediaUrl: url, replyTo: _replyTo);
      if (mounted) setState(() => _replyTo = null);
    } catch (_) {
      if (mounted) {
        _showError(
          widget.isBangla ? 'ভিডিও পাঠানো যায়নি।' : 'Could not send video.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    if (pickedFile.size > 10 * 1024 * 1024) {
      if (!mounted) return;
      _showError(
        widget.isBangla
            ? 'ফাইল সাইজ ১০ MB এর বেশি হবে না।'
            : 'File size must be under 10 MB.',
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final file = File(pickedFile.path!);
      final url = await _uploadToCloudinary(file, 'raw');

      if (url == null || url.trim().isEmpty) {
        if (mounted) {
          _showError(
            widget.isBangla
                ? 'ফাইল upload করা যায়নি। আবার চেষ্টা করুন।'
                : 'File upload failed. Try again.',
          );
        }
        return;
      }

      await _sendMessage(
        type: 'file',
        mediaUrl: url,
        fileName: pickedFile.name,
        fileSize: pickedFile.size,
        replyTo: _replyTo,
      );
      if (mounted) setState(() => _replyTo = null);
    } catch (_) {
      if (mounted) {
        _showError(
          widget.isBangla ? 'ফাইল পাঠানো যায়নি।' : 'Could not send file.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryMaroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<String?> _uploadToCloudinary(File file, String type) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/$type/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = cloudinaryUploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      final bytes = await response.stream.toBytes();
      final json = jsonDecode(String.fromCharCodes(bytes));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json['secure_url'] as String;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showAttachmentSheet() {
    final bn = widget.isBangla;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _attachOption(
                      icon: Icons.image,
                      label: bn ? 'ছবি' : 'Image',
                      color: const Color(0xFF43A047),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage();
                      },
                    ),
                    _attachOption(
                      icon: Icons.videocam,
                      label: bn ? 'ভিডিও' : 'Video',
                      color: const Color(0xFFE53935),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendVideo();
                      },
                    ),
                    _attachOption(
                      icon: Icons.attach_file,
                      label: bn ? 'ফাইল' : 'File',
                      color: const Color(0xFF1E88E5),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendFile();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: mainText,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final bn = widget.isBangla;
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // ✅ Stack ব্যবহার করা হলো যাতে রেকর্ডিং ওভারলে ঠিকমতো কাজ করে
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: _buildAppBar(bn),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildMessageList(bn, myUid)),
              if (_isSending) _buildSendingBar(bn),
              if (_replyTo != null) _buildReplyPreview(bn),
              _buildInputBar(bn),
              // ✅ ইনপুট বারের ঠিক নিচে ব্যানার অ্যাড বসানো হলো
              const SafeArea(
                top: false,
                child: BannerAdWidget(
                  placementId: AdConfig.placementChat, // অথবা placementChatList
                ),
              ),
            ],
          ),
          // ✅ রেকর্ডিং ওভারলে (উপরে ভেসে থাকবে)
          if (_isRecording) _buildRecordingOverlay(bn),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================
  PreferredSizeWidget _buildAppBar(bool bn) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 1,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _openOtherUserProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                backgroundImage: widget.otherUserPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherUserPhoto)
                    : null,
                child: widget.otherUserPhoto.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(_chatId)
                      .snapshots(),
                  builder: (context, chatSnap) {
                    final chatData =
                        chatSnap.data?.data() as Map<String, dynamic>?;
                    final isTyping = _isOtherUserTyping(chatData);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                widget.otherUserName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isOtherUserVerified) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 14),
                            ],
                          ],
                        ),
                        Text(
                          isTyping
                              ? (bn ? 'লিখছেন...' : 'typing...')
                              : (bn ? 'অনলাইন' : 'online'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontStyle:
                                isTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _startVoiceCall,
            icon: const Icon(Icons.call, color: Colors.white),
          ),
          IconButton(
            onPressed: _startVideoCall,
            icon: const Icon(Icons.videocam, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE LIST — with cursor pagination
  // ============================================================
  Widget _buildMessageList(bool bn, String myUid) {
    if (_chatId == null) {
      return const Center(
        child: CircularProgressIndicator(color: primaryMaroon),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _messagesMap.isEmpty &&
            _pendingMessages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: primaryMaroon),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Could not load messages',
              style: TextStyle(color: secondaryText),
            ),
          );
        }

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            _messagesMap[doc.id] = {...data, '_docId': doc.id};
          }
          if (_oldestTimestamp == null && snapshot.data!.docs.isNotEmpty) {
            final oldestData =
                snapshot.data!.docs.last.data() as Map<String, dynamic>?;
            if (oldestData != null) {
              final ts = oldestData['timestamp'] as Timestamp?;
              if (ts != null) _oldestTimestamp = ts;
            }
            if (snapshot.data!.docs.length < _pageSize) {
              _hasMoreMessages = false;
            }
          }
        }

        final allMessages = _messagesMap.values.toList();
        allMessages.sort((a, b) {
          final ta = a['timestamp'] as Timestamp?;
          final tb = b['timestamp'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        final confirmedCids = <String>{};
        for (final m in allMessages) {
          final cid = m['clientId'] as String?;
          if (cid != null) confirmedCids.add(cid);
        }

        final items = <_ChatItem>[];
        for (final m in allMessages) {
          final text = (m['text'] as String?)?.trim() ?? '';
          final mediaUrl = (m['mediaUrl'] as String?)?.trim() ?? '';
          final fileName = (m['fileName'] as String?)?.trim() ?? '';
          if (text.isEmpty && mediaUrl.isEmpty && fileName.isEmpty) continue;
          items.add(_ChatItem(
            docId: m['_docId'] as String? ?? '',
            data: m,
            isPending: false,
          ));
        }

        for (final p in _pendingMessages) {
          final cid = p['clientId'] as String?;
          if (cid == null || !confirmedCids.contains(cid)) {
            final pText = (p['text'] as String?)?.trim() ?? '';
            final pMedia = (p['mediaUrl'] as String?)?.trim() ?? '';
            if (pText.isEmpty && pMedia.isEmpty) continue;
            items.add(_ChatItem(docId: cid ?? '', data: p, isPending: true));
          }
        }

        final hasPendingToRemove =
            _pendingMessages.any((p) => confirmedCids.contains(p['clientId']));
        if (hasPendingToRemove) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _pendingMessages.removeWhere(
                (p) => confirmedCids.contains(p['clientId']),
              );
            });
          });
        }

        if (items.isEmpty) return _buildEmptyState(bn);

        final latestId = items.first.docId;
        final isNewMessage = latestId != _lastMsgId;
        _lastMsgId = latestId;

        if (isNewMessage && _isAtBottom && !_isLoadingOlder) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          });
        }

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + (_hasMoreMessages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  return _buildOlderLoadingIndicator();
                }
                final item = items[index];
                final data = item.data;
                final isMe = data['senderId'] == myUid;

                // ✅ কল লগের জন্য আলাদা UI
                if (data['type'] == 'call') {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              data['isVideo'] == true
                                  ? Icons.videocam
                                  : Icons.call,
                              size: 14,
                              color: secondaryText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              data['text'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final newerData = index > 0 ? items[index - 1].data : null;
                final olderData =
                    index < items.length - 1 ? items[index + 1].data : null;

                final isPrevSame = newerData != null &&
                    newerData['senderId'] == data['senderId'] &&
                    newerData['type'] != 'system';
                final isNextSame = olderData != null &&
                    olderData['senderId'] == data['senderId'] &&
                    olderData['type'] != 'system';

                Widget? dateSeparator;
                final isTopmost = index == items.length - 1;
                final dayChanged = olderData != null &&
                    !_isSameDay(data['timestamp'], olderData['timestamp']);
                if (isTopmost || dayChanged) {
                  dateSeparator = _buildDateSeparator(data['timestamp']);
                }

                return Column(
                  children: [
                    if (dateSeparator != null) dateSeparator,
                    PremiumMessageBubble(
                      messageId: item.docId,
                      data: data,
                      isMe: isMe,
                      isBangla: bn,
                      isPrevSame: isPrevSame,
                      isNextSame: isNextSame,
                      onReact: item.isPending ? (_, __) {} : _addReaction,
                      onReply: item.isPending
                          ? (_) {}
                          : (r) => setState(() => _replyTo = r),
                      onDelete: item.isPending
                          ? () {}
                          : () => _deleteMessage(item.docId),
                    ),
                  ],
                );
              },
            ),
            if (_showScrollButton)
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => _scrollToBottom(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: primaryMaroon,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOlderLoadingIndicator() {
    if (_isLoadingOlder) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: primaryMaroon,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 20);
  }

  // ============================================================
  // INPUT BAR
  // ============================================================
  Widget _buildInputBar(bool bn) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _showAttachmentSheet,
                      icon: const Icon(
                        Icons.add,
                        color: primaryMaroon,
                        size: 26,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocus,
                        textInputAction: TextInputAction.newline,
                        keyboardType: TextInputType.multiline,
                        onChanged: _onTextChanged,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(
                          fontSize: 15,
                          color: mainText,
                        ),
                        decoration: InputDecoration(
                          hintText: bn ? 'Message' : 'Message',
                          hintStyle: const TextStyle(
                            color: secondaryText,
                            fontSize: 15,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _showSendButton
                  ? _sendTextMessage
                  : (_isRecording ? _stopAndSendRecording : _startRecording),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryMaroon,
                ),
                child: Icon(
                  _showSendButton
                      ? Icons.send_rounded
                      : (_isRecording ? Icons.stop : Icons.mic),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SENDING BAR
  // ============================================================
  Widget _buildSendingBar(bool bn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryMaroon,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            bn ? 'পাঠানো হচ্ছে...' : 'Sending...',
            style: const TextStyle(
              color: secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPLY PREVIEW — with media thumbnail
  // ============================================================
  Widget _buildReplyPreview(bool bn) {
    final reply = _replyTo!;
    final type = (reply['type'] as String?) ?? 'text';
    final mediaUrl = (reply['mediaUrl'] as String?) ?? '';

    Widget previewThumb;
    if (type == 'image' && mediaUrl.isNotEmpty) {
      previewThumb = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 40,
            height: 40,
            color: lightMaroon,
            child: const Icon(
              Icons.image_outlined,
              color: primaryMaroon,
              size: 20,
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 40,
            height: 40,
            color: lightMaroon,
            child: const Icon(
              Icons.broken_image_outlined,
              color: primaryMaroon,
              size: 20,
            ),
          ),
        ),
      );
    } else if (type == 'voice') {
      previewThumb = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: lightMaroon,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.mic, color: primaryMaroon, size: 22),
      );
    } else if (type == 'video') {
      previewThumb = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: lightMaroon,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.videocam, color: primaryMaroon, size: 22),
      );
    } else if (type == 'file') {
      previewThumb = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: lightMaroon,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.attach_file, color: primaryMaroon, size: 22),
      );
    } else {
      previewThumb = const SizedBox(width: 0, height: 0);
    }

    final hasThumb = previewThumb is! SizedBox;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 3,
            height: hasThumb ? 48 : 40,
            decoration: BoxDecoration(
              color: primaryMaroon,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (hasThumb) ...[
            previewThumb,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (reply['senderName'] ?? '').toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryMaroon,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _replyPreviewText(reply),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: secondaryText),
            onPressed: () => setState(() => _replyTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _replyPreviewText(Map<String, dynamic> reply) {
    final text = (reply['text'] ?? '').toString();
    if (text.isNotEmpty) return text;
    switch (reply['type']) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 ${reply['fileName'] ?? 'File'}';
      default:
        return '';
    }
  }

  // ============================================================
  // DATE SEPARATOR
  // ============================================================
  Widget _buildDateSeparator(dynamic timestamp) {
    if (timestamp == null) return const SizedBox();
    try {
      final dt = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      String label;
      if (_isSameDay(timestamp, Timestamp.fromDate(now))) {
        label = widget.isBangla ? 'আজ' : 'TODAY';
      } else if (_isSameDay(timestamp,
          Timestamp.fromDate(now.subtract(const Duration(days: 1))))) {
        label = widget.isBangla ? 'গতকাল' : 'YESTERDAY';
      } else {
        label = DateFormat('dd MMM yyyy').format(dt).toUpperCase();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF54656F),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return const SizedBox();
    }
  }

  bool _isSameDay(dynamic t1, dynamic t2) {
    if (t1 == null || t2 == null) return false;
    try {
      final d1 = (t1 as Timestamp).toDate();
      final d2 = (t2 as Timestamp).toDate();
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================
  Widget _buildEmptyState(bool bn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryGold.withValues(alpha: 0.2),
                  primaryMaroon.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: primaryMaroon,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            bn ? 'কথা শুরু করুন' : 'Break the ice',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: deepMaroon,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            bn ? 'এখানে থেকে একটা প্রশ্ন বেছে নিন' : 'Pick a question to start',
            style: const TextStyle(
              fontSize: 13,
              color: secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ..._icebreakers.map((question) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  _messageController.text = question;
                  _messageController.selection = TextSelection.fromPosition(
                    TextPosition(offset: question.length),
                  );
                  _inputFocus.requestFocus();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: primaryMaroon.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryMaroon.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: primaryMaroon,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          question,
                          style: const TextStyle(
                            fontSize: 13,
                            color: mainText,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_outlined,
                        color: secondaryText,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _icebreakers =
                    ChatIcebreakers.getRandom(widget.isBangla, count: 4);
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              bn ? 'আরো প্রশ্ন' : 'More questions',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: primaryMaroon,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF6C4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF54656F),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    bn
                        ? 'শুধু আপনারা দুজন message দেখতে পাবেন'
                        : 'Only you two can see messages',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF54656F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECORDING OVERLAY
  // ============================================================
  Widget _buildRecordingOverlay(bool bn) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 30),
              Text(
                _formatRecordDuration(_recordingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bn ? 'রেকর্ড হচ্ছে...' : 'Recording...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _cancelRecording,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: _stopAndSendRecording,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHAT ITEM
// ============================================================
class _ChatItem {
  final String docId;
  final Map<String, dynamic> data;
  final bool isPending;
  _ChatItem({
    required this.docId,
    required this.data,
    required this.isPending,
  });
}
