import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/success_story.dart';

class SuccessStoryService {
  static final _firestore = FirebaseFirestore.instance;

  // ============================================================
  // STREAM — Approved Stories (home page-এ দেখাবে)
  // ============================================================
  static Stream<List<SuccessStory>> streamApproved({int limit = 10}) {
    return _firestore
        .collection('success_stories')
        .where('isApproved', isEqualTo: true)
        .orderBy('isFeatured', descending: true)
        .orderBy('order', descending: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SuccessStory.fromDoc(d))
              .where((s) => s.story.isNotEmpty)
              .toList(),
        );
  }

  // ============================================================
  // COUNT
  // ============================================================
  static Stream<int> streamCount() {
    return _firestore
        .collection('success_stories')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ============================================================
  // ✅ USER SUBMIT — নতুন story (pending status-এ)
  // ============================================================
  static Future<String?> submitStory({
    required String coupleNames,
    required String husbandName,
    required String wifeName,
    required String story,
    required List<String> photoUrls,
    required String district,
    DateTime? marriageDate,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      if (photoUrls.isEmpty) {
        debugPrint('❌ No photos');
        return null;
      }

      final docRef = await _firestore.collection('success_stories').add({
        'coupleNames': coupleNames.trim(),
        'husbandName': husbandName.trim(),
        'wifeName': wifeName.trim(),
        'story': story.trim(),
        'photoUrl': photoUrls.first,
        'weddingPhotos': photoUrls,
        'district': district.trim(),
        'marriageDate':
            marriageDate != null ? Timestamp.fromDate(marriageDate) : null,
        'isApproved': false, // ✅ pending
        'isFeatured': false,
        'uid': uid,
        'submittedBy': uid, // ✅
        'order': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Story submitted: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ submitStory failed: $e');
      return null;
    }
  }

  // ============================================================
  // MY SUBMISSIONS — user-এর নিজের submit করা story
  // ============================================================
  static Stream<List<SuccessStory>> streamMySubmissions() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('success_stories')
        .where('submittedBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SuccessStory.fromDoc(d)).toList());
  }

  // ============================================================
  // DELETE OWN PENDING STORY
  // ============================================================
  static Future<void> deleteMyStory(String storyId) async {
    try {
      await _firestore.collection('success_stories').doc(storyId).delete();
      debugPrint('✅ Story deleted');
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
    }
  }
}
