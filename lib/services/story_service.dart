import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/story.dart';

class StoryService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static const int maxDurationSeconds = 15;
  static const int maxFileSizeMB = 20;
  static const Duration ttl = Duration(hours: 24);

  // ============================================================
  // VIDEO DURATION CHECK
  // ============================================================
  static Future<int> getVideoDurationSeconds(File file) async {
    final c = VideoPlayerController.file(file);
    try {
      await c.initialize();
      final sec = c.value.duration.inSeconds;
      return sec;
    } finally {
      await c.dispose();
    }
  }

  // ============================================================
  // CREATE STORY
  // ============================================================
  static Future<Story> createStory({
    required File file,
    required StoryMediaType type,
    required String userName,
    required String userPhoto,
    String? caption,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    // File size check
    final sizeMB = await file.length() / (1024 * 1024);
    if (sizeMB > maxFileSizeMB) {
      throw Exception('File too large (max ${maxFileSizeMB}MB)');
    }

    // Video duration check
    int durationSec = maxDurationSeconds;
    if (type == StoryMediaType.video) {
      durationSec = await getVideoDurationSeconds(file);
      if (durationSec > maxDurationSeconds) {
        throw Exception(
            'Video $durationSec সেকেন্ড — সর্বোচ্চ $maxDurationSeconds সেকেন্ড দরকার');
      }
    }

    // Upload to Storage
    final ext = type == StoryMediaType.video ? 'mp4' : 'jpg';
    final path =
        'stories/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: type == StoryMediaType.video ? 'video/mp4' : 'image/jpeg',
    );
    await ref.putFile(file, metadata);
    final url = await ref.getDownloadURL();

    // Firestore doc
    final now = DateTime.now();
    final docRef = await _db.collection('stories').add({
      'uid': user.uid,
      'userName': userName,
      'userPhoto': userPhoto,
      'mediaUrl': url,
      'type': type == StoryMediaType.video ? 'video' : 'image',
      'durationSeconds': durationSec,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(ttl)),
      'viewers': <String>[],
      'reactionCount': 0, // ✅ NEW
    });

    debugPrint('✅ [Story] Created: ${docRef.id}');
    return Story(
      id: docRef.id,
      uid: user.uid,
      userName: userName,
      userPhoto: userPhoto,
      mediaUrl: url,
      type: type,
      durationSeconds: durationSec,
      caption: caption,
      createdAt: now,
      expiresAt: now.add(ttl),
      viewers: const [],
      reactionCount: 0, // ✅ NEW (optional — Story model-এ field থাকলে)
    );
  }

  // ============================================================
  // FETCH ACTIVE STORIES
  // ============================================================
  static Future<List<UserStories>> fetchActiveStories() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return [];

    final cutoff = DateTime.now().subtract(ttl);

    final snap = await _db
        .collection('stories')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();

    final Map<String, List<Story>> grouped = {};
    final Map<String, Map<String, String>> meta = {};

    for (final doc in snap.docs) {
      final s = Story.fromDoc(doc);
      if (s.isExpired) continue;
      grouped.putIfAbsent(s.uid, () => []).add(s);
      meta[s.uid] = {'name': s.userName, 'photo': s.userPhoto};
    }

    final list = grouped.entries.map((e) {
      final uid = e.key;
      final stories = e.value
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final m = meta[uid]!;
      return UserStories(
        uid: uid,
        userName: m['name'] ?? '',
        userPhoto: m['photo'] ?? '',
        stories: stories,
      );
    }).toList();

    list.sort((a, b) {
      if (a.uid == myUid) return -1;
      if (b.uid == myUid) return 1;
      final aUnseen = a.hasUnseen(myUid);
      final bUnseen = b.hasUnseen(myUid);
      if (aUnseen != bUnseen) return aUnseen ? -1 : 1;
      return b.latest.createdAt.compareTo(a.latest.createdAt);
    });

    return list;
  }

  // ============================================================
  // MARK VIEWED
  // ============================================================
  static Future<void> markViewed(String storyId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    try {
      await _db.collection('stories').doc(storyId).update({
        'viewers': FieldValue.arrayUnion([myUid]),
      });
    } catch (e) {
      debugPrint('⚠️ markViewed failed: $e');
    }
  }

  // ============================================================
  // DELETE OWN STORY
  // ============================================================
  static Future<void> deleteStory(Story story) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != story.uid) return;

    try {
      await _storage.refFromURL(story.mediaUrl).delete();
    } catch (_) {}

    await _db.collection('stories').doc(story.id).delete();
    debugPrint('🗑️ [Story] Deleted: ${story.id}');
  }

  // ============================================================
  // CLEANUP EXPIRED — FIXED: only own stories
  //
  // ⚠️ Requires composite index: uid + expiresAt
  // Firestore error দিলে "Create Index" link-এ click করুন
  // ============================================================
  static Future<int> cleanupExpired() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return 0;

    final now = Timestamp.fromDate(DateTime.now());
    try {
      final snap = await _db
          .collection('stories')
          .where('uid', isEqualTo: myUid) // ✅ Only own stories
          .where('expiresAt', isLessThan: now)
          .limit(30)
          .get();

      int deleted = 0;
      for (final doc in snap.docs) {
        final s = Story.fromDoc(doc);
        try {
          await _storage.refFromURL(s.mediaUrl).delete();
        } catch (_) {}
        await doc.reference.delete();
        deleted++;
      }
      if (deleted > 0) {
        debugPrint('🧹 [Story] Cleaned up $deleted expired stories');
      }
      return deleted;
    } catch (e) {
      debugPrint('⚠️ cleanupExpired failed: $e');
      return 0;
    }
  }

  // ============================================================
  // ADD / UPDATE REACTION — FIXED
  //
  // Bugs fixed:
  // 1. Emoji change-এ count increment হত (এখন শুধু NEW হলে increment)
  // 2. Batch write — atomic
  // ============================================================
  static Future<bool> addReaction({
    required String storyId,
    required String emoji,
    required String userName,
    required String userPhoto,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || storyId.isEmpty || emoji.isEmpty) return false;

    try {
      final storyRef = _db.collection('stories').doc(storyId);
      final reactionRef = storyRef.collection('reactions').doc(myUid);

      // ✅ Check if reaction already exists
      final existing = await reactionRef.get();
      final isNew = !existing.exists;

      // ✅ Batch write — atomic
      final batch = _db.batch();
      batch.set(reactionRef, {
        'emoji': emoji,
        'reactedAt': FieldValue.serverTimestamp(),
        'userName': userName,
        'userPhoto': userPhoto,
      });

      // ✅ Only increment if this is a NEW reaction
      if (isNew) {
        batch.set(
          storyRef,
          {'reactionCount': FieldValue.increment(1)},
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      debugPrint('✅ [Story] Reaction $emoji '
          '${isNew ? "added" : "updated"} on $storyId');
      return true;
    } catch (e) {
      debugPrint('❌ [Story] addReaction failed: $e');
      return false;
    }
  }

  // ============================================================
  // REMOVE REACTION — FIXED: batch write
  // ============================================================
  static Future<bool> removeReaction(String storyId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || storyId.isEmpty) return false;

    try {
      final storyRef = _db.collection('stories').doc(storyId);
      final reactionRef = storyRef.collection('reactions').doc(myUid);

      final existing = await reactionRef.get();
      if (!existing.exists) return true;

      // ✅ Batch — atomic delete + decrement
      final batch = _db.batch();
      batch.delete(reactionRef);
      batch.set(
        storyRef,
        {'reactionCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );

      await batch.commit();

      debugPrint('✅ [Story] Reaction removed from $storyId');
      return true;
    } catch (e) {
      debugPrint('❌ [Story] removeReaction failed: $e');
      return false;
    }
  }

  // ============================================================
  // GET MY REACTION
  // ============================================================
  static Future<String?> getMyReaction(String storyId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || storyId.isEmpty) return null;

    try {
      final doc = await _db
          .collection('stories')
          .doc(storyId)
          .collection('reactions')
          .doc(myUid)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['emoji'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET ALL REACTIONS
  // ============================================================
  static Future<Map<String, List<Map<String, dynamic>>>> getReactions(
    String storyId,
  ) async {
    final result = <String, List<Map<String, dynamic>>>{};
    if (storyId.isEmpty) return result;

    try {
      final snap = await _db
          .collection('stories')
          .doc(storyId)
          .collection('reactions')
          .orderBy('reactedAt', descending: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final emoji = data['emoji'] as String? ?? '';
        if (emoji.isEmpty) continue;
        result.putIfAbsent(emoji, () => []);
        result[emoji]!.add({
          'uid': doc.id,
          'userName': data['userName'] ?? '',
          'userPhoto': data['userPhoto'] ?? '',
          'reactedAt': data['reactedAt'],
        });
      }
      return result;
    } catch (e) {
      debugPrint('❌ [Story] getReactions failed: $e');
      return result;
    }
  }

  // ============================================================
  // STREAM MY REACTION
  // ============================================================
  static Stream<String?> streamMyReaction(String storyId) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null || storyId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .collection('stories')
        .doc(storyId)
        .collection('reactions')
        .doc(myUid)
        .snapshots()
        .map((snap) => snap.exists ? (snap.data()?['emoji'] as String?) : null);
  }
}
