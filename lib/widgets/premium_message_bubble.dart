import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:matrimony_app/widgets/app_network_image.dart';

import 'voice_message_bubble.dart';

// ============================================================
// PREMIUM MESSAGE BUBBLE — WhatsApp Style
// ============================================================

class PremiumMessageBubble extends StatefulWidget {
  final String messageId;
  final Map<String, dynamic> data;
  final bool isMe;
  final bool isBangla;
  final bool isNextSame;
  final bool isPrevSame;
  final void Function(String messageId, String emoji) onReact;
  final void Function(Map<String, dynamic> replyData) onReply;
  final VoidCallback onDelete;

  const PremiumMessageBubble({
    super.key,
    required this.messageId,
    required this.data,
    required this.isMe,
    required this.isBangla,
    required this.onReact,
    required this.onReply,
    required this.onDelete,
    this.isNextSame = false,
    this.isPrevSame = false,
  });

  @override
  State<PremiumMessageBubble> createState() => _PremiumMessageBubbleState();
}

class _PremiumMessageBubbleState extends State<PremiumMessageBubble> {
  bool _showBigHeart = false;

  // ------------------------------------------------------------
  // WhatsApp palette
  // ------------------------------------------------------------
  static const Color _myBubble = Color(0xFF075E54);
  static const Color _otherBubble = Colors.white;
  static const Color _textColorMe = Colors.white;
  static const Color _textColorOther = Color(0xFF111B21);
  static const Color _timeColorMe = Color(0xFFB8D6D0);
  static const Color _timeColorOther = Color(0xFF667781);
  static const Color _readTickColor = Color(0xFF53BDEB);

  // ------------------------------------------------------------
  // Bubble radius constants
  // ------------------------------------------------------------
  static const double _roundRadius = 8.0;
  static const double _tailRadius = 0.0;

