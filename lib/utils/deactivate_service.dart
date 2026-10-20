import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
// DEACTIVATE SERVICE
// User account temporarily disable করা
// Data থেকে যায়, শুধু hidden হয়
// ============================================================

class DeactivateService {
  // ============================================================
  // DEACTIVATE ACCOUNT
  // ============================================================

  static Future<Map<String, dynamic>> deactivateAccount({
    required String reason,
    String feedback = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Not logged in'};
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isDeactivated': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
        'deactivationReason': reason,
        'deactivationFeedback': feedback,
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  // REACTIVATE ACCOUNT
  // ============================================================

  static Future<Map<String, dynamic>> reactivateAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'Not logged in'};
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isDeactivated': false,
        'deactivatedAt': null,
        'deactivationReason': null,
        'deactivationFeedback': null,
        'reactivatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  // CHECK — এই user deactivated কিনা
  // ============================================================

  static Future<bool> isDeactivated(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return false;
      final data = doc.data() ?? {};
      return data['isDeactivated'] == true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // RE-AUTHENTICATE
  // Sensitive operation এর আগে password verify করা লাগে
  // ============================================================

  static Future<Map<String, dynamic>> reauthenticate({
    required String password,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        return {'success': false, 'error': 'Not logged in'};
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Password ঠিক নেই';
          break;
        case 'too-many-requests':
          message = 'অনেকবার ভুল হয়েছে। কিছুক্ষণ পর চেষ্টা করুন';
          break;
        default:
          message = e.message ?? 'Authentication failed';
      }
      return {'success': false, 'error': message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}