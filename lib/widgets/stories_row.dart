import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:matrimony_app/widgets/app_network_image.dart';

import '../models/story.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';
import '../services/story_service.dart';
import '../theme/colors.dart';

// ============================================================
// STORIES ROW — Instagram-style with Story Media Preview
// ============================================================

class StoriesRow extends StatefulWidget {
  final bool isBangla;
  final String myName;
  final String myPhoto;

  const StoriesRow({
    super.key,
    required this.isBangla,
    required this.myName,
    required this.myPhoto,
  });

  @override
  State<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<StoriesRow> {
  List<UserStories> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await StoryService.fetchActiveStories();
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(
          isBangla: widget.isBangla,
          userName: widget.myName,
          userPhoto: widget.myPhoto,
        ),
      ),
    );
    if (result == true) _load();
  }

  void _openViewer(int userIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          users: _users,
          initialUserIndex: userIndex,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200);
    }

    final bn = widget.isBangla;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    // My story + other users
    final myStory =
        _users.where((u) => u.uid == myUid).cast<UserStories?>().firstOrNull;
    final otherUsers = _users.where((u) => u.uid != myUid).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HEADER
          // ============================================================
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryGold, primaryMaroon],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  bn ? 'স্টোরিজ' : 'Stories',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: deepMaroon,
                  ),
                ),
                const SizedBox(width: 6),
                if (_users.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: lightMaroon,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_users.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryMaroon,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  bn ? '২৪ ঘন্টা' : '24h',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryText.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ============================================================
          // STORY CARDS
          // ============================================================
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // ===== MY STORY =====
                _StoryMediaCard(
                  name: bn ? 'আপনার গল্প' : 'Your Story',
                  userPhoto: widget.myPhoto,
                  latestStory: myStory?.latest,
                  isMyStory: true,
                  hasUnseen: false,
                  hasStories: myStory != null, // ✅ NEW
                  storyCount: myStory?.stories.length ?? 0,
                  isBangla: bn,
                  onTap: () {
                    if (myStory != null) {
                      final i = _users.indexWhere((u) => u.uid == myUid);
                      if (i >= 0) _openViewer(i);
                    } else {
                      _openCreate();
                    }
                  },
                  onAdd: _openCreate,
                ),
                // ===== OTHER USERS =====
                ...otherUsers.asMap().entries.map((entry) {
                  final u = entry.value;
                  final globalIndex = _users.indexWhere((x) => x.uid == u.uid);
                  final hasUnseen = myUid != null && u.hasUnseen(myUid);

                  return _StoryMediaCard(
                    name: u.userName,
                    userPhoto: u.userPhoto,
                    latestStory: u.latest,
                    hasStories: true,
                    hasUnseen: hasUnseen,
                    storyCount: u.stories.length,
                    isBangla: bn,
                    onTap: () => _openViewer(globalIndex),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STORY MEDIA CARD — shows latest story media as thumbnail
// ============================================================
class _StoryMediaCard extends StatelessWidget {
  final String name;
  final String userPhoto;
  final Story? latestStory;
  final bool hasUnseen;
  final bool hasStories;
  final bool isMyStory;
  final int storyCount;
  final bool isBangla;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _StoryMediaCard({
    required this.name,
    required this.userPhoto,
    required this.latestStory,
    required this.hasUnseen,
    required this.storyCount,
    required this.isBangla,
    required this.onTap,
    this.isMyStory = false,
    this.hasStories = false,
    this.onAdd,
  });

  /// Cloudinary video → convert to thumbnail URL
  /// video/upload/xyz.mp4 → video/upload/xyz.jpg
  String? _getVideoThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return null;
    try {
      // Match Cloudinary video URLs
      if (videoUrl.contains('/video/upload/')) {
        return videoUrl
            .replaceAll('.mp4', '.jpg')
            .replaceAll('.mov', '.jpg')
            .replaceAll('.webm', '.jpg')
            .replaceAll('.avi', '.jpg');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which media to show as background
    String? backgroundImage;
    bool showPlayIcon = false;

    if (latestStory != null) {
      if (latestStory!.isVideo) {
        // Try video thumbnail
        backgroundImage = _getVideoThumbnail(latestStory!.mediaUrl);
        showPlayIcon = true;
        // If thumbnail fails, fallback to userPhoto
        if (backgroundImage == null || backgroundImage.isEmpty) {
          backgroundImage = userPhoto;
        }
      } else {
        // Image story
        backgroundImage = latestStory!.mediaUrl;
      }
    } else {
      // No story → show user's profile photo
      backgroundImage = userPhoto;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== CARD WITH MEDIA =====
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Gradient border wrapper
                Container(
                  width: 110,
                  height: 150,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: !hasStories
                        ? LinearGradient(
                            colors: [
                              Colors.grey.shade300,
                              Colors.grey.shade200,
                            ],
                          )
                        : hasUnseen
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  primaryGold,
                                  primaryMaroon,
                                  primaryGold,
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade300,
                                ],
                              ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: lightMaroon,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // ===== MEDIA (story thumbnail OR profile) =====
                        if (backgroundImage.isNotEmpty)
                          AppNetworkImage(
                            backgroundImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: lightMaroon,
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  color: primaryMaroon,
                                  size: 32,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: lightMaroon,
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  color: primaryMaroon,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        else
                          // Empty — show avatar
                          Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: lightMaroon,
                                border: Border.all(
                                  color: primaryMaroon.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: userPhoto.isNotEmpty
                                    ? AppNetworkImage(
                                        userPhoto,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: primaryMaroon,
                                        size: 32,
                                      ),
                              ),
                            ),
                          ),

                        // ===== Dark gradient overlay at bottom =====
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                                stops: const [0.0, 0.55, 1.0],
                              ),
                            ),
                          ),
                        ),

                        // ===== Play icon for video stories =====
                        if (showPlayIcon)
                          Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        // ===== User avatar (top-left, small) =====
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            width: 28,
                            height: 28,
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: hasUnseen ? primaryGold : Colors.white,
                                width: hasUnseen ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: userPhoto.isNotEmpty
                                  ? AppNetworkImage(
                                      userPhoto,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: primaryMaroon,
                                      size: 14,
                                    ),
                            ),
                          ),
                        ),

                        // ===== "NEW" badge for unseen =====
                        if (hasUnseen && !isMyStory)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryGold, primaryMaroon],
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryMaroon.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),

                        // ===== Story count (bottom-right, if >1) =====
                        if (hasStories && storyCount > 1)
                          Positioned(
                            bottom: 30,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.layers,
                                    color: Colors.white,
                                    size: 9,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$storyCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // ===== Name overlay (bottom) =====
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 8,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ===== My story empty state =====
                        if (isMyStory && !hasStories)
                          Container(
                            color: lightMaroon.withValues(alpha: 0.9),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [primaryGold, primaryMaroon],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isBangla ? 'Story যোগ করুন' : 'Add Story',
                                  style: const TextStyle(
                                    color: primaryMaroon,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ===== Floating "+" for my story (bottom-right) =====
                if (isMyStory && onAdd != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [primaryGold, primaryMaroon],
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryMaroon.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 6),

            // ===== Subtitle below card (for my story) =====
            if (isMyStory)
              SizedBox(
                width: 110,
                child: Text(
                  hasStories
                      ? (isBangla ? 'আপনার গল্প' : 'Your story')
                      : (isBangla ? 'যোগ করুন' : 'Add now'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasStories ? primaryMaroon : secondaryText,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
