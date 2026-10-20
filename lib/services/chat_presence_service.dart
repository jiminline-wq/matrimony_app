// ============================================================
// CHAT PRESENCE SERVICE
//
// Tracks which chat the user is currently viewing.
// Used by FcmService to suppress notifications for the
// chat the user is already inside.
//
// ⚠️ This is CLIENT-SIDE suppression only. For full backend
// suppression (when app is backgrounded), a Cloud Function
// should check a "lastActiveChat" field on the user doc.
// ============================================================

class ChatPresenceService {
  static String? _activeChatId;
  static String? _activeOtherUserId;

  /// ChatScreen-এ প্রবেশ করলে call করুন
  static void enterChat({
    required String chatId,
    required String otherUserId,
  }) {
    _activeChatId = chatId;
    _activeOtherUserId = otherUserId;
  }

  /// ChatScreen থেকে বের হলে call করুন
  static void exitChat() {
    _activeChatId = null;
    _activeOtherUserId = null;
  }

  /// এই senderId-র সাথে user কি এখন chat-এ আছে?
  static bool isInChatWith(String senderId) {
    if (senderId.isEmpty) return false;
    return _activeOtherUserId != null && _activeOtherUserId == senderId;
  }

  /// Current active chat ID (debug/analytics)
  static String? get activeChatId => _activeChatId;
}
