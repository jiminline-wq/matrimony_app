import 'package:flutter/material.dart';

// ============================================================
// VERIFIED BADGE — Blue tick with animation
// Reusable — যেকোনো জায়গায় ব্যবহার করা যাবে
// ============================================================

class VerifiedBadge extends StatelessWidget {
  final double size;
  final bool showTooltip;

  const VerifiedBadge({super.key, this.size = 18, this.showTooltip = true});

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(Icons.check, color: Colors.white, size: size * 0.7),
    );

    if (!showTooltip) return badge;

    return Tooltip(message: 'Verified Profile', child: badge);
  }
}

// ============================================================
// VERIFIED NAME — Name + Badge একসাথে
// ============================================================

class VerifiedName extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const VerifiedName({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return Text(name, style: style, maxLines: maxLines, overflow: overflow);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
        const SizedBox(width: 4),
        const VerifiedBadge(size: 16),
      ],
    );
  }
}
