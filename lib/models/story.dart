import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryMediaType { image, video }

class Story {
  final String id;
  final String uid;
  final String userName;
  final String userPhoto;
  final String mediaUrl;
  final StoryMediaType type;
  final int durationSeconds; // 15 (image-এ default), video-তে actual
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;
  final int reactionCount; // ✅ NEW

  Story({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.mediaUrl,
    required this.type,
    required this.durationSeconds,
    required this.createdAt,
    required this.expiresAt,
    required this.viewers,
    this.caption,
    this.reactionCount = 0, // ✅ NEW
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isVideo => type == StoryMediaType.video;

  factory Story.fromDoc(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    return Story(
      id: doc.id,
      uid: d['uid'] ?? '',
      userName: d['userName'] ?? '',
      userPhoto: d['userPhoto'] ?? '',
      mediaUrl: d['mediaUrl'] ?? '',
      type: d['type'] == 'video' ? StoryMediaType.video : StoryMediaType.image,
      durationSeconds: (d['durationSeconds'] as num?)?.toInt() ?? 15,
      caption: d['caption'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewers: List<String>.from(d['viewers'] ?? const []),
      reactionCount: (d['reactionCount'] as num?)?.toInt() ?? 0, // ✅ NEW
    );
  }
}

/// একটি user-এর সব story একসাথে (row-এ একটি avatar represent করে)
class UserStories {
  final String uid;
  final String userName;
  final String userPhoto;
  final List<Story> stories;

  UserStories({
    required this.uid,
    required this.userName,
    required this.userPhoto,
    required this.stories,
  });

  bool hasUnseen(String myUid) {
    return stories.any((s) => !s.viewers.contains(myUid));
  }

  Story get latest => stories.first;
}
