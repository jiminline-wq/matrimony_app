import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// CALL HISTORY ENTRY
// "calls" collection থেকে query করা entry
// ============================================================

class CallHistoryEntry {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerPhoto;
  final String receiverId;
  final String receiverName;
  final String receiverPhoto;
  final bool isVideoCall;
  final String status; // ringing | accepted | rejected | ended | missed
  final int duration; // seconds
  final DateTime createdAt;
  final DateTime? endedAt;

  CallHistoryEntry({
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhoto,
    required this.isVideoCall,
    required this.status,
    required this.duration,
    required this.createdAt,
    this.endedAt,
  });

  factory CallHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CallHistoryEntry(
      callId: doc.id,
      callerId: data['callerId'] ?? '',
      callerName: data['callerName'] ?? 'Unknown',
      callerPhoto: data['callerPhoto'] ?? '',
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      receiverPhoto: data['receiverPhoto'] ?? '',
      isVideoCall: data['isVideoCall'] == true,
      status: data['status'] ?? 'ended',
      duration: (data['duration'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ============================================================
  // HELPER GETTERS (current user perspective)
  // ============================================================
  bool isOutgoing(String myUid) => callerId == myUid;

  bool isMissedFor(String myUid) => status == 'missed' && receiverId == myUid;

  bool isRejectedFor(String myUid) =>
      status == 'rejected' &&
      ((receiverId == myUid && status == 'rejected') ||
          (callerId == myUid && status == 'rejected'));

  bool isAccepted(String myUid) => status == 'accepted' || status == 'ended';

  // Get the OTHER user's info
  String otherUserId(String myUid) => callerId == myUid ? receiverId : callerId;

  String otherUserName(String myUid) =>
      callerId == myUid ? receiverName : callerName;

  String otherUserPhoto(String myUid) =>
      callerId == myUid ? receiverPhoto : callerPhoto;

  // ============================================================
  // FORMATTED DURATION
  // ============================================================
  String get formattedDuration {
    if (duration <= 0) return '';
    if (duration < 60) return '${duration}s';
    final m = duration ~/ 60;
    final s = duration % 60;
    if (m < 60) return '${m}m ${s}s';
    final h = m ~/ 60;
    final remM = m % 60;
    return '${h}h ${remM}m';
  }

  // ============================================================
  // TIME AGO
  // ============================================================
  String timeAgo(bool isBangla) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return isBangla ? 'এখন' : 'just now';
    if (diff.inMinutes < 60) {
      return isBangla
          ? '${diff.inMinutes} মিনিট আগে'
          : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isBangla ? '${diff.inHours} ঘণ্টা আগে' : '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return isBangla ? '${diff.inDays} দিন আগে' : '${diff.inDays}d ago';
    }
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