  // ============================================================
  // TIME FORMATTER
  // ============================================================
  String _fmtTime(dynamic ts) {
    if (ts == null) return '';
    try {
      return DateFormat('hh:mm a').format((ts as Timestamp).toDate());
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // STATUS ICON — ⏱️ sending · ⚠️ failed · ✓ sent · ✓✓ delivered · ✓✓ read
  // ============================================================
  Widget _buildStatus() {
    final localStatus = widget.data['_status'] as String?;

    if (localStatus == 'sending') {
      return const Icon(Icons.schedule, size: 13, color: _timeColorMe);
    }
    if (localStatus == 'failed') {
      return const Icon(
        Icons.error_outline,
        size: 14,
        color: Colors.redAccent,
      );
    }

    final isRead = widget.data['read'] == true;
    final isDelivered = widget.data['delivered'] == true;

    final IconData icon;
    final Color color;

    if (isRead) {
      icon = Icons.done_all;
      color = _readTickColor;
    } else if (isDelivered) {
      icon = Icons.done_all;
      color = _timeColorMe;
    } else {
      icon = Icons.done;
      color = _timeColorMe;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Icon(
        icon,
        key: ValueKey('$isRead-$isDelivered-$localStatus'),
        size: 14,
        color: color,
      ),
    );
  }

  // ============================================================
  // DOUBLE TAP → big heart
  // ============================================================
  void _handleDoubleTap() {
    if (widget.data['_status'] == 'sending' ||
        widget.data['_status'] == 'failed') {
      return;
    }
    setState(() => _showBigHeart = true);
    HapticFeedback.mediumImpact();
    widget.onReact(widget.messageId, '❤️');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showBigHeart = false);
    });
  }

  // ============================================================
  // BORDER RADIUS — WhatsApp style
  // ============================================================
  BorderRadius _buildRadius() {
    // Same sender → tight corner in the direction of the group
    final me = widget.isMe;

    return BorderRadius.only(
      topLeft: Radius.circular(
        me ? _roundRadius : (widget.isPrevSame ? _roundRadius : _roundRadius),
      ),
      topRight: Radius.circular(
        me ? (widget.isPrevSame ? _roundRadius : _roundRadius) : _roundRadius,
      ),
      bottomLeft: Radius.circular(
        me ? _roundRadius : (widget.isNextSame ? _tailRadius : _roundRadius),
      ),
      bottomRight: Radius.circular(
        me ? (widget.isNextSame ? _tailRadius : _roundRadius) : _roundRadius,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final type = widget.data['type'] as String? ?? 'text';
    final ts = widget.data['timestamp'];
    final reactions = widget.data['reactions'] as Map<String, dynamic>? ?? {};
    final replyTo = widget.data['replyTo'] as Map<String, dynamic>?;

    final isPending = widget.data['_status'] == 'sending' ||
        widget.data['_status'] == 'failed';

    // ✅ Ghost bubble guard
    final txt = (widget.data['text'] as String?)?.trim() ?? '';
    final url = (widget.data['mediaUrl'] as String?)?.trim() ?? '';
    final fname = (widget.data['fileName'] as String?)?.trim() ?? '';
    if (txt.isEmpty && url.isEmpty && fname.isEmpty) {
      return const SizedBox.shrink();
    }

    final br = _buildRadius();

    return Padding(
      padding: EdgeInsets.only(
        top: widget.isPrevSame ? 1.5 : 4,
        bottom: widget.isNextSame ? 1.5 : 4,
        left: widget.isMe ? 60 : 8,
        right: widget.isMe ? 8 : 60,
      ),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ---------------------------------------------------
                // MESSAGE BUBBLE
                // ---------------------------------------------------
                Dismissible(
                  key: ValueKey('d_${widget.messageId}'),
                  direction: isPending
                      ? DismissDirection.none
                      : DismissDirection.startToEnd,
                  confirmDismiss: (_) async {
                    if (isPending) return false;
                    widget.onReply({
                      'messageId': widget.messageId,
                      'senderName': widget.isMe
                          ? (widget.isBangla ? 'আপনি' : 'You')
                          : widget.data['senderName'] ?? 'User',
                      'text': widget.data['text'] ?? _replyLabel(type),
                    });
                    HapticFeedback.lightImpact();
                    return false;
                  },
                  background: const Padding(
                    padding: EdgeInsets.only(left: 20),
                    child: Icon(
                      Icons.reply,
                      color: Color(0xFF075E54),
                      size: 24,
                    ),
                  ),
                  child: GestureDetector(
                    onDoubleTap: isPending ? null : _handleDoubleTap,
                    onLongPress:
                        isPending ? null : () => _showContextMenu(context),
                    child: Opacity(
                      opacity: widget.data['_status'] == 'failed' ? 0.65 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.isMe ? _myBubble : _otherBubble,
                          borderRadius: br,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (replyTo != null) _buildReplyPreview(replyTo),
                            Padding(
                              padding: type == 'text' || type == 'voice'
                                  ? const EdgeInsets.fromLTRB(10, 7, 10, 0)
                                  : const EdgeInsets.all(4),
                              child: _buildContent(type),
                            ),
                            _buildMetaRow(type, ts),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // -----------------------------------------------
                // Big heart (double-tap feedback)
                // -----------------------------------------------
                if (_showBigHeart)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1.5),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, s, _) => Transform.scale(
                            scale: s,
                            child: Opacity(
                              opacity: (1.5 - s).clamp(0.0, 1.0),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                                size: 70,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // -----------------------------------------------
                // Reactions badge
                // -----------------------------------------------
                if (reactions.isNotEmpty)
                  Positioned(
                    bottom: -8,
                    right: widget.isMe ? 8 : null,
                    left: widget.isMe ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: reactions.values
                            .toSet()
                            .take(3)
                            .map<Widget>(
                              (e) => Text(
                                e.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                            .toList(),
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

  String _replyLabel(String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'voice':
        return '🎤 Voice';
      case 'file':
        return '📎 File';
      default:
        return '';
    }
  }

  // ============================================================
  // META ROW — time + status
  // ============================================================
  Widget _buildMetaRow(String type, dynamic ts) {
    final isText = type == 'text' || type == 'voice';

    return Padding(
      padding: EdgeInsets.only(
        left: isText ? 10 : 8,
        right: 8,
        bottom: isText ? 5 : 4,
        top: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _fmtTime(ts),
            style: TextStyle(
              fontSize: 10.5,
              color: widget.isMe ? _timeColorMe : _timeColorOther,
            ),
          ),
          if (widget.isMe) ...[
            const SizedBox(width: 3),
            _buildStatus(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // REPLY PREVIEW
  // ============================================================
  Widget _buildReplyPreview(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.black.withValues(alpha: 0.15)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: widget.isMe
                ? Colors.white.withValues(alpha: 0.9)
                : const Color(0xFF075E54),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r['senderName'] ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.isMe ? Colors.white : const Color(0xFF075E54),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            r['text'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.9)
                  : _textColorOther,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================
  Widget _buildContent(String type) {
    final textColor = widget.isMe ? _textColorMe : _textColorOther;

    final url = (widget.data['mediaUrl'] as String?)?.trim() ?? '';
    final txt = (widget.data['text'] as String?)?.trim() ?? '';

    switch (type) {
      case 'text':
        if (txt.isEmpty) return const SizedBox.shrink();
        return Text(
          txt,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
        );

      case 'image':
        if (url.isEmpty) return const SizedBox.shrink();
        return _buildImage(url);

      case 'video':
        if (url.isEmpty) return const SizedBox.shrink();
        return _VideoMessage(url: url);

      case 'voice':
        if (url.isEmpty) return const SizedBox.shrink();
        return VoiceMessageBubble(
          url: url,
          duration: (widget.data['duration'] ?? 0) as int,
          isMe: widget.isMe,
        );

      case 'file':
        if (url.isEmpty) return const SizedBox.shrink();
        return _buildFileBubble(textColor);

      default:
        // Unknown type — but text আছে? show as text
        if (txt.isNotEmpty) {
          return Text(
            txt,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
          );
        }
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // IMAGE
  // ============================================================
  Widget _buildImage(String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImage(url: url),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Hero(
          tag: 'img_${widget.messageId}',
          child: AppNetworkImage(
            url,
            width: 230,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => Container(
              width: 230,
              height: 170,
              color: Colors.grey.shade300,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Color(0xFF075E54),
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 230,
              height: 170,
              color: Colors.grey.shade300,
              child: const Icon(
                Icons.broken_image,
                color: Color(0xFF075E54),
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILE
  // ============================================================
  Widget _buildFileBubble(Color textColor) {
    final name = widget.data['fileName'] ?? 'File';
    final size = widget.data['fileSize'] as int? ?? 0;

    return GestureDetector(
      onTap: () async {
        final url = widget.data['mediaUrl'] ?? '';
        if (url.isEmpty) return;
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF075E54).withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.insert_drive_file,
                color: widget.isMe ? Colors.white : const Color(0xFF075E54),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fmtBytes(size),
                    style: TextStyle(
                      color: widget.isMe
                          ? Colors.white.withValues(alpha: 0.75)
                          : _textColorOther.withValues(alpha: 0.7),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ============================================================
  // CONTEXT MENU
  // ============================================================
  void _showContextMenu(BuildContext context) {
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
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Emoji row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '😂', '😮', '😢', '👍', '🔥']
                        .map(
                          (e) => GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              widget.onReact(widget.messageId, e);
                            },
                            child: Text(
                              e,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const Divider(height: 1),

                // Reply
                _menuItem(
                  icon: Icons.reply,
                  label: bn ? 'উত্তর' : 'Reply',
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onReply({
                      'messageId': widget.messageId,
                      'senderName': widget.isMe
                          ? (bn ? 'আপনি' : 'You')
                          : widget.data['senderName'] ?? 'User',
                      'text': widget.data['text'] ??
                          _replyLabel(widget.data['type'] ?? 'text'),
                    });
                  },
                ),

                // Copy (text only)
                if (widget.data['type'] == 'text')
                  _menuItem(
                    icon: Icons.copy,
                    label: bn ? 'কপি' : 'Copy',
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.data['text'] ?? ''),
                      );
                      Navigator.pop(ctx);
                    },
                  ),

                // Delete (own messages)
                if (widget.isMe)
                  _menuItem(
                    icon: Icons.delete_outline,
                    label: bn ? 'মুছুন' : 'Delete',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF075E54)),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFF111B21),
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ============================================================
// FULLSCREEN IMAGE
// ============================================================
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: AppNetworkImage(
            url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// VIDEO MESSAGE
// ============================================================
class _VideoMessage extends StatefulWidget {
  final String url;
  const _VideoMessage({required this.url});

  @override
  State<_VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<_VideoMessage> {
  VideoPlayerController? _ctrl;
  bool _init = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _init = true);
      });
    _ctrl!.addListener(() {
      if (mounted) setState(() => _playing = _ctrl!.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_init || _ctrl == null) {
      return Container(
        width: 240,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _ctrl!.value.aspectRatio,
            child: VideoPlayer(_ctrl!),
          ),
          GestureDetector(
            onTap: () {
              if (_ctrl!.value.isPlaying) {
                _ctrl!.pause();
              } else {
                _ctrl!.play();
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(
                _playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
