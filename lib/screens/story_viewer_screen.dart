import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/story.dart';
import '../services/story_service.dart';
import '../theme/colors.dart';
import '../ads/banner_ad_widget.dart'; // ✅ ব্যানার অ্যাড ইমপোর্ট
import '../ads/ad_config.dart'; // ✅ অ্যাড কনফিগ ইমপোর্ট

class StoryViewerScreen extends StatefulWidget {
  final List<UserStories> users;
  final int initialUserIndex;

  const StoryViewerScreen({
    super.key,
    required this.users,
    required this.initialUserIndex,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _FlatStory {
  final UserStories user;
  final Story story;
  _FlatStory(this.user, this.story);
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late List<_FlatStory> _flat;
  late PageController _pageCtrl;
  late AnimationController _progress;
  int _index = 0;
  bool _paused = false;

  // ✅ Reaction state
  String? _myReaction;
  StreamSubscription<String?>? _myReactionSub;
  bool _showReactionPicker = false;
  final _reactionEmojis = const ['❤️', '😂', '😍', '👏', '😮', '😢'];
  String? _floatingEmoji;
  Map<String, dynamic>? _myProfile;

  // Video controller (only one at a time)
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _flat = [];
    for (final u in widget.users) {
      for (final s in u.stories) {
        _flat.add(_FlatStory(u, s));
      }
    }

    // Find start index (first story of initialUserIndex)
    int start = 0;
    int count = 0;
    for (int i = 0; i < widget.users.length; i++) {
      if (i == widget.initialUserIndex) {
        start = count;
        break;
      }
      count += widget.users[i].stories.length;
    }

    _index = start;
    _pageCtrl = PageController(initialPage: start);

    _progress =
        AnimationController(vsync: this, duration: const Duration(seconds: 15));
    _progress.addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

    // Load my profile once for reactions
    _loadMyProfileOnce();

    _startCurrent();
  }

  // ============================================================
  // LOAD MY PROFILE (for reactions)
  // ============================================================
  Future<void> _loadMyProfileOnce() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      _myProfile = doc.data();
    } catch (_) {}
  }

  // ============================================================
  // START CURRENT STORY
  // ============================================================
  Future<void> _startCurrent() async {
    if (_index < 0 || _index >= _flat.length) return;

    // Clean previous video
    await _video?.dispose();
    _video = null;

    // ✅ Reset reaction state and cancel listener
    await _myReactionSub?.cancel();
    _myReactionSub = null;
    _myReaction = null;
    _showReactionPicker = false;

    final story = _flat[_index].story;

    // Mark viewed
    StoryService.markViewed(story.id);

    // ✅ Subscribe to my reaction for this story
    _myReactionSub = StoryService.streamMyReaction(story.id).listen((emoji) {
      if (mounted) setState(() => _myReaction = emoji);
    });

    // Setup progress duration
    _progress.duration = Duration(seconds: story.durationSeconds);

    // If video → initialize & play
    if (story.isVideo) {
      try {
        final v = VideoPlayerController.networkUrl(Uri.parse(story.mediaUrl));
        await v.initialize();
        await v.setLooping(false);
        await v.play();
        _video = v;
        if (mounted) setState(() {});
      } catch (_) {}
    }

    _progress.forward(from: 0);
  }

  void _next() {
    if (_index < _flat.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_index > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _pause() {
    if (_paused) return;
    _paused = true;
    _progress.stop();
    _video?.pause();
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _progress.forward();
    _video?.play();
  }

  // ============================================================
  // SEND REACTION
  // ============================================================
  Future<void> _sendReaction(String emoji) async {
    if (_index < 0 || _index >= _flat.length) return;

    final current = _flat[_index];
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    // Can't react to own story
    if (current.story.uid == myUid) return;

    // Ensure profile loaded
    if (_myProfile == null) {
      await _loadMyProfileOnce();
    }

    final myName = (_myProfile?['name'] ?? '').toString();
    final myPhoto = (_myProfile?['photoUrl'] ?? '').toString();

    // Toggle: same emoji → remove, different → replace
    if (_myReaction == emoji) {
      await StoryService.removeReaction(current.story.id);
      if (mounted) {
        setState(() {
          _myReaction = null;
          _showReactionPicker = false;
        });
      }
    } else {
      // Floating animation trigger
      setState(() {
        _floatingEmoji = emoji;
        _showReactionPicker = false;
      });

      HapticFeedback.lightImpact();

      await StoryService.addReaction(
        storyId: current.story.id,
        emoji: emoji,
        userName: myName,
        userPhoto: myPhoto,
      );

      // Clear floating animation after 800ms
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _floatingEmoji = null);
      });
    }
  }

  // ============================================================
  // DELETE STORY
  // ============================================================
  Future<void> _deleteCurrent() async {
    final s = _flat[_index].story;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Story মুছবেন?'),
        content: const Text('এই story স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('হ্যাঁ, মুছুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await StoryService.deleteStory(s);
    if (!mounted) return;

    setState(() {
      _flat.removeAt(_index);
    });

    if (_flat.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_index >= _flat.length) _index = _flat.length - 1;
    _pageCtrl.jumpToPage(_index);
    _startCurrent();
  }

  @override
  void dispose() {
    _video?.dispose();
    _progress.dispose();
    _pageCtrl.dispose();
    _myReactionSub?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_flat.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final current = _flat[_index];
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = current.story.uid == myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ================= Media =================
            PageView.builder(
              controller: _pageCtrl,
              itemCount: _flat.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                _startCurrent();
              },
              itemBuilder: (_, i) {
                final item = _flat[i];
                if (item.story.isVideo) {
                  if (i == _index &&
                      _video != null &&
                      _video!.value.isInitialized) {
                    return Center(
                      child: AspectRatio(
                        aspectRatio: _video!.value.aspectRatio,
                        child: VideoPlayer(_video!),
                      ),
                    );
                  }
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                }
                return Center(
                  child: CachedNetworkImage(
                    imageUrl: item.story.mediaUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 64),
                    ),
                  ),
                );
              },
            ),

            // ================= Tap zones =================
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _prev,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _next,
                  ),
                ),
              ],
            ),

            // ================= Progress bars =================
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(
                  current.user.stories.length,
                  (i) {
                    final idxInUser = _indexInUser(current.user);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _Bar(
                          value: i < idxInUser
                              ? 1.0
                              : (i == idxInUser ? null : 0.0),
                          progress: _progress,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ================= Top header =================
            Positioned(
              top: MediaQuery.of(context).padding.top + 24,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  ClipOval(
                    child: current.user.userPhoto.isEmpty
                        ? Container(
                            width: 36,
                            height: 36,
                            color: Colors.grey.shade700,
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 20))
                        : CachedNetworkImage(
                            imageUrl: current.user.userPhoto,
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.user.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _timeAgo(current.story.createdAt),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isMine)
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.white, size: 22),
                      onPressed: _deleteCurrent,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ================= Caption =================
            if (current.story.caption != null &&
                current.story.caption!.isNotEmpty)
              Positioned(
                bottom: isMine ? 90 : 160, // ✅ অ্যাডের জন্য একটু উপরে সরানো হলো
                left: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    current.story.caption!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ================= Floating emoji animation =================
            if (_floatingEmoji != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, -100 * value),
                          child: Opacity(
                            opacity: (1 - value).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1.0 + (value * 0.5),
                              child: Text(
                                _floatingEmoji!,
                                style: const TextStyle(fontSize: 72),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

            // ================= Reaction bar =================
            if (!isMine)
              Positioned(
                left: 16,
                right: 16,
                bottom: 80 +
                    MediaQuery.of(context)
                        .padding
                        .bottom, // ✅ অ্যাডের জন্য উপরে সরানো হলো
                child: _buildReactionBar(),
              ),

            // ================= Banner Ad =================
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: BannerAdWidget(
                  placementId: AdConfig.placementStoryDetails,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REACTION BAR
  // ============================================================
  Widget _buildReactionBar() {
    if (_showReactionPicker) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _reactionEmojis.map((emoji) {
            final isSelected = _myReaction == emoji;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _sendReaction(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? primaryGold.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: isSelected ? 32 : 28,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _showReactionPicker = true),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_myReaction != null) ...[
                Text(
                  _myReaction!,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  'Your reaction',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.favorite_border,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'React to story',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _indexInUser(UserStories u) {
    int flatStart = 0;
    for (int i = 0; i < widget.users.length; i++) {
      if (widget.users[i].uid == u.uid) {
        return _index - flatStart;
      }
      flatStart += widget.users[i].stories.length;
    }
    return 0;
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'এইমাত্র';
    if (d.inMinutes < 60) return '${d.inMinutes} মিনিট আগে';
    if (d.inHours < 24) return '${d.inHours} ঘন্টা আগে';
    return '${d.inDays} দিন আগে';
  }
}

class _Bar extends StatelessWidget {
  final double? value;
  final AnimationController progress;

  const _Bar({required this.value, required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 3,
        child: value != null
            ? LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              )
            : AnimatedBuilder(
                animation: progress,
                builder: (_, __) => LinearProgressIndicator(
                  value: progress.value,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
      ),
    );
  }
}
